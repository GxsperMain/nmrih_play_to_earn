#include <sourcemod>
#include <sdktools>

public Plugin myinfo =
{
    name        = "Weapons On Spawn",
    author      = "GxsperMain",
    description = "Gives weapons on spawn",
    version     = SOURCEMOD_VERSION,
    url         = "https://github.com/GxsperMain/nmrih_play_to_earn",
    // referenceUrl         = "https://forums.alliedmods.net/showthread.php?t=288290"


}

static char weapons[3][20] = {
    "fa_1911",
    "ammobox_45acp",
    "ammobox_45acp",
};

bool      firstSpawnOnly = true;

ArrayList playersReceivedKit;

public OnPluginStart()
{
    // playersReceivedKit = new ArrayList();
    // HookEvent("player_spawn", Event_Spawn);
    // HookEvent("nmrih_reset_map", Event_Restart);
}

public void Event_Spawn(Handle event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(GetEventInt(event, "userid"));

    if (firstSpawnOnly)
    {
        if (playersReceivedKit.FindValue(client) == -1)
        {
            PrintToServer("[Kit Starter] Giving kit to %d", client);
            playersReceivedKit.Push(client);
            CreateTimer(1.0, GiveItemsToPlayer, client);
        }
        else {
            PrintToServer("[Kit Starter] Ignoring %d, because he already earned a kit this map", client);
        }
    }
    else {
        CreateTimer(1.0, GiveItemsToPlayer, client);
    }
}

public void Event_Restart(Handle event, const char[] name, bool dontBroadcast)
{
    playersReceivedKit = new ArrayList();
    PrintToServer("[Kit Starter] Round Restarted");
}

public Action GiveItemsToPlayer(Handle timer, any client)
{
    if (IsClientInGame(client) && IsPlayerAlive(client))
    {
        for (int i; i < sizeof(weapons); i++)
        {
            char item = GivePlayerItem(client, weapons[i]);
            if (item == -1) LogError("Can't give item '%s' to '%N'", weapons[i], client);
            else if (!AcceptEntityInput(item, "use", client, client)) LogError("Can't AcceptEntityInput 'use' for item '%s'", weapons[i]);
        }
    }
    return Plugin_Stop;
}