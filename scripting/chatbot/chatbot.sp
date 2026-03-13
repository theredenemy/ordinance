#include <sdkhooks>
#include <sdktools>
#include <sourcemod>
#include <SteamWorks>
#include <json>
#include <morecolors>

// NOT DONE

public Action Command_Say(int client, int args)
{
    char msg[256];
    char playername[1048];
    char arg[256];
    char sound[] = "friends/message.wav";
    int msg_len;
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
    
    CPrintToChatAllEx(client, "{teamcolor}%s\x01 : %s", playername, msg);
    PrecacheSound(sound, true);
		
	EmitSoundToAll(sound);
    PrintToServer("%s: %s", playername, msg);
    return Plugin_Handled;
}