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

Database  walletsDB;

char      onlinePlayers[MAXPLAYERS][256];
char      onlinePlayersCount      = 0;

bool      alertPlayerIncomings    = true;

char      waveRewards[15][20]     = { "100000000000000000", "10000000000000000", "100000000000000000",
                             "100000000000000000", "200000000000000000", "200000000000000000",
                             "200000000000000000", "200000000000000000", "200000000000000000",
                             "200000000000000000", "200000000000000000", "200000000000000000",
                             "200000000000000000", "200000000000000000", "300000000000000000" };
const int maxWaves                = 15;
char      waveRewardsShow[15][20] = { "0.1", "0.1", "0.1",
                                 "0.1", "0.2", "0.2",
                                 "0.2", "0.2", "0.2",
                                 "0.2", "0.2", "0.2",
                                 "0.2", "0.2", "0.3" };
int       scorePoints[20]         = { 5, 10, 15, 20, 25, 30, 35, 40, 45, 50, 55, 60, 65, 70, 75, 80, 85, 90, 95, 100 };
char      scoreRewards[20][20]    = {
    "100000000000000000",
    "200000000000000000",
    "300000000000000000",
    "400000000000000000",
    "500000000000000000",
    "600000000000000000",
    "700000000000000000",
    "800000000000000000",
    "900000000000000000",
    "1000000000000000000",
    "1100000000000000000",
    "1200000000000000000",
    "1300000000000000000",
    "1400000000000000000",
    "1500000000000000000",
    "1600000000000000000",
    "1700000000000000000",
    "1800000000000000000",
    "1900000000000000000",
    "2000000000000000000"
};

char scoreRewardsShow[20][20] = { "0.1", "0.2", "0.3",
                                  "0.4", "0.5", "0.6",
                                  "0.7", "0.8", "0.9",
                                  "1.0", "1.1", "1.2", "1.3",
                                  "1.4", "1.5", "1.6",
                                  "1.7", "1.8", "1.9",
                                  "2.0" };

int  serverWave               = 0;
int  playerAlives             = 0;

public void OnPluginStart()
{
    char walletDBError[32];
    walletsDB = SQL_Connect("default", true, walletDBError, sizeof(walletDBError));
    if (walletsDB == null)
    {
        PrintToServer("[PTE] ERROR Connecting to the database: %s", walletDBError);
        PrintToServer("[PTE] The plugin will stop now...");
        return;
    }

    // Player connected
    HookEvent("player_connect", OnPlayerConnect, EventHookMode_Post);

    // Player disconnected
    HookEventEx("player_disconnect", OnPlayerDisconnect, EventHookMode_Post);

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

    // Wallet command
    RegConsoleCmd("wallet", CommandRegisterWallet, "Set up your Wallet address");

    // ID command
    RegConsoleCmd("id", CommandViewSteamId, "View your steam id");

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

        char userData[256];
        playerObj.Encode(userData, sizeof(userData));
        json_cleanup_and_delete(playerObj);

        onlinePlayersCount++;
        onlinePlayers[onlinePlayersCount - 1] = userData;

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
        onlinePlayersCount--;
        removePlayerByUserId(userId);
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

    int length = onlinePlayersCount;
    for (int i = 0; i < length; i += 1)
    {
        JSON_Object playerObj = json_decode(onlinePlayers[i]);
        if (playerObj == null)
        {
            PrintToServer("[PTE] [OnWaveFinish] ERROR: %d (online index) have any invalid player object: ", i, onlinePlayers[i]);
            continue;
        }

        int client = GetClientOfUserId(playerObj.GetInt("userId"));
        if (!IsClientInGame(client) || IsFakeClient(client))
        {
            continue;
        }

        int playerScore = GetClientFrags(client);
        playerObj.SetInt("lastScore", playerScore);

        updateOnlinePlayerByUserId(playerObj.GetInt("userId"), playerObj);
        json_cleanup_and_delete(playerObj);
    }

    PrintToServer("[PTE] Wave %d Started, supply: %b", serverWave, isSupply);
}

