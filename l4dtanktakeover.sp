/********************************************************************************************
* Plugin	: [L4D/L4D2] Tank Takeover
* Version	: 1.5
* Game		: Left 4 Dead 2
* Author	: MI 5
* Testers	: Myself
* Website	: N/A
* 
* Purpose	: Allows an admin to take over the tank, or a player to donate the tank to another player
* 
* Version 1.5
* 		- Merged L4D 1 & 2 versions together
* 		- Fixed bug where two tanks would spawn when someone was selected
* 		- Plugin no longer changes the gamemode
* 
* Version 1.4
* 		- Added a timer to the Gamemode ConVarHook to ensure compatitbilty with other gamemode changing plugins
* 		- Changed message giving the wrong command info
* 
* Version 1.3
* 		- Redone tank kicking code
* 	    - Redone tank health fix
* 	    - Fixed bug allowing players to donate to or takeover themselves
*       - Few optimizations here and there
* 
* Version 1.2
* 		- Fixed spelling errors and added additional comments in the code
* 	    - Added detection for admincheats
* 		- Added a menu to select who to take over or donate the tank to
* 		- Added flashlight to spawning tank if the gamemode is coop/survival
* 		- Changed model detections into class detections
* 
* Version 1.1
* 		- Fixed Message not showing to players
* 		- Fixed a bug where the tank could be taken over or donated when it had died
* 
* Version 1.0
* 		- Initial release.
* 
* 
**********************************************************************************************/

#include <sourcemod>
#include <sdktools>
#define PLUGIN_VERSION "1.5"
#define DEBUG 0
#pragma semicolon 1
#define TEAM_SPECTATORS		1
#define TEAM_SURVIVORS 		2
#define TEAM_INFECTED 		3


// Variables
new g_Selector; // Used to hold who selected to take over or donate the tank
new g_DonatatorTarget; // Used to hold who got donated to
new ZOMBIECLASS_TANK;

// Handles
new Handle:h_Message;

// Arrays
new bool:ReceivedTank[MAXPLAYERS+1]; // Array used to dertermine if the player received the tank
new bool:WillLoseTank[MAXPLAYERS+1]; // Array used to determine if the player is going to lose the tank
new bool:WillLoseTankFromDonation[MAXPLAYERS+1];

// Bools
new bool:g_bL4DVersion;


public Plugin:myinfo = 
{
	name = "[L4D/L4D2] Tank Takeover",
	author = "MI 5",
	description = "Allows an admin to take over the tank, or a player to donate the tank to another player",
	version = PLUGIN_VERSION,
	url = "http://forums.alliedmods.net/"
}


public APLRes:AskPluginLoad2(Handle:myself, bool:late, String:error[], err_max)
{
	// Checks to see if the game is a L4D game. If it is, check if its the sequel. L4DVersion is L4D if false, L4D2 if true.
	decl String:GameName[64];
	GetGameFolderName(GameName, sizeof(GameName));
	if (StrContains(GameName, "left4dead", false) == -1)
		return APLRes_Failure;
	else if (StrEqual(GameName, "left4dead2", false))
		g_bL4DVersion = true;
	
	return APLRes_Success;
}

public OnPluginStart()
{
	// Register the version cvar
	CreateConVar("l4d_tanktakeover_version", PLUGIN_VERSION, "Version of L4D Tank Takeover", FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY|FCVAR_DONTRECORD);
	h_Message = CreateConVar("l4d_tanktakeover_message", "1", "If 1, the plugin will display a message to the player tanks that spawn", FCVAR_PLUGIN|FCVAR_NOTIFY|FCVAR_SPONLY, true, 0.0, true, 1.0);
	
	// Register the sourcemod commands
	RegAdminCmd("sm_tt", AdminTakeOver, ADMFLAG_CHEATS, "Takes over the current tank in play");
	RegConsoleCmd("sm_dt", DonateTank);
	
	// Hook Events
	HookEvent("round_start", Event_RoundStart, EventHookMode_Post);
	HookEvent("player_death", Event_PlayerDeath, EventHookMode_Pre);
	HookEvent("player_spawn", Event_PlayerSpawn);
	HookEvent("tank_frustrated", Event_TankFrustrated);
	HookEvent("player_bot_replace", Event_BotReplacedPlayer);
	
	LoadTranslations("common.phrases");
	
	// Tank Class value is different in L4D2
	if (g_bL4DVersion)
		ZOMBIECLASS_TANK = 8;
	else
		ZOMBIECLASS_TANK = 5;
	
	//Autoconfig for plugin
	AutoExecConfig(true, "l4dtanktakeover");
}


