/* 
* [L4D2] GunMenu by SwiftReal
* original plugin: TankBuster 2
* original author: teddyruxpin
*/

#include <sourcemod>
#include <sdktools>
#include <entity>

#define PLUGIN_VERSION		"1.0"
#define DELAY_EQUIPDEFIB	0.5
#define CVAR_FLAGS			FCVAR_PLUGIN|FCVAR_NOTIFY

new Handle:h_MaxGive[10]
new Handle:h_ReviveOrKit
new Handle:h_AutoDefib
new Handle:h_SpecialAmmo
new Handle:h_LaserSight
new Handle:h_InfiniteChainsaw
new Handle:timer_equipdefib

new max_give[10] //array for storing initial quota of each item
new give_quota0[MAXPLAYERS+1] //quota left (each player) for item 1
new give_quota1[MAXPLAYERS+1] //quota left (each player) for item 2
new give_quota2[MAXPLAYERS+1] //quota left (each player) for item 3
new give_quota3[MAXPLAYERS+1] //quota left (each player) for item 4
new give_quota4[MAXPLAYERS+1] //quota left (each player) for item 5
new give_quota5[MAXPLAYERS+1] //quota left (each player) for item 6
new give_quota6[MAXPLAYERS+1] //quota left (each player) for item 7
new give_quota7[MAXPLAYERS+1] //quota left (each player) for item 8
new give_quota8[MAXPLAYERS+1] //quota left (each player) for item 9
new give_quota9[MAXPLAYERS+1] //quota left (each player) for item 10

new String:g_MapName[128]
new String:g_TitleOptionZero[50]
new bool:g_bRoundEnded = false
new Float:vecLocationCheckpoint[3] = { 0.0, 0.0, 0.0 }
new Float:vecLocationStart[3] = { 0.0, 0.0, 0.0 }

public Plugin:myinfo = 
{
	name 			= "[L4D2] GunMenu",
	author 			= "SwiftReal",
	description 	= "Allows clients to get weapons and items from a gunmenu.",
	version 		= PLUGIN_VERSION,
	url 			= "N/A"
}

public OnPluginStart()
{
	// Require Left 4 Dead 2
	decl String:sGameName[50]
	GetGameFolderName(sGameName, sizeof(sGameName))
	if(!StrEqual(sGameName, "left4dead2", false))
		SetFailState("Only compatible with Left 4 Dead 2");
	
	//Gun menu cvars
	RegConsoleCmd("sm_gunmenu", ClientGunMenu, "Open up a gunmenu")
	RegConsoleCmd("sm_gm", ClientGunMenu, "Open up a gunmenu")
	
	//plugin version
	CreateConVar("gunmenu_version", PLUGIN_VERSION, "GunMenu version", CVAR_FLAGS|FCVAR_SPONLY|FCVAR_REPLICATED)
	SetConVarString(FindConVar("gunmenu_version"), PLUGIN_VERSION)
	
	//Gun menu quota cvars for each player
	h_ReviveOrKit		= CreateConVar("sm_gm_reviveorkit", "1", "Set 1st menu option to do what exactly? ( 1 = revive player  2 = give healthkit  0 = both possible )", CVAR_FLAGS, true, 0.0, true, 2.0)
	h_AutoDefib			= CreateConVar("sm_gm_defibrillator_autoequip", "1", "If 1, player will always have at least a defibrillator", CVAR_FLAGS, true, 0.0, true, 1.0)
	h_SpecialAmmo 		= CreateConVar("sm_gm_equip_specialammo", "0", "Equip each weapon with incendiary ammo, explosive ammo or neither? ( 1 = incendiary ammo  2 = explosive ammo  0 = disabled )", CVAR_FLAGS, true, 0.0, true, 2.0)
	h_LaserSight 		= CreateConVar("sm_gm_equip_lasersight", "1", "If 1, each weapon will be equiped with laser sights", CVAR_FLAGS, true, 0.0, true, 1.0)
	h_InfiniteChainsaw	= CreateConVar("sm_gm_chainsaw_infinite_ammo", "1", "If 1, each chainsaw will have infinite fuel supply", CVAR_FLAGS, true, 0.0, true, 1.0)
	h_MaxGive[0] 		= CreateConVar("sm_gm_max_reviveorkit", "1", "Quota given to each player for to selfrevive or obtain 100 health in each round ( -1 = unlimited  0 = disabled )", CVAR_FLAGS)
	h_MaxGive[1] 		= CreateConVar("sm_gm_max_sgpack", "5", "Quota given to each player for obtaining a shotgun pack in each round ( -1 = unlimited  0 = disabled )", CVAR_FLAGS)
	h_MaxGive[2] 		= CreateConVar("sm_gm_max_smgpack", "5", "Quota given to each player for obtaining an smg pack in each round ( -1 = unlimited  0 = disabled )", CVAR_FLAGS)
	h_MaxGive[3] 		= CreateConVar("sm_gm_max_riflepack", "5", "Quota given to each player for obtaining a rifle pack and melee in each round ( -1 = unlimited  0 = disabled )", CVAR_FLAGS)
	h_MaxGive[4] 		= CreateConVar("sm_gm_max_sniperpack", "5", "Quota given to each player for obtaining a sniper pack in each round ( -1 = unlimited  0 = disabled )", CVAR_FLAGS)
	h_MaxGive[5] 		= CreateConVar("sm_gm_max_magnummelee", "-1", "Quota given to each player for obtaining a magnum and melee in each round ( -1 = unlimited  0 = disabled )", CVAR_FLAGS)
	h_MaxGive[6] 		= CreateConVar("sm_gm_max_defibrillator", "10", "Quota given to each player for obtaining a defibrillator in each round ( -1 = unlimited  0 = disabled )", CVAR_FLAGS)
	h_MaxGive[7] 		= CreateConVar("sm_gm_max_fireworkcrate", "5", "Quota given to each player for obtaining a firework crate in each round ( -1 = unlimited  0 = disabled )", CVAR_FLAGS)
	h_MaxGive[8] 		= CreateConVar("sm_gm_max_propanetank", "5", "Quota given to each player for obtaining a propane tank in each round ( -1 = unlimited  0 = disabled )", CVAR_FLAGS)
	h_MaxGive[9] 		= CreateConVar("sm_gm_max_minigun", "3", "Quota given to each player for spawning a heavy machine gun in each round ( -1 = unlimited  0 = disabled )", CVAR_FLAGS)
	
	//Hook Events
	HookEvent("round_start", Event_RoundStart)
	HookEvent("round_end", Event_RoundEnd)
	HookEvent("player_incapacitated", Event_PlayerIncapacitated)
	HookEvent("weapon_drop", Event_WeaponDrop)
	HookEvent("player_ledge_grab", Event_PlayerLedgeGrab)
	
	//Precache Models
	PrecacheModel("models/v_models/v_rif_sg552.mdl", true)
	PrecacheModel("models/w_models/weapons/w_rifle_sg552.mdl", true)
	PrecacheModel("models/v_models/v_snip_awp.mdl", true)
	PrecacheModel("models/w_models/weapons/w_sniper_awp.mdl", true)
	PrecacheModel("models/v_models/v_snip_scout.mdl", true)
	PrecacheModel("models/w_models/weapons/w_sniper_scout.mdl", true)
	PrecacheModel("models/v_models/v_smg_mp5.mdl", true)
	PrecacheModel("models/w_models/weapons/w_smg_mp5.mdl", true)
	PrecacheModel("models/w_models/weapons/50cal.mdl", true)
	PrecacheModel("models/v_models/v_knife_t.mdl", true)
	PrecacheModel("models/w_models/weapons/w_knife_t.mdl", true)
	
	//Execute or create cfg
	AutoExecConfig(true, "l4d2gunmenu")	
}

