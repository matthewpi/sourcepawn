/*
 * Copyright (C) 2017-2018, Matthew Penner.
 *
 * All Rights Reserved, do not redistribute.
 */

#include <sourcemod>
#include <cstrike>
#include <emitsoundany>

#pragma semicolon 1

/* Start Globals */
#define CONSOLE_PREFIX "[Admin Utils]"
#define PREFIX "\x01[\x06Admin Utils\x01]"
#define COLORS "\x011 \x022 \x033 \x044 \x055 \x066 \x077 \x088"
#define ENABLED "\x04Enabled"
#define DISABLED "\x02Disabled"
/* End Globals */

/* Start Plugin Information */
public Plugin myinfo = 
{
	name = "Admin Utils",
	author = "Matthew Penner",
	description = "Utility Plugin for Administrators and Staff.",
	version = "1.0.1",
	url = "https://github.com/matthewpi"
};
/* End Plugin Information */

/* Start Hooks */
ConVar g_friendlyFire;
int swap_on_round_end[MAXPLAYERS];
/* End Hooks */

/**
 * Called on Plugin Start; used to register commands, register listeners, and enable hooks.
 */
public void OnPluginStart()
{
	// Translations
	LoadTranslations("common.phrases.txt");
	LoadTranslations("admin_utils.phrases.txt");
	
	// Hooks
	g_friendlyFire = FindConVar("mp_friendlyfire");
	
	// Register Commands
	RegisterCommands();
	
	// Register Events
	HookEvent("round_end", Event_RoundEnd);
}

/**
 * Called on Map Change/Start
 */
public void OnMapStart()
{
	AddFileToDownloadsTable("sound/tango/oof.mp3");
	PrecacheSoundAny("tango/oof.mp3");
}

/**
 * Called on client join
 */
public void OnClientConnected(int client)
{
	char steam_id[64];
	GetClientAuthId(client, AuthId_Steam2, steam_id, sizeof(steam_id), true);
	
	PrintToChatAll("%s \x05%N \x01has connected. (%s)", PREFIX, client, steam_id);
	PrintToServer("%s %N has connected. (%s)", CONSOLE_PREFIX, client, steam_id);
}

/**
 * Called on client disconnect
 */
public void OnClientDisconnect(int client)
{
	char steam_id[64];
	GetClientAuthId(client, AuthId_Steam2, steam_id, sizeof(steam_id), true);
	
	PrintToChatAll("%s \x05%N \x01has disconnected. (%s)", PREFIX, client, steam_id);
	PrintToServer("%s %N has disconnected. (%s)", CONSOLE_PREFIX, client, steam_id);
}

/**
 * Called on Round End
 */
public void Event_RoundEnd(Handle event, const char[] name, bool dontBroadcast)
{
	for(int client = 1; client < MaxClients; client++)
	{
		
		if(IsValidClient(client, false))
		{
			switch(swap_on_round_end[client])
			{
				case CS_TEAM_T:
				{
					CS_SwitchTeam(client, CS_TEAM_T);
				}
				
				case CS_TEAM_CT:
				{
					CS_SwitchTeam(client, CS_TEAM_CT);
				}
				
				case CS_TEAM_SPECTATOR:
				{
					CS_SwitchTeam(client, CS_TEAM_SPECTATOR);
				}
			}
			
			swap_on_round_end[client] = -1;
		}
	}
}

/**
 * sm_colors - Command
 *
 * This command sends a message containing colors
 * that may be used in messages.
 */
public Action Command_Colors(const int client, const int args)
{
	// Deny console.
	if(!IsValidClient(client, false))
	{
		ReplyToCommand(client, "%s You must be a client to execute this command.", CONSOLE_PREFIX);
		return Plugin_Handled;
	}
	
	// Send the message.
	PrintToChat(client, "%s %s", PREFIX, COLORS);
	
	// Log the command execution.
	LogCommand(client, -1, "sm_colors", "");
	
	return Plugin_Handled;
}

/**
 * sm_alert - Command
 *
 * This command sends a global alert
 * to all players on the server.
 */
