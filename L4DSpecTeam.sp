/********************************************************************************************
* Plugin	: Spectator Team Joiner
* Version	: 1.0.1
* Game		: Left 4 Dead 
* Author	: MI 5
* Testers	: MI 5
* Website	: none
* 
*  Note: This plugin is made for LordBurny. If you are not LordBurny, you are not authorized to use this plugin without his permission.
* 
**********************************************************************************************/

#include <sourcemod>

public Plugin:myinfo = 
{
	name = "Spectator Team Joiner",
	author = "MI 5",
	description = "Allows players to join the spectator team using a command",
	version = "1.0.1",
	url = "none"
}

new Handle:h_SpecAnnounceTimer;
new SpecAnnounceTimer;

new Handle:h_SpecAnnounceLimit;
new SpecAnnounceLimit;

new SpecHasBeenAnnouncedTo[MAXPLAYERS+1];

new bool:WasSpec[MAXPLAYERS+1];

public OnPluginStart()
{
	// Sets up the sourcemod commands
	
	RegConsoleCmd("sm_sp", JoinSpectator);
	RegConsoleCmd("sm_surv", JoinSurvivors);
	RegConsoleCmd("sm_inf", JoinInfected);
	
	// Hook event at round start to set some settings
	
	HookEvent("round_start", Event_RoundStart, EventHookMode_Post);
	HookEvent("player_team", Event_PlayerTeam)
	
	// Settings the cvars
	
	h_SpecAnnounceTimer = CreateConVar("l4d_specteam_announce_timer", "30", "Time in seconds when the plugin will announce to spectators that they can join survivors or infected", FCVAR_PLUGIN|FCVAR_NOTIFY);
	SpecAnnounceTimer = GetConVarInt(h_SpecAnnounceTimer)
	
	h_SpecAnnounceLimit = CreateConVar("l4d_specteam_announce_amount", "1", "Number of times it will announce messages to spectators per map", FCVAR_PLUGIN|FCVAR_NOTIFY);
	
	// Hook the convars so you can change them in game
	
	HookConVarChange(h_SpecAnnounceTimer, ConVarSpecAnnounce)
	HookConVarChange(h_SpecAnnounceLimit, ConVarSpecLimit)
}

public ConVarSpecAnnounce(Handle:convar, const String:oldValue[], const String:newValue[])
{
	// Useful if you want to change the timer in-game
	
	SpecAnnounceTimer = GetConVarInt(h_SpecAnnounceTimer);
}

public ConVarSpecLimit(Handle:convar, const String:oldValue[], const String:newValue[])
{
	// Useful if you want to change the limit in-game
	
	SpecAnnounceLimit = GetConVarInt(h_SpecAnnounceLimit);
}


public Action:Event_RoundStart(Handle:event, const String:name[], bool:dontBroadcast)
{
	// vs_max_team_switches is set to 9999 so that there is no limit on players joining survivors
	
	SetConVarInt(FindConVar("vs_max_team_switches"), 9999);
	
	// Loop used for putting players on spectator after a round
	
	for (new i=1;i<=MaxClients;i++)
	{
		if (IsClientConnected(i) && (!IsFakeClient(i)) && IsClientInGame(i)) // player is connected and is not fake and it's in game ...
		{
			// Change player over to spec if player was spec in a previous map
			if (WasSpec[i] == true)
				ChangeClientTeam(i, 1)
		}
	}
}

public Action:Event_PlayerTeam(Handle:event, const String:name[], bool:dontBroadcast)
{
	// We get the client id and time
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	
	// If client is valid
	if (client == 0) return Plugin_Continue;
	if (!IsClientConnected(client)) return Plugin_Continue;
	if (!IsClientInGame(client)) return Plugin_Continue;
	
	// If player is a bot, we ignore this ...
	new bool:isbot = GetEventBool(event, "isbot");
	if (isbot) return Plugin_Continue;
	
	// We get some data needed ...
	new newteam = GetEventInt(event, "team");
	
	// If player's new team is spectator
	if (newteam == 1)
	{
		CreateTimer(float(SpecAnnounceTimer), AnnounceJoinTeams, client);
		SpecHasBeenAnnouncedTo[client] = SpecAnnounceLimit
		WasSpec[client] = true;
	}
	else
	{
		WasSpec[client] = false;
	}
	return Plugin_Continue;
}

public OnClientPutInServer(client)
{
	if (client && GetClientTeam(client) == 1)
	{
		CreateTimer(float(SpecAnnounceTimer), AnnounceJoinTeams, client);
		SpecHasBeenAnnouncedTo[client] = SpecAnnounceLimit
	}
}

// Allows players to join the Spectator Team

public Action:JoinSpectator(client, args)
{
	if (client)
	{
		ChangeClientTeam(client, 1);
	}
}

// Allows players to join the Infected Team

public Action:JoinInfected(client, args)
{
	if (client)
	{
		ChangeClientTeam(client, 3);
	}
}

// Allows players to join the Survivor Team

public Action:JoinSurvivors(client, args)
{
	if (client)
	{
		FakeClientCommand(client, "jointeam 2")
	}
}

public Action:AnnounceJoinTeams(Handle:timer, any:client)
{
	if (IsClientInGame(client) && !IsFakeClient(client) && GetClientTeam(client) == 1 && SpecHasBeenAnnouncedTo[client] > 0)
	{
		SpecHasBeenAnnouncedTo[client]--
		PrintToChat(client, "\x04[SM] \x03L4D SpecTeam: \x04Type \x03!inf \x04 in chat to join the infected team or type \x03!surv \x04to join the survivors!");
		if (SpecAnnounceLimit > 0)
			CreateTimer(float(SpecAnnounceTimer), AnnounceJoinTeams, client);
	}
}

////////////////////////