public OnMapStart()
{	
	GetCurrentMap(g_MapName, sizeof(g_MapName))
	FindSafeAreas()
}

public OnMapEnd()
{
	if(timer_equipdefib != INVALID_HANDLE)
	{
		KillTimer(timer_equipdefib)
		timer_equipdefib = INVALID_HANDLE
	}
}

public FindSafeAreas()
{
	new iEntityCount = GetEntityCount()
	new String:sEdictClassname[128]
	new Float:vecLocation[3]
	
	for (new i = 0; i <= iEntityCount; i++)
	{
		if(IsValidEntity(i))
		{
			GetEdictClassname(i, sEdictClassname, sizeof(sEdictClassname))
			if(StrContains(sEdictClassname, "info_survivor_position", false) != -1)
			{
				GetEntPropVector(i, Prop_Send, "m_vecOrigin", vecLocation)
				vecLocationStart = vecLocation
				continue
			}			
			if(StrContains(sEdictClassname, "prop_door_rotating_checkpoint", false) != -1)
			{
				GetEntPropVector(i, Prop_Send, "m_vecOrigin", vecLocation)
				if(GetEntProp(i, Prop_Send, "m_bLocked") == 1)
					vecLocationStart = vecLocation
				else
				vecLocationCheckpoint = vecLocation
			}
		}
	}
	if(vecLocationCheckpoint[0] + vecLocationCheckpoint[1] + vecLocationCheckpoint[2] == 0.0)
		vecLocationCheckpoint = vecLocationStart
}

bool:AllowedToSpawnItems(client)
{
	new Float:vecPlayer[3]
	GetClientAbsOrigin(client, vecPlayer)
	
	// is player far enough from safehouse doors?
	if(GetVectorDistance(vecLocationStart, vecPlayer, false) > 700 && GetVectorDistance(vecLocationCheckpoint, vecPlayer, false) > 700)
	{
		// is player not in an elevator?
		if(GetEntProp(client, Prop_Send, "m_hElevator") == -1)
		{
			// is player far enough from the recue vehicle?
			if(StrEqual(g_MapName, "c1m4_atrium", false))
			{
				decl Float:vecVehicle1[3] = { -4787.0, -3558.0, 113.0 }
				if(GetVectorDistance(vecVehicle1, vecPlayer, false) > 400)
					return true
			}
			else if(StrEqual(g_MapName, "c2m5_concert", false))
			{
				decl Float:vecVehicle1[3] = { -3528.0, 2996.0, -21.0 }
				decl Float:vecVehicle2[3] = { -1113.0, 2637.0, 63.0 }
				if((GetVectorDistance(vecVehicle1, vecPlayer, false) > 250) && (GetVectorDistance(vecVehicle2, vecPlayer, false) > 250))
					return true
			}
			else if(StrEqual(g_MapName, "c3m4_plantation", false))
			{
				decl Float:vecVehicle1[3] = { 1664.0, 4668.0, 49.0 }
				if(GetVectorDistance(vecVehicle1, vecPlayer, false) > 400)
					return true
			}
			else if(StrEqual(g_MapName, "c4m5_milltown_escape", false))
			{
				decl Float:vecVehicle1[3] = { -7198.0, 7693.0, 189.0 }
				decl Float:vecRadio[3] = { -5836.0, 7496.0, 463.0 }
				if((GetVectorDistance(vecVehicle1, vecPlayer, false) > 400) && (GetVectorDistance(vecRadio, vecPlayer, false) > 50))
					return true
			}
			else if(StrEqual(g_MapName, "c5m5_bridge", false))
			{
				decl Float:vecVehicle1[3] = { 7368.0, 3828.0, 266.0 }
				if(GetVectorDistance(vecVehicle1, vecPlayer, false) > 400)
					return true
			}
			else if(StrEqual(g_MapName, "c6m3_port", false))
			{
				decl Float:vecVehicle1[3] = { 3.0, -2996.0, 21.0 }
				if(GetVectorDistance(vecVehicle1, vecPlayer, false) > 400)
					return true
			}
			else
			{
				return true
			}
		}
	}
	return false
}

public Event_PlayerIncapacitated(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"))
	if(!client) return
	if(IsFakeClient(client)) return
	
	if(give_quota0[client] != 0 && !g_bRoundEnded && GetConVarInt(h_ReviveOrKit) != 2)
		CreateTimer(3.0, Timer_TipReviveSelf, client, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE)
}

public Event_PlayerLedgeGrab(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"))
	if(!client) return
	if(IsFakeClient(client)) return
	
	if(give_quota0[client] != 0 && !g_bRoundEnded && GetConVarInt(h_ReviveOrKit) != 2)
		CreateTimer(3.0, Timer_TipReviveSelf, client, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE)
}

public Action:Timer_TipReviveSelf(Handle:timer, any:client)
{
	if(!IsClientConnected(client))
		return Plugin_Stop
	if(!IsClientInGame(client))
		return Plugin_Stop
	if(GetClientTeam(client)!=2)
		return Plugin_Stop
	
	if((IsPlayerIncapacitated(client) || IsPlayerGrabbingLedge(client)) && IsAlive(client))
	{
		if(IsLeft4Dead(client))
			PrintHintText(client, "You are left 4 dead. Type !gm to revive yourself.")
	}
	else
	{
		return Plugin_Stop
	}
	
	return Plugin_Continue
}

stock bool:IsPlayerIncapacitated(client)
{
	if(!GetEntProp(client, Prop_Send, "m_isIncapacitated"))
		return false
	
	return true
}

stock bool:IsPlayerGrabbingLedge(client)
{
	if(!GetEntProp(client, Prop_Send, "m_isHangingFromLedge"))
		return false
	
	return true
}

stock bool:IsAlive(client)
{
	if(!GetEntProp(client, Prop_Send, "m_lifeState"))
		return true
	
	return false
}

stock bool:IsLeft4Dead(client)
{
	new Float:flClientOrigin[3]
	GetClientAbsOrigin(client, flClientOrigin)
	
	for(new i = 1; i <= MaxClients; i++)
	{
		if(IsClientConnected(i))
		{
			if(IsClientInGame(i))
			{
				if(GetClientTeam(i)==2 && !IsFakeClient(i) && !IsPlayerIncapacitated(i) && !IsPlayerGrabbingLedge(i) && IsAlive(i))
				{
					decl Float:flReviverOrigin[3]
					GetClientAbsOrigin(i, flReviverOrigin)
					
					if(GetVectorDistance(flClientOrigin , flReviverOrigin, false) < 800)
						return false
				}
			}
		}
	}
	return true
}

