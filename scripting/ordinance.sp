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
// #define ORDINANCE_SERVER "10.0.0.100:5000"
ConVar g_ordinance_server;
bool g_ordserveronline;
char g_mapname[128];
public Plugin myinfo =
{
	name = "ordinance",
	author = "TheRedEnemy",
	description = "",
	version = "2.0.0",
	url = "https://github.com/theredenemy/ordinance"
};

#include <submit_pawn/submit_pawn.sp>
#include <ordinance_controller/ordinance_controller.sp>
public void OnPluginStart()
{
	g_triggername = CreateConVar("pawn_trigger", "\0");
	g_autokick = CreateConVar("pawn_autokick", "0");
	g_ordserveronline = false;
	HookEvent("teamplay_round_start", Event_RoundStart, EventHookMode_Post);
	HookEvent("player_spawn", Event_PlayerSpawn, EventHookMode_Post);
	RegServerCmd("pawn_submit", pawn_submit_cmd);
	RegServerCmd("pawn_check", pawn_check_cmd);
	RegServerCmd("vul_text", display_vul_text_cmd);
	makePawnConfig();
	g_ordinance_enabled = CreateConVar("ordinance_enabled", "0");
	g_ordinance_server = CreateConVar("ordinance_server", "127.0.0.1:5000");
	g_ordserveronline = false;
	RegServerCmd("ord_input", ord_input_command);
	RegServerCmd("ord_render", ord_render_command);
	RegServerCmd("ord_clear", ord_clear_command);
	RegServerCmd("ord_getinputs", ord_get_inputs);
	PrintToServer("ordinance Has Loaded");
}
public int CheckOrdServer(Handle hRequest, bool bFailure, bool bRequestSuccessful, EHTTPStatusCode statuscode)
{
	if (bRequestSuccessful && statuscode == k_EHTTPStatusCode200OK)
	{
		CloseHandle(hRequest);
		PrintToServer("Close Handle");
		g_ordserveronline = true;
		if (StrEqual(g_mapname, "ordinance"))
		{
			SendInput("BEGIN");
		}
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
		kv.SetString("date", "DECEMBER 31TH 2099");
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
	GetConVarString(g_ordinance_server, ord_server, sizeof(ord_server));
	g_hit_vul_door = false;
	GetCurrentMap(mapname, sizeof(mapname));
	if (StrEqual(mapname, "ord_error"))
	{
		set_pawn_state("dead", false);
	}
	HookEntityOutput("trigger_hurt", "OnHurtPlayer", OnTriggerHurt);
	Format(url, sizeof(url), "http://%s", ord_server);
	Handle hRequest = SteamWorks_CreateHTTPRequest(k_EHTTPMethodGET, url);
	SteamWorks_SetHTTPCallbacks(hRequest, CheckOrdServer);
	SteamWorks_SendHTTPRequest(hRequest);
	g_mapname = "\0";
	GetCurrentMap(g_mapname, sizeof(g_mapname));
	char path2[PLATFORM_MAX_PATH];
	char state[256];
	BuildPath(Path_SM, path2, sizeof(path2), "configs/%s", PAWN_STATE_FILE);
	if (StrEqual(mapname, "ordinance"))
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
		if (StrEqual(state, "dead"))
		{
			PrintCenterTextAll("ADMIN: I AM YOU");
			CreateTimer(20.0, OrdCry);
			return;
		}
		
	}
}