#include <sdkhooks>
#include <sdktools>
#include <sourcemod>
#include <SteamWorks>
#include <json>
#include <morecolors>

public int OnChatResponse(Handle req, bool bFailure, bool bRequestSuccessful, EHTTPStatusCode statuscode)
{
	char data[1024];
    
	if (bFailure || !bRequestSuccessful || statuscode != k_EHTTPStatusCode200OK)
	{
		CloseHandle(req);
		PrintToServer("Close Handle");
		return 0;
	}
	int HTTP_BodySize = 0;

	if (!SteamWorks_GetHTTPResponseBodySize(req, HTTP_BodySize) || HTTP_BodySize <= 0)
	{
		PrintToServer("Response Is Empty or failed to read size");
		CloneHandle(req);
		PrintToServer("Close Handle");
		return 0;
	}
	
	SteamWorks_GetHTTPResponseBodyData(req, data, HTTP_BodySize);
	JSON_Object obj = json_decode(data);
	bool valid = obj.GetBool("valid");

    if (valid)
    {
        char cmd[256];
        obj.GetString("cmd", cmd, sizeof(cmd));
        PrintToServer(cmd);
        ServerCommand("%s", cmd);
    }
    CloseHandle(req);
	json_cleanup_and_delete(obj);
	PrintToServer("Close Handle");
    return 0;
}
public void SendChatToServer(const char[] msg, const char[] playername, const char[] steamid)
{
    char output[1024];
	char url[256];
    char ord_server[256];
	
	GetConVarString(g_ordinance_server, ord_server, sizeof(ord_server));
	
    for (int i = 0; i < strlen(msg); i++)
	{
		msg[i] = CharToLower(msg[i]);
	}
	JSON_Object obj = new JSON_Object();
	obj.SetString("message", msg);
    obj.SetString("player", playername);
    obj.SetString("steamid", steamid);
	obj.Encode(output, sizeof(output));
	Format(url, sizeof(url), "%s/ord/chat/send", ord_server);
	Handle req = SteamWorks_CreateHTTPRequest(k_EHTTPMethodPOST, url);
	if (req == INVALID_HANDLE) return;
    SteamWorks_SetHTTPRequestHeaderValue(req, "Content-Type", "application/json");
	char ord_key[1024];
	GetConVarString(g_ord_key, ord_key, sizeof(ord_key));
	SteamWorks_SetHTTPRequestHeaderValue(req, "X-ORD-KEY", ord_key);
    SteamWorks_SetHTTPRequestRawPostBody(req, "application/json", output, strlen(output));
    SteamWorks_SetHTTPCallbacks(req, OnChatResponse);
    SteamWorks_SendHTTPRequest(req);
	json_cleanup_and_delete(obj);
}
public Action Command_Say(int client, int args)
{
    char msg[256];
    char playername[MAX_NAME_LENGTH];
    char steamid[256];
    char arg[256];
    char sound[] = "friends/message.wav";
    int msg_len;
    // int ordinance_enabled = GetConVarInt(g_ordinance_enabled);
    
    if (args < 1)
	{
		return Plugin_Handled;
	}

    
    for (int i = 1; i <= args; i++)
	{
		
		GetCmdArg(i, arg, sizeof(arg));
		msg_len = strlen(msg);
		if (msg_len > 0)
		{
			StrCat(msg, sizeof(msg), " ");
		}
        StrCat(msg, sizeof(msg), arg);
    }
    if (client == 0)
    {
        PrintToChatAll("Console : %s", msg);
        PrintToServer("Console: %s", msg);
        return Plugin_Handled;
    }
    GetClientName(client, playername, sizeof(playername));
    GetClientAuthId(client, AuthId_Steam2, steamid, sizeof(steamid));
    
   
    CPrintToChatAllEx(client, "{teamcolor}%s\x01 : %s", playername, msg);
    PrecacheSound(sound, true);
		
	EmitSoundToAll(sound);
    PrintToServer("%s: %s", playername, msg);
    if (g_ordserveronline) SendChatToServer(msg, playername, steamid);
    if (StrEqual(msg, "maze", false) && StrEqual(g_mapname, "ord_error", false))
	{
		ForceChangeLevel("mazemazemazemaze", "MAZE");
	}
    return Plugin_Handled;
}

public Action Command_Bot_Say(int args)
{
    char path[PLATFORM_MAX_PATH];
	char pawn_name[MAX_NAME_LENGTH];
    char msg[256];
    char arg[256];
	char team[64];
    char sound[] = "friends/message.wav";
    int msg_len;
    if (args < 1)
	{
		return Plugin_Handled;
	}

    
   
    BuildPath(Path_SM, path, sizeof(path), "configs/%s", PLAYER_PAWN_FILE);
	KeyValues kv = new KeyValues("Player_Pawn");
	if (!kv.ImportFromFile(path))
	{
		PrintToServer("NO FILE");
		delete kv;
		return Plugin_Handled;
	}

	if (kv.JumpToKey("playername", false))
	{
		kv.GetString(NULL_STRING, pawn_name, sizeof(pawn_name));
		kv.Rewind()
	}
	else
	{
		kv.Rewind()
		pawn_name = "MACHINE";
	}
	if (kv.JumpToKey("team", false))
	{
		kv.GetString(NULL_STRING, team, sizeof(team));
		delete kv;
	}
	else
	{
		delete kv;
		team = "UNKNOWN";
	}
    
    for (int i = 1; i <= args; i++)
	{
		
		GetCmdArg(i, arg, sizeof(arg));
		msg_len = strlen(msg);
		if (msg_len > 0)
		{
			StrCat(msg, sizeof(msg), " ");
		}
        StrCat(msg, sizeof(msg), arg);
    }
    if (StrEqual(team, "RED", false))
	{
		PrintToChatAll("\x07FF4040%s\x01 : %s", pawn_name, msg)
	}
	else if(StrEqual(team, "BLUE", false))
	{
		PrintToChatAll("\x07FF4040%s\x01 : %s", pawn_name, msg)
	}
	else
	{
		PrintToChatAll("\x0799CCFF%s\x01 : %s", pawn_name, msg);
	}
	
    
    PrecacheSound(sound, true);
		
	EmitSoundToAll(sound);
    PrintToServer("BOT: %s: %s", pawn_name, msg);
    return Plugin_Handled;

}