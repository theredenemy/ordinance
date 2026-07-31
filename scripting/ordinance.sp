#include <sdkhooks>
#include <sdktools>
#include <sourcemod>

#include <SteamWorks>
#include <json>
#pragma newdecls required
#pragma semicolon 1
ConVar g_ordinance_enabled;
#define PLAYER_PAWN_FILE "player_pawn.txt"
#define PAWN_STATE_FILE "pawn_state.txt"
ConVar g_ordinance_server;
ConVar g_ord_key;
bool g_ordserveronline;
bool g_pawnalive;
char g_mapname[128];
char g_last_weapon[MAXPLAYERS+1][128];
KeyValues g_KvItems;
public Plugin myinfo =
{
	name = "ordinance",
	author = "TheRedEnemy",
	description = "",
	version = "8.0.0",
	url = "https://github.com/theredenemy/ordinance"
};

#include <submit_pawn/submit_pawn.sp>
#include <ordinance_controller/ordinance_controller.sp>
#include <chatbot/chatbot.sp>
#include <play/play.sp>


public void OnPluginStart()
{
	g_triggername = CreateConVar("pawn_trigger", "\0");
	g_autokick = CreateConVar("pawn_autokick", "0");
	g_ord_key = CreateConVar("ord_key", "\0");
	g_ordserveronline = false;
	g_pawnalive = true;
	g_spray = false;
	g_allow_spray_submit = false;
	g_KvItems = new KeyValues("items_game");
	HookEvent("teamplay_round_start", Event_RoundStart, EventHookMode_Post);
	HookEvent("player_spawn", Event_PlayerSpawn, EventHookMode_Post);
	RegServerCmd("pawn_submit", pawn_submit_cmd);
	RegServerCmd("pawn_check", pawn_check_cmd);
	RegServerCmd("pawn_clear", pawn_clear_cmd);
	RegServerCmd("vul_text", display_vul_text_cmd);
	makePawnConfig();
	g_ordinance_enabled = CreateConVar("ordinance_enabled", "0");
	g_ordinance_server = CreateConVar("ordinance_server", "http://127.0.0.1:5000");
	g_ordserveronline = false;
	RegServerCmd("ord_input", ord_input_command);
	RegServerCmd("ord_render", ord_render_command);
	RegServerCmd("ord_clear", ord_clear_command);
	RegServerCmd("ord_getinputs", ord_get_inputs);
	RegServerCmd("bot_say", Command_Bot_Say);
	RegServerCmd("ord_mode", ord_mode_command);
	RegServerCmd("pawn_state", pawn_state_cmd);
	RegConsoleCmd("say", Command_Say);
	RegConsoleCmd("say_team", Command_Say);
	SetConVarFlags(g_ordinance_enabled, FCVAR_NOTIFY);
	SetConVarFlags(g_ord_key, FCVAR_PROTECTED & FCVAR_NOTIFY);
	SetConVarFlags(g_ordinance_server, FCVAR_NOTIFY);
	LogMessage("LOADING ITEMS_GAME.TXT...");
	if (!g_KvItems.ImportFromFile("scripts/items/items_game.txt"))
		{
			SetFailState("ITEMS_GAME.TXT FAILED TO LOAD");
		}
	CreateTimer(20.0, CheckOrd_Server_timer, _, TIMER_REPEAT);
	PrintToServer("ordinance Has Loaded");
}
public void OnPluginEnd()
{
	LogMessage("UNLOADING ITEMS_GAME.TXT...");
	delete g_KvItems;
	PrintToServer("BYEBYE");

}
public void SendPlayerData(int client)
{
	char playername[MAX_NAME_LENGTH];
	char playersteamid[256];
	char output[1024];
	char url[256];
	char ord_server[256];
	GetConVarString(g_ordinance_server, ord_server, sizeof(ord_server));
	JSON_Object obj = new JSON_Object();
	GetClientName(client, playername, sizeof(playername));
	GetClientAuthId(client, AuthId_Steam2, playersteamid, sizeof(playersteamid));
	obj.SetString("player", playername);
	obj.SetString("steamid", playersteamid);
	obj.Encode(output, sizeof(output));
	Format(url, sizeof(url), "%s/getdata", ord_server);
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
public void EnterOrdPlay()
{
	char validChars[] = "qwertyuiopasdfghjklzxcvbnm";
	char password[16];
	char playername[MAX_NAME_LENGTH];
	int[] clients = new int[MaxClients + 1];
	int count = 0;

	for (int i = 0; i < sizeof(password) - 1; i++)
	{
		int randomindex = GetRandomInt(0, strlen(validChars) - 1);
		password[i] = validChars[randomindex];
	}
	PrintToServer("PASSWORD: %s", password);
	SetConVarString(FindConVar("sv_password"), password);

	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && !IsClientSourceTV(i) && i != 0)
		{
			clients[count] = i;
			count++;
		}
	}
	g_allow_spray_submit = true;
	if (count >> 1)
	{
		int randomclient = clients[GetRandomInt(0, count - 1)];
		GetClientName(randomclient, playername, sizeof(playername));
		PrintToServer("PLAYER: %s", playername);
		for (int i = 1; i <= MaxClients; i++)
		{
			if (IsClientInGame(i) && !IsClientSourceTV(i))
			{
				GetClientName(i, playername, sizeof(playername));
				PrintToServer(playername);
				if (i != randomclient)
				{
					KickClient(i, "ORD_PLAY AUTO_KICK");
				}
			}
		}
	}
	
	return;
}
public void OnClientPutInServer(int client)
{
	SDKHook(client, SDKHook_WeaponSwitchPost, WeaponSwitchPostCheck);
	if (g_ordserveronline)
	{
		SendPlayerData(client);
	}
	
}
public Action WeaponSwitchPostCheck(int client, int weapon)
{
	char index_STRING[64];
	if (IsValidEntity(weapon))
	{
		int index = GetEntProp(weapon, Prop_Send, "m_iItemDefinitionIndex");
		IntToString(index, index_STRING, sizeof(index_STRING));
		
		

		if (g_KvItems.JumpToKey("items"))
		{
			if (g_KvItems.JumpToKey(index_STRING))
			{
				g_KvItems.GetString("name", g_last_weapon[client], sizeof(g_last_weapon));
				g_KvItems.Rewind();
				return Plugin_Continue;
			}
			else
			{
				GetEdictClassname(weapon, g_last_weapon[client], sizeof(g_last_weapon));
				g_KvItems.Rewind();
				return Plugin_Continue;
			}
		}
		else
		{
			GetEdictClassname(weapon, g_last_weapon[client], sizeof(g_last_weapon));
			g_KvItems.Rewind();
			return Plugin_Continue;
		}
		

		
	}
	else
	{
		g_last_weapon[client] = "INVALID_ENTITY";
		return Plugin_Continue;
	}
	
}
public Action OrdPlayEnter_timer(Handle timer)
{
	EnterOrdPlay();
	return Plugin_Continue;
}
public Action OrdError(Handle timer)
{
	if (IsMapValid("ord_error"))
	{
		ForceChangeLevel("ord_error", "PAWN IS DEAD");
	}
	else
	{
		ForceChangeLevel("cp_dustbowl", "NO INPUT");
	}
	
	return Plugin_Continue;
}