public Action Command_Alert(const int client, const int args)
{
	// Deny console.
	if(!IsValidClient(client, false))
	{
		ReplyToCommand(client, "%s You must be a client to execute this command.", CONSOLE_PREFIX);
		return Plugin_Handled;
	}
	
	// Checking arguments to make sure they don't contain a message.
	if (args == 0) {
		// Send usage.
		PrintToChat(client, "%s \x07Usage: \x01/alert <message>", PREFIX);
		
		// Log the command being ran.
		LogCommand(client, -1, "sm_alert", "(Message: null)");
		
		return Plugin_Handled;
	}
	
	// Getting all the arguments as one string (the message).
	char message[256];
	GetCmdArgString(message, sizeof(message));
	
	// Sending the Alert to all players.
	for (int clients = 1; clients <= MaxClients; clients++)
	{
		if (!IsValidClient(clients, false))
		{
			continue;
		}
		
		if (GetUserAdmin(clients) != INVALID_ADMIN_ID)
		{
			PrintToChat(clients, "%s \x07(Alert): \x06%N\x01: %s", PREFIX, client, message);
			PrintCenterText(clients, "%N: %s", client, message);
		}
		else
		{
			PrintToChat(clients, "%s \x07(Alert): \x06%s\x01: %s", PREFIX, "ADMIN", message);
			PrintCenterText(clients, "%s: %s", "ADMIN", message);
		}
	}
	
	// Send sound effect to all players.
	EmitSoundToAllAny("tango/oof.mp3");
	
	// Log the command execution
	LogCommand(client, -1, "sm_alert", "(Message: '%s')", message);
	
	return Plugin_Handled;
}

/**
 * sm_friendlyfire - Command
 *
 * This command shows the current state
 * of the friendly fire convar.
 */
public Action Command_FriendlyFire(const int client, const int args)
{
	// Deny console.
	if(!IsValidClient(client, false))
	{
		ReplyToCommand(client, "%s You must be a client to execute this command.", CONSOLE_PREFIX);
		return Plugin_Handled;
	}
	
	// Send the message.
	PrintToChat(client, "%s \x07Friendly Fire \x01is %s", PREFIX, (g_friendlyFire.BoolValue ? ENABLED : DISABLED));
	
	// Log the command execution.
	LogCommand(client, -1, "sm_friendlyfire", "");
	
	//g_friendlyFire.SetBool(!g_friendlyFire.BoolValue, false, false);
	
	return Plugin_Handled;
}

/**
 * sm_team_t - Command
 *
 * This command swaps a client to the Terrorist team.
 */
public Action Command_Team_T(const int client, const int args)
{
	// Deny console.
	if(!IsValidClient(client, false))
	{
		ReplyToCommand(client, "%s You must be a client to execute this command.", CONSOLE_PREFIX);
		return Plugin_Handled;
	}
	
	if (args != 1 && args != 2)
	{
		PrintToChat(client, "%s \x07Usage: \x01/team_t <#userid;target> [true;false (on round end)]", PREFIX);
		return Plugin_Handled;
	}
	
	char target[64];
	
	GetCmdArg(1, target, sizeof(target));
	
	char target_name[MAX_TARGET_LENGTH];
	int targets[MAXPLAYERS];
	bool tn_is_ml;
	
	int num_targets = ProcessTargetString(target, client, targets, MAXPLAYERS, COMMAND_FILTER_CONNECTED, target_name, sizeof(target_name), tn_is_ml);
	
	if (num_targets <= 0)
	{
		ReplyToTargetError(client, num_targets);
		LogCommand(client, -1, "sm_team_t", "");
		
		return Plugin_Handled;
	}
	
	if (num_targets > 2)
	{
		PrintToChat(client, "%s \x07Too many clients were found.", PREFIX);
		LogCommand(client, -1, "sm_team_t", "");
		
		return Plugin_Handled;
	}
	
	bool swap_on_end = false;
	
	if (args == 2)
	{
		char canSwap[512];
		GetCmdArg(2, canSwap, sizeof(canSwap));
		
		if(StrEqual(canSwap, "true", false))
		{
			swap_on_end = true;
		}
	}
	
	int target_id = targets[0];
	
	char team[4];
	char other[4];
	
	IntToString(GetClientTeam(target_id), team, sizeof(team));
	IntToString(CS_TEAM_T, other, sizeof(other));
	
	if(!StrEqual(team, other, false))
	{
		if(swap_on_end)
		{
			swap_on_round_end[target_id] = CS_TEAM_T;
			PrintToChat(client, "%s \x05%s \x01will be swapped to the \x07Terrorist \x01team on round end.", PREFIX, target_name);
		}
		else
		{
			CS_SwitchTeam(target_id, CS_TEAM_T);
			PrintToChat(client, "%s \x05%s \x01has been swapped to the \x07Terrorist \x01team", PREFIX, target_name);
		}
	}
	else
	{
		PrintToChat(client, "%s \x05%s \x01is already on the \x07Terrorist \x01team", PREFIX, target_name);
	}
	
	// Log the command execution.
	LogCommand(client, target_id, "sm_team_t", "(Target: '%s')", target_name);
	
	return Plugin_Handled;
}

