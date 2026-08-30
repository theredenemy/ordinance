#include <sdkhooks>
#include <sdktools>
#include <sourcemod>
#include <SteamWorks>
#include <json>
#pragma newdecls required
#pragma semicolon 1
#define MAX_INPUT_LEN 256



public Action OrdEnd(Handle timer)
{
	char ord_end_level[PLATFORM_MAX_PATH];
	GetConVarString(g_ord_end_level, ord_end_level, sizeof(ord_end_level));
	if (IsMapValid(ord_end_level))
	{
		ForceChangeLevel(ord_end_level, "NO INPUT");
	}
	else
	{
		ForceChangeLevel("cp_dustbowl", "NO INPUT");
	}
	return Plugin_Continue;
}
public Action OrdCry(Handle timer)
{
	// Do You take Arbys Gift cards
	if (IsMapValid("ord_cry"))
	{
		ForceChangeLevel("ord_cry", "FUCKING DIE");
	}
	else
	{
		ForceChangeLevel("cp_dustbowl", "NO MAP");
	}
	
	return Plugin_Continue;
}
public int OnModeSetResponse(Handle req, bool bFailure, bool bRequestSuccessful, EHTTPStatusCode statuscode)
{
	if (bFailure || !bRequestSuccessful || statuscode != k_EHTTPStatusCode200OK)
	{
		CloseHandle(req);
		PrintCenterTextAll("ADMIN: CANT SET MODE");
		PrintToServer("Close Handle");
		return 0;
	}
	CloseHandle(req);
	PrintToServer("Close Handle");
	return 0;
}
public int OnRenderResponse(Handle req, bool bFailure, bool bRequestSuccessful, EHTTPStatusCode statuscode)
{
	char data[1024];
	char message[256];
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
	obj.GetString("message", message, sizeof(message));
	if (StrEqual(message, "ORD_ERROR"))
	{
		PrintToServer("PAWN IS DEAD");
		CreateTimer(20.0, OrdError);
	}
	else if(StrEqual(message, "NO_INPUT"))
	{
		PrintToServer("NO_INPUT");
		CreateTimer(20.0, OrdEnd);
	}
	CloseHandle(req);
	json_cleanup_and_delete(obj);
	PrintToServer("Close Handle");
	return 0;
	 
}

