#include <sourcemod>
#include <multicolors>
#include <cstrike>
#include <autoexecconfig>

#pragma semicolon 1

#pragma newdecls required

char g_ChatPrefix[256];
ConVar gConVar_Chat_Prefix;

ConVar g_ConVar_FreePass_Admins;

ConVar g_ConVar_Block_Terrorist;
ConVar g_ConVar_Block_Counter_Terrorist;
ConVar g_ConVar_Block_Spectator;

ConVar g_ConVar_Block_Terrorist_Message;
ConVar g_ConVar_Block_Counter_Terrorist_Message;
ConVar g_ConVar_Block_Spectator_Message;

ConVar gConVar_JoinMsg;

public Plugin myinfo = 
{
	name = "Block Join Teams", 
	author = "Lantejoula", 
	description = "Makes the All Teams Unjoinable", 
	version = "1.1", 
	url = "https://steamcommunity.com/id/lantejoula/"
};

public void OnPluginStart()
{
	// Translations
	LoadTranslations("blockjointeams.phrases");
	
	//Convars
	AutoExecConfig_SetFile("plugin.blockjointeams");
	
	gConVar_Chat_Prefix = AutoExecConfig_CreateConVar("sm_blockjointeams_chat_prefix", "{green}[TAG]{default}", "Chat Prefix");
	
	g_ConVar_FreePass_Admins = AutoExecConfig_CreateConVar("sm_freepass_admins", "0", "Allow admins to pass the spectator block? (1 - Enable | 0 - Disable)", 0, true, 0.0, true, 1.0);
	
	g_ConVar_Block_Terrorist = AutoExecConfig_CreateConVar("sm_block_terrorist", "1", "Enable/Disable Block Join Team Terrorist? (1 - Enable | 0 - Disable)", 0, true, 0.0, true, 1.0);
	g_ConVar_Block_Counter_Terrorist = AutoExecConfig_CreateConVar("sm_block_counter_terrorist", "1", "Enable/Disable Block Join Team Counter-Terrorist? (1 - Enable | 0 - Disable)", 0, true, 0.0, true, 1.0);
	g_ConVar_Block_Spectator = AutoExecConfig_CreateConVar("sm_block_spectator", "1", "Enable/Disable Block Join Team Spectator? (1 - Enable | 0 - Disable)", 0, true, 0.0, true, 1.0);
	
	g_ConVar_Block_Terrorist_Message = AutoExecConfig_CreateConVar("sm_block_terrorist_message", "1", "Enable/Disable Message When Someone Try to Join Team Terrorist (1 - Enable | 0 - Disable)", 0, true, 0.0, true, 1.0);
	g_ConVar_Block_Counter_Terrorist_Message = AutoExecConfig_CreateConVar("sm_block_counter_terrorist_message", "1", "Enable/Disable Message When Someone Try to Join Team Counter-Terrorist (1 - Enable | 0 - Disable)", 0, true, 0.0, true, 1.0);
	g_ConVar_Block_Spectator_Message = AutoExecConfig_CreateConVar("sm_block_spectator_message", "1", "Enable/Disable Message When Someone Try to Join Team Spectator (1 - Enable | 0 - Disable)", 0, true, 0.0, true, 1.0);
	
	gConVar_JoinMsg = AutoExecConfig_CreateConVar("sm_blockjointeams_join_message", "1", "Enable/Disable the Message when STAFF Join (1 - Enable | 0 - Disable)", 0, true, 0.0, true, 1.0);
	
	AutoExecConfig_ExecuteFile();
	AutoExecConfig_CleanFile();
	
	gConVar_Chat_Prefix.AddChangeHook(OnPrefixChange);
	
	//Events
	AddCommandListener(Command_JoinTeam, "jointeam"); //Spectator
	AddCommandListener(Command_JoinTeam1, "jointeam"); //Terrorist
	AddCommandListener(Command_JoinTeam2, "jointeam"); //Counter-Terrorist
}

////////
//Prefix
////////

public void SavePrefix()
{
	GetConVarString(gConVar_Chat_Prefix, g_ChatPrefix, sizeof(g_ChatPrefix));
}

public void OnConfigsExecuted()
{
	SavePrefix();
}

public void OnPrefixChange(ConVar cvar, char[] oldvalue, char[] newvalue)
{
	SavePrefix();
}

///////////////////
//AUTO JOIN MESSAGE
///////////////////

public void OnClientPutInServer(int client)
{
	CreateTimer(8.5, JoinMsg, client);
}

public Action JoinMsg(Handle timer, any client)
{
	if (gConVar_JoinMsg.BoolValue)
		CPrintToChat(client, "%s %t", g_ChatPrefix, "JoinMsg");
}

///////////
//Spectator
///////////

public Action Command_JoinTeam(int client, char[] command, int args)
{
	if (g_ConVar_Block_Spectator.BoolValue)
	{
		char Team[8];
		GetCmdArg(1, Team, sizeof(Team));
		int iTeam = StringToInt(Team);
		if (iTeam == 1) // Spectator
		{
			if (CheckCommandAccess(client, "sm_fake_command", ADMFLAG_GENERIC, true) && g_ConVar_FreePass_Admins.BoolValue)
			{
				return Plugin_Continue;
			}
			else
			{
				if (g_ConVar_Block_Spectator_Message.BoolValue)
					CPrintToChat(client, "%s %t", g_ChatPrefix, "Spectator");
				return Plugin_Handled;
			}
		}
		else
		{
			return Plugin_Continue;
		}
	}
	return Plugin_Continue;
}

///////////
//Terrorist
///////////

public Action Command_JoinTeam1(int client, char[] command, int args)
{
	if (g_ConVar_Block_Terrorist.BoolValue)
	{
		char Team[8];
		GetCmdArg(1, Team, sizeof(Team));
		int iTeam = StringToInt(Team);
		if (iTeam == 2) // Terrorist
		{
			if (CheckCommandAccess(client, "sm_fake_command", ADMFLAG_GENERIC, true) && g_ConVar_FreePass_Admins.BoolValue)
			{
				return Plugin_Continue;
			}
			else
			{
				if (g_ConVar_Block_Terrorist_Message.BoolValue)
					CPrintToChat(client, "%s %t", g_ChatPrefix, "Terrorist");
				return Plugin_Handled;
			}
		}
		else
		{
			return Plugin_Continue;
		}
	}
	return Plugin_Continue;
}

///////////////////
//Counter Terrorist
///////////////////

public Action Command_JoinTeam2(int client, char[] command, int args)
{
	if (g_ConVar_Block_Counter_Terrorist.BoolValue)
	{
		char Team[8];
		GetCmdArg(1, Team, sizeof(Team));
		int iTeam = StringToInt(Team);
		if (iTeam == 3) // Counter Terrorist
		{
			if (CheckCommandAccess(client, "sm_fake_command", ADMFLAG_GENERIC, true) && g_ConVar_FreePass_Admins.BoolValue)
			{
				return Plugin_Continue;
			}
			else
			{
				if (g_ConVar_Block_Counter_Terrorist_Message.BoolValue)
					CPrintToChat(client, "%s %t", g_ChatPrefix, "CounterTerrorist");
				return Plugin_Handled;
			}
		}
		else
		{
			return Plugin_Continue;
		}
	}
	return Plugin_Continue;
} 