public Action Command_Team_CT(const int client, const int args)
{
	// Deny console.
	if(!IsValidClient(client, false))
	{
		ReplyToCommand(client, "%s You must be a client to execute this command.", CONSOLE_PREFIX);
		return Plugin_Handled;
	}
	
	if (args != 1 && args != 2)
	{
		PrintToChat(client, "%s \x07Usage: \x01/team_ct <#userid;target> [true;false (on round end)]", PREFIX);
		LogCommand(client, -1, "sm_team_ct", "");
		
		return Plugin_Handled;
	}
	
	char target[64];
	
	GetCmdArg(1, target, sizeof(target));
	
	char target_name[MAX_TARGET_LENGTH];
	int targets[MAXPLAYERS];
	bool tn_is_ml;
	
	int num_targets = ProcessTargetString(target, client, targets, MAXPLAYERS, COMMAND_FILTER_CONNECTED, target_name, sizeof(target_name), tn_is_ml);
	
	if (num_targets <= 0)
	{
		ReplyToTargetError(client, num_targets);
		LogCommand(client, -1, "sm_team_ct", "");
		
		return Plugin_Handled;
	}
	
	if (num_targets > 2)
	{
		PrintToChat(client, "%s \x07Too many clients were found.", PREFIX);
		LogCommand(client, -1, "sm_team_ct", "");
		
		return Plugin_Handled;
	}
	
	bool swap_on_end = false;
	
	if (args == 2)
	{
		char canSwap[512];
		GetCmdArg(2, canSwap, sizeof(canSwap));
		
		if (StrEqual(canSwap, "true", false))
		{
			swap_on_end = true;
		}
	}
	
	int target_id = targets[0];
	
	char team[4];
	char other[4];
	
	IntToString(GetClientTeam(target_id), team, sizeof(team));
	IntToString(CS_TEAM_CT, other, sizeof(other));
	
	if (!StrEqual(team, other, false))
	{
		if (swap_on_end)
		{
			swap_on_round_end[target_id] = CS_TEAM_CT;
			PrintToChat(client, "%s \x05%s \x01will be swapped to the \x07Counter-Terrorist \x01team on round end.", PREFIX, target_name);
		}
		else
		{
			CS_SwitchTeam(target_id, CS_TEAM_CT);
			PrintToChat(client, "%s \x05%s \x01has been swapped to the \x07Counter-Terrorist \x01team", PREFIX, target_name);
		}
	}
	else
	{
		PrintToChat(client, "%s \x05%s \x01is already on the \x07Counter-Terrorist \x01team", PREFIX, target_name);
	}
	
	// Log the command execution.
	LogCommand(client, target_id, "sm_team_ct", "(Target: '%s')", target_name);
	
	return Plugin_Handled;
}

