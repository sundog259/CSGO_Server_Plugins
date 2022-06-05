#pragma newdecls required

public Plugin myinfo = 
{
	name = "Silence Cvar Messages", 
	author = "LanteJoula", 
	description = "Silence Cvar Messages for All Players", 
	version = "1.0", 
	url = "https://steamcommunity.com/id/lantejoula/"
};

public void OnPluginStart()
{
	HookEvent("server_cvar", SilentEvent, EventHookMode_Pre);
}

public Action SilentEvent(Event event, const char[] name, bool dontBroadcast)
{
	SetEventBroadcast(event, true);
	return Plugin_Continue;
} 