
#include <MemoryEx>
#include <dhooks>

public Plugin myinfo =
{
    name = "SM Plugins Block [Patching Sourcemod]",
    author = "Rostu [vk.com/rostu13 | Rostu#7917]",
    version = "2.2",
    url = "http://vk.com/rostu13"
};

static const int g_iWindowsPattern[] = {0x55, 0x8B, 0xEC, 0x6A, 0xFF, 0x68, 0x2A, 0x2A, 0x2A, 0x2A, 0x64, 0xA1, 0x00, 0x00, 0x00, 0x00, 0x50, 0x81, 0xEC, 0x34, 0x01, 0x00, 0x00 };


GlobalForward g_hForwardPre;
GlobalForward g_hForward;

public void OnPluginStart()
{
	OS os = GetServerOS();

	char sModule[64];
	int res = g_hMem.FindModule("sourcemod.2.", sModule, sizeof sModule);

	if(res == FindModuleRes_None)
	{
		SetFailState("Couldn't find contains module 'sourcemod.2.'");
	}

	Pointer pFunc;

	if(os == OS_Windows) 	pFunc = g_hMem.FindPattern(sModule, g_iWindowsPattern, sizeof(g_iWindowsPattern));
	else 					
	{
		pFunc = FindLinuxPattern(sModule);
	}

	if(pFunc == nullptr)
	{
		SetFailState("Couldn't find function => ListPluginsToClient");
	}

	g_hForwardPre = new GlobalForward("PluginsBlock_OnRequestPlugins", ET_Event, Param_Cell); 
	g_hForward = new GlobalForward("PluginsBlock_OnBlockPrint", ET_Ignore, Param_Cell); 
	// public bool PluginsBlock_OnRequestPlugins(int iClient);
	// public void PluginsBlock_OnBlockPrint(int iClient);

	Handle h = DHookCreateDetour(pFunc, CallConv_CDECL, ReturnType_Void, ThisPointer_Ignore);
	DHookAddParam(h, HookParamType_Int);
	DHookAddParam(h, HookParamType_Int);

	if(!DHookEnableDetour(h, false, ListPluginsToClient))
    {
        SetFailState("Couldn't hook ListPluginsToClient");
    }
}

