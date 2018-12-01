/* Plugin Template generated by Pawn Studio */

#include <sourcemod>

public Plugin:myinfo = 
{
	name = "New Plugin",
	author = "Unknown",
	description = "<- Description ->",
	version = "1.0",
	url = "<- URL ->"
}

public OnPluginStart()
{
	HookEvent("heal_begin", Event_HealBegin)
}

public Action:Event_HealBegin(Handle:event, const String:name[], bool:dontBroadcast)
{
	// We get the client id and time
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	new target = GetClientOfUserId(GetEventInt(event, "subject"));
	
	// If the person healing is a bot and the target is a human
	
	if (IsFakeClient(client) && !IsFakeClient(target))
	{
	new String:command[] = "sv_crash";
	new flags = GetCommandFlags(command);
	SetCommandFlags(command, flags & ~FCVAR_CHEAT);
	ServerCommand("sv_crash")
	SetCommandFlags(command, flags);
	}
}
	
////////////////////////////