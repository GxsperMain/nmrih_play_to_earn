// Based on the code of the plugin "Skins" by Grey83

#include <sdktools_functions>
#include <sdktools_stringtables>

public Plugin myinfo =
{
    name        = "Skin Reader",
    description = "Read skins from a nmrih_skins database for each player",
    version     = SOURCEMOD_VERSION,
    author      = "GxsperMain",
    url         = "https://github.com/GxsperMain/nmrih_play_to_earn"
    // referenceUrl = "https://forums.alliedmods.net/showthread.php?t=301319"


}

Database          walletsDB;

static const char SKINS_DOWNLOAD_LIST[] = "addons/sourcemod/configs/skins_reader/downloads_list.ini",
                  SKINS_ID_PATH[]       = "addons/sourcemod/configs/skins_reader/skins_id.init";
int  TotalSkins                         = 0;

bool bTPView[MAXPLAYERS + 1];

bool preCacheModelsOnMapStartup   = false;

bool enableDefaultSkinsFor0Rarity = true;
int  maxAvailableDefaultSkins     = 6;

public void OnPluginStart()
{
    char walletDBError[32];
    walletsDB = SQL_Connect("default", true, walletDBError, sizeof(walletDBError));
    if (walletsDB == null)
    {
        PrintToServer("[Skins Reader] ERROR Connecting to the database: %s", walletDBError);
        PrintToServer("[Skins Reader] The plugin will stop now...");
        return;
    }

    HookEvent("player_spawn", Event_PlayerSpawn);

    // Third Person command
    RegConsoleCmd("tps", ToggleView, "Enters in third person");

    PrintToServer("[Skin Reader] Skin Reader plugin has been initialized");
}

public void OnMapStart()
{
    TotalSkins = 0;
    PreCacheModels();
}

public void OnMapEnd()
{
}

//
// Commands
//
stock Action ToggleView(int client, int args)
{
    if (IsFakeClient(client) || !IsPlayerAlive(client))
    {
        return Plugin_Handled;
    }

    if (bTPView[client])
    {
        bTPView[client] = false;
        SetEntPropEnt(client, Prop_Send, "m_hObserverTarget", client);
        SetEntProp(client, Prop_Send, "m_iObserverMode", 0);
        SetEntProp(client, Prop_Send, "m_bDrawViewmodel", 1);
        SetEntProp(client, Prop_Send, "m_iFOV", 90);
    }
    else
    {
        bTPView[client] = true;
        SetEntPropEnt(client, Prop_Send, "m_hObserverTarget", 0);
        SetEntProp(client, Prop_Send, "m_iObserverMode", 1);
        SetEntProp(client, Prop_Send, "m_bDrawViewmodel", 0);
        SetEntProp(client, Prop_Send, "m_iFOV", 70);
    }

    return Plugin_Handled;
}

//
// Events
//
public void Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
    CreateTimer(1.0, Timer_Spawn, GetClientOfUserId(event.GetInt("userid")));
}

public Action Timer_Spawn(Handle timer, any client)
{
    UpdatePlayerSkin(client);
    return Plugin_Stop;
}

//
// Utils
//
stock void ApplyModel(const int client, const char[] model)
{
    if (preCacheModelsOnMapStartup)
    {
        if (!model[0] || !IsModelPrecached(model))
        {
            return;
        }
    }

    SetEntityModel(client, model);
    SetEntityRenderColor(client);
}

stock void UpdatePlayerSkin(int client)
{
    int  steamId = GetSteamAccountID(client);

    // Checking player existence in database
    char checkQuery[128];
    Format(checkQuery, sizeof(checkQuery),
           "SELECT skinid FROM nmrih_skins WHERE uniqueid = '%d';",
           steamId);

    // Checking the player uniqueid existence
    DBResultSet hQuery = SQL_Query(walletsDB, checkQuery);
    if (hQuery == null)
    {
        char error[255];
        SQL_GetError(walletsDB, error, sizeof(error));
        PrintToServer("[Skin Reader] Error checking if %d exists: %s", steamId, error);
        return;
    }
    else
    {
        if (SQL_FetchRow(hQuery))
        {
            char skinId[255];
            SQL_FetchString(hQuery, 0, skinId, sizeof(skinId));

            char skinPath[PLATFORM_MAX_PATH];
            if (GetModelPathByID(skinId, skinPath, sizeof(skinPath)))
            {
                PrintToServer("[Skin Reader] [UpdatePlayerSkin] Changing player \"%d\" skin to: %s path: %s", steamId, skinId, skinPath);
                if (preCacheModelsOnMapStartup)
                {
                    ApplyModel(client, skinPath);
                }
                else {
                    if (!IsModelPrecached(skinPath))
                    {
                        PrecacheModel(skinPath);
                        ApplyModel(client, skinPath);
                        TotalSkins++;
                        PrintToServer("[Skin Reader] [UpdatePlayerSkin] TOTAL SKINS IN CACHE: %d", TotalSkins);
                    }
                    else {
                        ApplyModel(client, skinPath);
                    }
                }
            }
            else {
                PrintToServer("[Skin Reader] [UpdatePlayerSkin] ERROR SteamID \"%d\" found. SkinID: %s, BUT THE MODEL IS NOT AVAILABLE INGAME", steamId, skinId);
            }
        }
        else
        {
            if (enableDefaultSkinsFor0Rarity)
            {
                int  skinNumber = GetRandomInt(0, maxAvailableDefaultSkins);
                char skinId[255];
                char skinPath[PLATFORM_MAX_PATH];
                Format(skinId, sizeof(skinId), "0-%d", skinNumber);

                if (GetModelPathByID(skinId, skinPath, sizeof(skinPath)))
                {
                    PrintToServer("[Skin Reader] [UpdatePlayerSkin] Changing player \"%d\" default skin to: %s path: %s", steamId, skinId, skinPath);
                    if (preCacheModelsOnMapStartup)
                    {
                        ApplyModel(client, skinPath);
                    }
                    else {
                        if (!IsModelPrecached(skinPath))
                        {
                            PrecacheModel(skinPath);
                            ApplyModel(client, skinPath);
                            TotalSkins++;
                            PrintToServer("[Skin Reader] [UpdatePlayerSkin] TOTAL SKINS IN CACHE: %d", TotalSkins);
                        }
                        else {
                            ApplyModel(client, skinPath);
                        }
                    }
                }
                else {
                    PrintToServer("[Skin Reader] [UpdatePlayerSkin] ERROR SteamID \"%d\" found. SkinID: %s, BUT THE MODEL IS NOT AVAILABLE INGAME", steamId, skinId);
                }
            }
            else {
                PrintToServer("[Skin Reader] [UpdatePlayerSkin] SteamID \"%d\" not equipped skin.", steamId);
            }
        }
    }
}

