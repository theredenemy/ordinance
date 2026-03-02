#include <sdkhooks>
#include <sdktools>
#include <sourcemod>
#include <SteamWorks>
#include <json>
#pragma newdecls required
#pragma semicolon 1
char g_playername[MAX_NAME_LENGTH];
char g_playersteamid[256];

bool g_hit_vul_door;

ConVar g_triggername;
ConVar g_autokick;

void clearPawnVars()
{
	g_playername = "\0";
	SetConVarString(g_triggername, "\0");
	PrintToServer("Vars Cleared");
}

public void SendData(const char[] player, const char[] trigger, int timestamp)
{
	char date[256];
	char output[1024];
	char url[256];
	char ord_server[256];
	GetConVarString(g_ordinance_server, ord_server, sizeof(ord_server));
	JSON_Object obj = new JSON_Object();
	FormatTime(date, sizeof(date), "%B %dTH %Y", timestamp);
	PrintToChatAll("Player : %s Trigger : %s Date : %s", player, trigger, date);
	obj.SetString("player", player);
	obj.SetInt("timestamp", timestamp);
	obj.SetString("trigger", trigger);
	obj.Encode(output, sizeof(output));
	Format(url, sizeof(url), "http://%s/ord/pawn/submit", ord_server);
	Handle req = SteamWorks_CreateHTTPRequest(k_EHTTPMethodPOST, url);
	if (req == INVALID_HANDLE) return;
	SteamWorks_SetHTTPRequestHeaderValue(req, "Content-Type", "application/json");
	SteamWorks_SetHTTPRequestRawPostBody(req, "application/json", output, strlen(output));
	SteamWorks_SetHTTPCallbacks(req, OnHTTPResponse);
	SteamWorks_SendHTTPRequest(req);
}

public void set_pawn_state(const char[] state, bool senddata)
{
	char path[PLATFORM_MAX_PATH];
	char ord_server[256];
	GetConVarString(g_ordinance_server, ord_server, sizeof(ord_server));
	BuildPath(Path_SM, path, sizeof(path), "configs/%s", PAWN_STATE_FILE);
	KeyValues kv = new KeyValues("Pawn_state");
	kv.SetString("state", state);
	kv.Rewind();
	kv.ExportToFile(path);
	delete kv;
	if (senddata == true)
	{
		char output[1024];
		char url[256];
		JSON_Object obj = new JSON_Object();
		obj.SetString("state", state);
		obj.Encode(output, sizeof(output));
		Format(url, sizeof(url), "http://%s/ord/pawn/state", ord_server);
		Handle req = SteamWorks_CreateHTTPRequest(k_EHTTPMethodPOST, url);
		if (req == INVALID_HANDLE) return;
		SteamWorks_SetHTTPRequestHeaderValue(req, "Content-Type", "application/json");
		SteamWorks_SetHTTPRequestRawPostBody(req, "application/json", output, strlen(output));
		SteamWorks_SetHTTPCallbacks(req, OnHTTPResponse);
		SteamWorks_SendHTTPRequest(req);
	}

}
public void set_pawn(const char[] player, const char[] date)
{
	char path[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, path, sizeof(path), "configs/%s", PLAYER_PAWN_FILE);
	KeyValues kv = new KeyValues("Player_Pawn");
	kv.SetString("playername", player);
	kv.SetString("date", date);
	kv.Rewind();
	kv.ExportToFile(path);
	delete kv;
	set_pawn_state("alive", true);
}


public void OnTriggerHurt(const char[] output, int caller, int activator, float delay)
{
	if (activator >= 1 && activator <= MaxClients && IsClientInGame(activator))
	{
		char callerClass[64];
		GetEntityClassname(caller, callerClass, sizeof(callerClass)); 
		GetClientName(activator, g_playername, sizeof(g_playername));
		GetClientAuthId(activator, AuthId_Steam2, g_playersteamid, sizeof(g_playersteamid));
		PrintToServer("Player %s With SteamID %s Has Hit A %s", g_playername, g_playersteamid, callerClass);

	}
}


public Action Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	clearPawnVars();
	return Plugin_Continue;
}
public Action Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	ServerCommand("pawn_check");
	return Plugin_Continue;
}
public Action SubmitPawnTimer(Handle timer)
{
	ForceChangeLevel("submit_pawn", "SUBMIT");
	return Plugin_Continue;
}