public Event_WeaponDrop(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"))
	
	if(client == 0)
		return	
	if(GetClientTeam(client) != 2)
		return
	if(!IsAlive(client))
		return
	
	new weaponId = GetEventInt(event, "propid")	
	if(!IsValidEntity(weaponId) || weaponId == 0)
		return
	
	decl String:weaponClassname[100]
	GetEdictClassname(weaponId, weaponClassname, sizeof(weaponClassname))
	
	/**
	* no: 	gnome,cola_bottles,fireworkcrate,gascan,propanetank,oxygentank,first_aid_kit,adrenaline,pain_pills,weapon_grenade_launcher,melee,vomitjar,molotov,
	* 		give pipe_bomb,incendiary_ammo,explosive_ammo
	* yes:	pistol,pistol_magnum,autoshotgun,shotgun_chrome,pumpshotgun,shotgun_spas,smg,smg_silenced,smg_mp5,rifle_sg552,rifle_ak47,rifle,rifle_desert,
	* 		hunting_rifle,sniper_military,chainsaw,frying_pan,electric_guitar,katana,machete,tonfa,cricket_bat,crowbar,fireaxe,baseball_bat,knife,defibrillator
	**/
	
	if(
	StrEqual(weaponClassname, "weapon_pistol") ||
	StrEqual(weaponClassname, "weapon_pistol_magnum") ||
	StrEqual(weaponClassname, "weapon_autoshotgun") ||
	StrEqual(weaponClassname, "weapon_shotgun_chrome") ||
	StrEqual(weaponClassname, "weapon_pumpshotgun") ||
	StrEqual(weaponClassname, "weapon_shotgun_spas") ||
	StrEqual(weaponClassname, "weapon_smg") ||
	StrEqual(weaponClassname, "weapon_smg_silenced") ||
	StrEqual(weaponClassname, "weapon_smg_mp5") ||
	StrEqual(weaponClassname, "weapon_rifle_sg552") ||
	StrEqual(weaponClassname, "weapon_rifle_ak47") ||
	StrEqual(weaponClassname, "weapon_rifle") ||
	StrEqual(weaponClassname, "weapon_rifle_desert") ||
	StrEqual(weaponClassname, "weapon_hunting_rifle") ||
	StrEqual(weaponClassname, "weapon_sniper_military") ||
	StrEqual(weaponClassname, "weapon_chainsaw") ||
	StrEqual(weaponClassname, "weapon_melee")
	)
	{
		CreateTimer(20.0, Timer_KillWeapon, weaponId)
	}
	
	if(StrEqual(weaponClassname, "weapon_defibrillator"))
	{
		CreateTimer(5.0, Timer_KillWeapon, weaponId)
	}
}

public Action:Timer_KillWeapon(Handle:timer, any:weaponId)
{
	if(!IsValidEntity(weaponId) || weaponId == 0)
		return Plugin_Handled
	
	decl String:weaponClassname[100]
	GetEdictClassname(weaponId, weaponClassname, sizeof(weaponClassname))
	
	if(
	StrEqual(weaponClassname, "weapon_pistol") ||
	StrEqual(weaponClassname, "weapon_pistol_magnum") ||
	StrEqual(weaponClassname, "weapon_autoshotgun") ||
	StrEqual(weaponClassname, "weapon_shotgun_chrome") ||
	StrEqual(weaponClassname, "weapon_pumpshotgun") ||
	StrEqual(weaponClassname, "weapon_shotgun_spas") ||
	StrEqual(weaponClassname, "weapon_smg") ||
	StrEqual(weaponClassname, "weapon_smg_silenced") ||
	StrEqual(weaponClassname, "weapon_smg_mp5") ||
	StrEqual(weaponClassname, "weapon_rifle_sg552") ||
	StrEqual(weaponClassname, "weapon_rifle_ak47") ||
	StrEqual(weaponClassname, "weapon_rifle") ||
	StrEqual(weaponClassname, "weapon_rifle_desert") ||
	StrEqual(weaponClassname, "weapon_hunting_rifle") ||
	StrEqual(weaponClassname, "weapon_sniper_military") ||
	StrEqual(weaponClassname, "weapon_chainsaw") ||
	StrEqual(weaponClassname, "weapon_melee") ||
	StrEqual(weaponClassname, "weapon_defibrillator")
	)
	{
		if(GetEntProp(weaponId, Prop_Send, "m_hOwner") == -1)
			AcceptEntityInput(weaponId, "Kill")
	}	
	return Plugin_Handled
}

public Event_RoundStart(Handle:event, const String:name[], bool:dontBroadcast)
{ 
	g_bRoundEnded = false
	
	//Get inital quotas from cvars
	max_give[0] = GetConVarInt(h_MaxGive[0])
	max_give[1] = GetConVarInt(h_MaxGive[1])
	max_give[2] = GetConVarInt(h_MaxGive[2])
	max_give[3] = GetConVarInt(h_MaxGive[3])
	max_give[4] = GetConVarInt(h_MaxGive[4])
	max_give[5] = GetConVarInt(h_MaxGive[5])
	max_give[6] = GetConVarInt(h_MaxGive[6])
	max_give[7] = GetConVarInt(h_MaxGive[7])
	max_give[8] = GetConVarInt(h_MaxGive[8])
	max_give[9] = GetConVarInt(h_MaxGive[9])
	
	//Sets inital quotas for every player
	for (new client = 1; client <= MaxClients; client++)
	{
		give_quota0[client] = max_give[0]
		give_quota1[client] = max_give[1]
		give_quota2[client] = max_give[2]
		give_quota3[client] = max_give[3]
		give_quota4[client] = max_give[4]
		give_quota5[client] = max_give[5]
		give_quota6[client] = max_give[6]
		give_quota7[client] = max_give[7]
		give_quota8[client] = max_give[8]
		give_quota9[client] = max_give[9]
	}
	
	if(GetConVarBool(h_AutoDefib))
	{
		if(timer_equipdefib == INVALID_HANDLE)
			timer_equipdefib = CreateTimer(DELAY_EQUIPDEFIB, Timer_EquipDefib, _, TIMER_REPEAT)
	}
}

public Action:Timer_EquipDefib(Handle:timer)
{
	for (new client = 1; client <= MaxClients; client++)
	{
		if(IsClientConnected(client))
		{
			if(IsClientInGame(client))
			{	
				if(!IsFakeClient(client) && GetClientTeam(client) == 2 && IsAlive(client) && !IsPlayerIncapacitated(client) && AllowedToSpawnItems(client))
				{
					if(!IsValidEdict(GetPlayerWeaponSlot(client, 3)))
						BypassAndExecuteCommand(client, "give", "defibrillator")
				}
			}	
		}			
	}	
	return Plugin_Continue
}