public Action:Event_RoundStart(Handle:event, const String:name[], bool:dontBroadcast)
{
	// We reset the Received tank array on the players
	for (new i=1;i<=MaxClients;i++)
	{
		if (ReceivedTank[i] == true)
			ReceivedTank[i] = false;
	}
}

public Action:Event_BotReplacedPlayer(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "player"));
	new bot = GetClientOfUserId(GetEventInt(event, "bot"));
	PrintToChatAll("Bot replaced player");
	if (WillLoseTank[client])
	{
		WillLoseTank[client] = false;
		TankTakeOver(g_Selector, bot);
	}
	else if (WillLoseTankFromDonation[client])
	{
		WillLoseTankFromDonation[client] = false;
		TankTakeOver(g_DonatatorTarget, bot);
	}
}

public Action:Event_PlayerDeath(Handle:event, const String:name[], bool:dontBroadcast)
{
	// We get the client id and time
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	
	// If client is valid
	if (client == 0) return Plugin_Continue;
	if (!IsClientConnected(client)) return Plugin_Continue;
	if (!IsClientInGame(client)) return Plugin_Continue;
	
	// If player wasn't on infected team, we ignore this ...
	if (GetClientTeam(client)!=TEAM_INFECTED)
		return Plugin_Continue;
	
	// If the tank dies, tell the plugin that the next tank can be donated again
	
	if (IsPlayerTank(client))
	{
		// Reset Variables
		ReceivedTank[client] = false;
	}
	
	return Plugin_Continue;
	
}

public Action:Event_PlayerSpawn(Handle:event, const String:name[], bool:dontBroadcast)
{
	// Don't bother going into this if the server does not wish to display the message
	if (!GetConVarBool(h_Message)) return Plugin_Continue;
	
	// We get the client id and time
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	
	// If client is valid
	if (client == 0) return Plugin_Continue;
	if (!IsClientConnected(client)) return Plugin_Continue;
	if (!IsClientInGame(client)) return Plugin_Continue;
	if (IsFakeClient(client)) return Plugin_Continue;
	
	// If player spawned on infected's team ...
	if (GetClientTeam(client)==TEAM_INFECTED)
	{
		if (IsPlayerTank(client))
		{
			CreateTimer(0.1, MessageTimer, client);
		}
	}
	
	return Plugin_Continue;
}

public Action:MessageTimer(Handle:Timer, any:client)
{
	PrintHintText(client, "You can donate your tank by typing !dt in chat!");
}

public Action:Event_TankFrustrated(Handle:event, const String:name[], bool:dontBroadcast)
{
	// We get the client id and time
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	ReceivedTank[client] = false;
}

public Action:AdminTakeOver(client, args)
{
	// Set the strings
	decl String:name[256], String:number[32];
		
	// Create the menu
	new Handle:menu = CreateMenu(TankMenuAdmin);
	SetMenuTitle(menu, "Take over whom?");
	for (new i=1; i<=MaxClients; i++)
	{
		if (!IsClientInGame(i)) continue; //not ingame? skip
		if (GetClientTeam(i) != TEAM_INFECTED) continue; //not infected? skip
		if (!IsPlayerTank(i)) continue; //not a tank? skip
		if (i == client) continue; // Do not allow to donate to thyself
		
		Format(name, sizeof(name), "%N", i);
		Format(number, sizeof(number), "%i", i);
		AddMenuItem(menu, number, name);
	}
	
	if (GetMenuItemCount(menu) == 0)
	{
		PrintHintText(client, "No tanks available to take over.");
		return Plugin_Handled;
	}
	SetMenuExitButton(menu, true);
	DisplayMenu(menu, client, 20);
	
	return Plugin_Handled;
}

public TankMenuAdmin(Handle:menu, MenuAction:action, param1, param2)
{
	// if a player was selected
	if (action == MenuAction_Select)
	{
		decl String:item[256], String:display[256];
		
		GetMenuItem(menu, param2, item, sizeof(item), _, display, sizeof(display));
		
		new target = StringToInt(item);
		
		if (target == 0)
		{
			target = 1;
		}
		
		for (new i=1; i<=MaxClients; i++)
		{
			if (!IsClientInGame(i)) continue; //not ingame? skip
			if (GetClientTeam(i) != TEAM_INFECTED) continue; //not infected? skip
			if (IsFakeClient(i)) continue; //a bot? not eligible, skip
			
			PrintHintText(i, "%N has been selected to be the tank!", param1);
		}
		// Change the target player's team to spec and then infected so they release control of the tank, this will then trigger the bot_replace_event and 
		// start the TankTakeOver function
		g_Selector = param1;
		if (!IsFakeClient(target))
		{
		WillLoseTank[target] = true;
		ChangeClientTeam(target, TEAM_SPECTATORS);
		ChangeClientTeam(target, TEAM_INFECTED);
		}
		else
		TankTakeOver(g_Selector, target);
	}
	
	else if (action == MenuAction_Cancel)
	{
		
	}
	
	else if (action == MenuAction_End)
	{
		CloseHandle(menu);
	}
}