public Action ChangeLevel_Timer(Handle timer, Handle data)
{
	char map[PLATFORM_MAX_PATH];
	char reason[1024];

	ResetPack(data);
	ReadPackString(data, map, sizeof(map));
	ReadPackString(data, reason, sizeof(reason));
	if (IsMapValid(map))
	{
		ForceChangeLevel(map, reason);
	}
	return Plugin_Continue;

}

public void Time_ForceChangeLevel(float interval, const char[] map, const char[] reason)
{
	Handle data = CreateDataPack();

	CreateDataTimer(interval, ChangeLevel_Timer, data, TIMER_DATA_HNDL_CLOSE);
	WritePackString(data, map);
	WritePackString(data, reason);
	return;

}
public int CheckOrdServer(Handle hRequest, bool bFailure, bool bRequestSuccessful, EHTTPStatusCode statuscode)
{
	if (bRequestSuccessful && statuscode == k_EHTTPStatusCode200OK)
	{
		bool forbid = (StrEqual(g_mapname, "2fort", false) || StrEqual(g_mapname, "cp_dustbowl", false) || StrEqual(g_mapname, "ord_error", false) || StrEqual(g_mapname, "askask", false) || StrEqual(g_mapname, "ord_ren", false) || StrEqual(g_mapname, "ord_end", false) || StrEqual(g_mapname, "ordinance", false) || StrEqual(g_mapname, "view", false) || StrEqual(g_mapname, "ord_mode", false));
		char state[256];
		char data[1024];
		char kv_state[256];
		char path2[PLATFORM_MAX_PATH];
		
		
		g_ordserveronline = true;
		
		
		if (StrEqual(g_mapname, "ordinance", false))
		{
			SendInput("BEGIN");
		}
		BuildPath(Path_SM, path2, sizeof(path2), "configs/%s", PAWN_STATE_FILE);
	
		KeyValues kv3 = new KeyValues("Pawn_state");
		if (!kv3.ImportFromFile(path2))
		{
			PrintToServer("NO FILE");
			delete kv3;
			CloseHandle(hRequest);
			PrintToServer("Close Handle");
			return 0;
		}

		if (kv3.JumpToKey("state", false))
		{
			kv3.GetString(NULL_STRING, kv_state, sizeof(kv_state));
			delete kv3;
		}
		else
		{
			delete kv3;
			kv_state = "alive";
		}
		int HTTP_BodySize = 0;

		if (!SteamWorks_GetHTTPResponseBodySize(hRequest, HTTP_BodySize) || HTTP_BodySize <= 0)
		{
			PrintToServer("Response Is Empty or failed to read size");
			CloneHandle(hRequest);
			PrintToServer("Close Handle");
			return 0;
		}
		SteamWorks_GetHTTPResponseBodyData(hRequest, data, HTTP_BodySize);
		JSON_Object obj = json_decode(data);
		obj.GetString("state", state, sizeof(state));
		
		
		json_cleanup_and_delete(obj);
		if (StrEqual(state, "dead"))
		{
			g_pawnalive = false;
			if (!forbid && !StrEqual(kv_state, "dead", false))
			{
				PrintToServer("PAWN IS DEAD");
				CreateTimer(20.0, OrdError);
			}
				
		}
		else
		{
			g_pawnalive = true;
		}
		
		CloseHandle(hRequest);
		PrintToServer("Close Handle");
		return 0;
	}
	else
	{
		CloseHandle(hRequest);
		PrintToServer("Close Handle");
		g_ordserveronline = false;
		return 0;
	}

}
public int OnHTTPResponse(Handle req, bool bFailure, bool bRequestSuccessful, EHTTPStatusCode statuscode)
{
	CloseHandle(req);
	PrintToServer("Close Handle");
	return 0;
}
void makePawnConfig()
{
	char path[PLATFORM_MAX_PATH];
	char path2[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, path, sizeof(path), "configs/%s", PLAYER_PAWN_FILE);
	BuildPath(Path_SM, path2, sizeof(path2), "configs/%s", PAWN_STATE_FILE);
	if (!FileExists(path))
	{
		PrintToServer(path);
		KeyValues kv = new KeyValues("Player_Pawn");
		kv.SetString("playername", "SERVICE MANAGER");
		// Change This From 2099 Due to Y2K38
		kv.SetString("date", "DECEMBER 31TH 2008");
		kv.SetString("team", "UNKNOWN");
		kv.SetString("weapon", "UNKNOWN");
		kv.SetString("playerclass", "UNKNOWN");
		kv.Rewind();
		kv.ExportToFile(path);
		delete kv;
	}
	if (!FileExists(path2))
	{
		KeyValues kv = new KeyValues("Pawn_state");
		kv.SetString("state", "alive");
		kv.Rewind();
		kv.ExportToFile(path2);
		delete kv;
	}
}
public int CheckOrdServer_OnTimer(Handle hRequest, bool bFailure, bool bRequestSuccessful, EHTTPStatusCode statuscode)
{
	if (bRequestSuccessful && statuscode != k_EHTTPStatusCode200OK && g_ordserveronline)
	{
		char sound[] = "common/bugreporter_failed.wav";
		PrecacheSound(sound, true);
		PrintToChatAll("ORD SERVER IS NOW OFFLINE");
		EmitSoundToAll(sound);
		g_ordserveronline = false;
		
		CloseHandle(hRequest);
		//PrintToServer("Close Handle");
		return 0;
	}
	else if(bRequestSuccessful && statuscode == k_EHTTPStatusCode200OK && !g_ordserveronline)
	{
		g_ordserveronline = true;
		char sound[] = "friends/friend_online.wav";
		PrecacheSound(sound, true);
		PrintToChatAll("ORD SERVER IS NOW ONLINE Reloading Level.");
		EmitSoundToAll(sound);
		Time_ForceChangeLevel(10.0, g_mapname, "ORDSERVER_ONLINE");
		CloseHandle(hRequest);
		//PrintToServer("Close Handle");
		
		return 0;	
	}
	else
	{
		CloseHandle(hRequest);
		//PrintToServer("Close Handle");
		return 0;
	}

}
public Action CheckOrd_Server_timer(Handle timer)
{
	char url[256];
	char ord_server[256];
	GetConVarString(g_ordinance_server, ord_server, sizeof(ord_server));
	Format(url, sizeof(url), "%s/ord/info", ord_server);
	Handle hRequest = SteamWorks_CreateHTTPRequest(k_EHTTPMethodGET, url);
	char ord_key[1024];
	GetConVarString(g_ord_key, ord_key, sizeof(ord_key));
	SteamWorks_SetHTTPRequestHeaderValue(hRequest, "X-ORD-KEY", ord_key);
	SteamWorks_SetHTTPCallbacks(hRequest, CheckOrdServer_OnTimer);
	SteamWorks_SendHTTPRequest(hRequest);
	return Plugin_Continue;
}
public void OnMapStart()
{
	clearPawnVars();
	char url[256];
	char ord_server[256];
	int ordinance_enabled = GetConVarInt(g_ordinance_enabled);
	GetConVarString(g_ordinance_server, ord_server, sizeof(ord_server));
	g_hit_vul_door = false;
	g_spray = false;
	g_allow_spray_submit = false;
	g_mapname = "\0";
	GetCurrentMap(g_mapname, sizeof(g_mapname));
	if (StrEqual(g_mapname, "ord_error", false))
	{
		set_pawn_state("dead", false);
	}
	HookEntityOutput("trigger_hurt", "OnHurtPlayer", OnTriggerHurt);
	Format(url, sizeof(url), "%s/ord/info", ord_server);
	Handle hRequest = SteamWorks_CreateHTTPRequest(k_EHTTPMethodGET, url);
	char ord_key[1024];
	GetConVarString(g_ord_key, ord_key, sizeof(ord_key));
	SteamWorks_SetHTTPRequestHeaderValue(hRequest, "X-ORD-KEY", ord_key);
	SteamWorks_SetHTTPCallbacks(hRequest, CheckOrdServer);
	SteamWorks_SendHTTPRequest(hRequest);
	if (StrEqual(g_mapname, "view", false))
	{
		// I dont know why tf2 does not download view.wav
		// AddFileToDownloadsTable("sound/view.wav");
		AddFileToDownloadsTable("materials/view.vmt");
		AddFileToDownloadsTable("materials/view.vtf");
	}
	char path2[PLATFORM_MAX_PATH];
	char state[256];
	BuildPath(Path_SM, path2, sizeof(path2), "configs/%s", PAWN_STATE_FILE);
	if (StrEqual(g_mapname, "ordinance") || StrEqual(g_mapname, "ord_mode") )
	{
		KeyValues kv3 = new KeyValues("Pawn_state");
		if (!kv3.ImportFromFile(path2))
		{
			PrintToServer("NO FILE");
			delete kv3;
			return;
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
		if (StrEqual(state, "dead") && ordinance_enabled == 1 && g_ordserveronline)
		{
			PrintCenterTextAll("ADMIN: I AM YOU");
			CreateTimer(20.0, OrdCry);
			return;
		}
		
	}
	if (StrEqual(g_mapname, "ord_play", false))
	{
		CreateTimer(30.0, OrdPlayEnter_timer);
	}
}