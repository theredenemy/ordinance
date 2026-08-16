#include <sdkhooks>
#include <sdktools>
#include <sourcemod>
#include <SteamWorks>
#include <json>
#include <tf2_stocks>
#pragma newdecls required
#pragma semicolon 1
char g_playername[MAX_NAME_LENGTH];
char g_playersteamid[256];
char g_playerclass[128];
char g_playerweapon[256];
char g_playerteam[64];
bool g_hit_vul_door;

ConVar g_triggername;
ConVar g_autokick;

void clearPawnVars()
{
	g_playername = "\0";
	SetConVarString(g_triggername, "\0");
	PrintToServer("Vars Cleared");
}
public bool IsPawnAlive()
{
	char state[256];
	char path2[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, path2, sizeof(path2), "configs/%s", PAWN_STATE_FILE);
	KeyValues kv_pawn = new KeyValues("Pawn_state");
	if (!kv_pawn.ImportFromFile(path2))
	{
		PrintToServer("NO FILE");
		delete kv_pawn;
		return false;
	}

	if (kv_pawn.JumpToKey("state", false))
	{
		kv_pawn.GetString(NULL_STRING, state, sizeof(state));
		delete kv_pawn;
	}
	else
	{
		delete kv_pawn;
		state = "alive";
	}
	if (StrEqual("alive", state))
	{
		return true;
	}
	else
	{
		return false;
	}
}
public void SendData(const char[] player, const char[] trigger, int timestamp, const char[] team, const char[] weapon, const char[] playerclass)
{
	char date[256];
	char output[1024];
	char url[256];
	char ord_server[256];
	GetConVarString(g_ordinance_server, ord_server, sizeof(ord_server));
	JSON_Object obj = new JSON_Object();
	FormatTime(date, sizeof(date), "%B %dTH %Y", timestamp);
	PrintToConsoleAll("Player : %s Trigger : %s Date : %s Team : %s Weapon : %s Player Class : %s", player, trigger, date, team, weapon, playerclass);
	obj.SetString("player", player);
	obj.SetInt("timestamp", timestamp);
	obj.SetString("date", date);
	obj.SetString("trigger", trigger);
	obj.SetString("team", team);
	obj.SetString("weapon", weapon);
	obj.SetString("playerclass", playerclass);
	obj.Encode(output, sizeof(output));
	Format(url, sizeof(url), "%s/ord/pawn/submit", ord_server);
	Handle req = SteamWorks_CreateHTTPRequest(k_EHTTPMethodPOST, url);
	if (req == INVALID_HANDLE) return;
	SteamWorks_SetHTTPRequestHeaderValue(req, "Content-Type", "application/json");
	SteamWorks_SetHTTPRequestRawPostBody(req, "application/json", output, strlen(output));
	char ord_key[1024];
	GetConVarString(g_ord_key, ord_key, sizeof(ord_key));
	SteamWorks_SetHTTPRequestHeaderValue(req, "X-ORD-KEY", ord_key);
	SteamWorks_SetHTTPCallbacks(req, OnHTTPResponse);
	SteamWorks_SendHTTPRequest(req);
	json_cleanup_and_delete(obj);
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
		Format(url, sizeof(url), "%s/ord/pawn/state", ord_server);
		Handle req = SteamWorks_CreateHTTPRequest(k_EHTTPMethodPOST, url);
		if (req == INVALID_HANDLE) return;
		SteamWorks_SetHTTPRequestHeaderValue(req, "Content-Type", "application/json");
		SteamWorks_SetHTTPRequestRawPostBody(req, "application/json", output, strlen(output));
		char ord_key[1024];
		GetConVarString(g_ord_key, ord_key, sizeof(ord_key));
		SteamWorks_SetHTTPRequestHeaderValue(req, "X-ORD-KEY", ord_key);
		SteamWorks_SetHTTPCallbacks(req, OnHTTPResponse);
		SteamWorks_SendHTTPRequest(req);
		json_cleanup_and_delete(obj);
	}

}
public void set_pawn(const char[] player, const char[] date, const char[] team, const char[] weapon, const char[] playerclass)
{
	char path[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, path, sizeof(path), "configs/%s", PLAYER_PAWN_FILE);
	KeyValues kv = new KeyValues("Player_Pawn");
	kv.SetString("playername", player);
	kv.SetString("date", date);
	kv.SetString("team", team);
	kv.SetString("weapon", weapon);
	kv.SetString("playerclass", playerclass);
	kv.Rewind();
	kv.ExportToFile(path);
	delete kv;
	Handle data = CreateDataPack();

	CreateDataTimer(3.0, SetPawnState_Timer, data, TIMER_DATA_HNDL_CLOSE);
	WritePackString(data, "alive");
	// set_pawn_state("alive", true);
}

