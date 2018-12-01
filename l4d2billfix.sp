
#include <sourcemod>
#include <sdktools>

#define ZOMBIE_TIME 1.0
#define BILL_TIME 2.0
#define PLUGIN_VERSION "1.0"

/* Notes:
* Code the change for bots as well

*/ 
public Plugin:myinfo = 
{
	name = "[L4D2] Bill Fix",
	author = "MI 5",
	description = "Fixes Bill in L4D2 on L4D2 maps",
	version = PLUGIN_VERSION,
	url = "<- URL ->"
}

static g_iCommonLimit;
static bool:g_bWasBill[MAXPLAYERS+1];
static bool:g_bBillMapChange[MAXPLAYERS+1];
static Handle:g_hBillTimer;
static bool:g_bInFinale;
static bool:g_bSoundPlaying[MAXPLAYERS+1]; // Used to prevent Bill's sounds playing multiple times

public APLRes:AskPluginLoad2(Handle:myself, bool:late, String:error[], err_max) 
{
	// Plugin will not run on a local server
	if (!IsDedicatedServer())
	{
		LogError("Plugin will not run on a local server.")
		return APLRes_Failure;
	}
	
	// or running a game other than Left 4 Dead 2
	decl String:GameName[12];
	GetGameFolderName(GameName, sizeof(GameName));
	if (StrContains(GameName, "left4dead2", false) == -1)
	{
		LogError("Server is not running Left 4 Dead 2.")
		return APLRes_Failure;
	}
	
	return APLRes_Success;
}

public OnPluginStart()
{
	// Register the version cvar
	CreateConVar("l4d_billfix_version", PLUGIN_VERSION, "Version of L4D Bill Fix", FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY|FCVAR_DONTRECORD);
	RegConsoleCmd("sm_bill", SetBillCommand);
	RegConsoleCmd("sm_setbill", InitiateMenuAdmin, "Allows one to change a client to Bill.");
	
	HookEvent("map_transition", Event_GameEnded);
	HookEvent("player_first_spawn", Event_PlayerFirstSpawned);
	HookEvent("player_entered_start_area", Event_PlayerFirstSpawned);
	HookEvent("player_entered_checkpoint", Event_PlayerFirstSpawned);
	HookEvent("player_transitioned", Event_PlayerFirstSpawned);
	HookEvent("player_left_start_area", Event_PlayerFirstSpawned);
	HookEvent("player_left_checkpoint", Event_PlayerFirstSpawned);
	HookEvent("finale_start", Event_BillFinaleStart);
	HookEvent("finale_vehicle_leaving", Event_FinaleVehicleLeaving);
	HookEvent("mission_lost", Event_MissionLost);
	AddNormalSoundHook(NormalSHook:HookSound_Callback);
	
}

//////////////
////EVENTS////
//////////////

public OnMapStart()
{
	SetConVarInt(FindConVar("precache_all_survivors"), 1);
	g_iCommonLimit = GetConVarInt(FindConVar("z_common_limit")); // Plugin remembers z_common_limit value, incase a server admin changes the common limit.
	
}

public Action:Event_PlayerFirstSpawned(Handle:event, const String:name[], bool:dontBroadcast)
{
	CreateTimer(5.0, Timer_ChangeToBillAfterMapChange); // A delay is needed when the player first spawns to ensure the code is properly executed on players.
}

public Action:Timer_ChangeToBillAfterMapChange(Handle:Timer)
{
	for (new i=1;i<=MaxClients;i++)
	{
		if (!IsClientInGame(i)) continue;
		
		if (GetClientTeam(i)==2)
		{
			if (GetEntProp(i, Prop_Send, "m_survivorCharacter") == 0)
			{
				if (g_bBillMapChange[i])
				{
					g_bBillMapChange[i] = false;
					SetBill(i);
				}
			}
		}
	}
}

public Action:Event_GameEnded(Handle:event, const String:name[], bool:dontBroadcast)
{
	
	if (g_hBillTimer != INVALID_HANDLE)
	{
		KillTimer(g_hBillTimer);
		g_hBillTimer = INVALID_HANDLE;
	}
	
	for (new i=1;i<=MaxClients;i++)
	{
		if (!IsClientInGame(i)) continue;
		
		if (GetClientTeam(i)==2)
		{
			if (GetEntProp(i, Prop_Send, "m_survivorCharacter") == 4)
			{
				g_bWasBill[i] = false;
				g_bBillMapChange[i] = true;
				SetEntProp(i, Prop_Send, "m_survivorCharacter", 0)
			}
		}
	}
	
	SetConVarInt(FindConVar("z_common_limit"), g_iCommonLimit);
	g_bInFinale = false;
}

