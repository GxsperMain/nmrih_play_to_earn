#include <sourcemod>
#include <json>
#include <regex.inc>

public Plugin myinfo =
{
    name        = "Play To Earn",
    author      = "Gxsper",
    description = "Play to Earn for No More Room in Hell",
    version     = SOURCEMOD_VERSION,
    url         = "https://github.com/GxsperMain/nmrih_play_to_earn"
};

Database    walletsDB;

JSON_Object onlinePlayers;    // Stores online players datas `https://wiki.alliedmods.net/Generic_Source_Server_Events#player_connect

bool        alertNonWalletRegisteredPlayers = true;
bool        alertPlayerIncomings            = true;

char        waveRewards[15][20]             = { "100000000000000000", "10000000000000000", "100000000000000000",
                             "100000000000000000", "200000000000000000", "200000000000000000",
                             "200000000000000000", "200000000000000000", "200000000000000000",
                             "200000000000000000", "200000000000000000", "200000000000000000",
                             "200000000000000000", "200000000000000000", "300000000000000000" };
int         maxWaves                        = 15;
char        waveRewardsShow[15][20]         = { "0.1", "0.1", "0.1",
                                 "0.1", "0.2", "0.2",
                                 "0.2", "0.2", "0.2",
                                 "0.2", "0.2", "0.2",
                                 "0.2", "0.2", "0.3" };

int         serverWave                      = 0;
int         playerAlives                    = 0;

public void OnPluginStart()
{
    PrintToServer("PLAY TO EARN: 1.1");

    char walletDBError[32];
    walletsDB = SQL_Connect("default", true, walletDBError, sizeof(walletDBError));
    if (walletsDB == null)
    {
        PrintToServer("[PTE] ERROR Connecting to the database: %s", walletDBError);
        PrintToServer("[PTE] The plugin will stop now...");
        return;
    }

    onlinePlayers = new JSON_Object();

    // Player connected
    HookEvent("player_connect", OnPlayerConnect, EventHookMode_Post);

    // Player disconnected
    HookEventEx("player_disconnect", OnPlayerDisconnect, EventHookMode_Post);

    // Wallet command
    RegConsoleCmd("wallet", CommandRegisterWallet, "Set up your Wallet address");

    // Wave Start
    HookEventEx("new_wave", OnWaveStart, EventHookMode_Post);

    // Survival Start
    HookEventEx("nmrih_round_begin", OnSurvivalStart, EventHookMode_PostNoCopy);

    // Player Started playing
    HookEvent("player_active", OnPlayerActive, EventHookMode_Post);

    // Player died
    HookEvent("player_death", OnPlayerDie, EventHookMode_Post);

    // Player spawn
    HookEvent("player_spawn", OnPlayerSpawn, EventHookMode_Post);

    if (alertNonWalletRegisteredPlayers)
    {
        // Player Warning
        CreateTimer(300.0, WarnPlayersWithoutWallet, _, TIMER_REPEAT);
    }

    PrintToServer("[PTE] Play to Earn plugin has been initialized");
}

//
// EVENTS
//
public void OnPlayerConnect(Event event, const char[] name, bool dontBroadcast)
{
    char playerName[32];
    char networkId[32];
    char address[32];
    int  index  = event.GetInt("index");
    int  userId = event.GetInt("userid");
    bool isBot  = event.GetBool("bot");

    event.GetString("name", playerName, sizeof(playerName));
    event.GetString("networkid", networkId, sizeof(networkId));
    event.GetString("address", address, sizeof(address));

    if (!isBot)
    {
        JSON_Object playerObj = new JSON_Object();
        playerObj.SetString("playerName", playerName);
        playerObj.SetString("networkId", networkId);
        playerObj.SetString("address", address);
        playerObj.SetInt("userId", userId);
        playerObj.SetInt("index", index);
        playerObj.SetInt("walletStatus", -1);

        char userIdStr[32];
        IntToString(userId, userIdStr, sizeof(userIdStr));

        onlinePlayers.SetObject(userIdStr, playerObj);

        PrintToServer("[PTE] Player Connected: Name: %s | ID: %d | Index: %d | SteamID: %s | IP: %s | Bot: %d",
                      playerName, userId, index, networkId, address, isBot);
    }
}

