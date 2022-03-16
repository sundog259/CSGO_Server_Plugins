/*
 * =============================================================================
 * File:		  Boss_Hud
 * Type:		  Base
 * Description:   Plugin's base file.
 *
 * Copyright (C)   Anubis Edition. All rights reserved.
 * =============================================================================
 *
 * This program is free software; you can redistribute it and/or modify it under
 * the terms of the GNU General Public License, version 3.0, as published by the
 * Free Software Foundation.
 * 
 * This program is distributed in the hope that it will be useful, but WITHOUT
 * ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
 * FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
 * details.
 *
 * You should have received a copy of the GNU General Public License along with
 * this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 * As a special exception, AlliedModders LLC gives you permission to link the
 * code of this program (as well as its derivative works) to "Half-Life 2," the
 * "Source Engine," the "SourcePawn JIT," and any Game MODs that run on software
 * by the Valve Corporation.  You must obey the GNU General Public License in
 * all respects for all other code used.  Additionally, AlliedModders LLC grants
 * this exception to all derivative works.  AlliedModders LLC defines further
 * exceptions, found in LICENSE.txt (as of this writing, version JULY-31-2007),
 * or <http://www.sourcemod.net/license.php>.
 */

#define PLUGIN_NAME           "Boss_Hud"
#define PLUGIN_AUTHOR         "Anubis"
#define PLUGIN_DESCRIPTION    "Shows the func_physbox/func_physbox_multiplayer/func_breakable/math_counter you are shooting at"
#define PLUGIN_VERSION        "1.1"
#define PLUGIN_URL            "https://github.com/Stewart-Anubis"

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <clientprefs>
#include <csgocolors_fix>

#pragma semicolon 1

#pragma newdecls required

#define MAX_TEXT_LENGTH	64
#define MENU_LINE_REG_LENGTH 64
#define MENU_LINE_BIG_LENGTH 128
#define HUGE_LINE_LENGTH 512
#define MENU_LINE_TITLE_LENGTH MENU_LINE_BIG_LENGTH



Handle g_hkvbosshp = INVALID_HANDLE;
Handle g_hkvbosshpAdmin = INVALID_HANDLE;
Handle g_hmp_maxmoney = INVALID_HANDLE;
Handle g_hsv_disable_radar = INVALID_HANDLE;

Handle g_hHpBhEnable = INVALID_HANDLE;
Handle g_hHpBrEnable = INVALID_HANDLE;
Handle g_hHudType = INVALID_HANDLE;
Handle g_hHitmEnable = INVALID_HANDLE;
Handle g_hTopdEnable = INVALID_HANDLE;
Handle g_hHudPasition = INVALID_HANDLE;


char g_sPathFileBoss[PLATFORM_MAX_PATH];
char g_sValue_mp_maxmoney[10];
char g_sValue_sv_disable_radar[10];
char g_sHudTopPosX[MAXPLAYERS+1][8];
char g_sHudTopPosY[MAXPLAYERS+1][8];

ConVar g_cBossHud = null;
ConVar g_cVUpdateTime = null;
ConVar g_cVUTopRankTime = null;

bool g_bBoshudDebugger[MAXPLAYERS+1] = {false, ...};
bool g_bBossHud = true;
bool g_bBossDestroy = false;

int g_iTop_Rank_Dmg[MAXPLAYERS+1];
int g_iSayingSettings[MAXPLAYERS + 1];
int g_iItemSettings[MAXPLAYERS + 1];
int g_iVUpdateTime = 3;
int g_iVUTopRankTime = 10;
int g_iVUTopRankTimer;

enum struct BossHud_Enum
{
	int e_iTimer;
	int e_iEntityID;
	bool e_bHpBhEnable;
	bool e_bHpBrEnable;
	bool e_bHitmEnable;
	bool e_bTopdEnable;
	bool e_bHudType;
	char e_sHudPasition[MAX_TEXT_LENGTH];
	int e_iHammerID;
	char e_sName[MAX_TEXT_LENGTH];
	char e_sTextBar[MAX_TEXT_LENGTH];
	int e_iHPvalue_Max;
	int e_iHPvalue;
	int e_iHPpercent;
}

BossHud_Enum BossHudClientEnum[MAXPLAYERS+1];

public Plugin myinfo =
{
	name = PLUGIN_NAME,
	author = PLUGIN_AUTHOR,
	description = PLUGIN_DESCRIPTION,
	version = PLUGIN_VERSION,
	url = PLUGIN_URL
};

public void OnPluginStart()
{
	g_cBossHud = CreateConVar("sm_boss_hud", "1", "Boss Hud Enable = 1/Disable = 0");
	g_cVUpdateTime = CreateConVar("sm_boss_hud_updatetime", "3", "How long to update the client's hud with current health for.");
	g_cVUTopRankTime = CreateConVar("sm_boss_hud_boss_rank", "10", "How long after they stop shooting to appear the Top Boss Rank.");

	g_hHpBhEnable = RegClientCookie("Boss_Hud_Enable", "BossHud Hud Enable", CookieAccess_Protected);
	g_hHpBrEnable = RegClientCookie("Boss_Breakable", "BossHud Breakable", CookieAccess_Protected);
	g_hHudType = RegClientCookie("Boss_Hud_Type", "BossHud Hud Type", CookieAccess_Protected);
	g_hHitmEnable = RegClientCookie("Boss_Hit_Marker", "BossHud Hit Marker", CookieAccess_Protected);
	g_hTopdEnable = RegClientCookie("Boss_Top_Rank", "BossHud Top Rank", CookieAccess_Protected);
	g_hHudPasition = RegClientCookie("Boss_Hud_Position", "BossHud Psition Hud", CookieAccess_Protected);

	HookEntityOutput("func_physbox", "OnHealthChanged", OnHealthChanged);
	HookEntityOutput("func_physbox_multiplayer", "OnHealthChanged", OnHealthChanged);
	HookEntityOutput("func_breakable", "OnHealthChanged", OnHealthChanged);
	HookEntityOutput("math_counter", "OutValue", CounterOutValue);
	HookEvent("round_start",Event_RoundStart, EventHookMode_PostNoCopy);
	HookEvent("round_end", Event_RoundEnd, EventHookMode_PostNoCopy);

	RegAdminCmd("sm_bhudadmin", Command_BhudAdmin, ADMFLAG_GENERIC, "Bhud_Admin");
	RegAdminCmd("sm_bhuddebug", Command_BhudDebug, ADMFLAG_GENERIC, "Bhud_Debug");
	RegConsoleCmd("sm_bhud", Command_Bhud, "Bhud");

	g_cBossHud.AddChangeHook(ConVarChange);
	g_cVUpdateTime.AddChangeHook(ConVarChange);
	g_cVUTopRankTime.AddChangeHook(ConVarChange);

	g_bBossHud = g_cBossHud.BoolValue;
	g_iVUpdateTime = g_cVUpdateTime.IntValue;
	g_iVUTopRankTime = g_cVUTopRankTime.IntValue;
	
	g_hmp_maxmoney = FindConVar("mp_maxmoney");
	GetConVarString(g_hmp_maxmoney, g_sValue_mp_maxmoney, sizeof(g_sValue_mp_maxmoney));
	g_hsv_disable_radar = FindConVar("sv_disable_radar");
	GetConVarString(g_hsv_disable_radar, g_sValue_sv_disable_radar, sizeof(g_sValue_sv_disable_radar));

	CreateTimer(0.25, UpdateHUD, _, TIMER_REPEAT);

	for(int i = 1; i <= MaxClients; i++)
	{ 
		if(IsValidClient(i))
		{	
			OnClientCookiesCached(i);
		}
	}

	AutoExecConfig(true, "Boss_hud");
}