public void OnSurvivalStart(Event event, const char[] name, bool dontBroadcast)
{
    serverWave = 0;

    PrintToServer("[PTE] Survival Started");
}

public void OnWaveFinish()
{
    int indexReward = 0;
    if (serverWave > maxWaves)
    {
        indexReward = maxWaves - 1;
    }
    else {
        indexReward = serverWave - 1;
    }

    int length = onlinePlayersCount;
    for (int i = 0; i < length; i += 1)
    {
        JSON_Object playerObj = json_decode(onlinePlayers[i]);
        if (playerObj == null)
        {
            PrintToServer("[PTE] [OnWaveFinish] ERROR: %d (online index) have any invalid player object: ", i, onlinePlayers[i]);
            continue;
        }

        int client = GetClientOfUserId(playerObj.GetInt("userId"));
        if (IsFakeClient(client) || !IsClientInGame(client))
        {
            continue
        }

        char playerName[32];
        playerObj.GetString("playerName", playerName, sizeof(playerName));

        if (playerObj.GetBool("dead", true))
        {
            PrintToServer("[PTE] Ignoring %s because he is dead", playerName);
            continue;
        }

        // Wave survival reward
        {
            char currentEarning[20];
            char textToShow[20];
            strcopy(currentEarning, sizeof(currentEarning), waveRewards[indexReward]);
            strcopy(textToShow, sizeof(textToShow), waveRewardsShow[indexReward]);
            char outputText[32];
            Format(outputText, sizeof(outputText), "%s PTE", textToShow);

            IncrementWallet(client, currentEarning, outputText, ", for Surviving");
        }

        // Score reward
        int scoreDifference = GetClientFrags(client) - playerObj.GetInt("lastScore");
        PrintToServer("[PTE] %d scored: %d, in this round, total: %d", client, scoreDifference, GetClientFrags(client));
        if (scoreDifference > 0)
        {
            int size = sizeof(scorePoints);
            int j;
            for (j = 0; j < size; j++)
            {
                PrintToServer("%d < %d ? %b", scorePoints[j], scoreDifference, scorePoints[j] > scoreDifference);
                if (scorePoints[j] > scoreDifference)
                {
                    break;
                }
            }

            if (j > 0)
            {
                char currentEarning[20];
                char textToShow[20];
                strcopy(currentEarning, sizeof(currentEarning), scoreRewards[j - 1]);
                strcopy(textToShow, sizeof(textToShow), scoreRewardsShow[j - 1]);
                char outputText[32];
                Format(outputText, sizeof(outputText), "%s PTE", textToShow);

                IncrementWallet(client, currentEarning, outputText, ", for Scoring");
            }
        }

        json_cleanup_and_delete(playerObj);
    }

    PrintToServer("[PTE] Wave %d Finished", serverWave);
}

public void OnPlayerActive(Event event, const char[] name, bool dontBroadcast)
{
    int         userId    = event.GetInt("userid");

    JSON_Object playerObj = getPlayerByUserId(userId);
    if (playerObj == null)
    {
        PrintToServer("[PTE] [OnPlayerActive] ERROR: %d have any invalid player object");
        return;
    }

    int client        = GetClientOfUserId(userId);
    int clientSteamId = GetSteamAccountID(client);

    if (!PlayerRegistered(clientSteamId))
    {
        PrintToServer("[PTE] Player %d not registered, registering...", clientSteamId);
        RegisterPlayer(clientSteamId);
    }

    if (playerObj.GetInt("walletStatus") == -1)
    {
        if (WalletRegistered(clientSteamId))
        {
            playerObj.SetInt("walletStatus", 1);
            updateOnlinePlayerByUserId(userId, playerObj);
        }
        else {
            playerObj.SetInt("walletStatus", 0);
            updateOnlinePlayerByUserId(userId, playerObj);
        }
    }

    json_cleanup_and_delete(playerObj);

    PrintToServer("[PTE] Player started playing %d", userId);
}

