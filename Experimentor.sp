#include <sourcemod>
#include <sdktools>

public Plugin:myinfo = 
{
	name = "Experimentor",
	author = "MI 5",
	description = "Allows one to check and set netprops",
	version = "1.0",
	url = "<- URL ->"
}



public OnPluginStart()
{
	RegConsoleCmd("sm_excheck", ExperimentCheck);
	RegConsoleCmd("sm_exset", Experiment);
	RegConsoleCmd("sm_excheckdata", ExperimentCheckData);
	RegConsoleCmd("sm_exsetdata", ExperimentData);
	RegConsoleCmd("sm_exsetclient", ExperimentClient);
}

public Action:ExperimentCheck(client, args)
{
	if (client == 0)
		client = 1
	
	decl String:netprop[64]
	GetCmdArg(1, netprop, 64);
	new data = GetEntProp(client, Prop_Send, netprop)
	
	PrintToChatAll("%s contains value of %i", netprop, data)
}

public Action:ExperimentCheckData(client, args)
{
	if (client == 0)
		client = 1
	
	decl String:netprop[64]
	GetCmdArg(1, netprop, 64);
	new data = GetEntProp(client, Prop_Data, netprop)
	
	PrintToChatAll("%s contains value of %i", netprop, data)
}

public Action:Experiment(client, args)
{
	if (client == 0)
		client = 1
	
	decl String:netprop[64]
	decl String:value[64]
	GetCmdArg(1, netprop, 64);
	GetCmdArg(2, value, 64);
	SetEntProp(client, Prop_Send, netprop, StringToInt(value))
	new data = GetEntProp(client, Prop_Send, netprop)
	
	PrintToChatAll("%s now contains value of %i", netprop, data)
}

public Action:ExperimentClient(client, args)
{
	if (client == 0)
		client = 1
	
	decl String:clientid[64]
	decl String:netprop[64]
	decl String:value[64]
	GetCmdArg(1, clientid, 64);
	GetCmdArg(2, netprop, 64);
	GetCmdArg(3, value, 64);
	SetEntProp(StringToInt(clientid), Prop_Send, netprop, StringToInt(value))
	new data = GetEntProp(StringToInt(clientid), Prop_Send, netprop)
	
	PrintToChatAll("%N's netprop %s now contains value of %i", clientid, netprop, data)
}

public Action:ExperimentData(client, args)
{
	if (client == 0)
		client = 1
	
	decl String:netprop[64]
	decl String:value[64]
	GetCmdArg(1, netprop, 64);
	GetCmdArg(2, value, 64);
	SetEntPropFloat(client, Prop_Data, netprop, StringToFloat(value))
	new data = GetEntProp(client, Prop_Data, netprop)
	
	PrintToChatAll("%s now contains value of %f", netprop, data)
}

////////////////////////