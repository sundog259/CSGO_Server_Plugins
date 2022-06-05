#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <cstrike>
#include <morecolors>

#define PLUGIN_VERSION "2.0"

#pragma newdecls required

bool g_bIsEnabled[MAXPLAYERS + 1];

public Plugin myinfo = 
{
	name = "Toggle radio mute command",
	author = "Nano",
	description = "You can enable or disable the radio voice/text messages using a command",
	version = PLUGIN_VERSION,
	url = "http://steamcommunity.com/id/marianzet1"
};

public void OnPluginStart()
{
	RegConsoleCmd("sm_radiomute", Command_RadioMute);
	RegConsoleCmd("sm_muteradio", Command_RadioMute);
	RegConsoleCmd("sm_mr", Command_RadioMute);
}

public void OnClientPostAdminCheck(int client)
{
    g_bIsEnabled[client] = false;
}

public void OnClientDisconnect(int client)
{
	g_bIsEnabled[client] = false;
}

public Action Command_RadioMute(int client, int args)
{	
	if(!g_bIsEnabled[client])
	{
		g_bIsEnabled[client] = true;
		FakeClientCommand(client, "ignorerad");
		CPrintToChat(client, "{green}[{lightgreen}Mute-Radio{green}]{default} You have {fullred}disabled {default}all radio messages.");
		return Plugin_Handled;
	}
	else
	{
		g_bIsEnabled[client] = false;
		FakeClientCommand(client, "ignorerad");
		CPrintToChat(client, "{green}[{lightgreen}Mute-Radio{green}]{default} You have {aqua}enabled {default}all radio messages.");
		return Plugin_Handled;
	}
}