public void OnTriggerHurt(const char[] output, int caller, int activator, float delay)
{
	if (activator >= 1 && activator <= MaxClients && IsClientInGame(activator))
	{
		char callerClass[64];
		char name[256];
		TFClassType tf_class = TF2_GetPlayerClass(activator);
		TFTeam tf_team = TF2_GetClientTeam(activator);
		GetEntityClassname(caller, callerClass, sizeof(callerClass)); 
		GetClientName(activator, g_playername, sizeof(g_playername));
		GetClientAuthId(activator, AuthId_Steam2, g_playersteamid, sizeof(g_playersteamid));
		g_playerweapon = g_last_weapon[activator];
		GetEntPropString(caller, Prop_Data, "m_iName", name, sizeof(name));
		SetConVarString(g_triggername, name);
		ReplaceString(g_playername, sizeof(g_playername), "/", "");
		ReplaceString(g_playername, sizeof(g_playername), "\\", "");
		ReplaceString(g_playername, sizeof(g_playername), "\"", "");
		ReplaceString(g_playername, sizeof(g_playername), "\'", "");
		char classnames[10][9] = {
			"UNKNOWN",
			"SCOUT",
			"SNIPER",
			"SOLDIER",
			"DEMOMAN",
			"MEDIC",
			"HEAVY",
			"PYRO",
			"SPY",
			"ENGINEER"
		};
		g_playerclass = classnames[tf_class];
		char teams[4][11] = {
			"UNASSIGNED",
			"SPECTATOR",
			"RED",
			"BLU"
		};
		g_playerteam = teams[tf_team];

		PrintToServer("Player %s With SteamID %s On Team %s With The Class %s And Has a %s Has Hit A %s With The Name %s", g_playername, g_playersteamid, g_playerteam, g_playerclass, g_playerweapon, callerClass, name);

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
	char submit_pawn_level[PLATFORM_MAX_PATH];
	GetConVarString(g_submit_pawn_level, submit_pawn_level, sizeof(submit_pawn_level));
	ForceChangeLevel(submit_pawn_level, "SUBMIT");
	return Plugin_Continue;
}
public Action SetPawnState_Timer(Handle timer, Handle data)
{
	char state[128];

	ResetPack(data);
	ReadPackString(data, state, sizeof(state));
	set_pawn_state(state, true);
	return Plugin_Continue;

}
public Action pawn_clear_cmd(int args)
{
	clearPawnVars();
	return Plugin_Handled;
}
public Action pawn_submit_cmd(int args)
{
	char arg[256];
    char full[256];
	char cmd[256];
	char triggername[256];
	char date[64];
	int ordinance_enabled = GetConVarInt(g_ordinance_enabled);
	int timestamp = GetTime();
	int cmd_len;
	char server_error_level[PLATFORM_MAX_PATH];
	GetConVarString(g_server_error_level, server_error_level, sizeof(server_error_level));
	if (args < 1)
	{
		PrintToServer("[SM] Usage: pawn_submit '<cmd>' '<arg>'");
		return Plugin_Handled;
	}
	GetCmdArgString(full, sizeof(full));
	if (!g_ordserveronline || ordinance_enabled != 1)
		{
			if (IsMapValid(server_error_level))
			{
				ForceChangeLevel(server_error_level, "NO INPUT");
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
	set_pawn(g_playername, date, g_playerteam, g_playerweapon, g_playerclass);
	SendData(g_playername, triggername, timestamp, g_playerteam, g_playerweapon, g_playerclass);
	PrintHintTextToAll("ADMIN: CALCULATING");

	return Plugin_Handled;
}
public Action pawn_check_cmd(int args)
{
	char playername[MAX_NAME_LENGTH];
	char path[PLATFORM_MAX_PATH];
	char mapname[128];
	int ordinance_enabled = GetConVarInt(g_ordinance_enabled);
	char reason[256] = "YOU ARE IN THE MACHINE NOW";
	int autokick = GetConVarInt(g_autokick);
	char pawn_name[MAX_NAME_LENGTH];
	char submit_pawn_level[PLATFORM_MAX_PATH];
	GetConVarString(g_submit_pawn_level, submit_pawn_level, sizeof(submit_pawn_level));
	if (autokick != 1)
	{
		PrintToServer("autokick off");
		return Plugin_Handled;
	}
	if (!g_ordserveronline || ordinance_enabled != 1)
	{
		return Plugin_Handled;
	}
	
	BuildPath(Path_SM, path, sizeof(path), "configs/%s", PLAYER_PAWN_FILE);
	KeyValues kv = new KeyValues("Player_Pawn");
	GetCurrentMap(mapname, sizeof(mapname));
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
		if (!StrEqual(mapname, submit_pawn_level, false))
		{
			if (IsMapValid(submit_pawn_level))
			{
				PrintToServer("NO PLAYER PAWN");
				ForceChangeLevel(submit_pawn_level, "NO PLAYER PAWN");
				return Plugin_Handled;
			}
			else
			{
				return Plugin_Handled;
			}
		}
	}
	// PrintToServer(pawn_name);
	
	if (StrEqual(mapname, "2fort", false) || StrEqual(mapname, "cp_dustbowl", false))
	{
		return Plugin_Handled;
	}
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && !IsClientSourceTV(i) && IsPlayerAlive(i))
		{
			GetClientName(i, playername, sizeof(playername));
			// PrintToServer(playername);
			if (StrEqual(playername, pawn_name, false))
			{
				KickClient(i, reason);
			}
		}
	}
	return Plugin_Handled;

}

