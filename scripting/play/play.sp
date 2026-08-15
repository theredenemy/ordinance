#include <sdkhooks>
#include <sdktools>
#include <sourcemod>
#include <SteamWorks>
#include <json>
#pragma newdecls required
#pragma semicolon 1
bool g_spray;
bool g_allow_spray_submit;
public Action OrdPlay_Render(Handle timer)
{
    SetConVarString(FindConVar("sv_password"), "");
    SendInput("BEGIN");
    // ServerCommand("ord_clear");
    ServerCommand("ord_render");
    return Plugin_Continue;
}
public int On_Ord_Play_Response(Handle req, bool bFailure, bool bRequestSuccessful, EHTTPStatusCode statuscode)
{
    if (bRequestSuccessful && statuscode == k_EHTTPStatusCode200OK)
    {
        g_spray = true;
        g_allow_spray_submit = false;
        CreateTimer(20.0, OrdPlay_Render);
    }
    else
    {
        char server_error_level[PLATFORM_MAX_PATH];
	    GetConVarString(g_server_error_level, server_error_level, sizeof(server_error_level));
        g_spray = true;
        g_allow_spray_submit = false;
        SetConVarString(FindConVar("sv_password"), "");
        PrintToChatAll("ORD_PLAY IS OFF");
        Time_ForceChangeLevel(10.0, server_error_level, "SERVER_ERROR");
    }
	CloseHandle(req);
	PrintToServer("Close Handle");
	return 0;
}
public Action OnPlayerRunCmd(int client, int& buttons, int& impulse, float vel[3], float angles[3], int& weapon, int& subtype, int& cmdnum, int& tickcount, int& seed, int mouse[2])
{
    char ord_server[256];
    char ord_play_level[PLATFORM_MAX_PATH];
    char url[256];
	GetConVarString(g_ordinance_server, ord_server, sizeof(ord_server));
    GetConVarString(g_ord_play_level, ord_play_level, sizeof(ord_play_level));
    if (!g_allow_spray_submit)
    {
        return Plugin_Continue;
    }
    if (g_spray)
    {
        return Plugin_Continue;
    }
    if (!StrEqual(g_mapname, ord_play_level, false))
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
    char filename[PLATFORM_MAX_PATH];
    strcopy(hexid, sizeof(hexid), hexHash);
    Format(filename, sizeof(path), "%s.dat", hexHash);
    Format(path, sizeof(path), "download/user_custom/%s/%s.dat", hexid, hexHash);
    PrintToServer("%s", path);
    Format(url, sizeof(url), "%s/ord/play", ord_server);
	Handle req = SteamWorks_CreateHTTPRequest(k_EHTTPMethodPOST, url);
	if (req == INVALID_HANDLE) return Plugin_Continue;
    SteamWorks_SetHTTPRequestHeaderValue(req, "X-FILE-NAME", filename);
    SteamWorks_SetHTTPRequestRawPostBodyFromFile(req, "application/octet-stream", path);
	char ord_key[1024];
	GetConVarString(g_ord_key, ord_key, sizeof(ord_key));
	SteamWorks_SetHTTPRequestHeaderValue(req, "X-ORD-KEY", ord_key);
	SteamWorks_SetHTTPCallbacks(req, On_Ord_Play_Response);
	SteamWorks_SendHTTPRequest(req);
    
    return Plugin_Continue;
}