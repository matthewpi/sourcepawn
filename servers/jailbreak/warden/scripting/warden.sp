/*
 * Copyright (C) 2017-2018, Matthew Penner.
 *
 * All Rights Reserved, do not redistribute.
 */

#include <sourcemod>
#include <cstrike>

#pragma semicolon 1

/* Start Globals */
#define CONSOLE_PREFIX "[Warden]"
#define PREFIX "\x01[\x06Warden\x01]"
/* End Globals */

/* Start Plugin Information */
public Plugin myinfo = 
{
	name = "Warden",
	author = "Matthew Penner",
	description = "Allow CTs to take Warden.",
	version = "1.0.1",
	url = "https://github.com/matthewpi"
};
/* End Plugin Information */

/* Start Hooks */
ConVar g_sm_wardenEnabled;
ConVar g_sm_wardenRecoverTime;

bool g_wardenAllowed;
int g_warden;

Handle g_wardenRecoverTimer;

//int g_wardenAmount[MAXPLAYERS];
/* End Hooks */

/* Start Forwards */
Handle g_onNewWarden = INVALID_HANDLE;
Handle g_onRemoveWarden = INVALID_HANDLE;
/* End Forwards */

/**
 * Called on Plugin Start; used to register commands, register event listeners, and enable hooks.
 */
public void OnPluginStart()
{
	// Translations
	LoadTranslations("common.phrases.txt");
	LoadTranslations("warden.phrases.txt");
	
	// Register Commands
	RegisterCommands();
	
	// Hooks
	g_sm_wardenEnabled = CreateConVar("sm_warden_enabled", "1", "Should Warden be able to be taken.", _, true, 0.0, true, 1.0);
	g_sm_wardenRecoverTime = CreateConVar("sm_warden_recovertime", "10", "After a Warden is removed how many seconds until it becomes a freeday.", _, true, 0.0, true, 15.0);
	
	// Forwards
	g_onNewWarden = CreateGlobalForward("Warden_OnNewWarden", ET_Ignore, Param_Cell);
	g_onRemoveWarden = CreateGlobalForward("Warden_OnRemoveWarden", ET_Ignore);
	
	// Events
	HookEvent("round_start", OnRoundStart);
	HookEvent("player_death", OnPlayerDeath);	
}

/**
 * Called on Round Start
 */
public Action OnRoundStart(Event event, const char[] name, bool dontBroadcast)
{
	g_wardenAllowed = true;
	g_warden = 0;
	g_wardenRecoverTimer = null;
	
	return Plugin_Continue;
}

/**
 * Called on Player Death
 */
public Action OnPlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	
	if(client == g_warden)
	{
		PrintToChatAll("%s The \x07Warden\x01 has died.", PREFIX);
		Warden_Remove();
	}
	
	return Plugin_Continue;
}

public Action Timer_WardenDeath(Handle timer)
{
	g_wardenAllowed = false;
	
	PrintToChatAll("%s \x07Warden\x01 can no longer be taken.", PREFIX);
	
	return Plugin_Handled;
}

/* Start Commands */

/**
 * sm_warden
 *
 * This command will allow a CT to take Warden.
 */
public Action Command_Warden(int client, int args)
{
	// Deny console.
	if(!IsValidClient(client, false))
	{
		ReplyToCommand(client, "%s You must be a client to execute this command.", CONSOLE_PREFIX);
		return Plugin_Handled;
	}
	
	// Check the Warden enabled ConVar
	if(!Warden_IsEnabled())
	{
		ReplyToCommand(client, "%s \x07Warden\x01 is currently \x04Disabled\x01.", PREFIX);
		LogCommand(client, -1, "sm_w", "");
		
		return Plugin_Handled;
	}
	
	// Check if Warden isn't allowed.
	if(!Warden_IsAllowed())
	{
		ReplyToCommand(client, "%s \x07Warden\x01 cannot be taken.", PREFIX);
		LogCommand(client, -1, "sm_w", "");
		
		return Plugin_Handled;
	}
	
	// Check if they are on the Counter-Terrorist team.
	if(GetClientTeam(client) != CS_TEAM_CT || g_warden != 0)
	{
		if(g_warden == 0)
		{
			ReplyToCommand(client, "%s \x07Warden\x01 has not been taken.", PREFIX);
		}
		else
		{
			ReplyToCommand(client, "%s The \x07Warden\x01 is \x05%N\x01.", PREFIX, client);
		}
		
		LogCommand(client, -1, "sm_w", "");
		
		return Plugin_Handled;
	}
	
	Warden_Set(client);
	LogCommand(client, -1, "sm_w", "(New Warden: '%N')", client);
	
	return Plugin_Handled;
}