public Action pawn_state_cmd(int args)
{
	int ordinance_enabled = GetConVarInt(g_ordinance_enabled);
	char arg[128];
	if (args > 1)
	{
		return Plugin_Handled;
	}
	else if(args < 1)
	{
		PrintToServer("[SM] Usage: pawn_state <state>");
		return Plugin_Handled;
	}
	if (ordinance_enabled != 1 || !g_ordserveronline)
	{
		return Plugin_Handled;
	}
	GetCmdArg(1, arg, sizeof(arg));

	set_pawn_state(arg, true);
	return Plugin_Handled;
}

public Action display_vul_text_cmd(int args)
{
	char path[PLATFORM_MAX_PATH];
	char path2[PLATFORM_MAX_PATH];
	int ordinance_enabled = GetConVarInt(g_ordinance_enabled);
	char pawn_name[MAX_NAME_LENGTH];
	char team[64];
	char playerclass[128];
	char weapon[256];
	char date[64];
	char state[256];
	char server_error_level[PLATFORM_MAX_PATH];
	GetConVarString(g_server_error_level, server_error_level, sizeof(server_error_level));
	if (!g_ordserveronline) {
		PrintHintTextToAll("ADMIN: ORDINANCE SERVER NOT ONLINE PLEASE TRY AGAIN LATER");
		if (!IsPawnAlive())
		{
			if (IsMapValid(server_error_level))
			{
				ForceChangeLevel(server_error_level, "NO INPUT");
			}
			else
			{
				ForceChangeLevel("cp_dustbowl", "NO INPUT");
			}
			return Plugin_Handled;
		}
		
	}
	if (ordinance_enabled != 1)
	{
		PrintHintTextToAll("ADMIN: ORDINANCE DISABLED");
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
		kv.Rewind();
	}
	else
	{
		kv.Rewind();
		pawn_name = "MACHINE";
	}
	
	



	if (kv.JumpToKey("date", false))
	{
		kv.GetString(NULL_STRING, date, sizeof(date));
		kv.Rewind();
	}
	else
	{
		kv.Rewind();
		date = "DECEMBER 31TH 2008";
	}
	if (kv.JumpToKey("team", false))
	{
		kv.GetString(NULL_STRING, team, sizeof(team));
		kv.Rewind();
	}
	else
	{
		kv.Rewind();
		team = "UNKNOWN";
	}
	
	if (kv.JumpToKey("weapon", false))
	{
		kv.GetString(NULL_STRING, weapon, sizeof(weapon));
		kv.Rewind();
	}
	else
	{
		kv.Rewind();
		weapon = "UNKNOWN";
	}
	if (kv.JumpToKey("weapon", false))
	{
		kv.GetString(NULL_STRING, weapon, sizeof(weapon));
		kv.Rewind();
	}
	else
	{
		kv.Rewind();
		weapon = "UNKNOWN";
	}
	if (kv.JumpToKey("PlayerClass", false))
	{
		kv.GetString(NULL_STRING, playerclass, sizeof(playerclass));
		delete kv;
	}
	else
	{
		delete kv;
		weapon = "UNKNOWN";
	}
	KeyValues kv_pawn = new KeyValues("Pawn_state");
	if (!kv_pawn.ImportFromFile(path2))
	{
		PrintToServer("NO FILE");
		delete kv_pawn;
		return Plugin_Handled;
	}

	if (kv_pawn.JumpToKey("state", false))
	{
		kv_pawn.GetString(NULL_STRING, state, sizeof(state));
		delete kv_pawn;
	}
	else
	{
		delete kv_pawn;
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
	for (int i = 0; i < strlen(weapon); i++)
	{
		weapon[i] = CharToUpper(weapon[i]);
	}
	ReplaceString(weapon, sizeof(weapon), "THE ", "");
	PrintCenterTextAll("ADMIN: I AM %s. A %s %s WITH A %s. I DIED ON %s AND THEN RESPAWN IN THE MACHINE", pawn_name, team, playerclass, weapon, date);
	return Plugin_Handled;


}