public int OnGetInputsResponse(Handle req, bool bFailure, bool bRequestSuccessful, EHTTPStatusCode statuscode)
{
	char data[1024];
	char message[2048];
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
	obj.GetString("message", message, sizeof(message));
	if (message[0])
	{
		PrintToConsoleAll(message);
	}
	CloseHandle(req);
	json_cleanup_and_delete(obj);
	PrintToServer("Close Handle");
	return 0;
	 
}
public void SendInput(const char[] input)
{
	char path[PLATFORM_MAX_PATH];
	char pawn_name[MAX_NAME_LENGTH];
	char output[1024];
	char url[256];
	char ord_server[256];
	GetConVarString(g_ordinance_server, ord_server, sizeof(ord_server));
	JSON_Object obj = new JSON_Object();
	BuildPath(Path_SM, path, sizeof(path), "configs/%s", PLAYER_PAWN_FILE);
	KeyValues kv = new KeyValues("Player_Pawn");
	if (!kv.ImportFromFile(path))
	{
		PrintToServer("NO FILE");
		delete kv;
		return;
	}

	if (kv.JumpToKey("playername", false))
	{
		kv.GetString(NULL_STRING, pawn_name, sizeof(pawn_name));
		delete kv;
	}

	PrintToServer("input : %s pawn_name : %s", input, pawn_name);
	obj.SetString("input", input);
	obj.SetString("pawn_name", pawn_name);
	obj.Encode(output, sizeof(output));
	Format(url, sizeof(url), "%s/ord/input", ord_server);
	Handle req = SteamWorks_CreateHTTPRequest(k_EHTTPMethodPOST, url);
	if (req == INVALID_HANDLE) return;
	SteamWorks_SetHTTPRequestHeaderValue(req, "Content-Type", "application/json");
	char ord_key[1024];
	GetConVarString(g_ord_key, ord_key, sizeof(ord_key));
	SteamWorks_SetHTTPRequestHeaderValue(req, "X-ORD-KEY", ord_key);
	SteamWorks_SetHTTPRequestRawPostBody(req, "application/json", output, strlen(output));
	SteamWorks_SetHTTPCallbacks(req, OnHTTPResponse);
	SteamWorks_SendHTTPRequest(req);
	json_cleanup_and_delete(obj);
}
public Action ord_clear_command(int args)
{
	SendInput("BEGIN");
	return Plugin_Handled;
}
public Action ord_mode_command(int args)
{
	char arg[256];
	int ordinance_enabled = GetConVarInt(g_ordinance_enabled);
	char url[256];
	char output[1024];
	char ord_server[256];
	GetConVarString(g_ordinance_server, ord_server, sizeof(ord_server));
	JSON_Object obj = new JSON_Object();


	if (args > 1)
	{
		return Plugin_Handled;
	}
	else if(args < 1)
	{
		PrintToServer("[SM] Usage: ord_mode <mode>");
		return Plugin_Handled;
	}
	if (ordinance_enabled != 1 || !g_ordserveronline)
	{
		return Plugin_Handled;
	}
	GetCmdArg(1, arg, sizeof(arg));

	obj.SetString("mode", arg);
	obj.Encode(output, sizeof(output));
	Format(url, sizeof(url), "%s/ord/mode", ord_server);
	Handle req = SteamWorks_CreateHTTPRequest(k_EHTTPMethodPOST, url);
	if (req == INVALID_HANDLE) return Plugin_Handled;
	SteamWorks_SetHTTPRequestHeaderValue(req, "Content-Type", "application/json");
	char ord_key[1024];
	GetConVarString(g_ord_key, ord_key, sizeof(ord_key));
	SteamWorks_SetHTTPRequestHeaderValue(req, "X-ORD-KEY", ord_key);
	SteamWorks_SetHTTPRequestRawPostBody(req, "application/json", output, strlen(output));
	SteamWorks_SetHTTPCallbacks(req, OnModeSetResponse);
	SteamWorks_SendHTTPRequest(req);
	json_cleanup_and_delete(obj);
	return Plugin_Handled;
}
public Action ord_input_command(int args)
{
	char arg[MAX_INPUT_LEN];
    char full[256];
	char map[PLATFORM_MAX_PATH];
	int ordinance_enabled = GetConVarInt(g_ordinance_enabled);
	int auto_ord_func_level_change = GetConVarInt(g_auto_ord_func_level_change);
	char ord_end_level[PLATFORM_MAX_PATH];
	GetConVarString(g_ord_end_level, ord_end_level, sizeof(ord_end_level));
	if (args > 1)
	{
		PrintToServer("ONLY ONE INPUT AT A TIME");
		return Plugin_Handled;
	}
	else if(args < 1)
	{
		PrintToServer("[SM] Usage: ord_input <input>");
		return Plugin_Handled;
	}
	if (ordinance_enabled != 1 || !g_ordserveronline || !g_pawnalive)
	{
		if (IsMapValid(ord_end_level))
		{
			ForceChangeLevel(ord_end_level, "NO INPUT");
			return Plugin_Handled;
		}
		else
		{
			ForceChangeLevel("cp_dustbowl", "NO INPUT");
			return Plugin_Handled;
		}
	}

    GetCmdArgString(full, sizeof(full));
	
	GetCmdArg(1, arg, sizeof(arg));
	SendInput(arg);
	if (auto_ord_func_level_change == 1)
	{
		GetConVarString(g_ord_func_template, map, sizeof(map));
		ReplaceString(map, sizeof(map), "(input)", arg);
		//Format(map, sizeof(map), "ord_%sfunc", arg);
		PrintToServer(map);
		PrintToChatAll(arg);
		if (IsMapValid(map))
		{
			ForceChangeLevel(map, "INPUT MADE");
		}
		else
		{
			ForceChangeLevel("cp_dustbowl", "INVAILD INPUT");
			return Plugin_Handled;
		}
	}
	
	
	
	return Plugin_Handled;

}
public Action ord_if_command(int args)
{
	int ordinance_enabled = GetConVarInt(g_ordinance_enabled);
	char arg[256];
	char cmd[256];
	char arg2[256];
	if (args < 1)
	{
		PrintToServer("[SM] Usage: ord_if '<server>' '<online/offline>' '<cmd>' <else> '<cmd>'");
		return Plugin_Handled;
	}
	if (args > 5)
	{
		return Plugin_Handled;
	}
	GetCmdArg(1, arg, sizeof(arg));
	if (StrEqual(arg, "server", false))
	{
		GetCmdArg(2, arg, sizeof(arg));
		GetCmdArg(4, arg2, sizeof(arg2));
		if (StrEqual(arg, "online", false))
		{
			if (g_ordserveronline && ordinance_enabled == 1)
			{
				GetCmdArg(3, cmd, sizeof(cmd));
				ServerCommand("%s", cmd);
			}
			else if (StrEqual(arg2, "else", false))
			{
				GetCmdArg(5, cmd, sizeof(cmd));
				ServerCommand("%s", cmd);
			}
		}
		if (StrEqual(arg, "offline", false))
		{
			if (!g_ordserveronline || ordinance_enabled != 1)
			{
				GetCmdArg(3, cmd, sizeof(cmd));
				ServerCommand("%s", cmd);
			}
			else if (StrEqual(arg2, "else", false))
			{
				GetCmdArg(5, cmd, sizeof(cmd));
				ServerCommand("%s", cmd);
			}
		}
	}
	return Plugin_Handled;
}
public Action ord_render_command(int args)
{
	int ordinance_enabled = GetConVarInt(g_ordinance_enabled);
	char url[256];
	char ord_server[256];
	char ord_render_level[PLATFORM_MAX_PATH];
	GetConVarString(g_ordinance_server, ord_server, sizeof(ord_server));
	GetConVarString(g_ord_render_level, ord_render_level, sizeof(ord_render_level));
	if (IsMapValid(ord_render_level))
	{
		if (ordinance_enabled == 1) 
		{
			Format(url, sizeof(url), "%s/ord/input/render", ord_server);
			Handle req = SteamWorks_CreateHTTPRequest(k_EHTTPMethodGET, url);
			SteamWorks_SetHTTPRequestHeaderValue(req, "Content-Type", "application/json");
			char ord_key[1024];
			GetConVarString(g_ord_key, ord_key, sizeof(ord_key));
			SteamWorks_SetHTTPRequestHeaderValue(req, "X-ORD-KEY", ord_key);
			SteamWorks_SetHTTPCallbacks(req, OnRenderResponse);
			SteamWorks_SendHTTPRequest(req);
		}
		
		
		ForceChangeLevel(ord_render_level, "RENDER");
		
		
		return Plugin_Handled;
	}
	else
	{
		ForceChangeLevel("cp_dustbowl", "NO MAP");
		return Plugin_Handled;
	}
}

public Action ord_get_inputs(int args)
{
	int ordinance_enabled = GetConVarInt(g_ordinance_enabled);
	char url[256];
	char ord_server[256];
	GetConVarString(g_ordinance_server, ord_server, sizeof(ord_server));
	if (ordinance_enabled == 1) 
	{
		Format(url, sizeof(url), "%s/ord/input", ord_server);
		Handle req = SteamWorks_CreateHTTPRequest(k_EHTTPMethodGET, url);
		SteamWorks_SetHTTPRequestHeaderValue(req, "Content-Type", "application/json");
		char ord_key[1024];
		GetConVarString(g_ord_key, ord_key, sizeof(ord_key));
		SteamWorks_SetHTTPRequestHeaderValue(req, "X-ORD-KEY", ord_key);
		SteamWorks_SetHTTPCallbacks(req, OnGetInputsResponse);
		SteamWorks_SendHTTPRequest(req);
	}
	return Plugin_Handled;
}