public Action Command_Team_Spec(const int client, const int args)
{
	// Deny console.
	if(!IsValidClient(client, false))
	{
		ReplyToCommand(client, "%s You must be a client to execute this command.", CONSOLE_PREFIX);
		return Plugin_Handled;
	}
	
	if (args != 1 && args != 2)
	{
		PrintToChat(client, "%s \x07Usage: \x01/team_spec <#userid;target> [true;false (on round end)]", PREFIX);
		LogCommand(client, -1, "sm_team_spec", "");
		
		return Plugin_Handled;
	}
	
	char target[64];
	
	GetCmdArg(1, target, sizeof(target));
	
	char target_name[MAX_TARGET_LENGTH];
	int targets[MAXPLAYERS];
	bool tn_is_ml;
	
	int num_targets = ProcessTargetString(target, client, targets, MAXPLAYERS, COMMAND_FILTER_CONNECTED, target_name, sizeof(target_name), tn_is_ml);
	
	if (num_targets <= 0)
	{
		ReplyToTargetError(client, num_targets);
		LogCommand(client, -1, "sm_team_spec", "");
		
		return Plugin_Handled;
	}
	
	if (num_targets > 2)
	{
		PrintToChat(client, "%s \x07Too many clients were found.", PREFIX);
		LogCommand(client, -1, "sm_team_spec", "");
		
		return Plugin_Handled;
	}
	
	bool swap_on_end = false;
	
	if (args == 2)
	{
		char canSwap[512];
		GetCmdArg(2, canSwap, sizeof(canSwap));
		
		if (StrEqual(canSwap, "true", false))
		{
			swap_on_end = true;
		}
	}
	
	int target_id = targets[0];
	
	char team[4];
	char other[4];
	
	IntToString(GetClientTeam(target_id), team, sizeof(team));
	IntToString(CS_TEAM_SPECTATOR, other, sizeof(other));
	
	if (!StrEqual(team, other, false))
	{
		if (swap_on_end)
		{
			swap_on_round_end[target_id] = CS_TEAM_SPECTATOR;
			PrintToChat(client, "%s \x05%s \x01will be swapped to the \x07Spectator \x01team on round end.", PREFIX, target_name);
		}
		else
		{
			ChangeClientTeam(target_id, CS_TEAM_SPECTATOR);
			PrintToChat(client, "%s \x05%s \x01has been swapped to the \x07Spectator \x01team", PREFIX, target_name);
		}
	}
	else
	{
		PrintToChat(client, "%s \x05%s \x01is already on the \x07Spectator \x01team", PREFIX, target_name);
	}
	
	// Log the command execution.
	LogCommand(client, target_id, "sm_team_spec", "(Target: '%s')", target_name);
	
	return Plugin_Handled;
}


/**
 * Registers all of the commands.
 */
public void RegisterCommands()
{
	RegConsoleCmd("sm_colors", Command_Colors, "Shows a list of available colors.");
	RegAdminCmd("sm_alert", Command_Alert, ADMFLAG_CHAT, "Alert all players in the server.");
	RegAdminCmd("sm_friendlyfire", Command_FriendlyFire, ADMFLAG_CONVARS, "Show the current state of friendly fire.");
	RegAdminCmd("sm_team_t", Command_Team_T, ADMFLAG_CHAT, "Swap a client to the terrorist team.");
	RegAdminCmd("sm_team_ct", Command_Team_CT, ADMFLAG_CHAT, "Swap a client to the counter-terrorist team.");
	RegAdminCmd("sm_team_spec", Command_Team_Spec, ADMFLAG_CHAT, "Swap a client to the spectator team.");
}

/**
 * Called whenever a client sends a chat message.
 */
public Action OnClientSayCommand(int client, const char[] command, const char[] message)
{
	if(!IsValidClient(client, false))
	{
		return Plugin_Continue;
	}
	
	if(!StrEqual(command, "say_team", true))
	{
		return Plugin_Continue;
	}
	
	
	int team = GetClientTeam(client);
	
	PrintToServer("%s (%s Chat): %N: %s", CONSOLE_PREFIX, (team == CS_TEAM_T ? "T" : (team == CS_TEAM_CT ? "CT" : (team == CS_TEAM_SPECTATOR ? "Spec" : "Undefined"))), client, message);
	
	for(int admin = 1; admin <= MaxClients; admin++)
	{
		if (!IsValidClient(admin, false) || GetUserAdmin(admin) == INVALID_ADMIN_ID)
		{
			continue;
		}
		
		PrintToChat(admin, "%s \x07(%s Chat): \x06%N\x01: %s", PREFIX, (team == CS_TEAM_T ? "T" : (team == CS_TEAM_CT ? "CT" : (team == CS_TEAM_SPECTATOR ? "Spec" : "Undefined"))), client, message);
	}
	
	return Plugin_Continue;
}

/**
 * Used to log a command execution.
 */
public void LogCommand(const int client, const int target, const char[] command, const char[] extra, any...)
{
	if(strlen(extra) > 0)
	{
		char buffer[512];
		VFormat(buffer, sizeof(buffer), extra, 5);
		
		LogAction(client, target, "%N executed command '%s' %s", client, command, buffer);
	}
	else
	{
		LogAction(client, target, "%N executed command '%s'", client, command);
	}
}

public bool IsValidClient(const int client, const bool bots) {
	if(client <= 0 || client > MaxClients || !IsClientConnected(client) || !IsClientInGame(client) || (bots && IsFakeClient(client)))
		return false;
	
	return true;
}