public void ConVarChange(ConVar CVar, const char[] oldVal, const char[] newVal)
{
	g_bBossHud = g_cBossHud.BoolValue;
	g_iVUpdateTime = g_cVUpdateTime.IntValue;
	g_iVUTopRankTime = g_cVUTopRankTime.IntValue;
}

public void OnMapStart()
{
	LoadTranslations("boss_hud.phrases");
	LoadTranslations("common.phrases");
	LoadTranslations("core.phrases");
	ReadFileBoss();
}

public Action Event_RoundStart(Event event, char[] name, bool dontBroadcast)
{
	Top_Rank_Reset();
	g_bBossDestroy = false;
	ReadFileBoss();
}

public void Event_RoundEnd(Event event, char[] name, bool dontBroadcast)
{
	if(g_bBossDestroy)
	{
		g_bBossDestroy = false;
		if(g_bBossHud) PrintBossHitRanks();
	}
}

public void OnClientCookiesCached(int client)
{
	g_iSayingSettings[client] = 0;
	g_iItemSettings[client] = 0;
	char scookie[MAX_TEXT_LENGTH];

	GetClientCookie(client, g_hHpBhEnable, scookie, sizeof(scookie));
	if(!StrEqual(scookie, ""))
	{
		BossHudClientEnum[client].e_bHpBhEnable = view_as<bool>(StringToInt(scookie));
	}
	else	BossHudClientEnum[client].e_bHpBhEnable = true;
		
	GetClientCookie(client, g_hHpBrEnable, scookie, sizeof(scookie));
	if(!StrEqual(scookie, ""))
	{
		BossHudClientEnum[client].e_bHpBrEnable = view_as<bool>(StringToInt(scookie));
	}
	else	BossHudClientEnum[client].e_bHpBrEnable = true;

	GetClientCookie(client, g_hHudType, scookie, sizeof(scookie));
	if(!StrEqual(scookie, ""))
	{
		BossHudClientEnum[client].e_bHudType = view_as<bool>(StringToInt(scookie));
	}
	else	BossHudClientEnum[client].e_bHudType = true;
	
	GetClientCookie(client, g_hHitmEnable, scookie, sizeof(scookie));
	if(!StrEqual(scookie, ""))
	{
		BossHudClientEnum[client].e_bHitmEnable = view_as<bool>(StringToInt(scookie));
	}
	else	BossHudClientEnum[client].e_bHitmEnable = true;
	
	GetClientCookie(client, g_hTopdEnable, scookie, sizeof(scookie));
	if(!StrEqual(scookie, ""))
	{
		BossHudClientEnum[client].e_bTopdEnable = view_as<bool>(StringToInt(scookie));
	}
	else	BossHudClientEnum[client].e_bTopdEnable = true;

	GetClientCookie(client, g_hHudPasition, scookie, sizeof(scookie));
	if(!StrEqual(scookie, ""))
	{
		BossHudClientEnum[client].e_sHudPasition = scookie;
	}
	else	BossHudClientEnum[client].e_sHudPasition = "-1.0 0.775";

	HudStringPos(client);
}

void HudStringPos(int client)
{
	char StringPos[2][8];
	
	ExplodeString(BossHudClientEnum[client].e_sHudPasition, " ", StringPos, sizeof(StringPos), sizeof(StringPos[]));

	Format(g_sHudTopPosX[client], sizeof(g_sHudTopPosX), StringPos[0]);
	Format(g_sHudTopPosY[client], sizeof(g_sHudTopPosY), StringPos[1]);
}

public void OnClientPutInServer(int client)
{
	if(IsValidClient(client))
	{
		OnClientCookiesCached(client);
	}
}

public void OnClientDisconnect(int client)
{
	if(IsValidClient(client))
	{
		g_iSayingSettings[client] = 0;
		g_iItemSettings[client] = 0;
	}
}

public void ReadFileBoss()
{
	delete g_hkvbosshp;
	delete g_hkvbosshpAdmin;
	char map[MAX_TEXT_LENGTH];
	GetCurrentMap(map, sizeof(map));
	BuildPath(Path_SM, g_sPathFileBoss, sizeof(g_sPathFileBoss), "configs/Boss_Hud/%s.txt", map);
	g_hkvbosshp = CreateKeyValues("BOSSHP");
	g_hkvbosshpAdmin = CreateKeyValues("BOSSHP");

	if(!FileExists(g_sPathFileBoss)) KeyValuesToFile(g_hkvbosshp, g_sPathFileBoss);
	else FileToKeyValues(g_hkvbosshp, g_sPathFileBoss);

	KvRewind(g_hkvbosshp);
	KvCopySubkeys(g_hkvbosshp, g_hkvbosshpAdmin);
	KvRewind(g_hkvbosshpAdmin);
}

public Action Command_BhudAdmin(int client, int argc)
{
	if(IsValidClient(client) && IsValidGenericAdmin(client))
	{
		MenuAdminBhud(client);
	}
	else
	PrintToChat(client, "%t", "No Access");
	return Plugin_Handled;
}

public Action Command_BhudDebug(int client, int argc)
{
	if(IsValidClient(client) && IsValidGenericAdmin(client))
	{
		if (g_bBoshudDebugger[client])
		{
			g_bBoshudDebugger[client] = false;
			CPrintToChat(client, "%t", "Boshud Debugger Desabled");
		}
		else
		{
			g_bBoshudDebugger[client] = true;
			CPrintToChat(client, "%t", "Boshud Debugger Enabled");
		}
	}
	else
	PrintToChat(client, "%t", "No Access");
	return Plugin_Handled;
}

public Action Command_Bhud(int client, int arg)
{
	if(IsValidClient(client) && g_bBossHud)
	{
		MenuClientBhud(client);
	}
	return Plugin_Handled;
}

