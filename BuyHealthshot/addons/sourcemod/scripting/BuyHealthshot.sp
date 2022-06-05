#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <sdktools_stringtables>
#include <sdktools_sound>
#include <sdktools_tempents>
#include <multicolors>

bool
	bEnable;

int
	iOffsetMoney,
	iMaxBuyPlayers[MAXPLAYERS+1],
	iMinHealth,
	iCost,
	iShowCall,
	iMaxBuy;


public Plugin myinfo = 
{
	name = "buy healthshot",
	author = "Prokke",
	description = "Возможность покупки шприца",
	version = "1.0",
	url = "vk.com/prokke"
};

public void OnPluginStart()
{
	LoadTranslations("buyhealthshot.phrases");
	
	ConVar cvar;
	cvar = CreateConVar("sm_buy_healthshot_enable", "1", "Включить/выключить плагин", _, true, _, true, 1.0);
	cvar.AddChangeHook(CVarChanged_Enable);
	bEnable = cvar.BoolValue;
	
	cvar = CreateConVar("sm_healthshot_minhealth", "100", "Минимальное количество хп для покупки шприца", _, true, 0.0);
	cvar.AddChangeHook(CVarChanged_MinHealth);
	iMinHealth = cvar.IntValue;
	
	
	cvar = CreateConVar("sm_healthshot_cost", "5000", "Количество денег необходимая для покупки шприца", _, true, 0.0);
	cvar.AddChangeHook(CVarChanged_Cost);
	iCost = cvar.IntValue;
	
	cvar = CreateConVar("sm_healthshot_showcall", "0", "Оповещать других игроков о факте покупки шприца", _, true, 0.0);
	cvar.AddChangeHook(CVarChanged_ShowCall);
	iShowCall = cvar.IntValue;
	
	cvar = CreateConVar("sm_healthshot_maxbuy", "1", "Сколько раз за 1 раунд игрок может купить шприц", _, true, 0.0);
	cvar.AddChangeHook(CVarChanged_MaxUse);
	iMaxBuy = cvar.IntValue;
	
	
	iOffsetMoney = FindSendPropInfo("CCSPlayer", "m_iAccount");
	
	HookEvent("player_spawn", Event_PlayerSpawn);
	
	RegConsoleCmd("sm_health", Command_Medic);
	
	AutoExecConfig(true, "healthshot_buy_all");
}

public void CVarChanged_Enable(ConVar CVar, const char[] oldValue, const char[] newValue)
{
	bEnable = CVar.BoolValue;
}

public void CVarChanged_MinHealth(ConVar cvar, const char[] oldValue, const char[] newValue)
{
	iMinHealth = cvar.IntValue;
}

public void CVarChanged_Cost(ConVar cvar, const char[] oldValue, const char[] newValue)
{
	iCost = cvar.IntValue;
}

public void CVarChanged_ShowCall(ConVar cvar, const char[] oldValue, const char[] newValue)
{
	iShowCall = cvar.IntValue;
}

public void CVarChanged_MaxUse(ConVar cvar, const char[] oldValue, const char[] newValue)
{
	iMaxBuy = cvar.IntValue;
}



public void OnClientConnected(int iClient)
{
	iMaxBuyPlayers[iClient] = 0;
}

public void OnClientDisconnect(int iClient)
{
	iMaxBuyPlayers[iClient] = 0;
}



public Action Event_PlayerSpawn(Handle hEvent, const char[] sName, bool dontBroadcast)
{
	if(!bEnable)
		return;
	
	int iClient = GetClientOfUserId(GetEventInt(hEvent, "userid"));

	iMaxBuyPlayers[iClient] = 0;
}

public Action Command_Medic(int iClient, any args)
{
	if(!bEnable || !IsPlayerAlive(iClient))
		return Plugin_Handled;

	if(iMaxBuyPlayers[iClient] >= iMaxBuy)
	{
		CPrintToChat(iClient, "%t", "Tag", "Limit", iMaxBuy);
		return Plugin_Handled;
	}
	
	int iMoney = GetClientMoney(iClient);
	
	if(iMoney < iCost && iCost != 0)
	{
		CPrintToChat(iClient, "%t", "Tag", "Not enough cash", iCost);
		return Plugin_Handled;
	}
	
	if(GetClientHealth(iClient) >= iMinHealth)
	{
		CPrintToChat(iClient, "%t", "Tag", "Too much health");	
		return Plugin_Handled;
	}
	
	iMaxBuyPlayers[iClient]++;
	
	GivePlayerItem(iClient, "weapon_healthshot");
	SetClientMoney(iClient, iMoney - iCost);
	CPrintToChat(iClient, "%t", "Tag", "Healthshot bought");	

	if(iShowCall)
	{
		char sName[32];
		GetClientName(iClient, sName, sizeof(sName) - 1);
		for(int i = 1; i <= MaxClients; i++) if(i != iClient && IsClientInGame(i) && !IsFakeClient(i))
			CPrintToChat(i, "%t", "Tag", "I bought a healthshot", sName, GetClientHealth(iClient));
	}
	
	
	return Plugin_Changed;
}	

stock void SetClientMoney(int iIndex, int iMoney)
{
	if(iOffsetMoney != -1)
	{
		SetEntData(iIndex, iOffsetMoney, iMoney);
	}
}

stock int GetClientMoney(int iIndex)
{
	if(iOffsetMoney != -1)
	{
		return GetEntData(iIndex, iOffsetMoney);
	}
	
	return 0;
}