public Action pawn_submit_cmd(int args)
{
	char arg[256];
    char full[256];
	char cmd[256];
	char triggername[256];
	char date[64];
	int timestamp = GetTime();
	int cmd_len;
	if (args < 1)
	{
		PrintToServer("[SM] Usage: pawn_submit '<cmd>' '<arg>'");
		return Plugin_Handled;
	}
	GetCmdArgString(full, sizeof(full));
	if (!g_ordserveronline)
		{
			if (IsMapValid("server_error"))
			{
				ForceChangeLevel("server_error", "NO INPUT");
				return Plugin_Handled;
			}
			else
			{
				ForceChangeLevel("cp_dustbowl", "NO INPUT");
				return Plugin_Handled;
			}
		}
	for (int i = 1; i <= args; i++)
	{
		
		GetCmdArg(i, arg, sizeof(arg));
		cmd_len = strlen(cmd);
		if (cmd_len > 0)
		{
			StrCat(cmd, sizeof(cmd), " ");
		}
		
		
		ReplaceString(arg, sizeof(arg), "(name)", g_playername);
		ReplaceString(arg, sizeof(arg), "(steamid)", g_playersteamid);
		

		StrCat(cmd, sizeof(cmd), arg);
	}
	ServerCommand("%s", cmd);
	g_triggername.GetString(triggername, sizeof(triggername));
	FormatTime(date, sizeof(date), "%B %dTH %Y", timestamp);
	set_pawn(g_playername, date);
	SendData(g_playername, triggername, timestamp);
	PrintHintTextToAll("ADMIN: CALCULATING");

	return Plugin_Handled;
}
public Action pawn_check_cmd(int args)
{
	char playername[MAX_NAME_LENGTH];
	char path[PLATFORM_MAX_PATH];
	char mapname[128];
	char reason[256] = "YOU ARE IN THE MACHINE NOW";
	int autokick = GetConVarInt(g_autokick);
	char pawn_name[MAX_NAME_LENGTH];
	if (autokick != 1)
	{
		PrintToServer("autokick off");
		return Plugin_Handled;
	}
	if (!g_ordserveronline)
	{
		return Plugin_Handled;
	}
	GetCurrentMap(mapname, sizeof(mapname));
	if (StrEqual(mapname, "2fort") || StrEqual(mapname, "cp_dustbowl"))
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
		delete kv;
	}
	else
	{
		if (!StrEqual(mapname, "submit_pawn"))
		{
			if (IsMapValid("submit_pawn"))
			{
				ForceChangeLevel("submit_pawn", "NO PLAYER PAWN");
				return Plugin_Handled;
			}
			else
			{
				return Plugin_Handled;
			}
		}
	}
	// PrintToServer(pawn_name);
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && !IsClientSourceTV(i) && IsPlayerAlive(i))
		{
			GetClientName(i, playername, sizeof(playername));
			// PrintToServer(playername);
			if (StrEqual(playername, pawn_name))
			{
				KickClient(i, reason);
			}
		}
	}
	return Plugin_Handled;

}



public Action display_vul_text_cmd(int args)
{
	char path[PLATFORM_MAX_PATH];
	char path2[PLATFORM_MAX_PATH];
	char pawn_name[MAX_NAME_LENGTH];
	char date[64];
	char state[256];

	if (!g_ordserveronline) {
		PrintHintTextToAll("ADMIN: ORDINANCE SERVER NOT ONLINE PLEASE TRY AGAIN LATER");
		return Plugin_Handled;
	}

	BuildPath(Path_SM, path, sizeof(path), "configs/%s", PLAYER_PAWN_FILE);
	BuildPath(Path_SM, path2, sizeof(path2), "configs/%s", PAWN_STATE_FILE);
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
		delete kv;
	}
	else
	{
		delete kv;
		pawn_name = "MACHINE";
	}
	KeyValues kv2 = new KeyValues("Player_Pawn");
	if (!kv2.ImportFromFile(path))
	{
		PrintToServer("NO FILE");
		delete kv2;
		return Plugin_Handled;
	}

	if (kv2.JumpToKey("date", false))
	{
		kv2.GetString(NULL_STRING, date, sizeof(date));
		delete kv2;
	}
	else
	{
		delete kv2;
		date = "DECEMBER 31TH 2099";
	}
	KeyValues kv3 = new KeyValues("Pawn_state");
	if (!kv3.ImportFromFile(path2))
	{
		PrintToServer("NO FILE");
		delete kv3;
		return Plugin_Handled;
	}

	if (kv3.JumpToKey("state", false))
	{
		kv3.GetString(NULL_STRING, state, sizeof(state));
		delete kv3;
	}
	else
	{
		delete kv3;
		state = "alive";
	}
	if (StrEqual(state, "dead"))
	{
		PrintCenterTextAll("ADMIN: I AM YOU");
		if (!g_hit_vul_door)
		{
			g_hit_vul_door = true;
			CreateTimer(20.0, SubmitPawnTimer);
		}
		
		return Plugin_Handled;
	}
	for (int i = 0; i < strlen(pawn_name); i++)
	{
		pawn_name[i] = CharToUpper(pawn_name[i]);
	}
	for (int i = 0; i < strlen(date); i++)
	{
		date[i] = CharToUpper(date[i]);
	}
	PrintCenterTextAll("ADMIN: I AM %s. I DIED ON %s AND THEN RESPAWN IN THE MACHINE", pawn_name, date);
	return Plugin_Handled;


}