/**
 * sm_uwarden
 *
 * This command will allow the Warden to resign.
 */
public Action Command_Unwarden(int client, int args)
{
	// Deny console.
	if(!IsValidClient(client, false))
	{
		ReplyToCommand(client, "%s You must be a client to execute this command.", CONSOLE_PREFIX);
		return Plugin_Handled;
	}
	
	// Check the Warden enabled ConVar
	if(!Warden_IsEnabled())
	{
		ReplyToCommand(client, "%s \x07Warden\x01 is currently \x04Disabled\x01.", PREFIX);
		LogCommand(client, -1, "sm_uw", "");
		
		return Plugin_Handled;
	}
	
	if(!Warden_IsTaken())
	{
		ReplyToCommand(client, "%s \x07Warden\x01 has not been taken.", PREFIX);
		LogCommand(client, -1, "sm_uw", "");
		
		return Plugin_Handled;
	}
	
	if(GetClientTeam(client) != CS_TEAM_CT || !Warden_IsWarden(client))
	{
		ReplyToCommand(client, "%s You are not the \x07Warden\x01.", PREFIX);
		LogCommand(client, -1, "sm_uw", "");
		
		return Plugin_Handled;
	}
	
	Warden_Remove();
	LogCommand(client, -1, "sm_uw", "(Removed: '%N')", client);
	
	return Plugin_Handled;
}

/**
 * sm_swarden
 *
 * This command will allow an admin to
 * set a new warden.
 */
public Action Command_Setwarden(int client, int args)
{
	// Deny console.
	if(!IsValidClient(client, false))
	{
		ReplyToCommand(client, "%s You must be a client to execute this command.", CONSOLE_PREFIX);
		return Plugin_Handled;
	}
	
	// Check the Warden enabled ConVar
	if(!Warden_IsEnabled())
	{
		ReplyToCommand(client, "%s \x07Warden\x01 is currently \x04Disabled\x01.", PREFIX);
		LogCommand(client, -1, "sm_sw", "");
		
		return Plugin_Handled;
	}
	
	if(args != 1)
	{
		ReplyToCommand(client, "%s \x07Usage: \x01/sw <#userid;target>", PREFIX);
		LogCommand(client, -1, "sm_sw", "");
		
		return Plugin_Handled;
	}
	
	// Check if Warden isn't allowed.
	if(!Warden_IsAllowed())
	{
		ReplyToCommand(client, "%s \x07Warden\x01 cannot be taken.", PREFIX);
		LogCommand(client, -1, "sm_sw", "");
		
		return Plugin_Handled;
	}
	
	char target[64];
	GetCmdArg(1, target, sizeof(target));
	
	char target_name[MAX_TARGET_LENGTH];
	int targets[MAXPLAYERS];
	bool tn_is_ml;
	int num_targets = ProcessTargetString(target, client, targets, MAXPLAYERS, COMMAND_FILTER_CONNECTED, target_name, sizeof(target_name), tn_is_ml);
	
	if(num_targets <= 0)
	{
		ReplyToTargetError(client, num_targets);
		LogCommand(client, -1, "sm_sw", "");
		
		return Plugin_Handled;
	}
	
	int target_id = targets[0];
	
	if(GetClientTeam(target_id) != CS_TEAM_CT)
	{
		ReplyToCommand(client, "%s \x07Warden\x01 cannot be taken.", PREFIX);
		LogCommand(client, -1, "sm_sw", "");
		
		return Plugin_Handled;
	}
	
	Warden_Set(target_id);
	LogCommand(client, target_id, "sm_sw", "(New Warden: '%N')", target_id);
	
	return Plugin_Handled;
}

/**
 * sm_removewarden
 *
 * This command will remove the current warden
 * to allow other CTs to take it.
 */
