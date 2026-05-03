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
	version = "5.0.4",
	url = "https://github.com/theredenemy/ordinance"
};

#include <submit_pawn/submit_pawn.sp>
#include <ordinance_controller/ordinance_controller.sp>
#include <chatbot/chatbot.sp>


public void OnPluginStart()
{
	g_triggername = CreateConVar("pawn_trigger", "\0");
	g_autokick = CreateConVar("pawn_autokick", "0");
	g_ord_key = CreateConVar("ord_key", "\0");
	g_ordserveronline = false;
	g_pawnalive = true;
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
	RegConsoleCmd("say", Command_Say);
	RegConsoleCmd("say_team", Command_Say);
	SetConVarFlags(g_ordinance_enabled, FCVAR_NOTIFY);
	LogMessage("LOADING ITEMS_GAME.TXT...");
	if (!g_KvItems.ImportFromFile("scripts/items/items_game.txt"))
		{
			SetFailState("ITEMS_GAME.TXT FAILED TO LOAD");
		}
	PrintToServer("ordinance Has Loaded");
}
public void OnClientPutInServer(int client)
{
	SDKHook(client, SDKHook_WeaponSwitchPost, WeaponSwitchPostCheck);
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
public void OnMapStart()
{
	clearPawnVars();
	char mapname[128];
	char url[256];
	char ord_server[256];
	int ordinance_enabled = GetConVarInt(g_ordinance_enabled);
	GetConVarString(g_ordinance_server, ord_server, sizeof(ord_server));
	g_hit_vul_door = false;
	GetCurrentMap(mapname, sizeof(mapname));
	if (StrEqual(mapname, "ord_error", false))
	{
		set_pawn_state("dead", false);
	}
	HookEntityOutput("trigger_hurt", "OnHurtPlayer", OnTriggerHurt);
	Format(url, sizeof(url), "%s/ord/info", ord_server);
	Handle hRequest = SteamWorks_CreateHTTPRequest(k_EHTTPMethodGET, url);
	SteamWorks_SetHTTPCallbacks(hRequest, CheckOrdServer);
	SteamWorks_SendHTTPRequest(hRequest);
	g_mapname = "\0";
	GetCurrentMap(g_mapname, sizeof(g_mapname));
	char path2[PLATFORM_MAX_PATH];
	char state[256];
	BuildPath(Path_SM, path2, sizeof(path2), "configs/%s", PAWN_STATE_FILE);
	if (StrEqual(mapname, "ordinance") || StrEqual(mapname, "ord_mode") )
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
}