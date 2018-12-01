/********************************************************************************************
* Plugin	: Left 4 100
* Version	: 1.3
* Game		: Left 4 Dead 
* Author	: MI 5
* Testers	: Myself
* Website	: N/A
* 
* Purpose	: Provides an alternative fun gamemode!
* 
* Version 1.3
* 		- Cvars that are changed by the plugin are reset when unloaded
* 		- Added a timer to the Gamemode ConVarHook to ensure compatitbilty with other gamemode changing plugins
* 
* Version 1.2
* 	    - Few optimizations here and there
* 		- Removed default difficulty "easy" (still recommend easy difficulty for this gamemode)
* 
* Version 1.1
* 		- Church Door problem fixed
* 		- Activation cvar being set 0 in the cfg now has effect
* 		- Redone Safe room detection method
* 
* Version 1.0
* 		- Initial release.
* 
**********************************************************************************************/

#include <sourcemod>
#define DEBUG 0
#define PLUGIN_VERSION "1.3"

public Plugin:myinfo = 
{
	name = "Left 4 100",
	author = "MI 5",
	description = "Provides a new gamemode where the survivors have to race to the end while facing hordes and hordes of zombies!",
	version = PLUGIN_VERSION,
	url = "N/A"
}

// Variables

new g_GameMode;

// Handles

new Handle:g_h_Activate;
new Handle:g_h_GameMode;
new Handle:g_h_Message;

// Bools

new bool:g_b_LeavedSafeRoom; // States if the survivors have left the safe room
new bool:g_b_MessageDisplayed;

public OnPluginStart()
{
	// Hook some events
	
	HookEvent("round_start", Event_RoundStart, EventHookMode_Post);
	HookEvent("round_end", Event_RoundEnd, EventHookMode_Pre);
	HookEvent("finale_start", Event_FinaleStart);
	HookEvent("create_panic_event", Event_SurvivalStart);
	HookEvent("explain_church_door", Event_ChurchDoor);
	
	// Cvar to turn the plugin on or off
	
	// Activate cvar
	g_h_Activate = CreateConVar("l4d_100_enable", "1", "If 1, Left 4 100 is enabled", FCVAR_PLUGIN|FCVAR_NOTIFY|FCVAR_SPONLY, true, 0.0, true, 1.0);
	HookConVarChange(g_h_Activate, ConVarActivate);
	
	// Gamemode hook
	g_h_GameMode = FindConVar("mp_gamemode")
	HookConVarChange(g_h_GameMode, ConVarGameMode);
	
	// Message cvar
	g_h_Message = CreateConVar("l4d_100_messages", "1", "If 1, Left 4 100 will display messages to players", FCVAR_PLUGIN|FCVAR_NOTIFY|FCVAR_SPONLY, true, 0.0, true, 1.0);
	
	// config file
	AutoExecConfig(true, "l4d100");
	
	// We register the version cvar
	CreateConVar("l4d_100_version", PLUGIN_VERSION, "Version of Left 4 100", FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY|FCVAR_DONTRECORD);
}

public OnPluginEnd()
{
	ResetConVar(FindConVar("z_common_limit"), true, true);
	ResetConVar(FindConVar("z_mega_mob_size"), true, true);
	ResetConVar(FindConVar("z_mob_spawn_max_size"), true, true);
	ResetConVar(FindConVar("z_mob_spawn_min_size"), true, true);
	ResetConVar(FindConVar("z_mob_spawn_finale_size"), true, true);
	ResetConVar(FindConVar("z_mega_mob_spawn_max_interval"), true, true);
	ResetConVar(FindConVar("z_mega_mob_spawn_min_interval"), true, true);
	ResetConVar(FindConVar("z_spawn_mobs_behind_chance"), true, true);
	ResetConVar(FindConVar("director_no_bosses"), true, true);
	ResetConVar(FindConVar("director_no_specials"), true, true);
	ResetConVar(FindConVar("director_panic_forever"), true, true);
	ResetConVar(FindConVar("z_tank_health"), true, true);
	ResetConVar(FindConVar("tank_burn_duration_normal"), true, true);
	ResetConVar(FindConVar("tank_burn_duration_hard"), true, true);
	ResetConVar(FindConVar("tank_burn_duration_expert"), true, true);
	ResetConVar(FindConVar("z_tank_burning_lifetime"), true, true);
}

