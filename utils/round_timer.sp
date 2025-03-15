#include <sourcemod>
#include <sdktools>
#include <clients>

public Plugin myinfo =
{
    name        = "Round Timer",
    author      = "GxsperMain",
    description = "Add limit for rounds",
    version     = SOURCEMOD_VERSION,
    url         = "https://github.com/GxsperMain/nmrih_play_to_earn",


}

int       currentTimestamp = 0;
int       waveTimestamp    = -1;
Handle    timestampTimer;

const int maxWaves          = 7;
int       secondsPerWave[7] = { 300, 350, 400, 450, 500, 550, 600 };
int       currentlyWave     = 0;
ArrayList connectedPlayers;

public OnPluginStart()
{
    connectedPlayers = new ArrayList();
    HookEvent("new_wave", OnWaveStart, EventHookMode_PostNoCopy);
    HookEvent("wave_complete", OnWaveComplete, EventHookMode_PostNoCopy);
    HookEvent("wave_low_zombies", OnWaveAlmostComplete, EventHookMode_PostNoCopy);
    HookEvent("wave_system_end", OnGameEnd, EventHookMode_PostNoCopy);
    HookEvent("extraction_begin", OnExtractionBegin, EventHookMode_PostNoCopy);

    HookEventEx("nmrih_round_begin", OnSurvivalStart, EventHookMode_PostNoCopy);
}

public void OnWaveStart(Event event, const char[] name, bool dontBroadcast)
{
    currentTimestamp = 0;
    if (currentlyWave >= maxWaves)
    {
        currentlyWave = maxWaves - 1;
    }
    waveTimestamp = secondsPerWave[currentlyWave];

    PrintToServer("[Round Timer] Round Time: %d", secondsPerWave[currentlyWave]);
    if (secondsPerWave[currentlyWave] > 60)
    {
        int minutes = secondsPerWave[currentlyWave] / 60;
        int seconds = secondsPerWave[currentlyWave] % 60;
        if (seconds < 10)
        {
            PrintToChatAll("[Wave] %d:0%d remaining...", minutes, seconds);
        }
        else {
            PrintToChatAll("[Wave] %d:%d remaining...", minutes, seconds);
        }
    }
    else {
        PrintToChatAll("[Wave] %d Seconds remaining...", secondsPerWave[currentlyWave]);
    }

    currentlyWave++;
}

public void OnWaveComplete(Event event, const char[] name, bool dontBroadcast)
{
    currentTimestamp = 0;
    waveTimestamp    = -1;
}

public void OnWaveAlmostComplete(Event event, const char[] name, bool dontBroadcast)
{
    currentTimestamp = 0;
    waveTimestamp    = -1;
}

public void OnGameEnd(Event event, const char[] name, bool dontBroadcast)
{
    currentTimestamp = 0;
    waveTimestamp    = -1;
}

public void OnSurvivalStart(Event event, const char[] name, bool dontBroadcast)
{
    currentlyWave = 0;
}

public void OnExtractionBegin(Event event, const char[] name, bool dontBroadcast)
{
    waveTimestamp = -1;
}

public void OnMapStart()
{
    waveTimestamp = -1;
    if (timestampTimer == null)
    {
        timestampTimer = CreateTimer(5.0, UpdateTimeStamp, _, TIMER_REPEAT);
    }
}

public void OnMapEnd()
{
    waveTimestamp = -1;
    if (timestampTimer != null)
    {
        KillTimer(timestampTimer);
        timestampTimer = null;
    }
}

public void OnServerEnterHibernation()
{
    waveTimestamp = -1;
    if (timestampTimer != null)
    {
        KillTimer(timestampTimer);
        timestampTimer = null;
    }
}

public void OnServerExitHibernation()
{
    waveTimestamp = -1;
    if (timestampTimer == null)
    {
        timestampTimer = CreateTimer(5.0, UpdateTimeStamp, _, TIMER_REPEAT);
    }
}

public Action UpdateTimeStamp(Handle timer)
{
    if (waveTimestamp != -1)
    {
        currentTimestamp++;

        if (waveTimestamp - currentTimestamp == 120)
        {
            PrintToChatAll("[Wave] 2 Minutes remaining...");
        }

        if (waveTimestamp - currentTimestamp == 60)
        {
            PrintToChatAll("[Wave] 1 Minute remaining...");
        }

        if (waveTimestamp - currentTimestamp == 30)
        {
            PrintToChatAll("[Wave] 30 Seconds remaining...");
        }

        if (waveTimestamp - currentTimestamp <= 10)
        {
            PrintToChatAll("[Wave] %d Seconds remaining...", waveTimestamp - currentTimestamp);
        }

        if (currentTimestamp >= waveTimestamp)
        {
            waveTimestamp = -1;
            PrintToChatAll("[Wave] Time is over...");
            for (int i = 0; i < connectedPlayers.Length; i++)
            {
                int client = connectedPlayers.Get(i);
                if (IsClientInGame(client) && IsPlayerAlive(client))
                {
                    ForcePlayerSuicide(client);
                }
            }
        }
    }
    return Plugin_Continue;
}

public void OnPlayerConnect(Event event, const char[] name, bool dontBroadcast)
{
    bool isBot = event.GetBool("bot");
    if (!isBot)
    {
        int userId = event.GetInt("userid");
        connectedPlayers.Push(userId);
    }
}

public void OnPlayerDisconnect(Event event, const char[] name, bool dontBroadcast)
{
    bool isBot = event.GetBool("bot");
    if (!isBot)
    {
        int userId      = event.GetInt("userid");
        int playerIndex = connectedPlayers.FindValue(userId);
        if (playerIndex != -1)
        {
            connectedPlayers.Erase(playerIndex);
        }
    }
}