void MenuClientBhud(int client)
{
	if (!IsValidClient(client))
	{
		return;
	}

	SendConVarValue(client, g_hmp_maxmoney, "0");
	SendConVarValue(client, g_hsv_disable_radar, "1");
	SetGlobalTransTarget(client);
	g_iItemSettings[client] = 0;

	char m_sTitle[MENU_LINE_TITLE_LENGTH];
	char m_sBoss_Hud[MENU_LINE_REG_LENGTH];
	char m_sBrekable_Hud[MENU_LINE_REG_LENGTH];
	char m_sBoss_Hud_Type[MENU_LINE_REG_LENGTH];
	char m_sBoss_Hit_Marker[MENU_LINE_REG_LENGTH];
	char m_sBoss_Top_Rank[MENU_LINE_REG_LENGTH];
	char m_sBoss_Hud_Position[MENU_LINE_REG_LENGTH];

	Format(m_sTitle ,sizeof(m_sTitle) ,"%t", "Boss Hud Title");
	if (BossHudClientEnum[client].e_bHpBhEnable) Format(m_sBoss_Hud ,sizeof(m_sBoss_Hud) ,"%t: [%t]" ,"Boss Hud Damage" ,"Enabled");
	else Format(m_sBoss_Hud ,sizeof(m_sBoss_Hud) ,"%t: [%t]" ,"Boss Hud Damage" ,"Desabled");

	if (BossHudClientEnum[client].e_bHpBrEnable) Format(m_sBrekable_Hud ,sizeof(m_sBrekable_Hud) ,"%t: [%t]" ,"Brekable Hud" ,"Enabled");
	else Format(m_sBrekable_Hud ,sizeof(m_sBrekable_Hud) ,"%t: [%t]" ,"Brekable Hud" ,"Desabled");

	if (BossHudClientEnum[client].e_bHudType) Format(m_sBoss_Hud_Type ,sizeof(m_sBoss_Hud_Type) ,"%t: [%t]" ,"Boss Hud Type" ,"Center");
	else Format(m_sBoss_Hud_Type ,sizeof(m_sBoss_Hud_Type) ,"%t: [%t]" ,"Boss Hud Type" ,"Display Hud");

	if (BossHudClientEnum[client].e_bHitmEnable) Format(m_sBoss_Hit_Marker ,sizeof(m_sBoss_Hit_Marker) ,"%t: [%t]" ,"Boss Hit Marker" ,"Enabled");
	else Format(m_sBoss_Hit_Marker ,sizeof(m_sBoss_Hit_Marker) ,"%t: [%t]" ,"Boss Hit Marker" ,"Desabled");

	if (BossHudClientEnum[client].e_bTopdEnable) Format(m_sBoss_Top_Rank ,sizeof(m_sBoss_Top_Rank) ,"%t: [%t]", "Boss Top Rank" ,"Enabled");
	else Format(m_sBoss_Top_Rank ,sizeof(m_sBoss_Top_Rank) ,"%t: [%t]" ,"Boss Top Rank" ,"Desabled");

	Format(m_sBoss_Hud_Position ,sizeof(m_sBoss_Hud_Position) ,"%t: [ %s ]", "Boss Hud Position" ,BossHudClientEnum[client].e_sHudPasition);

	Menu MenuBhud = new Menu(MenuClientBhudCallBack);

	MenuBhud.ExitButton = true;
	MenuBhud.SetTitle(m_sTitle);

	MenuBhud.AddItem("Boss_Hud_Enable", m_sBoss_Hud);
	MenuBhud.AddItem("Brekable_Hud_Enable", m_sBrekable_Hud);
	MenuBhud.AddItem("Boss_Hud_Type", m_sBoss_Hud_Type);
	MenuBhud.AddItem("Boss_Hit_Marker_Enable", m_sBoss_Hit_Marker);
	MenuBhud.AddItem("Boss_Top_Rank_Enable", m_sBoss_Top_Rank);
	MenuBhud.AddItem("Boss_Hud_Position", m_sBoss_Hud_Position);

	MenuBhud.Display(client, MENU_TIME_FOREVER);
}

public int MenuClientBhudCallBack(Handle MenuBhud, MenuAction action, int client, int itemNum)
{
	if (action == MenuAction_End)
	{
		delete MenuBhud;
	}

	if (action == MenuAction_Select)
    {
		char sItem[MAX_TEXT_LENGTH];
		GetMenuItem(MenuBhud, itemNum, sItem, sizeof(sItem));
		if (StrEqual(sItem[0], "Boss_Hud_Enable"))
		{
			BossHudClientEnum[client].e_bHpBhEnable = !BossHudClientEnum[client].e_bHpBhEnable;
			BossHudCookiesSetBool(client, g_hHpBhEnable, BossHudClientEnum[client].e_bHpBhEnable);
			MenuClientBhud(client);
		}
		else if (StrEqual(sItem[0], "Brekable_Hud_Enable"))
		{
			BossHudClientEnum[client].e_bHpBrEnable = !BossHudClientEnum[client].e_bHpBrEnable;
			BossHudCookiesSetBool(client, g_hHpBrEnable, BossHudClientEnum[client].e_bHpBrEnable);
			MenuClientBhud(client);
		}
		else if (StrEqual(sItem[0], "Boss_Hud_Type"))
		{
			BossHudClientEnum[client].e_bHudType = !BossHudClientEnum[client].e_bHudType;
			BossHudCookiesSetBool(client, g_hHudType, BossHudClientEnum[client].e_bHudType);
			MenuClientBhud(client);
		}
		else if (StrEqual(sItem[0], "Boss_Hit_Marker_Enable"))
		{
			BossHudClientEnum[client].e_bHitmEnable = !BossHudClientEnum[client].e_bHitmEnable;
			BossHudCookiesSetBool(client, g_hHitmEnable, BossHudClientEnum[client].e_bHitmEnable);
			MenuClientBhud(client);
		}
		else if (StrEqual(sItem[0], "Boss_Top_Rank_Enable"))
		{
			BossHudClientEnum[client].e_bTopdEnable = !BossHudClientEnum[client].e_bTopdEnable;
			BossHudCookiesSetBool(client, g_hTopdEnable, BossHudClientEnum[client].e_bTopdEnable);
			MenuClientBhud(client);
		}
		else if (StrEqual(sItem[0], "Boss_Hud_Position"))
		{
			g_iItemSettings[client] = 3;
			g_iSayingSettings[client] = 1;
			CPrintToChat(client, "%t", "Change Hud Position", BossHudClientEnum[client].e_sHudPasition);
			action = MenuAction_Cancel;
		}
 	}

	if (action == MenuAction_Cancel)
	{
		if (IsValidClient(client))
		{
			SendConVarValue(client, g_hmp_maxmoney, g_sValue_mp_maxmoney);
			SendConVarValue(client, g_hsv_disable_radar, g_sValue_sv_disable_radar);
		}
	}

	return 0;
}

void BossHudCookiesSetBool(int client, Handle cookie, bool cookievalue)
{
	char strCookievalue[8];
	BoolToString(cookievalue, strCookievalue, sizeof(strCookievalue));

	SetClientCookie(client, cookie, strCookievalue);
}

void BoolToString(bool value, char[] output, int maxlen)
{
	if(value) strcopy(output, maxlen, "1");
	else strcopy(output, maxlen, "0");
}