public ConVarActivate(Handle:convar, const String:oldValue[], const String:newValue[])
{
	if (GetConVarBool(g_h_Activate))
	{
		GameModeCheck()
		if (g_GameMode == 1 || g_GameMode == 2)
		{  
			
			ChangeCvars()
			
			// We search for any player client to execute the force panic event command. If there isn't any, we create a fake client instead and execute it on him.
			
			
			new anyclient = GetAnyClient();
			new bool:temp = false;
			if (anyclient == 0)
			{
				#if DEBUG
				LogMessage("[L4D 100] Creating temp client to fake command");
				#endif
				// we create a fake client
				anyclient = CreateFakeClient("Bot");
				if (anyclient == 0)
				{
					LogError("[L4D] 100: CreateFakeClient returned 0 -- Infected bot was not spawned");
					return
				}
				temp = true;
			}
			
			// Add Admin root flags so that this plugin is compatible with admincheats
			
			new admindata = GetUserFlagBits(anyclient)
			if (FindConVar("sm_admin_cheats_version") != INVALID_HANDLE)
			{
				SetUserFlagBits(anyclient, ADMFLAG_ROOT)
			}
			
			new flags = GetCommandFlags("director_force_panic_event");
			SetCommandFlags("director_force_panic_event", flags & ~FCVAR_CHEAT);
			
			// Execute the command
			
			FakeClientCommand(anyclient, "director_force_panic_event")
			
			//Put the cheat flags back on and restore the client's admin status
			
			SetCommandFlags("director_force_panic_event", flags);
			if (FindConVar("sm_admin_cheats_version") != INVALID_HANDLE)
			{
				SetUserFlagBits(anyclient, admindata)
			}
			
			
			// If client was temp, we setup a timer to kick the fake player
			if (temp) CreateTimer(0.1,kickbot,anyclient);
			
			if (!g_b_MessageDisplayed && GetConVarBool(g_h_Message))
			{
				PrintHintTextToAll("L4D 100: GET TO THE END OF THE MAP BEFORE THE HORDE OVERCOMES YOU!")
				g_b_MessageDisplayed = true;
			}
		}
		if (g_GameMode == 3)
		{
			if (!g_b_MessageDisplayed && GetConVarBool(g_h_Message))
			{
				PrintHintTextToAll("L4D 100: THE HORDE IS COMING! HOLDOUT FOR AS LONG AS YOU CAN!")
				g_b_MessageDisplayed = true;
				ChangeCvars()
			}
		}
	}
	
	if (!GetConVarBool(g_h_Activate))
	{
		ResetConVar(FindConVar("z_common_limit"), true, true);
		ResetConVar(FindConVar("z_mega_mob_size"), true, true);
		ResetConVar(FindConVar("z_mob_spawn_max_size"), true, true);
		ResetConVar(FindConVar("z_mob_spawn_min_size"), true, true);
		ResetConVar(FindConVar("z_mob_spawn_finale_size"), true, true);
		ResetConVar(FindConVar("z_mega_mob_spawn_max_interval"), true, true);
		ResetConVar(FindConVar("z_mega_mob_spawn_min_interval"), true, true);
		ResetConVar(FindConVar("z_spawn_mobs_behind_chance"), true, true);
		ResetConVar(FindConVar("director_no_bosses"), true, true);
		ResetConVar(FindConVar("director_no_specials"), true, true);
		ResetConVar(FindConVar("director_panic_forever"), true, true);
		ResetConVar(FindConVar("z_tank_health"), true, true);
		ResetConVar(FindConVar("tank_burn_duration_normal"), true, true);
		ResetConVar(FindConVar("tank_burn_duration_hard"), true, true);
		ResetConVar(FindConVar("tank_burn_duration_expert"), true, true);
		ResetConVar(FindConVar("z_tank_burning_lifetime"), true, true);
	}
}

public ConVarGameMode(Handle:convar, const String:oldValue[], const String:newValue[])
{
	CreateTimer(2.0, GameModeHookTimer)
}

public Action:GameModeHookTimer(Handle:Timer)
{
	GameModeCheck()
	if (GetConVarBool(g_h_Activate))
	{
		ChangeCvars()
	}
}

public Action:Event_RoundStart(Handle:event, const String:name[], bool:dontBroadcast)
{
	g_b_LeavedSafeRoom = false;
	g_b_MessageDisplayed = false;
	
	//Check the GameMode
	GameModeCheck()
	
	if (GetConVarBool(g_h_Activate))
	{
		ChangeCvars()
		
		if (g_GameMode == 1 || g_GameMode == 2)
		{
			CreateTimer(1.0, PlayerLeftStart);
		}
	}
}

