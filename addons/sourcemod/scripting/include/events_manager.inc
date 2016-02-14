#if defined _events_manager_included
 #endinput
#endif
#define _events_manager_included

enum EventType
{
	EventType_Gamemode = 0,
	EventType_Event
};

forward OnPlayerFree(client);

forward OnPlayerBusy(client);

native bool:RegPlugin();

native UnloadPlugin();

native RegEvent(EventType:type, const String:name[] = "");

native bool:SetEventName(id, const String:name[]);

native bool:SetEventMainCmd(id, const String:cmd[]);

native bool:SetEventInfoCmd(id, const String:cmd[]);

native bool:RegEventConVar(id, const String:name[], const String:description[]);

functag public StartGamemodeCB();

native bool:StartEvent(id, StartGamemodeCB:callback = INVALID_FUNCTION);

native bool:EndEvent(id);

native bool:IsPlayerFree(client);

native bool:GrabPlayer(id, client);

native bool:FreePlayer(id, client);

native bool:FreeAllPlayers(id);

native EMValid();

public EMCheckStatus()
{
	EMValid();
}

public SharedPlugin:__pl_events_manager =
{
	name = "bs_events_manager",
	file = "events_manager.smx",
#if defined REQUIRE_PLUGIN
	required = 1,
#else
	required = 0
#endif
};

#if !defined REQUIRE_PLUGIN
public __pl_events_manager_SetNTVOptional()
{
	MarkNativeAsOptional("RegPlugin");
	MarkNativeAsOptional("UnloadPlugin");
	MarkNativeAsOptional("RegEvent");
	MarkNativeAsOptional("RegGamemode");
	MarkNativeAsOptional("RegPlainEvent");
	MarkNativeAsOptional("RegGamemodeConVar");
	MarkNativeAsOptional("RegEventConVar");
	MarkNativeAsOptional("StartEvent");
	MarkNativeAsOptional("EndEvent");
	MarkNativeAsOptional("StartPlainEvent");
	MarkNativeAsOptional("EndPlainEvent");
	MarkNativeAsOptional("StartGamemode");
	MarkNativeAsOptional("EndGamemode");
	MarkNativeAsOptional("IsPlayerFree");
	MarkNativeAsOptional("GrabPlayer");
	MarkNativeAsOptional("FreePlayer");
	MarkNativeAsOptional("FreeAllPlayers");
	MarkNativeAsOptional("EMValid");
}
#endif