void MenuAdminBhud(int client, bool MenuAdmin2 = false, char[] ItemMenu = "")
{
	if(g_hkvbosshpAdmin == INVALID_HANDLE || g_hkvbosshp == INVALID_HANDLE)
	{
		ReadFileBoss();
	}

	g_iSayingSettings[client] = 0;
	g_iItemSettings[client] = 0;

	if (!IsValidClient(client))
	{
		return;
	}

	SetGlobalTransTarget(client);
	SendConVarValue(client, g_hmp_maxmoney, "0");
	SendConVarValue(client, g_hsv_disable_radar, "1");

	char sBuffer_temp[MAX_TEXT_LENGTH];
	char sBuffer_temp2[MAX_TEXT_LENGTH];
	char m_sTitle[MENU_LINE_TITLE_LENGTH];

	Menu MenuBhudAdmin = new Menu(MenuAdminBhudCallBack);

	if(MenuAdmin2 && strlen(ItemMenu) != 0)
	{
		if(!KvJumpToKey(g_hkvbosshpAdmin, ItemMenu))
		{
			CPrintToChat(client, "%t", "Invalid Entity", ItemMenu);
			return;
		}

		char c_sTemp[MAX_TEXT_LENGTH];
		char c_sMenu2_Boss[MENU_LINE_REG_LENGTH];
		char c_sChangeBossName[MENU_LINE_REG_LENGTH];
		char c_sChangeMax_Hp[MENU_LINE_REG_LENGTH];

		Format(c_sChangeBossName, sizeof(c_sChangeBossName), "%t", "Change Boss Name");
		Format(c_sChangeMax_Hp, sizeof(c_sChangeMax_Hp), "%t", "Change Boss Max_Hp");

		KvGetString(g_hkvbosshpAdmin, "m_iname", c_sTemp, sizeof(c_sTemp), "");

		if (KvGetNum(g_hkvbosshpAdmin, "enabled") <= 0)
		{
			Format(m_sTitle, sizeof(m_sTitle), "%t", "Boss Hud Title Admin Disabled", c_sTemp, KvGetNum(g_hkvbosshpAdmin, "hammerid"), KvGetNum(g_hkvbosshpAdmin, "HPvalue_max"));
			MenuBhudAdmin.SetTitle(m_sTitle);
			Format(c_sMenu2_Boss, sizeof(c_sMenu2_Boss), "%t", "Enable");
			MenuBhudAdmin.AddItem("To_Menu2_Enable", c_sMenu2_Boss);
		}
		else
		{
			Format(m_sTitle, sizeof(m_sTitle), "%t", "Boss Hud Title Admin Enabled", c_sTemp, KvGetNum(g_hkvbosshpAdmin, "hammerid"), KvGetNum(g_hkvbosshpAdmin, "HPvalue_max"));
			MenuBhudAdmin.SetTitle(m_sTitle);
			Format(c_sMenu2_Boss, sizeof(c_sMenu2_Boss), "%t", "Desable");
			MenuBhudAdmin.AddItem("To_Menu2_Disable", c_sMenu2_Boss);
		}
		MenuBhudAdmin.ExitBackButton = true;
		MenuBhudAdmin.AddItem("To_Menu2_BossName", c_sChangeBossName);
		MenuBhudAdmin.AddItem("To_Menu2_Max_Hp", c_sChangeMax_Hp);
		MenuBhudAdmin.AddItem("", "", ITEMDRAW_NOTEXT);
		MenuBhudAdmin.AddItem("", "", ITEMDRAW_NOTEXT);
		MenuBhudAdmin.AddItem("", "", ITEMDRAW_NOTEXT);
	}
	else
	{
		Format(m_sTitle, sizeof(m_sTitle), "%t", "Boss Hud Admin Title");
		MenuBhudAdmin.SetTitle(m_sTitle);
		MenuBhudAdmin.ExitBackButton = true;

		if (KvGotoFirstSubKey(g_hkvbosshpAdmin))
		{
			do
			{
				KvGetString(g_hkvbosshpAdmin, "m_iname", sBuffer_temp, sizeof(sBuffer_temp), "");
				if (KvGetNum(g_hkvbosshpAdmin, "enabled") <= 0)
				{
					Format(sBuffer_temp, sizeof(sBuffer_temp), "[%t] %s", "Desabled", sBuffer_temp);
				}
				else
				{
					Format(sBuffer_temp, sizeof(sBuffer_temp), "[%t] %s", "Enabled", sBuffer_temp);
				}
				KvGetSectionName(g_hkvbosshpAdmin, sBuffer_temp2, sizeof(sBuffer_temp2)); 
				MenuBhudAdmin.AddItem(sBuffer_temp2, sBuffer_temp);
			} while (KvGotoNextKey(g_hkvbosshpAdmin));
			KvRewind(g_hkvbosshpAdmin);
		}
		else
		{
			if (IsValidClient(client))
			{
				SendConVarValue(client, g_hmp_maxmoney, g_sValue_mp_maxmoney);
				SendConVarValue(client, g_hsv_disable_radar, g_sValue_sv_disable_radar);
				CPrintToChat(client, "%t", "No entity found");
			}
			KvRewind(g_hkvbosshpAdmin);
			delete MenuBhudAdmin;
			return;
		}
	}
	MenuBhudAdmin.Display(client, MENU_TIME_FOREVER);
}

public int MenuAdminBhudCallBack(Handle MenuBhudAdmin, MenuAction action, int client, int itemNum)
{
	if (action == MenuAction_End)
	{
		delete MenuBhudAdmin;
	}

	if (action == MenuAction_Select)
    {
		char sItem[MAX_TEXT_LENGTH];
		GetMenuItem(MenuBhudAdmin, itemNum, sItem, sizeof(sItem));

		if (StrEqual(sItem[0], "To_Menu2_Disable"))
		{
			char sBuffer[MAX_TEXT_LENGTH];
			KvSetNum(g_hkvbosshpAdmin, "enabled", 0);
			KvGetSectionName(g_hkvbosshpAdmin, sBuffer, sizeof(sBuffer));
			KvRewind(g_hkvbosshpAdmin);
			KvRewind(g_hkvbosshp);
			KvCopySubkeys(g_hkvbosshpAdmin, g_hkvbosshp);
			KeyValuesToFile(g_hkvbosshpAdmin, g_sPathFileBoss);

			MenuAdminBhud(client, true, sBuffer);
		}
		else if (StrEqual(sItem[0], "To_Menu2_Enable"))
		{
			char sBuffer[MAX_TEXT_LENGTH];
			KvSetNum(g_hkvbosshpAdmin, "enabled", 1);
			KvGetSectionName(g_hkvbosshpAdmin, sBuffer, sizeof(sBuffer));
			KvRewind(g_hkvbosshpAdmin);
			KvRewind(g_hkvbosshp);
			KvCopySubkeys (g_hkvbosshpAdmin, g_hkvbosshp);
			KeyValuesToFile(g_hkvbosshpAdmin, g_sPathFileBoss);

			MenuAdminBhud(client, true, sBuffer);
		}
		else if (StrEqual(sItem[0], "To_Menu2_BossName"))
		{
			char sBuffer_temp[MAX_TEXT_LENGTH];
			char c_sTemps[MAX_TEXT_LENGTH];
			KvGetSectionName(g_hkvbosshpAdmin, sBuffer_temp, sizeof(sBuffer_temp));
			g_iItemSettings[client] = 1;
			g_iSayingSettings[client] = StringToInt(sBuffer_temp);
			KvGetString(g_hkvbosshpAdmin, "m_iname", c_sTemps, sizeof(c_sTemps), "");
			CPrintToChat(client, "%t", "Rename the entity", c_sTemps);
			KvRewind(g_hkvbosshpAdmin);
			action = MenuAction_Cancel;
		}
		else if (StrEqual(sItem[0], "To_Menu2_Max_Hp"))
		{
			char sBuffer_temp[MAX_TEXT_LENGTH];
			KvGetSectionName(g_hkvbosshpAdmin, sBuffer_temp, sizeof(sBuffer_temp));
			g_iSayingSettings[client] = StringToInt(sBuffer_temp);
			g_iItemSettings[client] = 2;
			CPrintToChat(client, "%t", "Change Entity Hp_Max", KvGetNum(g_hkvbosshpAdmin, "HPvalue_max"));
			KvRewind(g_hkvbosshpAdmin);
			action = MenuAction_Cancel;
		}
		else MenuAdminBhud(client, true, sItem);
 	}

	if (action == MenuAction_Cancel)
	{
		if (IsValidClient(client))
		{
			SendConVarValue(client, g_hmp_maxmoney, g_sValue_mp_maxmoney);
			SendConVarValue(client, g_hsv_disable_radar, g_sValue_sv_disable_radar);
		}
	}

	if (itemNum == MenuCancel_ExitBack)
	{
		KvRewind(g_hkvbosshpAdmin);
		MenuAdminBhud(client);
	}

	return 0;
}