public Action:Event_ChurchDoor(Handle:event, const String:name[], bool:dontBroadcast)
{
	#if DEBUG
	PrintToChatAll("Church Door detected")
	#endif
	SetConVarInt(FindConVar("director_panic_forever"), 0);
}

public Action:Event_RoundEnd(Handle:event, const String:name[], bool:dontBroadcast)
{
	g_b_LeavedSafeRoom = false;
}

// Checks the current GameMode

GameModeCheck()
{
	//MI 5, We determine what the gamemode is
	decl String:GameName[16];
	GetConVarString(FindConVar("mp_gamemode"), GameName, sizeof(GameName));
	if (StrEqual(GameName, "survival", false))
	{
		g_GameMode = 3;
		//CreateTimer(30.0, NoSurvival)
	}
	else if (StrEqual(GameName, "versus", false))
		g_GameMode = 2;
	else if (StrEqual(GameName, "coop", false))
		g_GameMode = 1;
	else 
	{
		g_GameMode = 0;
		CreateTimer(30.0, IncorrectGameMode)
	}
}

ChangeCvars()
{
	SetConVarInt(FindConVar("z_common_limit"), 100);
	SetConVarInt(FindConVar("z_mega_mob_size"), 100);
	SetConVarInt(FindConVar("z_mob_spawn_max_size"), 100);
	SetConVarInt(FindConVar("z_mob_spawn_min_size"), 100);
	SetConVarInt(FindConVar("z_mob_spawn_finale_size"), 100);
	SetConVarInt(FindConVar("z_mega_mob_spawn_max_interval"), 200);
	SetConVarInt(FindConVar("z_mega_mob_spawn_min_interval"), 100);
	if (g_GameMode != 3)
	{
		SetConVarInt(FindConVar("z_spawn_mobs_behind_chance"), 0);
		SetConVarInt(FindConVar("director_panic_forever"), 1);
	}
	else
	{
		SetConVarInt(FindConVar("z_spawn_mobs_behind_chance"), 50);
		SetConVarInt(FindConVar("director_panic_forever"), 0);
	}
	SetConVarInt(FindConVar("director_no_bosses"), 1);
	SetConVarInt(FindConVar("director_no_specials"), 1);
	ResetConVar(FindConVar("z_tank_health"), true, true);
	ResetConVar(FindConVar("tank_burn_duration_normal"), true, true);
	ResetConVar(FindConVar("tank_burn_duration_hard"), true, true);
	ResetConVar(FindConVar("tank_burn_duration_expert"), true, true);
	ResetConVar(FindConVar("z_tank_burning_lifetime"), true, true);
}

ChangeCvarsFinale()
{
	SetConVarInt(FindConVar("director_panic_forever"), 0);
	SetConVarInt(FindConVar("tank_burn_duration_normal"), 100);
	SetConVarInt(FindConVar("tank_burn_duration_hard"), 200);
	SetConVarInt(FindConVar("tank_burn_duration_expert"), 300);
	SetConVarInt(FindConVar("z_tank_burning_lifetime"), 300);
	if (g_GameMode != 2)
	{
		SetConVarInt(FindConVar("z_tank_health"), 50000);
	}
	else
	{
		SetConVarInt(FindConVar("z_tank_health"), 20000);
	}
}

