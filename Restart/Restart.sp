int iTime;

public Plugin myinfo =
{
	name	= "Restart",
	author	= "Temlik & HolyHender",
	version	= "2.0"
};

public void OnPluginStart()
{
	RegAdminCmd("sm_restart", Command_Restart, ADMFLAG_ROOT);
}

public Action Command_Restart(int iClient, int iArgs)
{
	if(iArgs < 1)
	{
		ReplyToCommand(iClient, "Usage: sm_restart <seconds>");
		return Plugin_Handled;
	}
	
	char sTime[4];
	GetCmdArg(1, sTime, sizeof(sTime));
	iTime = StringToInt(sTime);
	if (iTime > 0)
	{
		CreateTimer(1.0, Timer_Restart, _, TIMER_REPEAT);
	}
	
	return Plugin_Handled;
}

public Action Timer_Restart(Handle hTimer)
{
	if (iTime > 0)
	{
		PrintCenterTextAll("Server will restart in: %i seconds.", iTime);
		iTime--;
		return Plugin_Continue;
	}
	else
	{
		PrintCenterTextAll("Рестарт!");
		ServerCommand("exit");
		return Plugin_Stop;
	}
}