public void OnClientConnected(int client)
{
	if (IsValidClient(client))
	{
		BossHudClientEnum[client].e_iEntityID = -1;
		BossHudClientEnum[client].e_iHammerID = -1;
		BossHudClientEnum[client].e_iTimer = 0;
	}
}

public void OnEntityCreated(int entity, const char[] classname)
{
	if(StrEqual(classname, "func_physbox", false) || StrEqual(classname, "func_physbox_multiplayer", false) || StrEqual(classname, "func_breakable", false))
	{
		if (IsValidEntity(entity))	SDKHook(entity, SDKHook_OnTakeDamage, OnTakeDamage);
	}
}

public void OnHealthChanged(const char[] output, int entity, int activator, float delay)
{
	if (IsValidClient(activator) && IsValidEntity(entity))
	{
		char targetname[MAX_TEXT_LENGTH];
		char bossname[MAX_TEXT_LENGTH];
		char hammerID[MAX_TEXT_LENGTH];

		GetEntPropString(entity, Prop_Data, "m_iName", targetname, sizeof(targetname));
		int HPvalue = GetEntProp(entity, Prop_Data, "m_iHealth");

		int hammerIDi = GetEntProp(entity, Prop_Data, "m_iHammerID");
		IntToString(hammerIDi, hammerID, sizeof(hammerID));

		if(strlen(targetname) == 0) targetname = "No-Name";
		Format(bossname, sizeof(bossname), "►[%s]◄", targetname);

		if (g_bBoshudDebugger[activator])
		{
			PrintToChat(activator, " \x04[Boss_HUD] Breakable: \x01%s  \x04HammerID: \x01%d  \x04HP: \x01%d\x04.", targetname, hammerIDi, HPvalue);
		}
		if(HPvalue <= 0 && HPvalue >= -20) HPvalue = 0;

		if(HPvalue >= 0 && HPvalue <= 900000)
		{
			BossHudDamage(entity, activator, HPvalue, bossname, hammerID, hammerIDi);
		}
	}
}

public void CounterOutValue(const char[] output, int entity, int activator, float delay)
{
	if (IsValidClient(activator) && (IsValidEntity(entity) || IsValidEdict(entity)))
	{
		char hammerID[MAX_TEXT_LENGTH];
		char targetname[MAX_TEXT_LENGTH];
		char bossname[MAX_TEXT_LENGTH];

		int hammerIDi = GetEntProp(entity, Prop_Data, "m_iHammerID");
		IntToString(hammerIDi, hammerID, sizeof(hammerID));
		
		GetEntPropString(entity, Prop_Data, "m_iName", targetname, sizeof(targetname));
		int HPvalue = RoundToNearest(GetEntDataFloat(entity, FindDataMapInfo(entity, "m_OutValue")));
		
		if(strlen(targetname) == 0) targetname = "No-Name";
		Format(bossname, sizeof(bossname), "►[BOSS %s]◄", targetname);

		if (g_bBoshudDebugger[activator])
		{
			PrintToChat(activator, " \x04[Boss_HUD] MathCounter: \x01%s  \x04HammerID: \x01%d  \x04HP: \x01%d\x04.", targetname, hammerIDi, HPvalue);
		}
		if(HPvalue <= 0 && HPvalue >= -20) HPvalue = 0;

		if(HPvalue >= 0 && HPvalue <= 900000)
		{
			BossHudDamage(entity, activator, HPvalue, bossname, hammerID, hammerIDi, true);
		}
	}
}

public Action OnTakeDamage (int entity, int &attacker, int &inflictor, float &damage, int &damagetype, int &weapon, float damageForce[3], float damagePosition[3])
{
	if (IsValidEntity(entity) && IsValidEdict(entity) && IsValidClient(attacker))
	{
		char hammerID[MAX_TEXT_LENGTH];
		char targetname[MAX_TEXT_LENGTH];
		char bossname[MAX_TEXT_LENGTH];
		char szType[MAX_TEXT_LENGTH];
		bool b_temp = false;

		int hammerIDi = GetEntProp(entity, Prop_Data, "m_iHammerID");
		IntToString(hammerIDi, hammerID, sizeof(hammerID));
		GetEntityClassname(entity, szType, sizeof(szType));
		
		GetEntPropString(entity, Prop_Data, "m_iName", targetname, sizeof(targetname));
		int HPvalue;

		if(strlen(targetname) == 0) targetname = "No-Name";

		if(StrEqual(szType, "math_counter", false))
		{
			HPvalue = RoundToNearest(GetEntDataFloat(entity, FindDataMapInfo(entity, "m_OutValue")));
			Format(bossname, sizeof(bossname), "►[BOSS %s]◄", targetname);
			b_temp = true;
		}
		else
		{
			HPvalue = GetEntProp(entity, Prop_Data, "m_iHealth");
			Format(bossname, sizeof(bossname), "►[%s]◄", targetname);
			b_temp = false;
		}
		if(HPvalue <= 0 && HPvalue >= -20) HPvalue = 0;

		if(HPvalue >= 0 && HPvalue <= 900000)
		{
			BossHudDamage(entity, attacker, HPvalue, bossname, hammerID, hammerIDi, b_temp);
		}
	}
}

void BossHudDamage(int entity, int attacker, int HPvalue, char[] bossname, char[] hammerID, int hammerIDi, bool math_counter = false)
{
	if (IsValidClient(attacker))
	{
		if(g_hkvbosshp == INVALID_HANDLE)
		{
			ReadFileBoss();
			return;
		}
		KvRewind(g_hkvbosshp);

		if(!KvJumpToKey(g_hkvbosshp, hammerID))
		{
			KvRewind(g_hkvbosshp);
			KvJumpToKey(g_hkvbosshp, hammerID, true);
			if(HPvalue >= 1 && HPvalue <= 900000) KvSetNum(g_hkvbosshp, "enabled", 1);
			else KvSetNum(g_hkvbosshp, "enabled", 0);
			KvSetString(g_hkvbosshp, "hammerid", hammerID);
			KvSetString(g_hkvbosshp, "m_iname", bossname);
			KvSetNum(g_hkvbosshp, "HPvalue_max", HPvalue);
			KvRewind(g_hkvbosshp);
			KeyValuesToFile(g_hkvbosshp, g_sPathFileBoss);
			KvRewind(g_hkvbosshpAdmin);
			KvCopySubkeys(g_hkvbosshp, g_hkvbosshpAdmin);
			KvJumpToKey(g_hkvbosshp, hammerID);
		}

		if (KvGetNum(g_hkvbosshp, "enabled") <= 0 || !g_bBossHud)
		{
			KvRewind(g_hkvbosshp);
			return;
		}

		if (hammerIDi != BossHudClientEnum[attacker].e_iHammerID)
		{
			char szString[MAX_TEXT_LENGTH];
			int HPvalue_MAX = KvGetNum(g_hkvbosshp, "HPvalue_max");
			KvGetString(g_hkvbosshp, "m_iname", szString, sizeof(szString), bossname);
			strcopy(BossHudClientEnum[attacker].e_sName, MAX_TEXT_LENGTH, szString);
			BossHudClientEnum[attacker].e_iHPvalue_Max = HPvalue_MAX;
			BossHudClientEnum[attacker].e_iEntityID = entity;
		}
		KvRewind(g_hkvbosshp);

		int HPpercent = RoundFloat(float(HPvalue)/float(BossHudClientEnum[attacker].e_iHPvalue_Max)*100.0);

		char sTextBar[MAX_TEXT_LENGTH];
		Format(sTextBar, sizeof(sTextBar), "%s", CreateIcon(HPpercent));

		BossHudClientEnum[attacker].e_iHammerID = StringToInt(hammerID);
		strcopy(BossHudClientEnum[attacker].e_sTextBar, MAX_TEXT_LENGTH, sTextBar);
		BossHudClientEnum[attacker].e_iHPvalue = HPvalue;
		BossHudClientEnum[attacker].e_iHPpercent = HPpercent;
		if (BossHudClientEnum[attacker].e_bHpBrEnable)
		{
			SendCenterMsg(attacker, BossHudClientEnum[attacker].e_sName, sTextBar, HPvalue, HPpercent);
			BossHudClientEnum[attacker].e_iTimer = GetTime();
		}
		if (math_counter)
		{
			g_iVUTopRankTimer = GetTime();
			g_bBossDestroy = true;
			g_iTop_Rank_Dmg[attacker]+= 1;
		}

		if (BossHudClientEnum[attacker].e_bHitmEnable)
		{
			SetHudTextParams(-1.0, -1.0, 0.1, 255, 0, 0, 0, 0, 6.0, 0.0, 0.0);
			ShowHudText(attacker, 5, "X");
		}
	}
}