public void OnPlayerDie(Event event, const char[] name, bool dontBroadcast)
{
    int userId = event.GetInt("userid");

    playerAlives--;
    PrintToServer("[PTE] Player died %d, Total Alive: %d", userId, playerAlives);

    JSON_Object playerObj = getPlayerByUserId(userId);
    if (playerObj == null)
    {
        // Is invalid always when a player disconnects, because disconnect function is called before the dead function
        // PrintToServer("[PTE] [OnPlayerDie] ERROR: %d have any invalid player object", userId);
        return;
    }

    playerObj.SetBool("dead", true);

    int playerScore = GetClientFrags(GetClientOfUserId(userId));
    playerObj.SetInt("lastScore", playerScore);

    updateOnlinePlayerByUserId(userId, playerObj);
    json_cleanup_and_delete(playerObj);
}

public void OnPlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
    int userId = event.GetInt("userid");

    PrintToServer("[PTE] Player spawned %d", userId);
    playerAlives++;

    JSON_Object playerObj = getPlayerByUserId(userId);
    if (playerObj == null)
    {
        PrintToServer("[PTE] [OnPlayerSpawn] ERROR: %d have any invalid player object", userId);
        return;
    }

    playerObj.SetBool("dead", false);

    int playerScore = GetClientFrags(GetClientOfUserId(userId));
    playerObj.SetInt("lastScore", playerScore);

    updateOnlinePlayerByUserId(userId, playerObj);
    json_cleanup_and_delete(playerObj);
}
//
//
//

//
// Commands
//
public Action CommandRegisterWallet(int client, int args)
{
    if (!IsClientConnected(client) || IsFakeClient(client))
    {
        return Plugin_Handled;
    }

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
        JSON_Object playerObj = getPlayerByUserId(GetClientUserId(client));
        if (playerObj == null)
        {
            PrintToServer("[PTE] [CommandRegisterWallet] ERROR: %d have any invalid player object", client);
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
                        updateOnlinePlayerByUserId(client, playerObj);
                    }
                }
            }
            else
            {
                PrintToChat(client, "Wallet updated!");
                PrintToServer("[PTE] Updated %d wallet to: %s", steamId, walletAddress);
            }
        }

        json_cleanup_and_delete(playerObj);
    }
    else {
        PrintToChat(client, "The wallet address provided is invalid, if you need help you can ask in your discord: discord.gg/vGHxVsXc4Q");
    }

    return Plugin_Handled;
}

public Action CommandViewSteamId(int client, int args)
{
    if (IsClientConnected(client) && !IsFakeClient(client))
    {
        PrintToChat(client, "[PTE] Your steam id is: %d", GetSteamAccountID(client));
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
    for (int i = 0; i < sizeof(onlinePlayers); i++)
    {
        if (strlen(onlinePlayers[i]) > 0)
        {
            JSON_Object playerObj = json_decode(onlinePlayers[i]);
            if (playerObj == null)
            {
                PrintToServer("[PTE] [WarnPlayersWithoutWallet] ERROR: %d (online index) have any invalid player object: %s", i, onlinePlayers[i]);
                continue;
            }

            if (playerObj.GetInt("walletStatus") == 0)
            {
                WarnPlayerWithoutWallet(GetClientOfUserId(playerObj.GetInt("userId")));
            }
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
    int  steamId = GetSteamAccountID(client);
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
        {
            PrintToChat(client, "[PTE] You received: %s%s", valueToShow, reason);
        }
        PrintToServer("[PTE] Incremented %d value: %s, reason: '%s'", steamId, valueToIncrement, reason);
    }
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
           "SELECT COUNT(*) FROM nmrih WHERE walletaddress = '%d';",
           steamId);

    // Checking the player walletaddress existance
    DBResultSet hQuery = SQL_Query(walletsDB, checkQuery);
    if (hQuery == null)
    {
        char error[128];
        SQL_GetError(walletsDB, error, sizeof(error));
        PrintToServer("[PTE] Error checking if %d exists: %s", steamId, error);
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
            else {
                return true;
            }
        }
        return false;
    }
}