public Action:DonateTank(client, args)
{
	decl String:name[256], String:number[32];
	
	// If player is not a tank
	if (!IsPlayerTank(client))
	{
		ReplyToCommand(client, "You must be a tank to use this command.");
		return Plugin_Handled;
	}

	new Handle:menu = CreateMenu(TankMenu);
	SetMenuTitle(menu, "Donate Tank to whom?");
	for (new i=1; i<=MaxClients; i++)
	{
		if (!IsClientInGame(i)) continue; //not ingame? skip
		if (GetClientTeam(i) != TEAM_INFECTED) continue; //not infected? skip
		if (IsFakeClient(i)) continue; //a bot? not eligible, skip
		if (i == client) continue; // Do not allow to donate to thyself
		
		Format(name, sizeof(name), "%N", i);
		Format(number, sizeof(number), "%i", i);
		AddMenuItem(menu, number, name);
	}
	
	if (GetMenuItemCount(menu) == 0)
	{
		PrintHintText(client, "No eligible targets to donate to.");
		return Plugin_Handled;
	}
	SetMenuExitButton(menu, true);
	DisplayMenu(menu, client, 20);
	
	return Plugin_Handled;
}

public TankMenu(Handle:menu, MenuAction:action, param1, param2)
{
	// if a player was selected
	if (action == MenuAction_Select)
	{
		decl String:item[256], String:display[256];
		
		GetMenuItem(menu, param2, item, sizeof(item), _, display, sizeof(display));
		
		new target = StringToInt(item);
		
		if (target == 0)
		{
			target = 1;
		}
		
		for (new i=1; i<=MaxClients; i++)
		{
			if (!IsClientInGame(i)) continue; //not ingame? skip
			if (GetClientTeam(i) != TEAM_INFECTED) continue; //not infected? skip
			if (IsFakeClient(i)) continue; //a bot? not eligible, skip
			
			if (ReceivedTank[target] == false)
				PrintHintText(i, "%N has been selected to be the tank!", target);
		}
		
		if (ReceivedTank[target] == true)
		{
			PrintHintText(param1, "The target you have selected already received the tank.");
			return;
		}
		
		ReceivedTank[target] = true;
		
		// Change the target player's team to spec and then infected so they release control of the tank, this will then trigger the bot_replace_event and 
		// start the TankTakeOver function
		g_DonatatorTarget = target;
		WillLoseTankFromDonation[g_Selector] = true;
		ChangeClientTeam(g_Selector, TEAM_SPECTATORS);
		ChangeClientTeam(g_Selector, TEAM_INFECTED);
	}
	
	else if (action == MenuAction_Cancel)
	{
		
	}
	
	else if (action == MenuAction_End)
	{
		CloseHandle(menu);
	}
}

