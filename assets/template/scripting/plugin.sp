/*
 * Copyright (C) 2017-2018, Matthew Penner.
 *
 * All Rights Reserved, do not redistribute.
 */

#include <sourcemod>
#include <cstrike>

#pragma semicolon 1

/* Start Globals */

#define CONSOLE_PREFIX "[Plugin]"
#define PREFIX "\x01[\Plugin\x01]"

/* End Globals */

/* Start Plugin Information */

public Plugin myinfo =
{
	name = "Plugin",
	author = "Matthew Penner",
	description = "",
	version = "1.0.1",
	url = "https://github.com/matthewpi"
};

/* End Plugin Information */

/* Start Hooks */



/* End Hooks */

/**
 * Called on Plugin Start; used to register commands, register listeners, and enable hooks.
 */
public void OnPluginStart()
{
	// Translations
	LoadTranslations("common.phrases.txt");
	LoadTranslations("_.phrases.txt");
	
	// Register Commands
	RegisterCommands();
}

/**
 * Registers all of the commands.
 */
public void RegisterCommands()
{
	
}

/**
 * Used to log a command execution.
 */
public void LogCommand(const int client, const int target, const char[] command, const char[] extra, any...)
{
	char client_name[32];
	GetClientName(client, client_name, sizeof(client_name));
	
	if (strlen(extra) > 0)
	{
		char buffer[512];
		VFormat(buffer, sizeof(buffer), extra, 5);
		
		LogAction(client, target, "%s executed command '%s' %s", client_name, command, buffer);
	}
	else
	{
		LogAction(client, target, "%s executed command '%s'", client_name, command);
	}
}

public bool IsValidClient(const int client, const bool bots) {
	if(client <= 0 || client > MaxClients || !IsClientConnected(client) || !IsClientInGame(client) || (bots && IsFakeClient(client)))
		return false;
	
	return true;
}
