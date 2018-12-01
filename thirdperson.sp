/****************************************************************/

#include <sourcemod>

public Plugin:myinfo = 
{
	name = "Thirdperson mode",
	author = "Unknown",
	description = "<- Description ->",
	version = "1.0",
	url = "<- URL ->"
}

new thirdperson[MAXPLAYERS+1]

public OnPluginStart()
{
	RegConsoleCmd("sm_view", thirdpersonview);
}


public Action:thirdpersonview(client, args)
{
	if (!thirdperson[client])
	{
	ClientCommand(client, "thirdpersonshoulder")
	thirdperson[client] = true;
	}
	else
	{
	ClientCommand(client, "firstperson")
	thirdperson[client] = false;
	}
}

public OnClientPutInServer(client)
{
	if (client)
	CreateTimer(60.0, AnnounceView)
}

public Action:AnnounceView(Handle:timer)
{
	PrintHintTextToAll("Thirdperson Mode: Type !view in chat to change the view to third person!")
	CreateTimer(60.0, AnnounceView)
}

////////////////////////