BypassAndExecuteCommand(client, String: strCommand[], String: strParam1[])
{
	new flags = GetCommandFlags(strCommand)
	SetCommandFlags(strCommand, flags & ~FCVAR_CHEAT)
	FakeClientCommand(client, "%s %s", strCommand, strParam1)
	SetCommandFlags(strCommand, flags)
}

stock SetEntityTempHealth(client, hp)
{
	SetEntPropFloat(client, Prop_Send, "m_healthBufferTime", GetGameTime())
	new Float:newOverheal = hp * 1.0; // prevent tag mismatch
	SetEntPropFloat(client, Prop_Send, "m_healthBuffer", newOverheal)
}

public Event_RoundEnd(Handle:event, const String:name[], bool:dontBroadcast)
{ 
	g_bRoundEnded = true
}

public OnClientPutInServer(client)
{
	//Get inital quotas from cvars
	max_give[0] = GetConVarInt(h_MaxGive[0])
	max_give[1] = GetConVarInt(h_MaxGive[1])
	max_give[2] = GetConVarInt(h_MaxGive[2])
	max_give[3] = GetConVarInt(h_MaxGive[3])
	max_give[4] = GetConVarInt(h_MaxGive[4])
	max_give[5] = GetConVarInt(h_MaxGive[5])
	max_give[6] = GetConVarInt(h_MaxGive[6])
	max_give[7] = GetConVarInt(h_MaxGive[7])
	max_give[8] = GetConVarInt(h_MaxGive[8])
	max_give[9] = GetConVarInt(h_MaxGive[9])
	
	//Sets inital quotas for the player just joined   
	give_quota0[client] = max_give[0]
	give_quota1[client] = max_give[1]
	give_quota2[client] = max_give[2]
	give_quota3[client] = max_give[3]
	give_quota4[client] = max_give[4]
	give_quota5[client] = max_give[5]
	give_quota6[client] = max_give[6]
	give_quota7[client] = max_give[7]
	give_quota8[client] = max_give[8]
	give_quota9[client] = max_give[9]
}

public Action:ClientGunMenu(client, args)
{
	if(g_bRoundEnded)
	{
		PrintToChat(client, "\x01[\x04GunMenu\x01] Round ended. No access.")
		return Plugin_Handled
	}
	
	if(IsAlive(client) && GetClientTeam(client) == 2)
	{
		GunMenu(client)
		
		decl String:PlayerName[128]
		GetClientName(client, PlayerName, sizeof(PlayerName))
		PrintToChat(client, "\x01[\x04GunMenu\x01] %s, you can also rapidly press reload twice to open the gunmenu", PlayerName)
	}
	
	return Plugin_Handled
}

public Action:GunMenu(client)
{
	new iReviveOrKit = GetConVarInt(h_ReviveOrKit)
	switch (iReviveOrKit)
	{
		case 0:
		{
			g_TitleOptionZero = "Revive or Healthkit"
		}
		case 1:
		{
			g_TitleOptionZero = "Revive Self"
		}
		case 2:
		{
			g_TitleOptionZero = "Healthkit"
		}
	}	
	
	new Handle:menu = CreateMenu(GunMenuHandler)
	SetMenuTitle(menu, "GunMenu Options")
	AddMenuItem(menu, "option0", g_TitleOptionZero)
	AddMenuItem(menu, "option1", "Shotgun Pack")
	AddMenuItem(menu, "option2", "Smg Pack")
	AddMenuItem(menu, "option3", "Rifle Pack")
	AddMenuItem(menu, "option4", "Sniper Pack")
	AddMenuItem(menu, "option5", "Melee")
	AddMenuItem(menu, "option6", "Defibrillator")
	AddMenuItem(menu, "option7", "Firework Crate")
	AddMenuItem(menu, "option8", "Propane Tank")
	AddMenuItem(menu, "option9", "Spawn Machine Gun")
	SetMenuExitButton(menu, true)
	DisplayMenu(menu, client, 6)
	//DisplayMenu(menu, client, MENU_TIME_FOREVER)
	//return Plugin_Handled
}

