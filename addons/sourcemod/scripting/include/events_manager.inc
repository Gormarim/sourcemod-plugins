#if defined _events_manager_included
 #endinput
#endif
#define _events_manager_included

enum EventType
{
	EventType_Gamemode = 0,
	EventType_Event,
	EventType_PlainEvent
};

forward OnPlayerFree(client);

forward OnPlayerBusy(client);

native bool:RegPlugin();

native bool:UnloadPlugin();

native bool:RegGamemode(const String:start_command[], const String:display_name[], const String:info[] = "", id = 0);

native bool:RegEvent(const String:start_command[], const String:display_name[], const String:info[] = "", id = 0);

native bool:RegPlainEvent(id = 0);

native bool:RegGamemodeConVar(char[] str_convar, id = 0);

native bool:RegEventConVar(char[] str_convar, id = 0);

native bool:StartEvent(id = 0);

native bool:EndEvent(id = 0);

native bool:StartPlainEvent(id = 0);

native bool:EndPlainEvent(id = 0);

functag public StartGamemodeCB();

native bool:StartGamemode(StartGamemodeCB:callback, id = 0);

native bool:EndGamemode(id = 0);

native bool:IsPlayerFree(client);

native bool:GrabPlayer(client, EventType:type, id = 0);

native bool:FreePlayer(client, EventType:type, id = 0);

native bool:FreeAllPlayers(EventType:type, id = 0);

forward __EMCheckStatus();

native __EMValid();

public __EMCheckStatus()
{
	__EMValid();
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
	MarkNativeAsOptional("__EMValid");
}
#endif
