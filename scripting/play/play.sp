#include <sdkhooks>
#include <sdktools>
#include <sourcemod>
#include <SteamWorks>
#include <json>
#pragma newdecls required
#pragma semicolon 1

public Action OnPlayerRunCmd(int client, int& buttons, int& impulse, float vel[3], float angles[3], int& weapon, int& subtype, int& cmdnum, int& tickcount, int& seed, int mouse[2])
{
    if (!StrEqual(g_mapname, "ord_play", false))
    {
        return Plugin_Continue;
    }
    if (impulse != 201)
    {
        return Plugin_Continue;
    }
    char hexHash[200];
    if (!GetPlayerDecalFile(client, hexHash, sizeof(hexHash)))
    {
        PrintToServer("NO DECEL");
        return Plugin_Continue;
    }
    char path[PLATFORM_MAX_PATH];
    char hexid[3];
    strcopy(hexid, sizeof(hexid), hexHash);
    Format(path, sizeof(path), "%s/%s.dat", hexid, hexHash);
    PrintToServer("%s", path);
    return Plugin_Continue;
}