stock char CreateIcon(int hp)
{
	char sText[MAX_TEXT_LENGTH]; // ►[BOSS]◄

	if(hp >= 100)		sText = "⬛⬛⬛⬛⬛⬛⬛⬛⬛⬛⬛⬛⬛⬛⬛⬛⬛⬛⬛⬛";
	else if(hp >= 95)	sText = "⬛⬛⬛⬛⬛⬛⬛⬛⬛⬛⬛⬛⬛⬛⬛⬛⬛⬛⬛⬜";
	else if(hp >= 90)	sText = "⬛⬛⬛⬛⬛⬛⬛⬛⬛⬛⬛⬛⬛⬛⬛⬛⬛⬛⬜⬜";
	else if(hp >= 85)	sText = "⬛⬛⬛⬛⬛⬛⬛⬛⬛⬛⬛⬛⬛⬛⬛⬛⬛⬜⬜⬜";
	else if(hp >= 80)	sText = "⬛⬛⬛⬛⬛⬛⬛⬛⬛⬛⬛⬛⬛⬛⬛⬛⬜⬜⬜⬜";
	else if(hp >= 75)	sText = "⬛⬛⬛⬛⬛⬛⬛⬛⬛⬛⬛⬛⬛⬛⬛⬜⬜⬜⬜⬜";
	else if(hp >= 70)	sText = "⬛⬛⬛⬛⬛⬛⬛⬛⬛⬛⬛⬛⬛⬛⬜⬜⬜⬜⬜⬜";
	else if(hp >= 65)	sText = "⬛⬛⬛⬛⬛⬛⬛⬛⬛⬛⬛⬛⬛⬜⬜⬜⬜⬜⬜⬜";
	else if(hp >= 60)	sText = "⬛⬛⬛⬛⬛⬛⬛⬛⬛⬛⬛⬛⬜⬜⬜⬜⬜⬜⬜⬜";
	else if(hp >= 55)	sText = "⬛⬛⬛⬛⬛⬛⬛⬛⬛⬛⬛⬜⬜⬜⬜⬜⬜⬜⬜⬜";
	else if(hp >= 50)	sText = "⬛⬛⬛⬛⬛⬛⬛⬛⬛⬛⬜⬜⬜⬜⬜⬜⬜⬜⬜⬜";
	else if(hp >= 45)	sText = "⬛⬛⬛⬛⬛⬛⬛⬛⬛⬜⬜⬜⬜⬜⬜⬜⬜⬜⬜⬜";
	else if(hp >= 40)	sText = "⬛⬛⬛⬛⬛⬛⬛⬛⬜⬜⬜⬜⬜⬜⬜⬜⬜⬜⬜⬜";
	else if(hp >= 35)	sText = "⬛⬛⬛⬛⬛⬛⬛⬜⬜⬜⬜⬜⬜⬜⬜⬜⬜⬜⬜⬜";
	else if(hp >= 30)	sText = "⬛⬛⬛⬛⬛⬛⬜⬜⬜⬜⬜⬜⬜⬜⬜⬜⬜⬜⬜⬜";
	else if(hp >= 25)	sText = "⬛⬛⬛⬛⬛⬜⬜⬜⬜⬜⬜⬜⬜⬜⬜⬜⬜⬜⬜⬜";
	else if(hp >= 20)	sText = "⬛⬛⬛⬛⬜⬜⬜⬜⬜⬜⬜⬜⬜⬜⬜⬜⬜⬜⬜⬜";
	else if(hp >= 15)	sText = "⬛⬛⬛⬜⬜⬜⬜⬜⬜⬜⬜⬜⬜⬜⬜⬜⬜⬜⬜⬜";
	else if(hp >= 10)	sText = "⬛⬛⬜⬜⬜⬜⬜⬜⬜⬜⬜⬜⬜⬜⬜⬜⬜⬜⬜⬜";
	else if(hp >= 5)	sText = "⬛⬜⬜⬜⬜⬜⬜⬜⬜⬜⬜⬜⬜⬜⬜⬜⬜⬜⬜⬜";
	else				sText = "⬜⬜⬜⬜⬜⬜⬜⬜⬜⬜⬜⬜⬜⬜⬜⬜⬜⬜⬜⬜";

	return sText;
}

public Action UpdateHUD(Handle timer, any client)
{
	int timeboss = GetTime() - g_iVUTopRankTimer;
	if(g_bBossDestroy && timeboss > g_iVUTopRankTime)
	{
		g_bBossDestroy = false;
		PrintBossHitRanks();
	}

	for(int i = 1; i <= MaxClients; i++)
	{
		if(IsValidClient(i) && IsValidEntity(BossHudClientEnum[i].e_iEntityID))
		{
			int time = GetTime() - BossHudClientEnum[i].e_iTimer;
			if (time > g_iVUpdateTime)
			continue;

			char szType[MAX_TEXT_LENGTH];
			int HPvalue;

			GetEntityClassname(BossHudClientEnum[i].e_iEntityID, szType, sizeof(szType));

			if(StrEqual(szType, "math_counter", false))
			{
				HPvalue = RoundToNearest(GetEntDataFloat(BossHudClientEnum[i].e_iEntityID, FindDataMapInfo(BossHudClientEnum[i].e_iEntityID, "m_OutValue")));
			}
			else
			{
				HPvalue = GetEntProp(BossHudClientEnum[i].e_iEntityID, Prop_Data, "m_iHealth");
			}
			if(HPvalue <= 0 && HPvalue >= -20) HPvalue = 0;

			if(HPvalue < 0 || HPvalue >= 900000)
			{
				continue;
			}

			int HPpercent = RoundFloat(float(HPvalue)/float(BossHudClientEnum[i].e_iHPvalue_Max)*100.0);

			char sTextBar[MAX_TEXT_LENGTH];
			Format(sTextBar, sizeof(sTextBar), "%s", CreateIcon(HPpercent));

			BossHudClientEnum[i].e_iHPpercent = HPpercent;
			strcopy(BossHudClientEnum[i].e_sTextBar, MAX_TEXT_LENGTH, sTextBar);
			BossHudClientEnum[i].e_iHPvalue = HPvalue;

			SendCenterMsg(i, BossHudClientEnum[i].e_sName, BossHudClientEnum[i].e_sTextBar, BossHudClientEnum[i].e_iHPvalue, BossHudClientEnum[i].e_iHPpercent);
		}
	}
}