stock bool GetModelPathByID(char[] providedSkinID, char[] skinPathBuffer, int skinPathBufferSize)
{
    Handle file = OpenFile(SKINS_ID_PATH, "r");
    if (file == INVALID_HANDLE)
    {
        PrintToServer("[Skin Reader] [PreCacheModels] ERROR: Cannot open the file. did you forget to create it?");
        return false;
    }

    char line[PLATFORM_MAX_PATH + 65];
    char buffers[2][PLATFORM_MAX_PATH];

    while (ReadFileLine(file, line, sizeof(line)))
    {
        TrimString(line);
        int numParts = ExplodeString(line, ":", buffers, 2, PLATFORM_MAX_PATH);

        if (numParts != 2)
        {
            PrintToServer("[Skin Reader] [GetModelPathByID] ERROR: Invalid format: %s, you should follow the standard: 'id:path'", line);
            continue;
        }

        char id[64];
        char path[PLATFORM_MAX_PATH];

        strcopy(id, sizeof(id), buffers[0]);
        strcopy(path, sizeof(path), buffers[1]);

        // PrintToServer("[Skin Reader] ITERATION: %s == %s", providedSkinID, id);

        if (StrEqual(id, providedSkinID))
        {
            strcopy(skinPathBuffer, skinPathBufferSize, path);
            return true;
        }
    }
    CloseHandle(file);

    return false;
}

stock void PreCacheModels()
{
    // LOADING SKINS ID
    if (preCacheModelsOnMapStartup)
    {
        Handle file = OpenFile(SKINS_ID_PATH, "r");
        if (file == INVALID_HANDLE)
        {
            PrintToServer("[Skin Reader] [PreCacheModels] ERROR: Cannot open the file. did you forget to create it?");
            return;
        }

        char line[PLATFORM_MAX_PATH + 65];
        char buffers[2][PLATFORM_MAX_PATH];

        while (ReadFileLine(file, line, sizeof(line)))
        {
            TrimString(line);
            int numParts = ExplodeString(line, ":", buffers, 2, PLATFORM_MAX_PATH);

            if (numParts != 2)
            {
                PrintToServer("[Skin Reader] [PreCacheModels] ERROR: Invalid format: %s, you should follow the standard: 'id:path'", line);
                continue;
            }

            char id[64];
            char path[PLATFORM_MAX_PATH];

            strcopy(id, sizeof(id), buffers[0]);
            strcopy(path, sizeof(path), buffers[1]);

            PrintToServer("[Skin Reader] MODEL CACHE: %s", path);

            PrecacheModel(path, true);
            TotalSkins++;
        }
        CloseHandle(file);
    }

    // LOADING DOWNLOAD LIST
    {
        Handle file = OpenFile(SKINS_DOWNLOAD_LIST, "r");
        if (file == INVALID_HANDLE)
        {
            PrintToServer("[Skin Reader] [PreCacheModels] ERROR: Cannot open the file. did you forget to create it?");
            return;
        }

        char line[PLATFORM_MAX_PATH];

        while (ReadFileLine(file, line, sizeof(line)))
        {
            TrimString(line);

            // Ignore comments, for some reason is inverted
            if (!StrContains(line, "//"))
            {
                continue;
            }
            // Ignore spaces
            if (strlen(line) == 0)
            {
                continue;
            }

            AddFileToDownloadsTable(line)
        }
        CloseHandle(file);
    }

    PrintToServer("[Skin Reader] TOTAL SKINS IN CACHE: %d", TotalSkins);
}