public void OnPlayerDisconnect(Event event, const char[] name, bool dontBroadcast)
{
    char playerName[64];
    char networkId[32];
    char reason[128];
    int  userId = event.GetInt("userid");
    bool isBot  = event.GetBool("bot");

    event.GetString("name", playerName, sizeof(playerName));
    event.GetString("networkid", networkId, sizeof(networkId));
    event.GetString("reason", reason, sizeof(reason));

    if (!isBot)
    {
        int length     = onlinePlayers.Length;
        int key_length = 0;
        for (int i = 0; i < length; i += 1)
        {
            key_length = onlinePlayers.GetKeySize(i);
            char[] key = new char[key_length];
            onlinePlayers.GetKey(i, key, key_length);

            JSON_Object playerObj = onlinePlayers.GetObject(key);
            if (playerObj == INVALID_HANDLE)
            {
                PrintToServer("[PTE] [OnPlayerDisconnect] ERROR: %s have any invalid player object", key);
                continue;
            }

            if (playerObj.GetInt("userId") == userId)
            {
                onlinePlayers.Remove(key);
                playerObj.Cleanup();
                playerObj = null;
                json_cleanup_and_delete(playerObj);
            }
        }

        PrintToServer("[PTE] Player Disconnected: Name: %s | ID: %d | SteamID: %s | Reason: %s | Bot: %d",
                      playerName, userId, networkId, reason, isBot);
    }
}

public void OnWaveStart(Event event, const char[] name, bool dontBroadcast)
{
    if (serverWave > 0)
    {
        OnWaveFinish();
    }

    bool isSupply = event.GetBool("resupply");
    if (!isSupply)
    {
        serverWave++;
    }

    PrintToServer("[PTE] Wave %d Started, supply: %b", serverWave, isSupply);
    WarnPlayersWithoutWallet(null);
}

public void OnSurvivalStart(Event event, const char[] name, bool dontBroadcast)
{
    serverWave = 0;

    PrintToServer("[PTE] Survival Started");
    WarnPlayersWithoutWallet(null);
}

public void OnWaveFinish()
{
    int indexReward = 0;
    // Minus 1 is required because waves starts in 1 not 0
    if (serverWave > maxWaves)
    {
        indexReward = maxWaves - 1;
    }
    else {
        indexReward = serverWave - 1;
    }

    char currentEarning[20];
    char textToShow[20];
    strcopy(currentEarning, sizeof(currentEarning), waveRewards[indexReward]);
    strcopy(textToShow, sizeof(textToShow), waveRewardsShow[indexReward]);

    int length     = onlinePlayers.Length;
    int key_length = 0;
    for (int i = 0; i < length; i += 1)
    {
        key_length = onlinePlayers.GetKeySize(i);
        char[] key = new char[key_length];
        onlinePlayers.GetKey(i, key, key_length);

        JSON_Object playerObj = onlinePlayers.GetObject(key);
        if (playerObj == INVALID_HANDLE)
        {
            PrintToServer("[PTE] [OnWaveFinish] ERROR: %s have any invalid player object", key);
            continue;
        }

        int client = GetClientOfUserId(playerObj.GetInt("userId"));
        if (IsFakeClient(client)) continue;
        if (!IsClientInGame(client)) continue;

        char playerName[32];
        playerObj.GetString("playerName", playerName, sizeof(playerName));

        if (playerObj.GetBool("dead", true))
        {
            PrintToServer("[PTE] Ignoring %s because he is dead", playerName);
            continue;
        }

        char outputText[32];
        Format(outputText, sizeof(outputText), "%s PTE", textToShow);

        IncrementWallet(GetClientOfUserId(playerObj.GetInt("userId")), currentEarning, outputText, ", for Surviving");
    }

    PrintToServer("[PTE] Wave %d Finished", serverWave);
}

public void OnPlayerActive(Event event, const char[] name, bool dontBroadcast)
{
    int  userId = event.GetInt("userid");

    char userIdStr[32];
    IntToString(userId, userIdStr, sizeof(userIdStr));

    if (!JsonContains(onlinePlayers, userIdStr))
    {
        PrintToServer("[PTE] [OnPlayerActive] ERROR: Invalid user id, not present in online players");
        return;
    }

    JSON_Object playerObj = onlinePlayers.GetObject(userIdStr);

    if (playerObj.GetInt("walletStatus") == -1)
    {
        int client = GetClientOfUserId(userId);
        if (WalletRegistered(GetSteamAccountID(client)))
        {
            playerObj.SetInt("walletStatus", 1);
        }
        else {
            playerObj.SetInt("walletStatus", 0);
            WarnPlayerWithoutWallet(client);
        }
    }

    PrintToServer("[PTE] Player started playing %d", userId);
}

public void OnPlayerDie(Event event, const char[] name, bool dontBroadcast)
{
    int userId = event.GetInt("userid");

    playerAlives--;
    PrintToServer("[PTE] Player died %d, Total Alive: %d", userId, playerAlives);

    char userIdStr[32];
    IntToString(userId, userIdStr, sizeof(userIdStr));

    if (!JsonContains(onlinePlayers, userIdStr))
    {
        PrintToServer("[PTE] [OnPlayerDie] ERROR: Invalid user id, not present in online players");
        return;
    }

    JSON_Object playerObj = onlinePlayers.GetObject(userIdStr);

    playerObj.SetBool("dead", true);
}