public Action PrintBossHitRanks()
{
	int TopOne, TopTwo, TopThree, TopFour, TopFive;
	char TopHudMessage[512];

	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && g_iTop_Rank_Dmg[i] >= g_iTop_Rank_Dmg[TopOne])
		{
			TopOne = i;
		}
	}
	for (int i = 1; i <= MaxClients; i++)
	{
		if (i != TopOne && IsClientInGame(i) && g_iTop_Rank_Dmg[i] >= g_iTop_Rank_Dmg[TopTwo])
		{		   
			TopTwo = i;
		}
	}	  
	for (int i = 1; i <= MaxClients; i++)
	{
		if (i != TopOne && i != TopTwo && IsClientInGame(i) && g_iTop_Rank_Dmg[i] >= g_iTop_Rank_Dmg[TopThree])
		{
			TopThree = i;
		}
	}
	for (int i = 1; i <= MaxClients; i++)
	{
		if (i != TopOne && i != TopTwo && i != TopThree && IsClientInGame(i) && g_iTop_Rank_Dmg[i] >= g_iTop_Rank_Dmg[TopFour])
		{
			TopFour = i;
		}
	}
	for (int i = 1; i <= MaxClients; i++)
	{
		if (i != TopOne && i != TopTwo && i != TopThree && i != TopFour && IsClientInGame(i) && g_iTop_Rank_Dmg[i] >= g_iTop_Rank_Dmg[TopFive])
		{
			TopFive = i;
		}
	}

	if(g_iTop_Rank_Dmg[TopFive]>=5)
	{ 
		char top5[512];
		Format(top5,sizeof(top5), "- Rank Top Defenders -\n1. %N - %i Dmg.\n2. %N - %i Dmg.\n3. %N - %i Dmg.\n4. %N - %i Dmg.\n5. %N - %i Dmg.", TopOne, g_iTop_Rank_Dmg[TopOne], TopTwo, g_iTop_Rank_Dmg[TopTwo], TopThree, g_iTop_Rank_Dmg[TopThree], TopFour, g_iTop_Rank_Dmg[TopFour], TopFive, g_iTop_Rank_Dmg[TopFive]);

		for (int client = 1; client <= MaxClients; client++)
		{
			if(IsValidClient(client) && BossHudClientEnum[client].e_bTopdEnable)
			{
				SetGlobalTransTarget(client);
				if (g_iTop_Rank_Dmg[client] >= 1)
				{
					Format(TopHudMessage,sizeof(TopHudMessage), "%s\n\n%t", top5, "You Points", client, g_iTop_Rank_Dmg[client]);
					SendCenterMsg(client, TopHudMessage, "", 0, 0, true);
				}
				else
				{
					Format(TopHudMessage,sizeof(TopHudMessage), "%s\n\n%t", top5, "You haven t done any damage");
					SendCenterMsg(client, TopHudMessage, "", 0, 0, true);
				}
			}
		}
	} 
	else if(g_iTop_Rank_Dmg[TopFour]>=5)
	{ 
		char top4[512];
		Format(top4,sizeof(top4), "- Rank Top Defenders -\n1. %N - %i Dmg.\n2. %N - %i Dmg.\n3. %N - %i Dmg.\n4. %N - %i Dmg.", TopOne, g_iTop_Rank_Dmg[TopOne], TopTwo, g_iTop_Rank_Dmg[TopTwo], TopThree, g_iTop_Rank_Dmg[TopThree], TopFour, g_iTop_Rank_Dmg[TopFour]);

		for (int client = 1; client <= MaxClients; client++)
		{
			if(IsValidClient(client) && BossHudClientEnum[client].e_bTopdEnable)
			{
				SetGlobalTransTarget(client);
				if (g_iTop_Rank_Dmg[client] >= 1)
				{
					Format(TopHudMessage,sizeof(TopHudMessage), "%s\n\n%t", top4, "You Points", client, g_iTop_Rank_Dmg[client]);
					SendCenterMsg(client, TopHudMessage, "", 0, 0, true);
				}
				else
				{
					Format(TopHudMessage,sizeof(TopHudMessage), "%s\n\n%t", top4, "You haven t done any damage");
					SendCenterMsg(client, TopHudMessage, "", 0, 0, true);
				}
			}
		}
	} 
	else if(g_iTop_Rank_Dmg[TopThree]>=5)
	{ 
		char top3[512];
		Format(top3,sizeof(top3), "- Rank Top Defenders -\n1. %N - %i Dmg.\n2. %N - %i Dmg.\n3. %N - %i Dmg.", TopOne, g_iTop_Rank_Dmg[TopOne], TopTwo, g_iTop_Rank_Dmg[TopTwo], TopThree, g_iTop_Rank_Dmg[TopThree]);

		for (int client = 1; client <= MaxClients; client++)
		{
			if(IsValidClient(client) && BossHudClientEnum[client].e_bTopdEnable)
			{
				SetGlobalTransTarget(client);
				if (g_iTop_Rank_Dmg[client] >= 1)
				{
					Format(TopHudMessage,sizeof(TopHudMessage), "%s\n\n%t", top3, "You Points", client, g_iTop_Rank_Dmg[client]);
					SendCenterMsg(client, TopHudMessage, "", 0, 0, true);
				}
				else
				{
					Format(TopHudMessage,sizeof(TopHudMessage), "%s\n\n%t", top3, "You haven t done any damage");
					SendCenterMsg(client, TopHudMessage, "", 0, 0, true);
				}
			}
		}
	} 
	else if(g_iTop_Rank_Dmg[TopTwo]>=5)
	{ 
		char top2[512];
		Format(top2,sizeof(top2), "- Rank Top Defenders -\n1. %N - %i Dmg.\n2. %N - %i Dmg.", TopOne, g_iTop_Rank_Dmg[TopOne], TopTwo, g_iTop_Rank_Dmg[TopTwo]);

		for (int client = 1; client <= MaxClients; client++)
		{
			if(IsValidClient(client) && BossHudClientEnum[client].e_bTopdEnable)
			{
				SetGlobalTransTarget(client);
				if (g_iTop_Rank_Dmg[client] >= 1)
				{
					Format(TopHudMessage,sizeof(TopHudMessage), "%s\n\n%t", top2, "You Points", client, g_iTop_Rank_Dmg[client]);
					SendCenterMsg(client, TopHudMessage, "", 0, 0, true);
				}
				else
				{
					Format(TopHudMessage,sizeof(TopHudMessage), "%s\n\n%t", top2, "You haven t done any damage");
					SendCenterMsg(client, TopHudMessage, "", 0, 0, true);
				}
			}
		}
	} 
	else if(g_iTop_Rank_Dmg[TopOne]>=5)
	{
		char top1[512];
		Format(top1,sizeof(top1), "- Rank Top Defenders -\n1. %N - %i Dmg.", TopOne, g_iTop_Rank_Dmg[TopOne]);

		for (int client = 1; client <= MaxClients; client++)
		{
			if(IsValidClient(client) && BossHudClientEnum[client].e_bTopdEnable)
			{
				SetGlobalTransTarget(client);
				if (g_iTop_Rank_Dmg[client] >= 1)
				{
					Format(TopHudMessage,sizeof(TopHudMessage), "%s\n\n%t", top1, "You Points", client, g_iTop_Rank_Dmg[client]);
					SendCenterMsg(client, TopHudMessage, "", 0, 0, true);
				}
				else
				{
					Format(TopHudMessage,sizeof(TopHudMessage), "%s\n\n%t", top1, "You haven t done any damage");
					SendCenterMsg(client, TopHudMessage, "", 0, 0, true);
				}
			}
		}
	}
	Top_Rank_Reset();
}