public Action Command_RemoveWarden(int client, int args)
{
	// Deny console.
	if(!IsValidClient(client, false))
	{
		ReplyToCommand(client, "%s You must be a client to execute this command.", CONSOLE_PREFIX);
		return Plugin_Handled;
	}
	
	// Check the Warden enabled ConVar
	if(!Warden_IsEnabled())
	{
		ReplyToCommand(client, "%s \x07Warden\x01 is currently \x04Disabled\x01.", PREFIX);
		LogCommand(client, -1, "sm_rw", "");
		
		return Plugin_Handled;
	}
	
	// Check if Warden isn't allowed.
	if(!Warden_IsAllowed())
	{
		ReplyToCommand(client, "%s \x07Warden\x01 cannot be removed.", PREFIX);
		LogCommand(client, -1, "sm_rw", "");
		
		return Plugin_Handled;
	}
	
	// Check if there is not a warden.
	if(Warden_IsTaken())
	{
		ReplyToCommand(client, "%s There is not a \x07Warden\x01.", PREFIX);
		LogCommand(client, -1, "sm_rw", "");
		
		return Plugin_Handled;
	}
	
	if(GetAdminImmunityLevel(GetUserAdmin(client)) < GetAdminImmunityLevel(GetUserAdmin(g_warden)))
	{
		ReplyToCommand(client, "%s You cannot target the \x07Warden\x01.", PREFIX);
		LogCommand(client, g_warden, "sm_rw", "(Failed Target: '%N')", g_warden);
		
		return Plugin_Handled;
	}
	
	LogCommand(client, g_warden, "sm_rw", "(Removed: '%N')", g_warden);
	Warden_Remove();
	
	return Plugin_Handled;
}

/**
 * Registers all of the commands.
 */
public void RegisterCommands()
{
	// "Warden" Command
	RegConsoleCmd("sm_w", Command_Warden, "Take Warden as a Counter-Terrorist.");
	RegConsoleCmd("sm_warden", Command_Warden, "Take Warden as a Counter-Terrorist.");
	
	// "Un-warden" Command
	RegConsoleCmd("sm_uw", Command_Unwarden, "Resign from being the Warden.");
	RegConsoleCmd("sm_uwarden", Command_Unwarden, "Resign from being the Warden.");

	// "Set Warden" Command
	RegAdminCmd("sm_sw", Command_Setwarden, ADMFLAG_BAN, "Force set a new warden.");
	RegAdminCmd("sm_swarden", Command_Setwarden, ADMFLAG_BAN, "Force set a new warden.");
	
	// "Remove Warden" Command
	RegAdminCmd("sm_rw", Command_RemoveWarden, ADMFLAG_BAN, "Remove the current warden.");
	RegAdminCmd("sm_removewarden", Command_RemoveWarden, ADMFLAG_BAN, "Remove the current warden.");
}
/* End Commands */

/* Start Natives */
public bool Warden_IsTaken()
{
	return g_warden == 0;
}

public bool Warden_IsAllowed()
{
	return g_wardenAllowed;
}

public bool Warden_IsEnabled()
{
	return g_sm_wardenEnabled.BoolValue;
}

public bool Warden_IsWarden(int client)
{
	return g_warden == client;
}

public void Warden_Set(int client)
{
	g_warden = client;
	
	if(g_wardenRecoverTimer != null)
	{
		CloseHandle(g_wardenRecoverTimer);
		g_wardenRecoverTimer = null;
	}
	
	// The line below this will be used to detect "Warden Hogging".
	//g_wardenAmount[client]++;
	
	PrintToChatAll("%s \x05%N\x01 is now the \x07Warden\x01.", PREFIX, client);
	
	Call_StartForward(g_onNewWarden);
	Call_PushCell(client);
	Call_Finish();
}

public void Warden_Remove()
{
	g_warden = 0;
	g_wardenRecoverTimer = CreateTimer(g_sm_wardenRecoverTime.FloatValue, Timer_WardenDeath);
	
	PrintToChatAll("%s The \x07Warden\x01 has been removed.", PREFIX);
	
	Call_StartForward(g_onRemoveWarden);
	Call_Finish();
}
/* End Natives */

/* Start Utils */
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

/**
 * Checks if a Client is valid.
 */
public bool IsValidClient(const int client, const bool bots)
{
	if(client <= 0 || client > MaxClients || !IsClientConnected(client) || !IsClientInGame(client) || (bots && IsFakeClient(client)))
		return false;
	
	return true;
}
/* End Utils */
