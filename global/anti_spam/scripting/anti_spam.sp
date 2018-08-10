/*
 * Copyright (C) 2017-2018, Matthew Penner.
 *
 * All Rights Reserved, do not redistribute.
 */

#include <sourcemod>
#include <basecomm>

#pragma semicolon 1

/* Start Globals */
#define CONSOLE_PREFIX "[Anti Spam]"
#define PREFIX "\x01[\x06Anti Spam\x01]"
#define ALLOWED "\x04Allowed"
#define DENIED "\x02Denied"
/* End Globals */

/* Start Plugin Information */
public Plugin myinfo = 
{
	name = "Anti Spam",
	author = "Matthew Penner",
	description = "Prevent players from Spamming chat or mic.",
	version = "1.0.1",
	url = "https://github.com/matthewpi"
};
/* End Plugin Information */

/* Start Hooks */
bool exempt_mic[MAXPLAYERS];
bool muted_players[MAXPLAYERS];
/* End Hooks */

/**
 * Called on Plugin Start; used to register commands, register listeners, and enable hooks.
 */
public void OnPluginStart()
{
	// Translations
	LoadTranslations("common.phrases.txt");
	LoadTranslations("anti_spam.phrases.txt");
	
	// Register Commands
	RegisterCommands();
	
	CreateTimer(1.0, Timer_CheckAudio, _, TIMER_REPEAT);
}

public void OnPluginEnd()
{
	for(int client = 1; client <= MaxClients; client++)
    {
    	if(IsMuted(client))
    	{
    		UnmuteClient(client);
    	}
   	}
}

public Action Command_Exempt(const int client, const int args)
{
	// Deny console.
	if(!IsValidClient(client, false))
	{
		ReplyToCommand(client, "%s You must be a client to execute this command.", CONSOLE_PREFIX);
		return Plugin_Handled;
	}

	// Check to make sure they supplied an argument.
	if(args != 1)
	{
		PrintToChat(client, "%s \x07Usage: \x01/exempt <#userid;target>", PREFIX);
		LogCommand(client, -1, "sm_exempt", "");
		
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
		LogCommand(client, -1, "sm_exempt", "");
		
		return Plugin_Handled;
	}
	
	if (num_targets > 2)
	{
		PrintToChat(client, "%s \x07Too many clients were found.", PREFIX);
		LogCommand(client, -1, "sm_exempt", "");
		
		return Plugin_Handled;
	}
	
	int target_id = targets[0];
	
	if(IsExempt(target_id))
	{
		PrintToChat(client, "%s \x05%s \x01is already exempted.", PREFIX, target_name);
		return Plugin_Handled;
	}
	
	ExemptClient(target_id);
	PrintToChat(client, "%s \x05%s \x01has been exempted from the \x07Anti Spam\x01 filter.", PREFIX, target_name);
	
	LogCommand(client, target_id, "sm_exempt", "(Target: '%s')", target_name);
	
	return Plugin_Handled;
}

public Action Command_Unexempt(const int client, const int args)
{
	// Deny console.
	if(!IsValidClient(client, false))
	{
		ReplyToCommand(client, "%s You must be a client to execute this command.", CONSOLE_PREFIX);
		return Plugin_Handled;
	}

	// Check to make sure they supplied an argument.
	if(args != 1)
	{
		PrintToChat(client, "%s \x07Usage: \x01/unexempt <#userid;target>", PREFIX);
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
		LogCommand(client, -1, "sm_exempt", "");
		
		return Plugin_Handled;
	}
	
	int target_id = targets[0];
	
	if(!IsExempt(target_id))
	{
		PrintToChat(client, "%s \x05%s \x01is not exempted.", PREFIX, target_name);
		return Plugin_Handled;
	}
	
	UnexemptClient(target_id);
	PrintToChat(client, "%s \x05%s\x01's exemption from the \x07Anti Spam\x01 filter has been removed.", PREFIX, target_name);
	
	LogCommand(client, target_id, "sm_unexempt", "(Target: '%s')", target_name);
	
	return Plugin_Handled;
}

/**
 * Registers all of the commands.
 */
public void RegisterCommands()
{
	RegAdminCmd("sm_exempt", Command_Exempt, ADMFLAG_CHAT, "exempt a player from being muted for Mic Spam.");
	RegAdminCmd("sm_unexempt", Command_Unexempt, ADMFLAG_CHAT, "Unexempt a player.");
}

/**
 * Called whenever a client connects.
 */
public void OnClientConnected(int client)
{
	exempt_mic[client] = false;
	muted_players[client] = false;
}

public Action Timer_CheckAudio(Handle timer, any data)
{
    for(int client = 1; client <= MaxClients; client++)
    {
		if(IsValidClient(client, false))
		{
			if(IsExempt(client))
			{
				return;
			}
			
			if(!IsMuted(client))
			{
				QueryClientConVar(client, "voice_inputfromfile", CheckClientVoice);
			}
		}
    }
}

public void CheckClientVoice(QueryCookie cookie, int client, ConVarQueryResult result, const char[] cvarName, const char[] cvarValue)
{
	if(result == ConVarQuery_Okay && StringToInt(cvarValue) == 1)
	{
		MuteClient(client, "Mic Spamming");
	}
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

public bool IsValidClient(const int client, const bool bots)
{
	if(client <= 0 || client > MaxClients || !IsClientConnected(client) || !IsClientInGame(client) || (bots && IsFakeClient(client)))
		return false;
	
	return true;
}

public void ExemptClient(const int client)
{
	exempt_mic[client] = true;
	
	PrintToChat(client, "%s You have been exempted from the \x07Anti Spam\x01 filter.", PREFIX);
}

public void UnexemptClient(const int client)
{
	exempt_mic[client] = false;
	
	PrintToChat(client, "%s Your exemption from the \x07Anti Spam\x01 filter has been removed.", PREFIX);
}

public bool IsExempt(const int client)
{
	return exempt_mic[client] == true;
}

public void MuteClient(const int client, const char[] reason)
{
	
	// Mute the client.
	muted_players[client] = true;
	BaseComm_SetClientMute(client, true);
	
	// Print that they were muted.
	PrintToChatAll("%s \x05%N \x01was automatically muted for \x07%s\x01.", PREFIX, client, reason);
}

public void UnmuteClient(const int client)
{
	muted_players[client] = false;
	BaseComm_SetClientMute(client, false);
}

public bool IsMuted(const int client)
{
	return muted_players[client] == true;
}
