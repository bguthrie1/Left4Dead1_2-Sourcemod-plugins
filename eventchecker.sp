
#include <sourcemod>

public Plugin:myinfo = 
{
	name = "Event Checker",
	author = "MI 5",
	description = "Checks to see if certain events are fired and displays a message",
	version = "1.0",
	url = "<- URL ->"
}

public OnPluginStart()
{
	HookEvent("round_end_message", Event_RoundEnd);
	HookEvent("start_score_animation", Event_StartScore);
	HookEvent("mission_lost", Event_MissionLost);
	HookEvent("versus_marker_reached", Event_VersusMarkerReached);
	HookEvent("final_reportscreen", Event_FinalReport);
	HookEvent("versus_match_finished", Event_VersusRoundEnd);
	HookEvent("map_transition", Event_MapTransitioned);
	HookEvent("player_transitioned", Event_PlayerTransitioned);
	HookEvent("tongue_grab", Event_DragBegin);
	HookEvent("tongue_release", Event_DragEnd);
	HookEvent("vote_started", Event_VoteStarted); // Does not trigger
	HookEvent("vote_changed", Event_VoteChanged); // Does not trigger
	HookEvent("vote_passed", Event_VotePassed); // Does not trigger
	HookEvent("vote_ended", Event_VoteEnded); // Does not trigger
	HookEvent("vote_failed", Event_VoteFailed); // Does not trigger
	HookEvent("vote_cast_yes", Event_VoteCastYes);
	HookEvent("vote_cast_no", Event_VoteCastNo);
	HookEvent("game_init", Event_GameInitiated);// Does not trigger
	HookEvent("game_newmap", Event_NewMap);// Does not trigger
	HookEvent("player_use", Event_PlayerUse);
	HookEvent("use_target", Event_PlayerUse2);// Does not trigger
	HookEvent("explain_panic_button", Event_FinaleRush);
	HookEvent("panic_event_finished", Event_PanicEventFinished);
	HookEvent("triggered_car_alarm", Event_TriggeredCar);
	HookEvent("create_panic_event", Event_CreatePanic);
}


public Action:Event_RoundEnd(Handle:event, const String:name[], bool:dontBroadcast)
{
	PrintToChatAll("Round Ended")
	LogMessage("Round Ended")
}

public Action:Event_MapTransitioned(Handle:event, const String:name[], bool:dontBroadcast)
{
	PrintToChatAll("Map Transitioned")
	LogMessage("Map Transitioned")
}

public Action:Event_PlayerTransitioned(Handle:event, const String:name[], bool:dontBroadcast)
{
	PrintToChatAll("Player Transitioned")
	LogMessage("Player Transitioned")
}

public Action:Event_VersusRoundEnd(Handle:event, const String:name[], bool:dontBroadcast)
{
	PrintToChatAll("Versus Round Ended")
	LogMessage("Versus Round Ended")
}

public Action:Event_StartScore(Handle:event, const String:name[], bool:dontBroadcast)
{
	PrintToChatAll("Start Score Event")
	LogMessage("Start Score Event")
}

public Action:Event_FinalReport(Handle:event, const String:name[], bool:dontBroadcast)
{
	PrintToChatAll("Final Report")
	LogMessage("Final Report")
}

public Action:Event_MissionLost(Handle:event, const String:name[], bool:dontBroadcast)
{
	PrintToChatAll("Mission Lost")
	LogMessage("Mission Lost")
}

public Action:Event_DragBegin(Handle:event, const String:name[], bool:dontBroadcast)
{
	PrintToChatAll("Drag Begin")
	LogMessage("Drag Begin")
}

public Action:Event_DragEnd(Handle:event, const String:name[], bool:dontBroadcast)
{
	PrintToChatAll("Drag End")
	LogMessage("Drag End")
}

public OnMapEnd()
{
	PrintToChatAll("Map Ended")
	LogMessage("Map Ended")
}

public Action:Event_VersusMarkerReached(Handle:event, const String:name[], bool:dontBroadcast)
{
	PrintToChatAll("Versus Marker Reached")
	LogMessage("Versus Marker Reached")
}

public Action:Event_VoteStarted(Handle:event, const String:name[], bool:dontBroadcast)
{
	PrintToChatAll("Vote Started")
	LogMessage("Vote Started")
}

public Action:Event_VotePassed(Handle:event, const String:name[], bool:dontBroadcast)
{
	PrintToChatAll("Vote Passed")
	LogMessage("Vote Passed")
}

public Action:Event_VoteChanged(Handle:event, const String:name[], bool:dontBroadcast)
{
	PrintToChatAll("Vote Changed")
	LogMessage("Vote Changed")
}

public Action:Event_VoteEnded(Handle:event, const String:name[], bool:dontBroadcast)
{
	PrintToChatAll("Vote Ended")
	LogMessage("Vote Ended")
}

public Action:Event_VoteFailed(Handle:event, const String:name[], bool:dontBroadcast)
{
	PrintToChatAll("Vote Failed")
	LogMessage("Vote Failed")
}

public Action:Event_VoteCastYes(Handle:event, const String:name[], bool:dontBroadcast)
{
	PrintToChatAll("Someone Voted Yes")
	LogMessage("Someone Voted Yes")
}

public Action:Event_VoteCastNo(Handle:event, const String:name[], bool:dontBroadcast)
{
	PrintToChatAll("Someone Voted No")
	LogMessage("Someone Voted No")
}

public Action:Event_GameInitiated(Handle:event, const String:name[], bool:dontBroadcast)
{
	PrintToChatAll("Game Started")
	LogMessage("Game Started")
}

public Action:Event_NewMap(Handle:event, const String:name[], bool:dontBroadcast)
{
	PrintToChatAll("Map fully loaded")
	LogMessage("Map fully loaded")
}

public Action:Event_PlayerUse(Handle:event, const String:name[], bool:dontBroadcast)
{
	new entity = GetEventInt(event, "targetid")
	
	decl String:classname[256]
	
	GetEdictClassname(entity, classname, sizeof(classname));
	
	PrintToChatAll("Entity index = %i, Classname = %s", entity, classname);
	
	PrintToChatAll("Player Used something")
	LogMessage("Player Used something")
}

public Action:Event_PlayerUse2(Handle:event, const String:name[], bool:dontBroadcast)
{
	new entity = GetEventInt(event, "targetid")
	
	decl String:classname[256]
	
	GetEventString(event, "classname", classname, sizeof(classname))
	
	PrintToChatAll("Entity index = %i, Classname = %s", entity, classname);
	
	PrintToChatAll("Player Used something")
	LogMessage("Player Used something")
}

public Action:Event_FinaleRush(Handle:event, const String:name[], bool:dontBroadcast)
{
	PrintToChatAll("Panic button near by")
	LogMessage("Panic button near by")
}

public Action:Event_PanicEventFinished(Handle:event, const String:name[], bool:dontBroadcast)
{
	PrintToChatAll("Panic finished")
	LogMessage("Panic finished")
}

public Action:Event_TriggeredCar(Handle:event, const String:name[], bool:dontBroadcast)
{
	PrintToChatAll("Triggered Car Alarm")
	LogMessage("Triggered Car Alarm")
}

public Action:Event_CreatePanic(Handle:event, const String:name[], bool:dontBroadcast)
{
	PrintToChatAll("Panic Event Created")
	LogMessage("Panic Event Created")
}