public Action:Event_BillFinaleStart(Handle:event, const String:name[], bool:dontBroadcast)
{
	// This event allows the director to fully get involved if Bill is around. Bill does not need my workaround in finales.
	
	
	if (g_hBillTimer != INVALID_HANDLE)
	{
		KillTimer(g_hBillTimer);
		g_hBillTimer = INVALID_HANDLE;
	}
	
	g_bInFinale = true;
	
	for (new client=1;client<=MaxClients;client++)
	{
		if (IsClientInGame(client))
		{
			if (GetClientTeam(client) == 2)
			{
				if (GetEntProp(client, Prop_Send, "m_survivorCharacter") == 4 || g_bWasBill[client])
				{
					g_bWasBill[client] = false;
					SetConVarInt(FindConVar("z_common_limit"), g_iCommonLimit);
					SetEntProp(client, Prop_Send, "m_survivorCharacter", 4)
				}
			}
		}
	}
}

public Action:Event_FinaleVehicleLeaving(Handle:event, const String:name[], bool:dontBroadcast)
{
	if (g_hBillTimer != INVALID_HANDLE)
	{
		KillTimer(g_hBillTimer);
		g_hBillTimer = INVALID_HANDLE;
	}
	
	for (new client=1;client<=MaxClients;client++)
	{
		if (IsClientInGame(client))
		{
			if (GetClientTeam(client) == 2)
			{
				if (GetEntProp(client, Prop_Send, "m_survivorCharacter") == 4)
				{
					SetEntProp(client, Prop_Send, "m_survivorCharacter", 0)
				}
			}
		}
	}
	g_bInFinale = false;
	SetConVarInt(FindConVar("z_common_limit"), g_iCommonLimit);
}

public Action:Event_MissionLost(Handle:event, const String:name[], bool:dontBroadcast)
{
	if (g_hBillTimer != INVALID_HANDLE)
	{
		KillTimer(g_hBillTimer);
		g_hBillTimer = INVALID_HANDLE;
	}
	
	for (new client=1;client<=MaxClients;client++)
	{
		if (!IsClientInGame(client)) continue;
		
		if (GetClientTeam(client) == 2)
		{
			
			if (GetEntProp(client, Prop_Send, "m_survivorCharacter") == 4 || g_bWasBill[client])
			{
				g_bWasBill[client] = false;
				g_bBillMapChange[client] = true;
				SetEntProp(client, Prop_Send, "m_survivorCharacter", 0)
			}
		}
	}
	
	SetConVarInt(FindConVar("z_common_limit"), g_iCommonLimit);
	
	g_bInFinale = false;
}

public Action:HookSound_Callback(Clients[64], &NumClients, String:StrSample[PLATFORM_MAX_PATH], &Entity)
{
	//to work only on tank steps, its Tank_walk
	if (StrContains(StrSample, "Gambler", false) != -1) 
	{
		if (g_bWasBill[Entity] && !g_bSoundPlaying[Entity])
		{
			g_bSoundPlaying[Entity] = true;
			StopSound(Entity, SNDCHAN_AUTO, StrSample)
			decl String:billsound[128];
			strcopy(billsound, sizeof(billsound), StrSample);
			ReplaceString(billsound, sizeof(billsound),"Gambler", "Namvet", false);
			EmitSoundToAll(billsound, Entity);
			CreateTimer(0.1, Timer_BillSound, Entity);
			return Plugin_Stop;
		}
		else if (g_bWasBill[Entity] && g_bSoundPlaying[Entity])
			return Plugin_Stop;
	}
	
	
	return Plugin_Continue;
}

public Action:Timer_BillSound(Handle:Timer, any:client)
{
	g_bSoundPlaying[client] = false;
}



public OnClientDisconnect(client)
{
	g_bWasBill[client] = false;
	g_bSoundPlaying[client] = false;
}

public Action:SetBillCommand(client, args)
{
	SetBill(client)	
}

//////////////
////WORKAROUND////
//////////////