public void OnPlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
    int userId = event.GetInt("userid");

    PrintToServer("[PTE] Player spawned %d", userId);
    playerAlives++;

    char userIdStr[32];
    IntToString(userId, userIdStr, sizeof(userIdStr));

    if (!JsonContains(onlinePlayers, userIdStr))
    {
        PrintToServer("[PTE] [OnPlayerSpawn] ERROR: Invalid user id, not present in online players");
        return;
    }

    JSON_Object playerObj = onlinePlayers.GetObject(userIdStr);

    playerObj.SetBool("dead", false);
}
//
//
//

//
// Commands
//
public Action CommandRegisterWallet(int client, int args)
{
    if (args < 1)
    {
        PrintToChat(client, "You can set your wallet in your discord: discord.gg/vGHxVsXc4Q");
        PrintToChat(client, "Or you can setup using !wallet 0x123...");
        return Plugin_Handled;
    }
    char walletAddress[256];
    GetCmdArgString(walletAddress, sizeof(walletAddress));

    if (ValidAddress(walletAddress))
    {
        char indexStr[32];
        IntToString(GetClientUserId(client), indexStr, sizeof(indexStr));

        JSON_Object playerObj = onlinePlayers.GetObject(indexStr);
        if (playerObj == INVALID_HANDLE)
        {
            PrintToServer("[PTE] [CommandRegisterWallet] ERROR: %s have any invalid player object", indexStr);
            return Plugin_Handled;
        }

        int  steamId = GetSteamAccountID(client);

        // Updating player in database
        char query[512];
        Format(query, sizeof(query),
               "UPDATE nmrih SET walletaddress = '%s' WHERE uniqueid = '%d';",
               walletAddress, steamId);

        // Running the update method
        if (!SQL_Query(walletsDB, query))
        {
            char error[255];
            SQL_GetError(walletsDB, error, sizeof(error));
            PrintToServer("[PTE] Cannot update %d wallet", steamId);
            PrintToServer(error);
            PrintToChat(client, "Any error occurs when setting up your wallet, contact the server owner");
        }
        else
        {
            int affectedRows = SQL_GetAffectedRows(walletsDB);
            if (affectedRows == 0)
            {
                // Updating player in database
                char query2[512];
                Format(query2, sizeof(query2),
                       "INSERT INTO nmrih (uniqueid, walletaddress) VALUES ('%d', '%s');",
                       steamId, walletAddress);

                // Running the update method
                if (!SQL_Query(walletsDB, query2))
                {
                    char error[255];
                    SQL_GetError(walletsDB, error, sizeof(error));
                    PrintToServer("[PTE] Cannot update %d wallet", steamId);
                    PrintToServer(error);
                    PrintToChat(client, "Any error occurs when setting up your wallet, contact the server owner");
                }
                else
                {
                    int affectedRows2 = SQL_GetAffectedRows(walletsDB);
                    if (affectedRows2 == 0)
                    {
                        PrintToChat(client, "Any error occurs when setting up your wallet, contact the server owner");
                        PrintToServer("[PTE] No rows updated for %d wallet. The uniqueid might not exist.", steamId);
                    }
                    else
                    {
                        PrintToChat(client, "Wallet set! you may now receive PTE while playing, have fun");
                        PrintToServer("[PTE] Updated %d wallet to: %s", steamId, walletAddress);
                        playerObj.SetInt("walletStatus", 1);
                    }
                }
            }
            else
            {
                PrintToChat(client, "Wallet updated!");
                PrintToServer("[PTE] Updated %d wallet to: %s", steamId, walletAddress);
            }
        }
    }
    else {
        PrintToChat(client, "The wallet address provided is invalid, if you need help you can ask in your discord: discord.gg/vGHxVsXc4Q");
    }

    return Plugin_Handled;
}

//
//
//

//
// Utils
//
public Action WarnPlayersWithoutWallet(Handle timer)
{
    int length     = onlinePlayers.Length;
    int key_length = 0;
    for (int i = 0; i < length; i += 1)
    {
        key_length = onlinePlayers.GetKeySize(i);
        char[] key = new char[key_length];
        onlinePlayers.GetKey(i, key, key_length);

        JSON_Object playerObj = onlinePlayers.GetObject(key);
        if (playerObj == INVALID_HANDLE)
        {
            PrintToServer("[PTE] [WarnPlayersWithoutWallet] ERROR: %s have any invalid player object", key);
            return Plugin_Continue;
        }

        if (playerObj.GetInt("walletStatus") == 0)
        {
            WarnPlayerWithoutWallet(GetClientOfUserId(playerObj.GetInt("userId")));
        }
    }
    return Plugin_Continue;
}