public GunMenuHandler(Handle:menu, MenuAction:action, client, itemNum)
{
	//Strip the CHEAT flag off of the "give" command
	new giveFlags = GetCommandFlags("give")
	SetCommandFlags("give", giveFlags & ~FCVAR_CHEAT)
	
	//Strip the CHEAT flag off of the "upgrade_add" command
	new upgradeFlags = GetCommandFlags("upgrade_add")
	SetCommandFlags("upgrade_add", upgradeFlags & ~FCVAR_CHEAT)
	
	new iReviveOrKit = GetConVarInt(h_ReviveOrKit)
	new iSpecialAmmoType = GetConVarInt(h_SpecialAmmo)
	new bool:bLaserSight = GetConVarBool(h_LaserSight)
	
	if(action == MenuAction_Select)
	{
		switch (itemNum)
		{
			case 0: // Revive or Healthkit or both
			{
				if( (give_quota0[client] > 0 || give_quota0[client] < 0) && IsAlive(client) && !g_bRoundEnded )
				{
					if((IsPlayerIncapacitated(client) || IsPlayerGrabbingLedge(client)) && iReviveOrKit <= 1)
					{
						if(!IsLeft4Dead(client))
						{
							PrintToChat(client, "\x01[\x04GunMenu\x01] You can only revive yourself when left 4 dead!", g_TitleOptionZero)
						}
						else
						{
							FakeClientCommand(client, "give health")
							decl String:GameMode[30]
							GetConVarString(FindConVar("mp_gamemode"), GameMode, sizeof(GameMode))
							
							if(StrEqual(GameMode, "mutation3", false))
							{
								SetEntityHealth(client, 1)
								SetEntityTempHealth(client, 99)
							}
							else
							{
								new survivor_revive_health = GetConVarInt(FindConVar("survivor_revive_health"))
								SetEntityHealth(client, survivor_revive_health)
								SetEntityTempHealth(client, 0)
							}
							//Decrease remaining quota of that player by 1
							give_quota0[client]--
						}
					}
					else if(!IsPlayerIncapacitated(client) && !IsPlayerGrabbingLedge(client) && (iReviveOrKit == 0 || iReviveOrKit == 2))
					{
						FakeClientCommand(client, "give first_aid_kit")
						
						//Decrease remaining quota of that player by 1
						give_quota0[client]--
					}
					else if(IsPlayerIncapacitated(client) && iReviveOrKit == 2)
					{
						PrintToChat(client, "\x01[\x04GunMenu\x01] You can not obtain a healthkit when incapacitated", g_TitleOptionZero)
					}
					else if(!IsPlayerIncapacitated(client) && iReviveOrKit == 1)
					{
						PrintToChat(client, "\x01[\x04GunMenu\x01] You can only be revived when incapacitated", g_TitleOptionZero)
					}
					
					//Notify remaining quota
					if(give_quota0[client] >= 0)
						PrintToChat(client, "\x01[\x04GunMenu\x01] \x04%s\x01: %dx left this round", g_TitleOptionZero, give_quota0[client])
				}
				else
				{
					if(g_bRoundEnded)
					{
						PrintToChat(client, "\x01[\x04GunMenu\x01] Round ended. No access.")
					}
					else
					{
						//No more quota left
						PrintToChat(client, "\x01[\x04GunMenu\x01] \x04%s\x01: None available", g_TitleOptionZero)
					}
				}
			}
			case 1: // Shotgun Pack
			{
				if(StrEqual(g_MapName, "c1m1_hotel", false))
				{
					PrintToChat(client, "\x01[\x04GunMenu\x01] \x04Shotgun Packs\x01: Not available this round")
				}
				else
				{
					if( (give_quota1[client] > 0 || give_quota1[client] < 0 || GetUserFlagBits(client) != 0) && IsAlive(client) && !IsPlayerIncapacitated(client) && !g_bRoundEnded )
					{
						//Give the player a Shotgun Pack
						
						//Give Auto Shotgun
						FakeClientCommand(client, "give autoshotgun")
						
						if(iSpecialAmmoType == 1)
							FakeClientCommand(client, "upgrade_add incendiary_ammo")
						else if(iSpecialAmmoType == 2)
							FakeClientCommand(client, "upgrade_add explosive_ammo")
						
						if(bLaserSight)
							FakeClientCommand(client, "upgrade_add laser_sight")
						
						FakeClientCommand(client, "give ammo")
						
						//Give Shotgun Spas
						FakeClientCommand(client, "give shotgun_spas")
						
						if(iSpecialAmmoType == 1)
							FakeClientCommand(client, "upgrade_add incendiary_ammo")
						else if(iSpecialAmmoType == 2)
							FakeClientCommand(client, "upgrade_add explosive_ammo")
						
						if(bLaserSight)
							FakeClientCommand(client, "upgrade_add laser_sight")
						
						FakeClientCommand(client, "give ammo")
						
						//Give Pump Shotgun
						FakeClientCommand(client, "give pumpshotgun")
						
						if(iSpecialAmmoType == 1)
							FakeClientCommand(client, "upgrade_add incendiary_ammo")
						else if(iSpecialAmmoType == 2)
							FakeClientCommand(client, "upgrade_add explosive_ammo")
						
						if(bLaserSight)
							FakeClientCommand(client, "upgrade_add laser_sight")
						
						FakeClientCommand(client, "give ammo")
						
						//Give Shotgun Chrome
						FakeClientCommand(client, "give shotgun_chrome")
						
						if(iSpecialAmmoType == 1)
							FakeClientCommand(client, "upgrade_add incendiary_ammo")
						else if(iSpecialAmmoType == 2)
							FakeClientCommand(client, "upgrade_add explosive_ammo")
						
						if(bLaserSight)
							FakeClientCommand(client, "upgrade_add laser_sight")
						
						FakeClientCommand(client, "give ammo")
						
						//Decrease remaining quota of that player by 1
						if(GetUserFlagBits(client) == 0)
							give_quota1[client]--
						
						//Notify remaining quota
						if(give_quota1[client] >= 0 && GetUserFlagBits(client) == 0)
							PrintToChat(client, "\x01[\x04GunMenu\x01] \x04Shotgun Packs\x01: %dx left this round",give_quota1[client])
					}
					else
					{
						if(g_bRoundEnded)
						{
							PrintToChat(client, "\x01[\x04GunMenu\x01] Round ended. No access.")
						}
						else if(IsPlayerIncapacitated(client))
						{
							PrintToChat(client, "\x01[\x04GunMenu\x01] You're incapacitated. No access.")
						}
						else
						{
							//No more quota left
							PrintToChat(client, "\x01[\x04GunMenu\x01] \x04Shotgun Packs\x01: None available")
						}
					}
				}
			}
			case 2: // SMG Pack
			{
				if(StrEqual(g_MapName, "c1m1_hotel", false))
				{
					PrintToChat(client, "\x01[\x04GunMenu\x01] \x04SMG Packs\x01: Not available this round")
				}
				else
				{
					if( (give_quota2[client] > 0 || give_quota2[client] < 0 || GetUserFlagBits(client) != 0) && IsAlive(client) && !IsPlayerIncapacitated(client) && !g_bRoundEnded )
					{
						//Give the player an SMG Pack
						
						//Give SMG MP5
						FakeClientCommand(client, "give smg_mp5")
						
						if(iSpecialAmmoType == 1)
							FakeClientCommand(client, "upgrade_add incendiary_ammo")
						else if(iSpecialAmmoType == 2)
							FakeClientCommand(client, "upgrade_add explosive_ammo")
						
						if(bLaserSight)
							FakeClientCommand(client, "upgrade_add laser_sight")
						
						FakeClientCommand(client, "give ammo")
						
						//Give SMG
						FakeClientCommand(client, "give smg")
						
						if(iSpecialAmmoType == 1)
							FakeClientCommand(client, "upgrade_add incendiary_ammo")
						else if(iSpecialAmmoType == 2)
							FakeClientCommand(client, "upgrade_add explosive_ammo")
						
						if(bLaserSight)
							FakeClientCommand(client, "upgrade_add laser_sight")
						
						FakeClientCommand(client, "give ammo")
						
						//Give SMG Silenced
						FakeClientCommand(client, "give smg_silenced")
						
						if(iSpecialAmmoType == 1)
							FakeClientCommand(client, "upgrade_add incendiary_ammo")
						else if(iSpecialAmmoType == 2)
							FakeClientCommand(client, "upgrade_add explosive_ammo")
						
						if(bLaserSight)
							FakeClientCommand(client, "upgrade_add laser_sight")
						
						FakeClientCommand(client, "give ammo")
						
						//Decrease remaining quota of that player by 1
						if(GetUserFlagBits(client) == 0)
							give_quota2[client]--
						
						//Notify remaining quota
						if(give_quota2[client] >= 0 && GetUserFlagBits(client) == 0)
							PrintToChat(client, "\x01[\x04GunMenu\x01] \x04SMG Packs\x01: %dx left this round",give_quota2[client])
					}
					else
					{
						if(g_bRoundEnded)
						{
							PrintToChat(client, "\x01[\x04GunMenu\x01] Round ended. No access.")
						}
						else if(IsPlayerIncapacitated(client))
						{
							PrintToChat(client, "\x01[\x04GunMenu\x01] You're incapacitated. No access.")
						}
						else
						{
							//No more quota left
							PrintToChat(client, "\x01[\x04GunMenu\x01] \x04SMG Packs\x01: None available")
						}
					}
				}
			}
			case 3: // Rifle Pack
			{
				if(StrEqual(g_MapName, "c1m1_hotel", false))
				{
					PrintToChat(client, "\x01[\x04GunMenu\x01] \x04Rifle Packs\x01: Not available this round")
				}
				else
				{
					if( (give_quota3[client] >= 0 || give_quota3[client] < 0 || GetUserFlagBits(client) != 0) && IsAlive(client) && !IsPlayerIncapacitated(client) && !g_bRoundEnded )
					{
						//Give the player a Rifle Pack
						
						//Give Rifle AK47
						FakeClientCommand(client, "give rifle_ak47")
						
						if(iSpecialAmmoType == 1)
							FakeClientCommand(client, "upgrade_add incendiary_ammo")
						else if(iSpecialAmmoType == 2)
							FakeClientCommand(client, "upgrade_add explosive_ammo")
						
						if(bLaserSight)
							FakeClientCommand(client, "upgrade_add laser_sight")
						
						FakeClientCommand(client, "give ammo")
						
						//Give Rifle (colt m4a1)
						FakeClientCommand(client, "give rifle")
						
						if(iSpecialAmmoType == 1)
							FakeClientCommand(client, "upgrade_add incendiary_ammo")
						else if(iSpecialAmmoType == 2)
							FakeClientCommand(client, "upgrade_add explosive_ammo")
						
						if(bLaserSight)
							FakeClientCommand(client, "upgrade_add laser_sight")
						
						FakeClientCommand(client, "give ammo")
						
						//Give Rifle SG552
						FakeClientCommand(client, "give rifle_sg552")
						
						if(iSpecialAmmoType == 1)
							FakeClientCommand(client, "upgrade_add incendiary_ammo")
						else if(iSpecialAmmoType == 2)
							FakeClientCommand(client, "upgrade_add explosive_ammo")
						
						if(bLaserSight)
							FakeClientCommand(client, "upgrade_add laser_sight")
						
						FakeClientCommand(client, "give ammo")
						
						//Give Rifle Desert
						FakeClientCommand(client, "give rifle_desert")
						
						if(iSpecialAmmoType == 1)
							FakeClientCommand(client, "upgrade_add incendiary_ammo")
						else if(iSpecialAmmoType == 2)
							FakeClientCommand(client, "upgrade_add explosive_ammo")
						
						if(bLaserSight)
							FakeClientCommand(client, "upgrade_add laser_sight")
						
						FakeClientCommand(client, "give ammo")
						
						//Decrease remaining quota of that player by 1
						if(GetUserFlagBits(client) == 0)
							give_quota3[client]--
						
						//Notify remaining quota
						if(give_quota3[client] >= 0 && GetUserFlagBits(client) == 0)
							PrintToChat(client, "\x01[\x04GunMenu\x01] \x04Rifle Packs\x01: %dx left this round",give_quota3[client])
					}
					else
					{
						if(g_bRoundEnded)
						{
							PrintToChat(client, "\x01[\x04GunMenu\x01] Round ended. No access.")
						}
						else if(IsPlayerIncapacitated(client))
						{
							PrintToChat(client, "\x01[\x04GunMenu\x01] You're incapacitated. No access.")
						}
						else
						{
							//No more quota left
							PrintToChat(client, "\x01[\x04GunMenu\x01] x04Rifle Packs\x01: None available")
						}
					}
				}
			}
			case 4: // Sniper Pack
			{
				if(StrEqual(g_MapName, "c1m1_hotel", false))
				{
					PrintToChat(client, "\x01[\x04GunMenu\x01] \x04Sniper Packs\x01: Not available this round")
				}
				else
				{
					if( (give_quota4[client] >= 0 || give_quota4[client] < 0 || GetUserFlagBits(client) != 0) && IsAlive(client) && !IsPlayerIncapacitated(client) && !g_bRoundEnded )
					{
						//Give the player a Sniper Pack
						
						//Give Sniper AWP
						FakeClientCommand(client, "give sniper_awp")
						
						if(iSpecialAmmoType == 1)
							FakeClientCommand(client, "upgrade_add incendiary_ammo")
						else if(iSpecialAmmoType == 2)
							FakeClientCommand(client, "upgrade_add explosive_ammo")
						
						if(bLaserSight)
							FakeClientCommand(client, "upgrade_add laser_sight")
						
						FakeClientCommand(client, "give ammo")
						
						//Give Sniper Military
						FakeClientCommand(client, "give sniper_military")
						
						if(iSpecialAmmoType == 1)
							FakeClientCommand(client, "upgrade_add incendiary_ammo")
						else if(iSpecialAmmoType == 2)
							FakeClientCommand(client, "upgrade_add explosive_ammo")
						
						if(bLaserSight)
							FakeClientCommand(client, "upgrade_add laser_sight")
						
						FakeClientCommand(client, "give ammo")
						
						//Give Sniper Hunting Rifle
						FakeClientCommand(client, "give hunting_rifle")
						
						if(iSpecialAmmoType == 1)
							FakeClientCommand(client, "upgrade_add incendiary_ammo")
						else if(iSpecialAmmoType == 2)
							FakeClientCommand(client, "upgrade_add explosive_ammo")
						
						if(bLaserSight)
							FakeClientCommand(client, "upgrade_add laser_sight")
						
						FakeClientCommand(client, "give ammo")
						
						//Give Sniper Scout
						FakeClientCommand(client, "give sniper_scout")
						
						if(iSpecialAmmoType == 1)
							FakeClientCommand(client, "upgrade_add incendiary_ammo")
						else if(iSpecialAmmoType == 2)
							FakeClientCommand(client, "upgrade_add explosive_ammo")
						
						if(bLaserSight)
							FakeClientCommand(client, "upgrade_add laser_sight")
						
						FakeClientCommand(client, "give ammo")
						
						//Decrease remaining quota of that player by 1
						if(GetUserFlagBits(client) == 0)
							give_quota4[client]--
						
						//Notify remaining quota
						if(give_quota4[client] >= 0 && GetUserFlagBits(client) == 0)
							PrintToChat(client, "\x01[\x04GunMenu\x01] \x04Sniper Packs\x01: %dx left this round",give_quota4[client])
					}
					else
					{
						if(g_bRoundEnded)
						{
							PrintToChat(client, "\x01[\x04GunMenu\x01] Round ended. No access.")
						}
						else if(IsPlayerIncapacitated(client))
						{
							PrintToChat(client, "\x01[\x04GunMenu\x01] You're incapacitated. No access.")
						}
						else
						{
							//No more quota left
							PrintToChat(client, "\x01[\x04GunMenu\x01] x04Sniper Packs\x01: None available")
						}
					}
				}
			}
			case 5: // Magnum and Melee
			{
				if( (give_quota5[client] > 0 || give_quota5[client] < 0 || GetUserFlagBits(client) != 0) && IsAlive(client) && !IsPlayerIncapacitated(client) && !g_bRoundEnded )
				{
					//Give the player a Magnum and Melee
					GiveMelee(client)
					
					//Decrease remaining quota of that player by 1
					if(GetUserFlagBits(client) == 0)
						give_quota5[client]--
					
					//Notify remaining quota
					if(give_quota5[client] >= 0 && GetUserFlagBits(client) == 0)
						PrintToChat(client, "\x01[\x04GunMenu\x01] \x04Magnum and Melee\x01: %dx left this round",give_quota5[client])
				}
				else
				{
					//No more quota left
					PrintToChat(client, "\x01[\x04GunMenu\x01] \x04Magnum and Melee\x01: None available")
				}
			}
			case 6: // Defibrillator
			{
				if( (give_quota6[client] > 0 || give_quota6[client] < 0 || GetUserFlagBits(client) != 0) && IsAlive(client) && !g_bRoundEnded )
				{
					//Give the player a Defibrillator
					FakeClientCommand(client, "give defibrillator")
					
					//Decrease remaining quota of that player by 1
					if(GetUserFlagBits(client) == 0)
						give_quota6[client]--
					
					//Notify remaining quota
					if(give_quota6[client] >= 0 && GetUserFlagBits(client) == 0)
						PrintToChat(client, "\x01[\x04GunMenu\x01] \x04Defibrillators\x01: %dx left this round",give_quota6[client])
				}
				else
				{
					if(g_bRoundEnded)
					{
						PrintToChat(client, "\x01[\x04GunMenu\x01] Round ended. No access.")
					}
					else if(IsPlayerIncapacitated(client))
					{
						PrintToChat(client, "\x01[\x04GunMenu\x01] You're incapacitated. No access.")
					}
					else
					{
						//No more quota left
						PrintToChat(client, "\x01[\x04GunMenu\x01] \x04Defibrillators\x01: None available")
					}
				}
			}
			case 7: // Firecrate
			{
				if(!AllowedToSpawnItems(client))
				{
					PrintToChat(client, "\x01[\x04GunMenu\x01] Not allowed at this location.")
				}
				else
				{
					if( (give_quota7[client] > 0 || give_quota7[client] < 0 || GetUserFlagBits(client) != 0) && IsAlive(client) && !IsPlayerIncapacitated(client) && !g_bRoundEnded )
					{
						//Give the player a Firecrate
						FakeClientCommand(client, "give fireworkcrate")
						
						//Decrease remaining quota of that player by 1
						if(GetUserFlagBits(client) == 0)
							give_quota7[client]--
						
						//Notify remaining quota
						if(give_quota7[client] >= 0 && GetUserFlagBits(client) == 0)
							PrintToChat(client, "\x01[\x04GunMenu\x01] \x04Firecrate\x01: %dx left this round",give_quota7[client])
					}
					else
					{
						if(g_bRoundEnded)
						{
							PrintToChat(client, "\x01[\x04GunMenu\x01] Round ended. No access.")
						}
						else if(IsPlayerIncapacitated(client))
						{
							PrintToChat(client, "\x01[\x04GunMenu\x01] You're incapacitated. No access.")
						}
						else
						{
							//No more quota left
							PrintToChat(client, "\x01[\x04GunMenu\x01] \x04Firecrate\x01: None available")
						}
					}
				}
			}
			case 8: // Propane Tank
			{
				if(!AllowedToSpawnItems(client))
				{
					PrintToChat(client, "\x01[\x04GunMenu\x01] Not allowed at this location.")
				}
				else
				{
					if( (give_quota8[client] > 0 || give_quota8[client] < 0 || GetUserFlagBits(client) != 0) && IsAlive(client) && !IsPlayerIncapacitated(client) )
					{
						//Give the player an Propane Tank
						FakeClientCommand(client, "give propanetank")
						
						//Decrease remaining quota of that player by 1
						if(GetUserFlagBits(client) == 0)
							give_quota8[client]--
						
						//Notify remaining quota
						if(give_quota8[client] >= 0 && GetUserFlagBits(client) == 0)
							PrintToChat(client, "\x01[\x04GunMenu\x01] \x04Propane Tank\x01: %dx left this round",give_quota8[client])
					}
					else
					{
						if(g_bRoundEnded)
						{
							PrintToChat(client, "\x01[\x04GunMenu\x01] Round ended. No access.")
						}
						else if(IsPlayerIncapacitated(client))
						{
							PrintToChat(client, "\x01[\x04GunMenu\x01] You're incapacitated. No access.")
						}
						else
						{
							//No more quota left
							PrintToChat(client, "\x01[\x04GunMenu\x01] \x04Propane Tank\x01: None available")
						}
					}
				}
			}
			case 9: // Spawn Machine Gun
			{
				if(StrEqual(g_MapName, "c1m1_hotel", false))
				{
					PrintToChat(client, "\x01[\x04GunMenu\x01] \x04Spawn Machine Gun\x01: Not available this round")
				}
				else
				{
					if(AllowedToSpawnItems(client) && GetEntProp(client, Prop_Data, "m_fFlags") & FL_ONGROUND)
					{
						if( (give_quota9[client] > 0 || give_quota9[client] < 0 || GetUserFlagBits(client) != 0) && IsAlive(client) && !IsPlayerIncapacitated(client) && !g_bRoundEnded )
						{
							//Spawn a minigun in front of the player
							SpawnMiniGun(client)
							
							//Decrease remaining quota of that player by 1
							if(GetUserFlagBits(client) == 0)
								give_quota9[client]--
							
							//Notify remaining quota
							if(give_quota9[client] >= 0 && GetUserFlagBits(client) == 0)
								PrintToChat(client, "\x01[\x04GunMenu\x01] \x04Spawn Machine Gun\x01: %dx left this round",give_quota9[client])
						}
						else
						{
							if(g_bRoundEnded)
							{
								PrintToChat(client, "\x01[\x04GunMenu\x01] Round ended. No access.")
							}
							else if(IsPlayerIncapacitated(client))
							{
								PrintToChat(client, "\x01[\x04GunMenu\x01] You're incapacitated. No access.")
							}
							else
							{
								//No more quota left
								PrintToChat(client, "\x01[\x04GunMenu\x01] \x04Spawn Machine Gun\x01: None available")
							}
						}
					}
					else
					{
						PrintToChat(client, "\x01[\x04GunMenu\x01] Not allowed at this location.")
					}
				}
			}
		}
	}
	
	//Add the CHEAT flag back to "give" command
	SetCommandFlags("give", giveFlags|FCVAR_CHEAT)
	
	//Add the CHEAT flag back to "upgrade_add" command
	SetCommandFlags("upgrade_add", upgradeFlags|FCVAR_CHEAT)
}