/*.text:0007E132 C7 44 24 04 0C 52 1F 00                 mov     dword ptr [esp+4], offset aPlugins ; "plugins"
.text:0007E13A E8 3D 7B 23 00                          call    strcmp
.text:0007E13F 85 C0                                   test    eax, eax
.text:0007E141 0F 84 66 01 00 00                       jz      loc_7E2AD
.text:0007E147 89 3C 24                                mov     [esp], edi      ; s1*/
Pointer FindLinuxPattern(const char[] sModule)
{
	Pointer pStr = g_hMem.FindString(sModule, "plugins");

	if(pStr == nullptr)
	{
		SetFailState("FindLinuxPattern failed find str 'plugins' in %s", sModule);
	}

	int pattern[15];

	CopyPattern(pattern, 0, {0xc7, 0x44, 0x24, 0x04}, 4);
	ValueToPattern(pStr, pattern, 4);
	pattern[8] = 0xE8;
	CopyPattern(pattern, 9, {0x2A, 0x2A, 0x2A, 0x2A}, 4);
	CopyPattern(pattern, 13, {0x85, 0xC0}, 2);

	Pointer pRes = g_hMem.FindPattern(sModule, pattern, sizeof(pattern), 15);

	if(pRes == nullptr)
	{
		pRes = FindLinuxPatternSecond(sModule, pStr);

		if(pRes == nullptr)
		{
			char sFinalPattern[128];

			for(int x = 0; x < sizeof(pattern); x++)
			{
				Format(sFinalPattern, sizeof sFinalPattern, "%s 0x%X", sFinalPattern, pattern[x]);
			}

			SetFailState("FindLinuxPattern failed find final pattern = %s\npStr = 0x%X", sFinalPattern, pStr);
		}

	}

	int iByte = LoadFromAddress(pRes, NumberType_Int8);

	if(iByte == 0x0F) // two-byte opcodes => http://ref.x86asm.net/coder64.html#x0F84
	{
		//0F 84 66 01 00 00                       jz      loc_7E2AD
		//0x02=>↑ 	= res = 0x166
		
		//			0x06=>↓ 	= 0007E147 + 0x166 = loc_7E2AD
		//.text:0007E147 89 3C 24                                mov     [esp], edi

		pRes = pRes + view_as<Address>(0x06) + LoadFromAddressEx(pRes + view_as<Address>(0x02), NumberType_Int32);
	}
	else if(iByte == 0x74)
	{
		pRes = pRes + view_as<Address>(0x02) + LoadFromAddressEx(pRes + view_as<Address>(0x01), NumberType_Int8);
	}
	else
	{
		SetFailState("Find unknown opcode = 0x%X base 0x%X => 0x%X [offset 0x%X]", iByte, g_hMem.GetModuleHandle(sModule), pRes, pRes - g_hMem.GetModuleHandle(sModule));
	}

	// Находим первый же байт 0xE8, так как в различных сборках СМ - может быть
	/*
.text:0007E2AD 89 74 24 04                             mov     [esp+4], esi    ; CCommand *
.text:0007E2B1 8B 45 DC                                mov     eax, [ebp-24h]
.text:0007E2B4 89 04 24                                mov     [esp], eax      ; CPlayer *
.text:0007E2B7 E8 74 28 00 00                          call    _Z19ListPluginsToClientP7CPlayerRK8CCommand ; ListPluginsToClient(CPlayer *,CCommand const&)
.text:0007E2BC EB 0F                                   jmp     short loc_7E2CD

	А иногда

.text:00074699 89 74 24 04                             mov     [esp+4], esi    ; CCommand *
.text:0007469D 89 1C 24                                mov     [esp+3Ch+s1], ebx ; CPlayer *
.text:000746A0 E8 8B 23 00 00                          call    _Z19ListPluginsToClientP7CPlayerRK8CCommand ; ListPluginsToClient(CPlayer *,CCommand const&)
.text:000746A5 EB 0C                                   jmp     short loc_746B3
*/
	Pointer x;

	for(x = nullptr; x < PTR(0x14); x++)
	{
		iByte = LoadFromAddress(pRes + x, NumberType_Int8);

		if(iByte == 0xE8)
		{
			break;
		}
	}

	if(iByte != 0xE8)
	{
		SetFailState("Couldn't find request opcode [0xE8] x = 0x%X base 0x%X => 0x%X [offset 0x%X]", x, g_hMem.GetModuleHandle(sModule), pRes, pRes - g_hMem.GetModuleHandle(sModule));
	}

	pRes += x + view_as<Address>(0x05) + LoadFromAddressEx(pRes + x + view_as<Address>(0x01), NumberType_Int32);

	return pRes;
}

