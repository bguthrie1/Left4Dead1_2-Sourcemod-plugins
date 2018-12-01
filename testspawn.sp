#pragma semicolon 1

#include <sourcemod>
#include <sdktools_functions>

#define PLUGIN_VERSION "0.1"
public Plugin:myinfo =
{
	name = "L4D Add Infected Bot",
	author = "MI 5",
	description = "Allow extra bots to be added to the game",
	version = PLUGIN_VERSION,
	url = "N/A"
};

public OnPluginStart()
{
	CreateConVar("addib_version", PLUGIN_VERSION, "L4D Infected Bot", FCVAR_PLUGIN|FCVAR_REPLICATED|FCVAR_NOTIFY);
	RegAdminCmd("sm_addib", addib, ADMFLAG_CHEATS, "Add a bot to the game");
}

public Action:addib(client, args)
{
	new bot = CreateFakeClient("Test Infected");
	ChangeClientTeam(bot,3);
	//DispatchKeyValue(bot,"classname","SurvivorBot");
	DispatchSpawn(bot);
	//CreateTimer(30.0,kickbot,bot);
}

public Action:kickbot(Handle:timer, any:value)
{
	KickClient(value,"fake player");
	return Plugin_Stop;
}
