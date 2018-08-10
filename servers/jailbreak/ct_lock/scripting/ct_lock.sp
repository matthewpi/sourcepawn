/*
 * Copyright (C) 2017-2018, Matthew Penner.
 *
 * All Rights Reserved, do not redistribute.
 */

#include <sourcemod>
#include <cstrike>

#pragma semicolon 1

/* Start Globals */
#define CONSOLE_PREFIX "[CT Lock]"
#define PREFIX "\x01[\x06CT Lock\x01]"
/* End Globals */

/* Start Plugin Information */
public Plugin myinfo = 
{
	name = "CT Lock",
	author = "Matthew Penner",
	description = "Automatically and Manually lock the CT side.",
	version = "1.0.1",
	url = "https://github.com/matthewpi"
};
/* End Plugin Information */

/* Start Hooks */
bool g_isCtLocked;
bool g_onTerroristSide[MAXPLAYERS];
/* End Hooks */

/**
 * Called on Plugin Start; used to register commands, register event listeners, and enable hooks.
 */
public void OnPluginStart()
{
	// Translations
	LoadTranslations("common.phrases.txt");
	LoadTranslations("ct_lock.phrases.txt");
	
	// Register Commands
	RegisterCommands();
	
	// Hooks
	g_isCtLocked = false;
	
	// Events
	HookEvent("player_team", OnTeamSelect);
}

public void OnClientConnected(int client)
{
	g_onTerroristSide[client] = false;
}

public void OnClientDisconnect(int client)
{
	g_onTerroristSide[client] = false;
}

/**
 * Called whenever a client selects a team.
 */
public Action OnTeamSelect(Event event, const char[] name, bool dontBroadcast)
{
	int team = GetEventInt(event, "team");
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	
	// Detect if they selected the terrorist team.
	if(team == CS_TEAM_T)
	{
		g_onTerroristSide[client] = true;
		
		return Plugin_Continue;
	}
	
	// Detect if they selected the spectator team.
	if(team == CS_TEAM_SPECTATOR)
	{
		g_onTerroristSide[client] = false;
		
		return Plugin_Continue;
	}
	
	// Checking if CT is Hard locked via command.
	if(g_isCtLocked)
	{
		// Checking if the player isn't on the Terrorist side.
		if(!g_onTerroristSide[client])
		{
			SwitchToTerrorist(client);
		}
		
		PrintToChat(client, "%s The \x07CT\x01 side is currently locked.", PREFIX);
		
		return Plugin_Stop;
	}
	
	// Checking if the CT side is soft locked (ratio will be broken).
	if(IsCtSoftLocked(g_onTerroristSide[client]))
	{
		SwitchToTerrorist(client);
		PrintToChat(client, "%s You may not join the \x07CT\x01 due to the ratio.", PREFIX);
		
		return Plugin_Handled;
	}
	
	g_onTerroristSide[client] = false;
	
	return Plugin_Continue;
}

/**
 * sm_lockct
 *
 * This command will allow admins to Lock the Counter-Terrorist team manually.
 */
public Action Command_LockCT(int client, int args)
{
	// Deny console.
	if(!IsValidClient(client, false))
	{
		ReplyToCommand(client, "%s You must be a client to execute this command.", CONSOLE_PREFIX);
		return Plugin_Handled;
	}
	
	if(g_isCtLocked)
	{
		ReplyToCommand(client, "%s \x07CT\x01 is already locked.", PREFIX);
		LogCommand(client, -1, "sm_lockct", "(CT was already locked)");
		
		return Plugin_Handled;
	}
	
	g_isCtLocked = true;
	PrintToChatAll("%s \x07CT\x01 has been locked.", PREFIX);
	LogCommand(client, -1, "sm_lockct", "(CT is now locked)");
	
	return Plugin_Handled;
}

/**
 * sm_unlockct
 *
 * This command will allow admins to Unlock the Counter-Terrorist team.
 */
public Action Command_UnlockCT(int client, int args)
{
	// Deny console.
	if(!IsValidClient(client, false))
	{
		ReplyToCommand(client, "%s You must be a client to execute this command.", CONSOLE_PREFIX);
		return Plugin_Handled;
	}
	
	if(!g_isCtLocked)
	{
		ReplyToCommand(client, "%s \x07CT\x01 is not locked.", PREFIX);
		LogCommand(client, -1, "sm_unlockct", "(CT is already unlocked)");
		
		return Plugin_Handled;
	}
	
	g_isCtLocked = false;
	PrintToChatAll("%s \x07CT\x01 has been un-locked.", PREFIX);
	LogCommand(client, -1, "sm_unlockct", "(CT is now unlocked)");
	
	return Plugin_Handled;
}

/**
 * Registers all of the commands.
 */
public void RegisterCommands()
{
	RegAdminCmd("sm_lockct", Command_LockCT, ADMFLAG_GENERIC, "Lock the Counter-Terrorist team.");
	RegAdminCmd("sm_unlockct", Command_UnlockCT, ADMFLAG_GENERIC, "Unlock the Counter-Terrorist team.");
}

/**
 * Used to log a command execution.
 */
public void LogCommand(const int client, const int target, const char[] command, const char[] extra, any...)
{
	if (strlen(extra) > 0)
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

public bool IsValidClient(const int client, const bool bots)
{
	if(client <= 0 || client > MaxClients || !IsClientConnected(client) || !IsClientInGame(client) || (bots && IsFakeClient(client)))
		return false;
	
	return true;
}

/**
 * Checks if the CT side is soft-locked. (Ratio will be broken)
 */
public bool IsCtSoftLocked(const bool isTerrorist)
{
	// Normal Ratio Check: (ct * 2) > t
	// Joining CT while not being on a team or being a spectator: ((ct + 1) * 2) > (t)
	// Swapping from T to CT: ((ct + 1) * 2) > (t - 1)
	
	// Amount of players on the Terrorist side.
	int t = 0;
	// Amount of players on the Counter-Terrorist side.
	int ct = 0;
	
	/* Start Team Counts */	
	for(int client = 1; client < MaxClients; client++) 
	{
		if(IsValidClient(client, false))
		{
			switch(GetClientTeam(client))
			{
				case CS_TEAM_T:
				{
					t++;
				}
				
				case CS_TEAM_CT:
				{
					ct++;
				}
			}
		}
	}
	/* End Team Counts */
	
	// Ignore if T side has less than 2 players.
	if(t < 2)
	{
		return false;
	}
	
	// Check if the joining client is currently on the Terrorist side to calculate differently.
	if(isTerrorist)
	{
		return ((ct + 1) * 2) > (t - 1);
	}
	
	// Otherwise handle ratio as if the client is not being moved from the Terrorist side.
	return ((ct + 1) * 2) > t;
}

/**
 * Move the client to the Terrorist side.
 */
public void SwitchToTerrorist(const int client)
{
	CreateTimer(0.1, Timer_SwapTeam, client);
}

/**
 * Handle moving the client to the Terrorist side.
 */
public Action Timer_SwapTeam(Handle timer, any client)
{
	CS_SwitchTeam(client, CS_TEAM_T);
}