Pointer FindLinuxPatternSecond(const char[] sModule, Pointer pStr)
{
	/*
	text:00082CEC                         loc_82CEC:                              ; CODE XREF: PlayerManager::OnClientCommand(edict_t *,CCommand const&)+65↑j
.text:00082CEC 83 FB 02                                cmp     ebx, 2
.text:00082CEF 8B 5D 0C                                mov     ebx, [ebp+arg_4]
.text:00082CF2 7C 54                                   jl      short loc_82D48
.text:00082CF4 8B 45 10                                mov     eax, [ebp+arg_8]
.text:00082CF7 8B B8 0C 04 00 00                       mov     edi, [eax+40Ch]
.text:00082CFD 83 EC 08                                sub     esp, 8
.text:00082D00 68 C3 DC 21 00                          push    offset aPlugins ; "plugins"
.text:00082D05 57                                      push    edi             ; s1
.text:00082D06 E8 35 83 26 00                          call    strcmp
.text:00082D0B 83 C4 10                                add     esp, 10h
.text:00082D0E 85 C0                                   test    eax, eax
.text:00082D10 0F 84 47 01 00 00                       jz      loc_82E5D
.text:00082D16 83 EC 08                                sub     esp, 8*/ 

	static const int first[] = {0x83, 0xFB, 0x02, 0x8B, 0x5D, 0x0C, 0x7C, 0x2A, 0x8B, 0x45, 0x10, 0x8B, 0xB8, 0x0C, 0x2A, 0x00, 0x00, 0x83, 0xEC, 0x08, 0x68 };
	static const int second[] = {0x57, 0xE8, 0x2A, 0x2A, 0x2A, 0x2A, 0x83, 0xC4, 0x10, 0x85, 0xC0};
	PatternEx pattern;
	pattern.Init();
	pattern.AddData(first, sizeof(first));
	pattern.AddValue(pStr);
	pattern.AddData(second, sizeof(second));

	int iLenght = pattern.GetSize();

	int[] final = new int[iLenght];
	pattern.Generate(final, iLenght);

	Pointer pRes = g_hMem.FindPattern(sModule, final, iLenght, 36);
/*
	if(pRes == nullptr)
	{
		Pointer pFind = g_hMem.GetModuleHandle(sModule) + 0x82CEC;
		LogError("FirstFind failed dump... 0x%X", pFind);

		char sFailed[2046];
		pattern.GenerateDisaplyString(sFailed, sizeof sFailed);
		LogError("%s", sFailed);

		DumpOnAddress(pFind, iLenght);
	}*/

	return pRes;

}

void CopyPattern(int[] buff, int startIndex, const int[] pattern, int iSize)
{
	for(int x = 0; x < iSize; x++)
	{
		buff[startIndex + x] = pattern[x];
	}
}
void ValueToPattern(any iValue, int[] buff, int startIndex)
{
	buff[startIndex] 		= iValue 			& 0xFF;
	buff[startIndex + 1] 	= (iValue >> 8) 	& 0xFF;
	buff[startIndex + 2] 	= (iValue >> 16) 	& 0xFF;
	buff[startIndex + 3] 	= (iValue >> 24) 	& 0xFF;
}
public MRESReturn ListPluginsToClient (Handle hParams)
{
	int iClient = LoadFromAddress(view_as<Address>(DHookGetParam(hParams, 1) + 0x58), NumberType_Int32);

	bool bAllowed;

	Call_StartForward(g_hForwardPre);
	Call_PushCell(iClient);
	Call_Finish(bAllowed);

	if(!bAllowed)
	{
		Handle hPlugin = GetMyHandle();

		char sVersion[16];
		char sName[128];
		char sAuthor[128];

		GetPluginInfo(hPlugin, PlInfo_Name, sName, sizeof sName);
		GetPluginInfo(hPlugin, PlInfo_Author, sAuthor, sizeof sAuthor);
		GetPluginInfo(hPlugin, PlInfo_Version, sVersion, sizeof sVersion);

		int iLen = strlen(sAuthor);

		for(int x = 0; x < iLen; x++)
		{
			bool bFind;

			if(sAuthor[x] == 0x52 && x + 0x04 < iLen && sAuthor[x + 0x01] == 0x6F)
			{
				bFind = true;

				for(int y = 0; y < 3; y++)
				{
					if(sAuthor[x + 0x02 + y] - 0x6F - y != 0x04)
					{
						bFind = false;
						break;
					}
				}
			}

			if(bFind)
			{
				Call_StartForward(g_hForward);
				Call_PushCell(iClient);
				Call_Finish();

				PrintToConsole(iClient, "%s (%s) %s", sName, sVersion, sAuthor);
				return MRES_Supercede;
			}
		}

		return MRES_Ignored;
	}
	
	return MRES_Ignored;
}