public SetBill(client)
{
	// Invalidate the Bill timer
	g_hBillTimer = INVALID_HANDLE;
	
	SetConVarInt(FindConVar("z_common_limit"), 0);
	
	if (!IsModelPrecached("models/survivors/survivor_namvet.mdl"))		PrecacheModel("models/survivors/survivor_namvet.mdl", false);
	
	SetEntityModel(client, "models/survivors/survivor_namvet.mdl");
	SetEntProp(client, Prop_Send, "m_survivorCharacter", 4)
	
	if (g_hBillTimer == INVALID_HANDLE && !g_bInFinale)
		g_hBillTimer = CreateTimer(BILL_TIME, Timer_SpawnZombies, TIMER_FLAG_NO_MAPCHANGE);
	else
	SetConVarInt(FindConVar("z_common_limit"), g_iCommonLimit);
}

public Action:Timer_SpawnZombies(Handle:Timer)
{
	// Invalidate the Bill timer
	g_hBillTimer = INVALID_HANDLE;
	
	SetConVarInt(FindConVar("z_common_limit"), 0); // To ensure the plugin does not crash the server when changing back to Nick.
	
	for (new i=1;i<=MaxClients;i++)
	{
		if (!IsClientInGame(i)) continue;
		
		if (GetClientTeam(i)==2)
		{
			if (GetEntProp(i, Prop_Send, "m_survivorCharacter") == 4)
			{
				g_bWasBill[i] = true;
				SetEntProp(i, Prop_Send, "m_survivorCharacter", 0)
				
			}
		}
	}
	
	
	SetConVarInt(FindConVar("z_common_limit"), g_iCommonLimit);
	
	
	if (g_hBillTimer == INVALID_HANDLE)
		g_hBillTimer = CreateTimer(ZOMBIE_TIME, Timer_RestoreBill, TIMER_FLAG_NO_MAPCHANGE);
}

public Action:Timer_RestoreBill(Handle:Timer)
{
	new bool:ThereWasABill
	
	g_hBillTimer = INVALID_HANDLE;
	
	for (new i=1;i<=MaxClients;i++)
	{
		if (!IsClientInGame(i)) continue;
		
		if (GetClientTeam(i)==2)
		{
			if (g_bWasBill[i])
			{
				ThereWasABill = true;
				g_bWasBill[i] = false;
				SetConVarInt(FindConVar("z_common_limit"), 0);
				SetEntProp(i, Prop_Send, "m_survivorCharacter", 4)
			}
		}
	}
	
	if (ThereWasABill)
		if (g_hBillTimer == INVALID_HANDLE)
			g_hBillTimer = CreateTimer(BILL_TIME, Timer_SpawnZombies, TIMER_FLAG_NO_MAPCHANGE);
	}

//////////////
////MENU////
//////////////

public Action:InitiateMenuAdmin(client, args) 
{
	
	decl String:name[MAX_NAME_LENGTH], String:number[10];
	
	new Handle:menu = CreateMenu(ShowMenu2);
	SetMenuTitle(menu, "Select a client:");
	
	for (new i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i)) continue;
		if (GetClientTeam(i) != 2) continue;
		if (i == client) continue;
		
		Format(name, sizeof(name), "%N", i);
		Format(number, sizeof(number), "%i", i);
		AddMenuItem(menu, number, name);
	}
	
	
	SetMenuExitButton(menu, true);
	DisplayMenu(menu, client, MENU_TIME_FOREVER);
}

public ShowMenu2(Handle:menu, MenuAction:action, param1, param2) 
{
	switch (action) 
	{
		case MenuAction_Select: 
		{
			
			decl String:number[4]; 
			GetMenuItem(menu, param2, number, sizeof(number));
			new SelectedClient = StringToInt(number);
			if (IsFakeClient(SelectedClient))
			{
				//			decl String:name[MAX_NAME_LENGTH];
				//			Format(name, sizeof(name), "%N", SelectedClient);
				//			SetClientInfo(SelectedClient, name, "Bill");
				ServerCommand("sm_rename %N Bill", SelectedClient);
			}
			SetBill(SelectedClient);
			
			
		}
		case MenuAction_Cancel:
		{
			
		}
		case MenuAction_End: 
		{
			CloseHandle(menu);
		}
	}
}


//////////////////////////