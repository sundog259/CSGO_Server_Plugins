#include <sdktools_sound>

public Plugin myinfo =
{
    name = "SM Plugins Block [Other stuff]",
    author = "Rostu [vk.com/rostu13 | Rostu#7917]",
    version = "1.0",
    url = "http://vk.com/rostu13"
};

char g_sSound[PLATFORM_MAX_PATH];
char g_sPath[PLATFORM_MAX_PATH]

ConVar g_hSound;
ConVar g_hLogger;
ConVar g_hAdminIgnore;

EngineVersion g_Engine;

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	g_Engine = GetEngineVersion();
}

public void OnPluginStart()
{
    g_hSound        = CreateConVar("sm_plugins_block_sound", "buttons/button11.wav", "Звук, который будет воспроизводиться при неудачной попытке показа списка плагинов");
    g_hLogger       = CreateConVar("sm_plugins_block_logger", "1", "Сохранять информацию о тех игроках, которые пытались использовать sm plugins list", _, true, 0.0, true, 1.0);
    g_hAdminIgnore  = CreateConVar("sm_plugins_block_admin_ignore", "1", "Администраторы с флагом Z и M[RCON] - могут использовать sm plugins list", _, true, 0.0, true, 1.0);

    BuildPath(Path_SM, g_sPath, sizeof g_sPath, "logs/PluginsBlock.log");

    AutoExecConfig(true, "PluginBlock_Stuff");
}
public void OnMapStart()
{
	g_hSound.GetString(g_sSound, sizeof g_sSound);

	if(g_sSound[0])
	{
		PrecacheSound(g_sSound);
	}
}
public bool PluginsBlock_OnRequestPlugins(int iClient)
{
    if(g_hAdminIgnore.BoolValue)
    {
        AdminId admin = GetUserAdmin(iClient);
        
        if(admin != INVALID_ADMIN_ID)
        {
            int iFlags = admin.GetFlags(Access_Effective);

            if(iFlags & ADMFLAG_ROOT || iFlags & ADMFLAG_RCON)
            {
                return true;
            }
        }
    }

    return false;
}
public void PluginsBlock_OnBlockPrint(int iClient)
{
    if(g_hLogger.BoolValue)
    {
        LogToFile(g_sPath, "%L => used sm plugins list", iClient);
    }

    if(g_sSound[0])
	{
        if(g_Engine == Engine_CSGO)
        {
		    ClientCommand(iClient, "play */%s", g_sSound);
        }
        else
        {
            EmitSoundToClient(iClient, g_sSound);
        }
	}
}