stock void SendCenterMsg(int client, const char[] szName, const char[] sTextBar, int HPvalue, int HPpercent, bool TopHud = false, any...)
{
	if (!IsValidClient(client, true, false))
	return;

	if(BossHudClientEnum[client].e_bHudType && !TopHud)
	{
		char colorh[8];
		if(HPpercent >= 66) colorh = "00FF00";
		else if(HPpercent >= 33) colorh = "ffff00";
		else colorh = "ff0000";

		PrintHintText(client, "%s HP: <font class='fontSize-xl' font color='#%s'>%d</font>\n<font color='#%s'>%s</font>", szName, colorh, HPvalue, colorh, sTextBar);
	}
	else
	{
		char topMessage[HUGE_LINE_LENGTH];
		char colorh[16];
		char hudfadin[8];
		char hudholdtime[8];

		if (TopHud)
		{
			Format(topMessage, sizeof(topMessage), "%s", szName);
			colorh = "255 255 0";
			hudfadin = "1.5";
			hudholdtime = "10.0";
		}
		else
		{
			Format(topMessage, sizeof(topMessage), "%s HP: %d \n%s", szName, HPvalue, sTextBar);
			if(HPpercent >= 66) colorh = "0 255 0";
			else if(HPpercent >= 33) colorh = "255 255 0";
			else colorh = "255 0 0";
			hudfadin = "0.1";
			hudholdtime = "3.0";
		}

		int entranktop = CreateEntityByName("game_text");
		DispatchKeyValue(entranktop, "channel", "4");
		DispatchKeyValue(entranktop, "color", colorh);
		DispatchKeyValue(entranktop, "color2", "0 0 0");
		DispatchKeyValue(entranktop, "effect", "0");
		DispatchKeyValue(entranktop, "fadein", hudfadin);
		DispatchKeyValue(entranktop, "fadeout", "0.5");
		DispatchKeyValue(entranktop, "fxtime", "0.25"); 		
		DispatchKeyValue(entranktop, "holdtime", hudholdtime);
		DispatchKeyValue(entranktop, "message", topMessage);
		DispatchKeyValue(entranktop, "spawnflags", "0"); 	
		DispatchKeyValue(entranktop, "x", g_sHudTopPosX[client]);
		DispatchKeyValue(entranktop, "y", g_sHudTopPosY[client]);
		DispatchSpawn(entranktop);
		SetVariantString("!activator");
		AcceptEntityInput(entranktop,"display",client);
	}
	return;
}

public void Top_Rank_Reset()
{
	for (int i = 1; i <= MaxClients; i++)
	{	
		g_iTop_Rank_Dmg[i] = 0;
	}
}

public Action OnClientSayCommand(int client, const char[] command, const char[] sArgs)
{
	if(!IsValidClient(client) || g_iSayingSettings[client] == 0 || g_iItemSettings[client] == 0)
	{
		return Plugin_Continue;
	}

	char Args[MAX_TEXT_LENGTH];
	Format(Args, sizeof(Args), sArgs);
	StripQuotes(Args);

	if(StrEqual(sArgs, "!cancel") || StrContains(command, "say") <= -1 || StrContains(command, "say_team") <= -1)
	{
		CPrintToChat(client, "%t", "Cancel");
		if (g_iItemSettings[client] < 3 && IsValidGenericAdmin(client)) MenuAdminBhud(client);
		if (g_iItemSettings[client] >= 3) MenuClientBhud(client);
		g_iSayingSettings[client] = 0;
		g_iItemSettings[client] = 0;
		return Plugin_Stop;
	}
	else if (g_iItemSettings[client] < 3 && IsValidGenericAdmin(client))
	{
		char sBuffer_temp[MAX_TEXT_LENGTH];
		IntToString(g_iSayingSettings[client], sBuffer_temp, sizeof(sBuffer_temp));

		if(!KvJumpToKey(g_hkvbosshpAdmin, sBuffer_temp))
		{
			CPrintToChat(client, "%t", "Invalid Entity", sBuffer_temp);
			g_iItemSettings[client] = 0;
			g_iSayingSettings[client] = 0;
			return Plugin_Stop;
		}
		else if (g_iItemSettings[client] == 1)
		{
			Format(Args, sizeof(Args), "►[%s]◄", Args);
			KvSetString(g_hkvbosshpAdmin, "m_iname", Args);
			KvRewind(g_hkvbosshpAdmin);
			KvRewind(g_hkvbosshp);
			KvCopySubkeys (g_hkvbosshpAdmin, g_hkvbosshp);
			KeyValuesToFile(g_hkvbosshpAdmin, g_sPathFileBoss);
			UpdateParametsAll();
			MenuAdminBhud(client, true, sBuffer_temp);
			g_iItemSettings[client] = 0;
			g_iSayingSettings[client] = 0;
		}
		else if (g_iItemSettings[client] == 2)
		{
			KvSetNum(g_hkvbosshpAdmin, "HPvalue_max", StringToInt(Args));
			KvRewind(g_hkvbosshpAdmin);
			KvRewind(g_hkvbosshp);
			KvCopySubkeys (g_hkvbosshpAdmin, g_hkvbosshp);
			KeyValuesToFile(g_hkvbosshpAdmin, g_sPathFileBoss);
			UpdateParametsAll();
			MenuAdminBhud(client, true, sBuffer_temp);
			g_iItemSettings[client] = 0;
			g_iSayingSettings[client] = 0;
		}
		return Plugin_Stop;
	}
	else if (g_iItemSettings[client] == 3)
	{
		BossHudClientEnum[client].e_sHudPasition = Args;
		g_iItemSettings[client] = 0;
		g_iSayingSettings[client] = 0;
		HudStringPos(client);
		SetClientCookie(client, g_hHudPasition, BossHudClientEnum[client].e_sHudPasition);
		MenuClientBhud(client);
		return Plugin_Stop;
	}
	return Plugin_Continue;
}

void UpdateParametsAll()
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsValidClient(i))
		{
			if (BossHudClientEnum[i].e_iHammerID != -1)
			{
				BossHudClientEnum[i].e_iHammerID = -1;
			}
		}
	}
}

stock bool IsValidClient(int client, bool bzrAllowBots = false, bool bzrAllowDead = true)
{
	if (!(1 <= client <= MaxClients) || !IsClientInGame(client) || (IsFakeClient(client) && !bzrAllowBots) || IsClientSourceTV(client) || IsClientReplay(client) || (!bzrAllowDead && !IsPlayerAlive(client)))
		return false;
	return true;
}

public bool IsValidGenericAdmin(int client) 
{ 
	return CheckCommandAccess(client, "generic_admin", ADMFLAG_GENERIC, false);
}