bool PlayerRegistered(const int steamId)
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
        PrintToServer("[PTE] Error checking if %d exists: %s", steamId, error);
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
                PrintToServer("[PTE] ERROR: uniqueid \"%d\" is on multiples rows, you setup the database wrongly, please check it. rows: %d", steamId, rows);
                return false;
            }
            else {
                return true;
            }
        }
        return false;
    }
}

bool RegisterPlayer(const int steamId)
{
    char checkQuery[128];
    Format(checkQuery, sizeof(checkQuery),
           "INSERT INTO nmrih (uniqueid) VALUES ('%d');",
           steamId);

    // Checking the player uniqueid existance
    DBResultSet hQuery = SQL_Query(walletsDB, checkQuery);
    if (hQuery == null)
    {
        char error[128];
        SQL_GetError(walletsDB, error, sizeof(error));
        PrintToServer("[PTE] Error registering %d exists: %s", steamId, error);
        return false;
    }
    else {
        while (SQL_FetchRow(hQuery))
        {
            int rows = SQL_GetAffectedRows(hQuery);
            if (rows == 0)
            {
                PrintToServer("[PTE] ERROR: No rows affected when registering for player: %d", steamId);
                return false;
            }
            else if (rows > 1) {
                PrintToServer("[PTE] ERROR: MULTIPLES ROWS AFFECTED WHILE INSERTING PLAYERS: %d", steamId, rows);
                return true;
            }
            else {
                return true;
            }
        }
        return false;
    }
}

JSON_Object getPlayerByUserId(int userId)
{
    for (int i = 0; i < sizeof(onlinePlayers); i++)
    {
        if (strlen(onlinePlayers[i]) > 0)
        {
            JSON_Object playerObj = json_decode(onlinePlayers[i]);
            if (playerObj == null)
            {
                PrintToServer("[PTE] [getPlayerByUserId] ERROR: %d (online index) have any invalid player object: %s", i, onlinePlayers[i]);
                continue;
            }

            if (playerObj.GetInt("userId") == userId)
            {
                return playerObj;
            }
        }
    }
    return null;
}

void removePlayerByUserId(int userId)
{
    // Getting player index to remove
    int playerIndex = -1;
    for (int i = 0; i < sizeof(onlinePlayers); i++)
    {
        if (strlen(onlinePlayers[i]) > 0)
        {
            JSON_Object playerObj = json_decode(onlinePlayers[i]);
            if (playerObj == null)
            {
                PrintToServer("[PTE] [removePlayerByUserId] ERROR: %d (online index) have any invalid player object: %s", i, onlinePlayers[i]);
                continue;
            }

            if (playerObj.GetInt("userId") == userId)
            {
                playerIndex = i;
                break;
            }
        }
    }
    if (playerIndex == -1)
    {
        PrintToServer("[PTE] [removePlayerByUserId] ERROR: %d player index no longer exists", userId);
        return;
    }

    // Moving values to back
    for (int i = playerIndex; i < sizeof(onlinePlayers) - 1; i++)
    {
        strcopy(onlinePlayers[i], sizeof(onlinePlayers[]), onlinePlayers[i + 1]);
    }

    // Cleaning last element
    onlinePlayers[sizeof(onlinePlayers) - 1][0] = '\0';
}

void updateOnlinePlayerByUserId(int userId, JSON_Object updatedPlayerObj)
{
    for (int i = 0; i < sizeof(onlinePlayers); i++)
    {
        if (strlen(onlinePlayers[i]) > 0)
        {
            JSON_Object playerObj = json_decode(onlinePlayers[i]);
            if (playerObj == null)
            {
                PrintToServer("[PTE] [updateOnlinePlayerByUserId] ERROR: %d (online index) have any invalid player object: %s", i, onlinePlayers[i]);
                continue;
            }

            if (playerObj.GetInt("userId") == userId)
            {
                char encodedPlayer[256];
                updatedPlayerObj.Encode(encodedPlayer, sizeof(encodedPlayer));
                onlinePlayers[i] = encodedPlayer;
            }
        }
    }
}
//
//
//
