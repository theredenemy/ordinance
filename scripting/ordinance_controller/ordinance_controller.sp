#include <sdkhooks>
#include <sdktools>
#include <sourcemod>
#include <SteamWorks>
#include <json>
#pragma newdecls required
#pragma semicolon 1
#define MAX_INPUT_LEN 256


public Action OrdError(Handle timer)
{
	ForceChangeLevel("ord_error", "PAWN IS DEAD");
	return Plugin_Continue;
}
public Action OrdEnd(Handle timer)
{
	ForceChangeLevel("ord_end", "NO INPUT");
	return Plugin_Continue;
}
public Action OrdCry(Handle timer)
{
	// Do You take Arbys Gift cards
	ForceChangeLevel("ord_cry", "FUCKING DIE");
	return Plugin_Continue;
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
	Format(url, sizeof(url), "http://%s/ord/input", ord_server);
	Handle req = SteamWorks_CreateHTTPRequest(k_EHTTPMethodPOST, url);
	if (req == INVALID_HANDLE) return;
	SteamWorks_SetHTTPRequestHeaderValue(req, "Content-Type", "application/json");
	SteamWorks_SetHTTPRequestRawPostBody(req, "application/json", output, strlen(output));
	SteamWorks_SetHTTPCallbacks(req, OnHTTPResponse);
	SteamWorks_SendHTTPRequest(req);
}
public Action ord_clear_command(int args)
{
	SendInput("BEGIN");
	return Plugin_Handled;
}
public Action ord_input_command(int args)
{
	char arg[MAX_INPUT_LEN];
    char full[256];
	char map[256];
	int ordinance_enabled = GetConVarInt(g_ordinance_enabled);
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
	if (ordinance_enabled != 1 || !g_ordserveronline)
	{
		if (IsMapValid("ord_end"))
		{
			ForceChangeLevel("ord_end", "NO INPUT");
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
	Format(map, sizeof(map), "ord_%sfunc", arg);
	PrintToServer(map);
	PrintToChatAll(arg);
	if (IsMapValid(map))
	{
		SendInput(arg);
		ForceChangeLevel(map, "INPUT MADE");
	}
	else
	{
		ForceChangeLevel("cp_dustbowl", "INVAILD INPUT");
		return Plugin_Handled;
	}
	
	
	return Plugin_Handled;

}

public Action ord_render_command(int args)
{
	int ordinance_enabled = GetConVarInt(g_ordinance_enabled);
	char url[256];
	char ord_server[256];
	GetConVarString(g_ordinance_server, ord_server, sizeof(ord_server));
	if (IsMapValid("ord_ren"))
	{
		if (ordinance_enabled == 1) 
		{
			Format(url, sizeof(url), "http://%s/ord/input/render", ord_server);
			Handle req = SteamWorks_CreateHTTPRequest(k_EHTTPMethodGET, url);
			SteamWorks_SetHTTPRequestHeaderValue(req, "Content-Type", "application/json");
			SteamWorks_SetHTTPCallbacks(req, OnRenderResponse);
			SteamWorks_SendHTTPRequest(req);
		}
		ForceChangeLevel("ord_ren", "RENDER");
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
		Format(url, sizeof(url), "http://%s/ord/input", ord_server);
		Handle req = SteamWorks_CreateHTTPRequest(k_EHTTPMethodGET, url);
		SteamWorks_SetHTTPRequestHeaderValue(req, "Content-Type", "application/json");
		SteamWorks_SetHTTPCallbacks(req, OnGetInputsResponse);
		SteamWorks_SendHTTPRequest(req);
	}
	return Plugin_Handled;
}