stock SpawnMiniGun(client)
{
	decl Float:vecOrigin[3], Float:vecAngles[3], Float:vecDirection[3]

	new minigun = CreateEntityByName("prop_minigun")

	if(minigun == -1)
	{
		ReplyToCommand(client, "[SM] %t", "MinigunFailed", LANG_SERVER)
	}

	DispatchKeyValue(minigun, "model", "Minigun_1")
	DispatchKeyValueFloat(minigun, "MaxPitch", 360.00)
	DispatchKeyValueFloat(minigun, "MinPitch", -360.00)
	DispatchKeyValueFloat(minigun, "MaxYaw", 90.00)
	DispatchKeyValueFloat(minigun, "spawnflags", 256.0)
	DispatchKeyValueFloat(minigun, "solid", 0.0)
	DispatchSpawn(minigun)

	GetClientAbsOrigin(client, vecOrigin)
	GetClientEyeAngles(client, vecAngles)
	GetAngleVectors(vecAngles, vecDirection, NULL_VECTOR, NULL_VECTOR)
	vecOrigin[0] += vecDirection[0] * 32
	vecOrigin[1] += vecDirection[1] * 32
	vecOrigin[2] += vecDirection[2] * 1
	vecAngles[0] = 0.0
	vecAngles[2] = 0.0
	DispatchKeyValueVector(minigun, "Angles", vecAngles)
	DispatchSpawn(minigun)
	TeleportEntity(minigun, vecOrigin, NULL_VECTOR, NULL_VECTOR)
}