public Action:PlayerLeftStart(Handle:Timer)
{
	if (LeftStartArea())
	{
		if (g_GameMode != 3 && GetConVarBool(g_h_Activate) && !g_b_LeavedSafeRoom)
		{  
			
			// We search for any player client to execute the force panic event command. If there isn't any, we create a fake client instead and execute it on him.
			
			
			new anyclient = GetAnyClient();
			new bool:temp = false;
			if (anyclient == 0)
			{
				#if DEBUG
				LogMessage("[L4D 100] Creating temp client to fake command");
				#endif
				// we create a fake client
				anyclient = CreateFakeClient("TempBot");
				if (anyclient == 0)
				{
					LogError("[L4D] 100: CreateFakeClient returned 0 -- TempBot was not spawned");
					return Plugin_Continue;
				}
				temp = true;
			}
			
			// Add Admin root flags so that this plugin is compatible with admincheats
			
			new admindata = GetUserFlagBits(anyclient)
			if (FindConVar("sm_admin_cheats_version") != INVALID_HANDLE)
			{
				SetUserFlagBits(anyclient, ADMFLAG_ROOT)
			}
			
			new flags = GetCommandFlags("director_force_panic_event");
			SetCommandFlags("director_force_panic_event", flags & ~FCVAR_CHEAT);
			
			// Execute the command
			
			FakeClientCommand(anyclient, "director_force_panic_event")
			
			//Put the cheat flags back on and restore the client's admin status
			
			SetCommandFlags("director_force_panic_event", flags);
			if (FindConVar("sm_admin_cheats_version") != INVALID_HANDLE)
			{
				SetUserFlagBits(anyclient, admindata)
			}
			
			
			// If client was temp, we setup a timer to kick the fake player
			if (temp) CreateTimer(0.1,kickbot,anyclient);
			
			if (!g_b_MessageDisplayed && GetConVarBool(g_h_Message))
			{
				PrintHintTextToAll("L4D 100: GET TO THE END OF THE MAP BEFORE THE HORDE OVERCOMES YOU!")
				g_b_MessageDisplayed = true;
			}
			g_b_LeavedSafeRoom = true;
		}
	}
	else
	{
		CreateTimer(1.0, PlayerLeftStart);
	}
	
	return Plugin_Continue;
}

public Action:Event_SurvivalStart(Handle:event, const String:name[], bool:dontBroadcast)
{
	if (g_GameMode == 3 && GetConVarBool(g_h_Activate))
	{  
		if (!g_b_MessageDisplayed && GetConVarBool(g_h_Message))
		{
			PrintHintTextToAll("L4D 100: THE HORDE IS COMING! HOLDOUT FOR AS LONG AS YOU CAN!")
			g_b_MessageDisplayed = true;
		}
	}
	
	return Plugin_Continue;
}

public Action:Event_FinaleStart(Handle:event, const String:name[], bool:dontBroadcast)
{
	if (GetConVarBool(g_h_Activate))
	{
		ChangeCvarsFinale()
		PrintHintTextToAll("L4D 100: THE TANK IS STRONGER THAN EVER! HOLDOUT!")
	}
}

public OnClientDisconnect(client)
{
	// If is a bot, skip this function
	if (IsFakeClient(client))
		return;
	
	if (!RealPlayersInGame(client))
	{	
		GameEnded();
	}
}

GameEnded()
{
	#if DEBUG
	LogMessage("Game ended")
	#endif
	g_b_LeavedSafeRoom = false;
}

public Action:IncorrectGameMode(Handle:Timer)
{
	if (g_GameMode == 0)
	{
		// Show this to everyone when the gamemode has been set incorrectly
		PrintToChatAll("\x04[SM] \x03L4D 100: \x03mp_gamemode \x04has been set \x03INCORRECTLY! PLUGIN WILL NOT START!")
	}
}

public GetAnyClient ()
{
	#if DEBUG
	LogMessage("[L4D 100] Looking for any real client to fake command");
	#endif
	for (new i=1;i<=MaxClients;i++)
	{
		if (IsClientConnected(i) && IsClientInGame(i) && (!IsFakeClient(i)))
		{
			return i;
		}
	}
	return 0;
}

public Action:kickbot(Handle:timer, any:value)
{
	KickThis(value);
}

KickThis (client)
{
	
	if (IsClientConnected(client) && (!IsClientInKickQueue(client)))
	{
		if (IsFakeClient(client)) KickClient(client,"Kick");
	}
}

bool:RealPlayersInGame (client)
{
	
	for (new i=1;i<=MaxClients;i++)
	{
		if (i != client)
		{
			if (IsClientConnected(i) && IsClientInGame(i) && !IsFakeClient(i))
				return true;
		}
	}
	
	return false;
}

bool:LeftStartArea()
{
	new ent = -1, maxents = GetMaxEntities();
	for (new i = MaxClients+1; i <= maxents; i++)
	{
		if (IsValidEntity(i))
		{
			decl String:netclass[64];
			GetEntityNetClass(i, netclass, sizeof(netclass));
			
			if (StrEqual(netclass, "CTerrorPlayerResource"))
			{
				ent = i;
				break;
			}
		}
	}
	
	if (ent > -1)
	{
		new offset = FindSendPropInfo("CTerrorPlayerResource", "m_hasAnySurvivorLeftSafeArea");
		if (offset > 0)
		{
			if (GetEntData(ent, offset))
			{
				if (GetEntData(ent, offset) == 1) return true;
			}
		}
	}
	return false;
}

////////////////