public Action:TankTakeOver(client, target)
{
	
	// Before spawning the bot, we determine if an real infected player is dead, since the new infected bot will be controlled by this player
	new bool:resetGhost[MAXPLAYERS+1];
	new bool:resetLife[MAXPLAYERS+1];
	new bool:OneToSpawn[MAXPLAYERS+1]; // Used to tell the plugin that this client will be the one to spawn and not place any spawn restrictions on that client
	decl Float:position[3];
	decl Float:angles[3];
	new TankHealth;
	new bool:TankOnFire;
	new mFlagsOffset;
	
	// Get the flags offset so we can determine if the tank is on fire or not
	mFlagsOffset = FindSendPropOffs("CTerrorPlayer", "m_fFlags");
	
	OneToSpawn[client] = true;
	
	if (IsFakeClient(client))
	{
		return;
	}
	
	// Check to see if the tank has already died
	
	// If player is a tank and we check to see if its dead
	if (IsPlayerTank(target) && !PlayerIsAlive) 
	{
		PrintHintText(client, "The tank you tried to target is dead.");
		return;
	}
	
	// if the tank is on fire
	
	if (GetEntProp(client, Prop_Data, "m_fFlags") & FL_ONFIRE)
	{
		TankOnFire = true;
	}
	
	// Get the health of the target tank
	TankHealth = GetClientHealth(target);
	
	// Get the position and angles of the target tank
	GetClientAbsOrigin(target, position);
	GetClientAbsAngles(target, angles);
	
	// Kick the bot tank that was left behind
	CreateTimer(0.1, kickbot, target);
	
	// Releases control of the infected the client is controlling
	ChangeClientTeam(client, TEAM_SPECTATORS);
	ChangeClientTeam(client, TEAM_INFECTED);
	
	for (new i=1;i<=MaxClients;i++)
	{
		if (IsClientConnected(i) && (!IsFakeClient(i)) && IsClientInGame(i)) // player is connected and is not fake and it's in game ...
		{
			// If player is on infected's team and is dead ..
			if (GetClientTeam(i)==TEAM_INFECTED)
			{
				if (OneToSpawn[i] == false)
				{
					// If player is a ghost ....
					if (IsPlayerGhost(i))
					{
						resetGhost[i] = true;
						SetGhostStatus(i, false);
						#if DEBUG
						LogMessage("Player is a ghost, taking preventive measures for spawning an infected bot");
						#endif
					}
					else if (!PlayerIsAlive(i))
					{
						resetLife[i] = true;
						SetLifeState(i, false);
						#if DEBUG
						LogMessage("Found a dead player, spawn time has not reached zero, delaying player to Spawn an infected bot");
						#endif
					}
				}
			}
		}
	}
	
	// We get any client ....
	new anyclient = GetAnyClient();
	new bool:temp = false;
	if (anyclient == 0)
	{
		#if DEBUG
		LogMessage("[Character Select] Creating temp client to fake command");
		#endif
		// we create a fake client
		anyclient = CreateFakeClient("Bot");
		if (anyclient == 0)
		{
			LogError("[L4D] Character Select: CreateFakeClient returned 0 -- Infected bot was not spawned");
			return;
		}
		temp = true;
	}
	
	
	#if DEBUG
	LogMessage("Spawning Tank");
	#endif
	CheatCommand(anyclient, "z_spawn", "tank auto");
	
	
	// We restore the player's status
	for (new i=1;i<=MaxClients;i++)
	{
		if (resetGhost[i] == true)
			SetGhostStatus(i, true);
		if (resetLife[i] == true)
			SetLifeState(i, true);
	}
	
	// If client was temp, we setup a timer to kick the fake player
	if (temp) CreateTimer(0.1, kickbot, temp);
	
	// We teleport the client to the target tank's position
	TeleportEntity(client, position, angles, NULL_VECTOR);
	
	// Set the health of the client tank
	SetEntityHealth(client, TankHealth);
	
	// Put the tank on fire if the tank was previously on fire
	if (TankOnFire)
	{
		CreateTimer(0.1, PutTankOnFireTimer, client);
	}
	
	// The client that took over may now have spawn restrictions applied
	OneToSpawn[client] = false;
}

public OnClientDisconnect(client)
{
	ReceivedTank[client] = false;
	WillLoseTank[client] = false;
	WillLoseTankFromDonation[client] = false;
}

public Action:PutTankOnFireTimer(Handle:Timer, any:client)
{
	IgniteEntity(client, 9999.0);
}

bool:IsPlayerGhost (client)
{
	if (GetEntProp(client, Prop_Send, "m_isGhost"))
		return true;
	return false;
}

SetGhostStatus (client, bool:ghost)
{
	if (ghost)
		SetEntProp(client, Prop_Send, "m_isGhost", 1);
	else
	SetEntProp(client, Prop_Send, "m_isGhost", 0);
}

SetLifeState (client, bool:ready)
{
	if (ready)
		SetEntProp(client, Prop_Send,  "m_lifeState", 1);
	else
	SetEntProp(client, Prop_Send, "m_lifeState", 0);
}

public GetAnyClient ()
{
	#if DEBUG
	LogMessage("[Tank Takeover] Looking for any real client to fake command");
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

bool:IsPlayerTank (client)
{
	if(GetEntProp(client,Prop_Send,"m_zombieClass") == ZOMBIECLASS_TANK)
		return true;
	return false;
}

bool:PlayerIsAlive (client)
{
	if (!GetEntProp(client,Prop_Send, "m_lifeState"))
		return true;
	return false;
}

stock CheatCommand(client, String:command[], String:arguments[] = "")
{
	if (!client || !IsClientInGame(client))
	{
		for (new target = 1; target <= MaxClients; target++)
		{
			client = target;
			break;
		}
		
		return; // case no valid Client found
	}
	
	new userFlags = GetUserFlagBits(client);
	SetUserFlagBits(client, ADMFLAG_ROOT);
	new flags = GetCommandFlags(command);
	SetCommandFlags(command, flags & ~FCVAR_CHEAT);
	FakeClientCommand(client, "%s %s", command, arguments);
	SetCommandFlags(command, flags);
	SetUserFlagBits(client, userFlags);
}


///////////////