public Action:OnPlayerRunCmd(client, &buttons, &impulse, Float:vel[3], Float:angles[3], &weapon)
{
	if(IsAlive(client) && GetClientTeam(client) == 2)
	{
		static oldButtons[MAXPLAYERS+1]
		
		if(buttons & IN_RELOAD)
		{
			static Float:doubletapTime[MAXPLAYERS+1]
			new Float:time = GetEngineTime()
			
			if(time < doubletapTime[client] && !(oldButtons[client] & IN_RELOAD))
			{
				//client just doubletapped use key
				GunMenu(client)
			}
			
			doubletapTime[client] = time + 0.3
		}
		
		oldButtons[client] = buttons
	}
}

public OnGameFrame()
{
	if(!IsServerProcessing())
		return
	
	if(GetConVarBool(h_InfiniteChainsaw))
	{
		for(new i = 1; i < MaxClients; i++)
		{
			if(IsClientConnected(i) && IsClientInGame(i) && IsAlive(i))
			{
				if(GetPlayerWeaponSlot(i, 1) != -1)
				{
					decl String:WeaponClass[100]
					GetEdictClassname(GetPlayerWeaponSlot(i, 1), WeaponClass, sizeof(WeaponClass))
					
					if(StrEqual(WeaponClass, "weapon_chainsaw"))
					{
						if(GetEntProp(GetPlayerWeaponSlot(i, 1), Prop_Send, "m_iClip1") < 30)
							SetEntProp(GetPlayerWeaponSlot(i, 1), Prop_Send, "m_iClip1", 30)
					}
				}
			}
		}
	}
}

