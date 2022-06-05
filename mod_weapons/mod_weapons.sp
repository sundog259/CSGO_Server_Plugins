#pragma semicolon 1 
#include <PTaH> 
#include <sdktools> 

Handle hGetCCSWeaponData;

public Plugin myinfo =
{
	name = "Mod Weapons",
	author = "Phoenix - Феникс",
	version = "1.1",
	url = "http://zizt.ru/ http://hlmod.ru/"
};

public void OnPluginStart()  
{ 
	Handle hGameConf = LoadGameConfigFile("mod_weapons.gamedata");
	if(!hGameConf) SetFailState("No gamedata mod_weapons!");
	
	StartPrepSDKCall(SDKCall_Raw);
	PrepSDKCall_SetFromConf(hGameConf, SDKConf_Signature, "GetCCSWeaponDataFromDef");
	PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);
	hGetCCSWeaponData = EndPrepSDKCall();
	if(!hGetCCSWeaponData) SetFailState("Could not initialize call to GetCCSWeaponDataFromDef");
	
	delete hGameConf;
	
	
	RegAdminCmd("sm_mod_weapons_reload", reload, ADMFLAG_CONFIG); 
}

public Action reload(int iClient, int args) 
{
	OnMapStart();
}

public void OnMapStart()  
{ 
	KeyValues KV_CFG = new KeyValues("mod_weapons");
	char sBuf[128];
	BuildPath(Path_SM, sBuf, sizeof(sBuf), "configs/mod_weapons.ini");
	if(!KV_CFG.ImportFromFile(sBuf)) SetFailState("[Mod Weapons] - Файл конфигураций не найден");
	else
	{
		CEconItemDefinition ItemDef;
		Address CCSWeaponData, aBuf;
		int iBuf;
		KV_CFG.Rewind();
		KV_CFG.GotoFirstSubKey();
		do
		{
			if(KV_CFG.GetSectionName(sBuf, sizeof(sBuf)))
			{
				ItemDef = PTaH_GetItemDefinitionByName(sBuf);
				if(ItemDef && (CCSWeaponData = SDKCall(hGetCCSWeaponData, ItemDef)))
				{
					if(KV_CFG.GotoFirstSubKey(false))
					{
						do
						{
							KV_CFG.GetSectionName(sBuf, sizeof(sBuf));
							aBuf = view_as<Address>(StringToInt(sBuf));
							KV_CFG.GetString(NULL_STRING, sBuf, sizeof(sBuf));
							if(FindCharInString(sBuf, '.') == -1) iBuf = KV_CFG.GetNum(NULL_STRING);
							else iBuf = view_as<int>(KV_CFG.GetFloat(NULL_STRING));
							StoreToAddress(CCSWeaponData + aBuf, iBuf, NumberType_Int32);
						}
						while KV_CFG.GotoNextKey(false);
						KV_CFG.GoBack();
					}
				}
				else LogError("Invalid weapon name %s", sBuf);
			}
		}
		while KV_CFG.GotoNextKey();
	}
	delete KV_CFG;
}