public void WarnPlayerWithoutWallet(int client)
{
    PrintToChat(client, "[PTE] You do not have a wallet set yet, find out more on our discord: discord.gg/vGHxVsXc4Q");
}

void IncrementWallet(
    int client,
    char[] valueToIncrement,
    char[] valueToShow = "0 PTE",
    char[] reason      = ", for Playing")
{
    int steamId = GetSteamAccountID(client);

    if (walletsDB == null)
    {
        PrintToServer("[PTE] ERROR: database is not connected");
        return;
    }

    // Checking player existance in database
    char checkQuery[128];
    Format(checkQuery, sizeof(checkQuery),
           "SELECT COUNT(*) FROM nmrih WHERE uniqueid = '%d';",
           steamId);

    // Checking the player uniqueid existance
    DBResultSet hQuery = SQL_Query(walletsDB, checkQuery);
    if (hQuery == null)
    {
        char error[255];
        SQL_GetError(walletsDB, error, sizeof(error));
        PrintToServer("[PTE] Error checking if %d exists: %s", steamId, error);
        return;
    }
    else {
        while (SQL_FetchRow(hQuery))
        {
            int index = SQL_FetchInt(hQuery, 0);
            if (index == 0)
            {
                PrintToServer("[PTE] [IncrementWallet] uniqueid \"%d\" not found.", steamId);
                return
            }
            else if (index > 1) {
                PrintToServer("[PTE] ERROR: uniqueid \"%d\" is on multiples rows, you setup the database wrongly, please check it. rows: %d", steamId, index);
                return;
            }
            else {
                PrintToServer("[PTE] [IncrementWallet] uniqueid \"%d\" was found in index. %d", steamId, index);
                break;
            }
        }
    }

    // Updating player in database
    char query[512];
    Format(query, sizeof(query),
           "UPDATE nmrih SET value = value + %s WHERE uniqueid = '%d';",
           valueToIncrement, steamId);

    // Running the update method
    if (!SQL_FastQuery(walletsDB, query))
    {
        char error[255];
        SQL_GetError(walletsDB, error, sizeof(error));
        PrintToServer("[PTE] Cannot increment %d values", steamId);
        PrintToServer(error);
    }
    else
    {
        if (alertPlayerIncomings)
            PrintToChat(client, "[PTE] You received: %s%s", valueToShow, reason);
        PrintToServer("[PTE] Incremented %d value: %s, reason: '%s'", steamId, valueToIncrement, reason);
    }
}

bool JsonContains(JSON_Object obj, const char[] keyToCheck)
{
    int length     = obj.Length;
    int key_length = 0;
    for (int i = 0; i < length; i += 1)
    {
        key_length = obj.GetKeySize(i);
        char[] key = new char[key_length];
        obj.GetKey(i, key, key_length);

        if (StrEqual(keyToCheck, key))
        {
            return true;
        }
    }
    return false;
}

bool ValidAddress(const char[] address)
{
    char       error[128];
    RegexError errcode;
    Regex      regex = CompileRegex("^[a-zA-Z0-9]{42}$");

    if (errcode != REGEX_ERROR_NONE)
    {
        PrintToServer("[PTE] Wrong regex typed: %s", error);
        return false;
    }

    int result = regex.Match(address);
    return result > 0;
}

bool WalletRegistered(const int steamId)
{
    char checkQuery[128];
    Format(checkQuery, sizeof(checkQuery),
           "SELECT COUNT(*) FROM nmrih WHERE uniqueid = '%d';",
           steamId);

    // Checking the player uniqueid existance
    DBResultSet hQuery = SQL_Query(walletsDB, checkQuery);
    if (hQuery == null)
    {
        char error[128];
        SQL_GetError(walletsDB, error, sizeof(error));
        PrintToServer("[PTE] Error checking if %s exists: %s", steamId, error);
        return false;
    }
    else {
        while (SQL_FetchRow(hQuery))
        {
            int rows = SQL_FetchInt(hQuery, 0);
            if (rows == 0)
            {
                return false;
            }
            else if (rows > 1) {
                PrintToServer("[PTE] ERROR: uniqueid \"%s\" is on multiples rows, you setup the database wrongly, please check it. rows: %d", steamId, rows);
                return false;
            }
            else {
                return true;
            }
        }
        return false;
    }
}
//
//
//