stock ForceClientCvars(client)
{
	ClientCommand(client, "cl_glow_item_far_r 0.0")
	ClientCommand(client, "cl_glow_item_far_g 0.7")
	ClientCommand(client, "cl_glow_item_far_b 0.2")
}

stock GiveMelee(client)
{
	FakeClientCommand(client, "give pistol")
	FakeClientCommand(client, "give pistol")
	FakeClientCommand(client, "give pistol_magnum")
	
	if((StrEqual(g_MapName, "c1m1_hotel", false)) || (StrEqual(g_MapName, "c1m2_streets", false)) || (StrEqual(g_MapName, "c1m3_mall", false)) || (StrEqual(g_MapName, "c1m4_atrium", false)))
	{
		FakeClientCommand(client, "give chainsaw")
		FakeClientCommand(client, "give cricket_bat")
		FakeClientCommand(client, "give crowbar")
		FakeClientCommand(client, "give baseball_bat")
		//FakeClientCommand(client, "give katana")
		//FakeClientCommand(client, "give fireaxe")
		FakeClientCommand(client, "give knife")
	}
	else if((StrEqual(g_MapName, "c2m1_highway", false)) || (StrEqual(g_MapName, "c2m2_fairgrounds", false)) || (StrEqual(g_MapName, "c2m3_coaster", false)) || (StrEqual(g_MapName, "c2m4_barns", false)) || (StrEqual(g_MapName, "c2m5_concert", false)))
	{
		FakeClientCommand(client, "give chainsaw")
		//FakeClientCommand(client, "give katana")
		FakeClientCommand(client, "give crowbar")
		//FakeClientCommand(client, "give fireaxe")
		FakeClientCommand(client, "give baseball_bat")
		FakeClientCommand(client, "give electric_guitar")
		FakeClientCommand(client, "give knife")
	}
	else if((StrEqual(g_MapName, "c3m1_plankcountry", false)) || (StrEqual(g_MapName, "c3m2_swamp", false)) || (StrEqual(g_MapName, "c3m3_shantytown", false)) || (StrEqual(g_MapName, "c3m4_plantation", false)))
	{
		FakeClientCommand(client, "give chainsaw")
		//FakeClientCommand(client, "give machete")
		FakeClientCommand(client, "give cricket_bat")
		//FakeClientCommand(client, "give fireaxe")
		FakeClientCommand(client, "give baseball_bat")
		FakeClientCommand(client, "give frying_pan")
		FakeClientCommand(client, "give knife")
	}
	else if((StrEqual(g_MapName, "c4m1_milltown_a", false)) || (StrEqual(g_MapName, "c4m2_sugarmill_a", false)) || (StrEqual(g_MapName, "c4m3_sugarmill_b", false)) || (StrEqual(g_MapName, "c4m4_milltown_b", false)) || (StrEqual(g_MapName, "c4m5_milltown_escape", false)))
	{
		FakeClientCommand(client, "give chainsaw")
		//FakeClientCommand(client, "give katana")
		FakeClientCommand(client, "give crowbar")
		//FakeClientCommand(client, "give fireaxe")
		FakeClientCommand(client, "give baseball_bat")
		FakeClientCommand(client, "give frying_pan")
		FakeClientCommand(client, "give knife")
	}
	else if((StrEqual(g_MapName, "c5m1_waterfront", false)) || (StrEqual(g_MapName, "c5m1_waterfront_sndscape", false)) || (StrEqual(g_MapName, "c5m2_park", false)) || (StrEqual(g_MapName, "c5m3_cemetery", false)) || (StrEqual(g_MapName, "c5m4_quarter", false)) || (StrEqual(g_MapName, "c5m5_bridge", false)))
	{
		FakeClientCommand(client, "give chainsaw")
		//FakeClientCommand(client, "give machete")
		FakeClientCommand(client, "give baseball_bat")
		FakeClientCommand(client, "give frying_pan")
		FakeClientCommand(client, "give electric_guitar")
		FakeClientCommand(client, "give tonfa")
		FakeClientCommand(client, "give knife")
	}
	else if((StrEqual(g_MapName, "c6m1_riverbank", false)) || (StrEqual(g_MapName, "c6m2_bedlam", false)) || (StrEqual(g_MapName, "c6m3_port", false)))
	{
		FakeClientCommand(client, "give chainsaw")
		//FakeClientCommand(client, "give katana")
		//FakeClientCommand(client, "give fireaxe")
		FakeClientCommand(client, "give baseball_bat")
		FakeClientCommand(client, "give frying_pan")
		FakeClientCommand(client, "give knife")
		FakeClientCommand(client, "give golfclub")
	}
	else
	{
		FakeClientCommand(client, "give chainsaw")
		FakeClientCommand(client, "give cricket_bat")
		FakeClientCommand(client, "give crowbar")
		FakeClientCommand(client, "give fireaxe")
		FakeClientCommand(client, "give baseball_bat")
		FakeClientCommand(client, "give frying_pan")
		FakeClientCommand(client, "give electric_guitar")
		FakeClientCommand(client, "give tonfa")
		FakeClientCommand(client, "give machete")
		FakeClientCommand(client, "give katana")
		FakeClientCommand(client, "give knife")
	}
}