#pragma semicolon 1

#include <sourcemod>

public Plugin myinfo = 
{
	name = "",
	author = "",
	description = "",
	version = "0.00",
	url = ""
};

enum EventType
{
	EventType_Gamemode = 0,
	EventType_Event,
	EventType_PlainEvent
};

#define MAX_STR_LEN 64

Handle g_fwdCheckStatus;
Handle g_fwdOnPlayerFree;
Handle g_fwdOnPlayerBusy;
Handle g_fwdCanStartGamemode;

StringMap g_statusMap;
ArrayList g_statusList;
StringMap g_pluginsMap;
ArrayList g_activeEvents;

bool g_bCanStartEvents;

Menu mn_main;
Menu mn_gamemodes;
Menu mn_events;
Menu mn_convars;
Menu mn_convars_gamemodes;
Menu mn_convars_events;

/********************************************
				STRUCTS
********************************************/

methodmap StringProp < ArrayList
{
	public StringProp(char[] str)
	{
		ArrayList t_str = new ArrayList(MAX_STR_LEN, 1);
		t_str.SetString(0, str);
		return view_as<StringProp>(t_str);
	}
	
	public void Set(char[] str)
	{
		this.SetString(0, str);
	}
	
	public void Get(char[] buffer, int maxLen)
	{
		this.GetString(0, buffer, maxLen);
	}
}
	
methodmap BBEvent < ArrayList
{
	public BBEvent(Handle plugin, EventType type, int id, char[] cmd, char[] name, char[] info)
	{
		ArrayList ev = new ArrayList(1, 9);
		
		ev.Set(0, id);
		ev.Set(1, false);
		ev.Set(2, new StringProp(cmd));
		ev.Set(3, new StringProp(name));
		ev.Set(4, new StringProp(info));
		ev.Set(5, new ArrayList(1, 0));
		ev.Set(6, plugin);
		ev.Set(7, type);
		ev.Set(8, INVALID_HANDLE);
		
		return view_as<BBEvent>(ev);
	}
	
	property int Id
	{
		public get(){ return this.Get(0); }
		public set(int id){ this.Set(0, id); }
	}
	property bool Active
	{
		public get(){ return this.Get(1); }
		public set(bool status){ this.Set(1, status); }
	}
	property StringProp StartCmd
	{
		public get(){ return this.Get(2); }
	}
	property StringProp Name
	{
		public get(){ return this.Get(3); }
	}
	property StringProp Info
	{
		public get(){ return this.Get(4); }
	}
	property ArrayList ConVars
	{
		public get(){ return this.Get(5); }
	}
	property Handle Plugin
	{
		public get(){ return this.Get(6); }	
	}
	property EventType Type
	{
		public get(){ return this.Get(7); }
		public set(EventType type){ this.Set(7, type); }
	}
	property Menu ConVarsMenu
	{
		public get(){ return this.Get(8); }
		public set(Menu menu){ this.Set(8, menu); }
	}
}

methodmap PluginData < ArrayList
{
	public PluginData(Handle plugin)
	{
		ArrayList pd = new ArrayList(1, 8);
		pd.Set(0, plugin);
		pd.Set(1, new ArrayList());
		pd.Set(2, new StringMap());
		pd.Set(3, new ArrayList());
		pd.Set(4, new StringMap());
		pd.Set(5, new ArrayList());
		pd.Set(6, new StringMap());
		pd.Set(7, new ArrayList(MAX_STR_LEN, 0));
		
		return view_as<PluginData>(pd);
	}
	
	property Handle Plugin
	{
		public get(){ return this.Get(0); }
	}
	property ArrayList Gamemodes
	{
		public get(){ return this.Get(1); }
	}
	property StringMap GamemodesMap
	{
		public get(){ return this.Get(2); }
	}
	property ArrayList Events
	{
		public get(){ return this.Get(3); }
	}
	property StringMap EventsMap
	{
		public get(){ return this.Get(4); }
	}
	property ArrayList PlainEvents
	{
		public get(){ return this.Get(5); }
	}
	property StringMap PlainEventsMap
	{
		public get(){ return this.Get(6); }
	}
	property ArrayList Cmds
	{
		public get(){ return this.Get(7); }
	}
}

BBEvent g_players[33];
BBEvent g_activeGamemode;
BBEvent g_pendingGamemode;

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{	
	CreateNative("RegPlugin", __RegPlugin);
	CreateNative("UnloadPlugin", __UnloadPlugin);
	CreateNative("RegGamemode", __RegGamemode);
	CreateNative("RegEvent", __RegEvent);
	CreateNative("RegPlainEvent", __RegPlainEvent);
	CreateNative("RegGamemodeConVar", __RegGamemodeConVar);
	CreateNative("RegEventConVar", __RegEventConVar);
	CreateNative("StartEvent", __StartEvent);
	CreateNative("EndEvent", __EndEvent);
	CreateNative("StartPlainEvent", __StartPlainEvent);
	CreateNative("EndPlainEvent", __EndPlainEvent);
	CreateNative("StartGamemode", __StartGamemode);
	CreateNative("EndGamemode", __EndGamemode);
	CreateNative("IsPlayerFree", __IsPlayerFree);
	CreateNative("GrabPlayer", __GrabPlayer);
	CreateNative("FreePlayer", __FreePlayer);
	CreateNative("FreeAllPlayers", __FreeAllPlayers);
	
	CreateNative("__EMValid", Valid);
	
	RegPluginLibrary("bs_events_manager");
	return APLRes_Success;
}

public void OnPluginStart()
{
	g_pluginsMap = new StringMap();
	
	g_activeEvents = new ArrayList();
	g_activeGamemode = null;
	g_pendingGamemode = null;
	
	g_statusMap = new StringMap();
	g_statusList = new ArrayList(2, 0);
	
	g_fwdCheckStatus = CreateForward(ET_Ignore);
	g_fwdOnPlayerFree = CreateGlobalForward("OnPlayerFree", ET_Ignore, Param_Cell);
	g_fwdOnPlayerBusy = CreateGlobalForward("OnPlayerBusy", ET_Ignore, Param_Cell);
	
	InitMenus();
	
	CreateTimer(5.0, CheckStatus, _, TIMER_REPEAT);
	
	RegConsoleCmd("sm_events", EventsMenu);
	
	/*
	RegConsoleCmd("ev_active_events", DumpActiveEvents);
	RegConsoleCmd("ev_active_gamemode", DumpActiveGamemode);
	RegConsoleCmd("ev_pending_gamemode", DumpPendingGamemode);
	*/
}

/*
public Action DumpActiveEvents(int client, int args)
{
	PrintToChatAll("Active Events Dump:");
	int len = g_activeEvents.Length;
	PrintToChatAll("Count: %d", len);
	for (int i = 0; i < len; ++i)
	{
		PrintToChatAll("[%d]", i);
		DumpEvent(view_as<BBEvent>(g_activeEvents.Get(i)));
	}
	
	return Plugin_Handled;
}

void DumpEvent(BBEvent ev)
{
	char cmd[64];
	ev.StartCmd.Get(cmd, 64);
	PrintToChatAll("(%d) Plugin: %d | Type: %d | Cmd: %s", ev, ev.Plugin, ev.Type, cmd);
}

public Action DumpActiveGamemode(int client, int args)
{
	PrintToChatAll("Active Gamemode Dump:");
	if (g_activeGamemode != null)
		DumpEvent(g_activeGamemode);
	else
		PrintToChatAll("Active Gamemode - NONE");
	
	return Plugin_Handled;
}

public Action DumpPendingGamemode(int client, int args)
{
	PrintToChatAll("Pending Gamemode Dump:");
	if (g_pendingGamemode != null)
		DumpEvent(g_pendingGamemode);
	else
		PrintToChatAll("Pending Gamemode - NONE");
	
	return Plugin_Handled;
}
*/

public void OnMapStart()
{
	g_bCanStartEvents = true;
}

public Action EventsMenu(int client, int args)
{
	if (client != 0)
		mn_main.Display(client, MENU_TIME_FOREVER);
		
	return Plugin_Handled;
}

/**
 * Status check 
**/

public Action CheckStatus(Handle timer)
{
	Call_StartForward(g_fwdCheckStatus);
	Call_Finish();
	
	DataPack dp;
	bool status;
	Handle plugin;
	int pos = g_statusList.Length - 1;
	while (pos >= 0)
	{
		dp = g_statusList.Get(pos);
		status = ReadPackCell(dp);
		if (status)
		{
			ResetPack(dp);
			WritePackCell(dp, false);
			ResetPack(dp);
		}
		else
		{
			plugin = ReadPackCell(dp);
			delete dp;
			char str_plugin[12];
			Format(str_plugin, 12, "%d", plugin);
			
			g_statusMap.Remove(str_plugin);
			g_statusList.Erase(pos);
			DeletePlugin(plugin);
		}	
		--pos;
	}

	return Plugin_Continue;
}

public int Valid(Handle plugin, int num_params)
{
	char str_plugin[12];
	Format(str_plugin, 12, "%d", plugin);
	DataPack dp;
	
	if (g_statusMap.GetValue(str_plugin, dp))
	{
		WritePackCell(dp, true);
		ResetPack(dp);
	}
	
	return;
}

void AddToStatusCheck(Handle plugin)
{
	char str_plugin[12];
	Format(str_plugin, 12, "%d", plugin);
	
	DataPack dp = CreateDataPack();
	WritePackCell(dp, false);
	WritePackCell(dp, plugin);
	ResetPack(dp);
	g_statusMap.SetValue(str_plugin, dp);
	g_statusList.Push(dp);
	
	AddToForward(g_fwdCheckStatus, plugin, GetFunctionByName(plugin, "__EMCheckStatus"));
}

/**
 * Misc functions
**/

PluginData GetPluginData(Handle plugin, bool create = false, bool &exist = false)
{
	char str_plugin[12];
	Format(str_plugin, 12, "%d", plugin);
	
	PluginData pd = null;
	g_pluginsMap.GetValue(str_plugin, pd);
	exist = true;
	
	if (pd == null)
	{
		exist = false;
		if (create)
		{
			pd = new PluginData(plugin);
			g_pluginsMap.SetValue(str_plugin, pd);
		}
	}
	
	return pd;
}

bool PluginExist(Handle plugin)
{
	return GetPluginData(plugin) != null;
}

bool AddPlugin(Handle plugin)
{	
	bool exist;
	GetPluginData(plugin, true, exist);
	return !exist;
}

bool DeletePlugin(Handle plugin)
{
	PluginData pd = GetPluginData(plugin);

	if (pd == null)
		return false;

	DeleteEventsList(pd.Gamemodes, true, mn_gamemodes, mn_convars_gamemodes);
	DeleteEventsList(pd.Events, true, mn_events, mn_convars_events);
	DeleteEventsList(pd.PlainEvents);
	
	delete pd.GamemodesMap;
	delete pd.EventsMap;
	delete pd.PlainEventsMap;
	delete pd.Cmds;
	delete pd;
	
	return true;
}

void DeleteEventsList(ArrayList list, bool menus = false, Menu menu1 = null, Menu menu2 = null)
{
	BBEvent ev;
	int len = list.Length;
	for (int i = 0; i < len; ++i)
	{
		ev = list.Get(i);
		if (menus)
			RemoveEventFromMenus(ev, menu1, menu2);
		DeleteEvent(ev);
	}
	
	delete list;
}

void DeleteEvent(BBEvent ev)
{	
	if (ev == g_pendingGamemode)
	{
		RemovePendingGamemodeFromMenu();
		if (g_activeGamemode == null)
			g_bCanStartEvents = true;
		g_pendingGamemode = null;
		CloseHandle(g_fwdCanStartGamemode);
	}
	else if (ev == g_activeGamemode)
	{
		RemoveActiveGamemodeFromMenu();
		if (g_pendingGamemode != null && ev.Plugin != g_pendingGamemode.Plugin)
		{
			RemovePendingGamemodeFromMenu();
			AddActiveGamemodeToMenu(g_pendingGamemode);
			g_activeGamemode = g_pendingGamemode;
			g_pendingGamemode = null;
			Call_StartForward(g_fwdCanStartGamemode);
			Call_Finish();
			CloseHandle(g_fwdCanStartGamemode);
		}
		else
		{
			g_activeGamemode = null;
			g_bCanStartEvents = true;
		}
	}
	
	if (ev.Active)
		g_activeEvents.Erase(g_activeEvents.FindValue(ev));
		
	if (ev.ConVarsMenu != null)
		ev.ConVarsMenu.Cancel();
	
	FreeEvent(ev);
	delete ev.StartCmd;
	delete ev.Name;
	delete ev.Info;
	delete ev.ConVars;
	delete ev.ConVarsMenu;
	delete ev;
}

BBEvent GetEvent(Handle plugin, EventType type, int id)
{
	PluginData pd = GetPluginData(plugin);
	if (pd == null)
		return null;
		
	char str_id[12];
	Format(str_id, 12, "%d", id);
	
	BBEvent ev = null;
	if (type == EventType_Gamemode)
		pd.GamemodesMap.GetValue(str_id, ev);
	else if (type == EventType_Event)
		pd.EventsMap.GetValue(str_id, ev);
	else
		pd.PlainEventsMap.GetValue(str_id, ev);
		
	return ev;
}

bool AddEvent(Handle plugin, EventType type, int id, char[] start_command = "", char[] display_name = "", char[] info = "")
{
	bool exist;
	PluginData pd = GetPluginData(plugin, true, exist);
	if (!exist)
		AddToStatusCheck(plugin);
	
	char str_id[12];
	Format(str_id, 12, "%d", id);
	
	ArrayList list;
	StringMap map;
	Menu menu;
	if (type == EventType_Gamemode)
	{
		list = pd.Gamemodes;
		map = pd.GamemodesMap;
		menu = mn_gamemodes;
	}
	else if (type == EventType_Event)
	{
		list = pd.Events;
		map = pd.EventsMap;
		menu = mn_events;
	}
	else
	{
		list = pd.PlainEvents;
		map = pd.PlainEventsMap;
	}
	
	BBEvent ev;
	if (map.GetValue(str_id, ev))
		return false;
	
	ev = new BBEvent(plugin, type, id, start_command, display_name, info);
	map.SetValue(str_id, ev);
	list.Push(ev);
	
	if (type != EventType_PlainEvent)
		AddEventToMenu(menu, ev);
		
	return true;
}

bool AddConVar(Handle plugin, char[] str_convar, EventType type, int id)
{
	ConVar cv = FindConVar(str_convar);
	if (cv == null)
		return false;

	BBEvent ev = GetEvent(plugin, type, id);
	if (ev == null)
		return false;
		
	if (ev.ConVars.FindValue(cv) != -1)
		return false;
	
	if (ev.ConVars.Length == 0)
	{
		char name[MAX_STR_LEN], title[200];
		ev.Name.Get(name, MAX_STR_LEN);
		Format(title, 200, "%s ConVars:", name);
		
		Menu mn_cvs = new Menu(MenuHandler_ConvarsDynamic, MENU_ACTIONS_DEFAULT);
		mn_cvs.SetTitle(title);
		mn_cvs.ExitBackButton = true;
		
		if (ev.Type == EventType_Gamemode)
		{
			AddEventToMenu(mn_convars_gamemodes, ev);
			mn_cvs.AddItem("0", "", ITEMDRAW_RAWLINE);
		}
		else if (ev.Type == EventType_Event)
		{
			AddEventToMenu(mn_convars_events, ev);
			mn_cvs.AddItem("1", "", ITEMDRAW_RAWLINE);
		}
	
		ev.ConVarsMenu = mn_cvs;
	}
	
	char buffer[200], desc[200];
	bool is_command;
	int flags;
	Handle iter = FindFirstConCommand(buffer, 200, is_command, flags, desc, 200);
	do
	{
		if (StrEqual(buffer, str_convar, false))
			break;
	}
	while (FindNextConCommand(iter, buffer, 200, is_command, flags, desc, 200));
	delete iter;
	
	ev.ConVarsMenu.AddItem(desc, str_convar);
	ev.ConVarsMenu.Cancel();
	ev.ConVars.Push(cv);
	
	return true;
}

bool StartEventInternal(Handle plugin, EventType type, int id)
{
	if (!g_bCanStartEvents)
		return false;
	
	BBEvent ev = GetEvent(plugin, type, id);
	if (ev == null)
		return false;
	
	if (ev.Active)
		return false;
	
	ev.Active = true;
	g_activeEvents.Push(ev);
	return true;
}

bool EndEventInternal(Handle plugin, EventType type, int id)
{
	BBEvent ev = GetEvent(plugin, type, id);
	if (ev == null)
		return false;
		
	if (!ev.Active)
		return false;
	
	ev.Active = false;
	g_activeEvents.Erase(g_activeEvents.FindValue(ev));
	FreeEvent(ev);
	
	if (g_pendingGamemode != null && g_activeGamemode == null && g_activeEvents.Length == 0)
	{
		RemovePendingGamemodeFromMenu();
		AddActiveGamemodeToMenu(g_pendingGamemode);
		g_activeGamemode = g_pendingGamemode;
		g_pendingGamemode = null;
		Call_StartForward(g_fwdCanStartGamemode);
		Call_Finish();
		CloseHandle(g_fwdCanStartGamemode);
	}
	
	return true;
}

/**
 * Natives
**/
public int __RegPlugin(Handle plugin, int numParams)
{
	if (AddPlugin(plugin))
	{
		AddToStatusCheck(plugin);
		return true;
	}
	
	return false;
}

public int __UnloadPlugin(Handle plugin, int numParams)
{
	char str_plugin[12];
	Format(str_plugin, 12, "%d", plugin);
	
	DataPack dp;
	if (!g_statusMap.GetValue(str_plugin, dp))
		return false;
		
	g_statusMap.Remove(str_plugin);
	g_statusList.Erase(g_statusList.FindValue(dp));
	DeletePlugin(plugin);
	
	delete dp;
	return true;
}

public int __RegGamemode(Handle plugin, int numParams)
{
	int len_cmd, len_name;
	GetNativeStringLength(1, len_cmd);
	GetNativeStringLength(2, len_name);
	if (len_cmd == 0 || len_name == 0)
		return false;
	
	char start_cmd[MAX_STR_LEN], display_name[MAX_STR_LEN], info[MAX_STR_LEN];
	GetNativeString(1, start_cmd, MAX_STR_LEN);
	GetNativeString(2, display_name, MAX_STR_LEN);
	GetNativeString(3, info, MAX_STR_LEN);
	
	return AddEvent(plugin, EventType_Gamemode, GetNativeCell(4), start_cmd, display_name, info);
}

public int __RegEvent(Handle plugin, int num_params)
{
	int len_cmd, len_name;
	GetNativeStringLength(1, len_cmd);
	GetNativeStringLength(2, len_name);
	if (len_cmd == 0 || len_name == 0)
		return false;
		
	char start_cmd[MAX_STR_LEN], display_name[MAX_STR_LEN], info[MAX_STR_LEN];
	GetNativeString(1, start_cmd, MAX_STR_LEN);
	GetNativeString(2, display_name, MAX_STR_LEN);
	GetNativeString(3, info, MAX_STR_LEN);
	
	return AddEvent(plugin, EventType_Event, GetNativeCell(4), start_cmd, display_name, info);
}

public int __RegPlainEvent(Handle plugin, int num_params)
{	
	return AddEvent(plugin, EventType_PlainEvent, GetNativeCell(1));
}

public int __RegGamemodeConVar(Handle plugin, int num_params)
{	
	char str_convar[MAX_STR_LEN];
	GetNativeString(1, str_convar, MAX_STR_LEN);
	
	return AddConVar(plugin, str_convar, EventType_Gamemode, GetNativeCell(2));
}

public int __RegEventConVar(Handle plugin, int num_params)
{
	char str_convar[MAX_STR_LEN];
	GetNativeString(1, str_convar, MAX_STR_LEN);
	
	return AddConVar(plugin, str_convar, EventType_Event, GetNativeCell(2));
}

public int __StartEvent(Handle plugin, int num_params)
{
	return StartEventInternal(plugin, EventType_Event, GetNativeCell(1));
}

public int __StartPlainEvent(Handle plugin, int num_params)
{
	return StartEventInternal(plugin, EventType_PlainEvent, GetNativeCell(1));
}

public int __EndEvent(Handle plugin, int num_params)
{
	return EndEventInternal(plugin, EventType_Event, GetNativeCell(1));
}

public __EndPlainEvent(Handle plugin, int num_params)
{
	return EndEventInternal(plugin, EventType_PlainEvent, GetNativeCell(1));
}

public int __StartGamemode(Handle plugin, int num_params)
{
	if (g_pendingGamemode != null)
		return false;
	
	BBEvent ev = GetEvent(plugin, EventType_Gamemode, GetNativeCell(2));
	if (ev == null)
		return false;
	
	if (g_activeGamemode == ev)
		return false;
	
	g_bCanStartEvents = false;
	if (g_activeGamemode == null && g_activeEvents.Length == 0)
	{
		AddActiveGamemodeToMenu(ev);
		g_activeGamemode = ev;
		Call_StartFunction(plugin, GetNativeFunction(1));
		Call_Finish();
	}
	else
	{
		AddPendingGamemodeToMenu(ev);
		g_pendingGamemode = ev;
		g_fwdCanStartGamemode = CreateForward(ET_Ignore);
		AddToForward(g_fwdCanStartGamemode, plugin, GetNativeFunction(1));
	}
	
	return true;
}

public int __EndGamemode(Handle plugin, int num_params)
{
	BBEvent ev = GetEvent(plugin, EventType_Gamemode, GetNativeCell(1));
	if (ev == null)
		return false;
	
	if (ev != g_activeGamemode)
		return false;
	
	RemoveActiveGamemodeFromMenu();
	if (g_pendingGamemode != null)
	{
		RemovePendingGamemodeFromMenu();
		AddActiveGamemodeToMenu(g_pendingGamemode);
		g_activeGamemode = g_pendingGamemode;
		g_pendingGamemode = null;
		Call_StartForward(g_fwdCanStartGamemode);
		Call_Finish();
	}
	else
	{
		g_activeGamemode = null;
		g_bCanStartEvents = true;
	}
	
	return true;
}

public int __IsPlayerFree(Handle plugin, int num_params)
{
	int client = GetNativeCell(1);
	if (client < 1 || client > MaxClients)
		return false;
		
	return IsClientFree(client);
}

public int __GrabPlayer(Handle plugin, int num_params)
{
	int client = GetNativeCell(1);
	if (client < 1 || client > MaxClients)
		return false;
		
	if (!IsClientFree(client))
		return false;

	BBEvent ev = GetEvent(plugin, GetNativeCell(2), GetNativeCell(3));
	if (ev == null)
		return false;
	
	if (!ev.Active)
		return false;
	
	SetClientEvent(client, ev);
	return true;
}

public int __FreePlayer(Handle plugin, int num_params)
{
	int client = GetNativeCell(1);
	if (client < 1 || client > MaxClients)
		return false;
	
	BBEvent ev = GetEvent(plugin, GetNativeCell(2), GetNativeCell(3));
	if (ev == null || GetClientEvent(client) != ev)
		return false;
		
	if (!ev.Active)
		return false;
		
	FreeClient(client);
	return true;
}

public int __FreeAllPlayers(Handle plugin, int num_params)
{
	BBEvent ev = GetEvent(plugin, GetNativeCell(1), GetNativeCell(2));
	if (ev == null)
		return false;
		
	if (!ev.Active)
		return false;
	
	FreeEvent(ev);
	return true;
}

bool IsClientFree(int client)
{
	return view_as<BBEvent>(g_players[client]) == null;
}

BBEvent GetClientEvent(int client)
{
	return view_as<BBEvent>(g_players[client]);
}

void SetClientEvent(int client, BBEvent ev)
{
	g_players[client] = ev;
	
	Call_StartForward(g_fwdOnPlayerBusy);
	Call_PushCell(client);
	Call_Finish();
}

void FreeClient(int client)
{
	g_players[client] = null;
		
	Call_StartForward(g_fwdOnPlayerFree);
	Call_PushCell(client);
	Call_Finish();
}

void FreeAllClients()
{
	for (int i = 1; i <= MaxClients; ++i)
		FreeClient(i);
}

void FreeEvent(BBEvent ev)
{
	for (int i = 1; i <= MaxClients; ++i)
		if (g_players[i] == ev)
			FreeClient(i);
}

/********************************************
				MENUS
********************************************/

void InitMenus()
{
	mn_main = new Menu(MenuHandler_Main, MENU_ACTIONS_DEFAULT);
	mn_main.SetTitle("Events Manager:");
	mn_main.Pagination = MENU_NO_PAGINATION;
	mn_main.ExitButton = true;
	mn_main.AddItem("", "Gamemodes");
	mn_main.AddItem("", "Events");
	mn_main.AddItem("", "ConVars description");
	
	mn_gamemodes = new Menu(MenuHandler_Gamemodes, MENU_ACTIONS_DEFAULT);
	mn_gamemodes.SetTitle("Gamemodes:");
	mn_gamemodes.ExitBackButton = true;
	
	mn_events = new Menu(MenuHandler_Events, MENU_ACTIONS_DEFAULT);
	mn_events.SetTitle("Events:");
	mn_events.ExitBackButton = true;
	
	//mn_custom = new Menu(MenuHandler_Custom, MENU_ACTIONS_DEFAULT);
	//mn_custom_save = new Menu(MenuHandler_CustomSave, MENU_ACTIONS_DEFAULT);
	//mn_custom_save_gamemodes = new Menu(MenuHandler_CustomSaveGamemodes, MENU_ACTIONS_DEFAULT);
	//mn_custom_save_events = new Menu(MenuHandler_CustomSaveEvents, MENU_ACTIONS_DEFAULT);
	//mn_custom_gamemodes = new Menu(MenuHandler_CustomGamemodes, MENU_ACTIONS_DEFAULT);
	//mn_custom_events = new Menu(MenuHandler_CustomEvents, MENU_ACTIONS_DEFAULT);
	
	//mn_commands = new Menu(MenuHandler_Commands, MENU_ACTIONS_DEFAULT);
	
	mn_convars = new Menu(MenuHandler_Convars, MENU_ACTIONS_DEFAULT);
	mn_convars.SetTitle("ConVars description:");
	mn_convars.ExitBackButton = true;
	mn_convars.AddItem("1", "Gamemodes");
	mn_convars.AddItem("2", "Events");
	
	mn_convars_gamemodes = new Menu(MenuHandler_ConvarsGamemodes, MENU_ACTIONS_DEFAULT);
	mn_convars_gamemodes.SetTitle("Gamemodes:");
	mn_convars_gamemodes.ExitBackButton = true;
	
	mn_convars_events = new Menu(MenuHandler_ConvarsEvents, MENU_ACTIONS_DEFAULT);
	mn_convars_events.SetTitle("Events:");
	mn_convars_events.ExitBackButton = true;
	
}

void AddPendingGamemodeToMenu(BBEvent ev)
{
	char name[MAX_STR_LEN], display[100];
	ev.Name.Get(name, MAX_STR_LEN);
	Format(display, 100, "Pending Gamemode:\n%s", name);
	mn_main.AddItem("5", display);
	mn_main.Cancel();
}

void RemovePendingGamemodeFromMenu()
{
	RemoveItem(mn_main, "5");
}

void AddActiveGamemodeToMenu(BBEvent ev)
{
	char name[MAX_STR_LEN], display[100];
	ev.Name.Get(name, MAX_STR_LEN);
	Format(display, 100, "Active Gamemode:\n%s", name);
	mn_main.AddItem("4", display, ITEMDRAW_DISABLED);
	mn_main.Cancel();
}

void RemoveActiveGamemodeFromMenu()
{
	RemoveItem(mn_main, "4");
}

void AddEventToMenu(Menu menu, BBEvent ev)
{
	char info[20], name[MAX_STR_LEN];
	Format(info, 20, "%d", ev);
	
	ev.Name.Get(name, MAX_STR_LEN);
	
	menu.AddItem(info, name);
	menu.Cancel();
}

void RemoveEventFromMenus(BBEvent ev, Menu menu1, Menu menu2)
{
	char str_ev[50];
	Format(str_ev, 50, "%d", ev);
	
	RemoveItem(menu1, str_ev);

	if (ev.ConVars.Length != 0)
	{
		RemoveItem(menu2, str_ev);
	}
}

void RemoveItem(Menu menu, char[] str_ev)
{
	char info[50], buff[50];
	int style;
	int sz = menu.ItemCount - 1;
	
	while (sz >= 0)
	{
		menu.GetItem(sz, info, 50, style, buff, 50);
		
		if (StrEqual(str_ev, info, false))
		{
			menu.RemoveItem(sz);
			break;
		}
		--sz;
	}
	
	menu.Cancel();
}

public int MenuHandler_Main(Menu menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_Select)
	{
		switch(param2)
		{
			case 0:
			{
				mn_gamemodes.Display(param1, MENU_TIME_FOREVER);
			}
			case 1:
			{
				mn_events.Display(param1, MENU_TIME_FOREVER);
			}
			case 2:
			{
				mn_convars.Display(param1, MENU_TIME_FOREVER);
			}
			default:
			{
				Menu mn_abort = new Menu(MenuHandler_Abort, MENU_ACTIONS_DEFAULT);
				mn_abort.ExitButton = false;
				mn_abort.SetTitle("Abort pending gamemode?");
				mn_abort.AddItem("", "Yes");
				mn_abort.AddItem("", "No");
				mn_abort.Display(param1, MENU_TIME_FOREVER);
			}
		}
	}
	
	return;
}

public int MenuHandler_Gamemodes(Menu menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_Select)
	{
		char info[100], name[100];
		int style;
		menu.GetItem(param2, info, 100, style, name, 100);
		
		BBEvent ev = view_as<BBEvent>(StringToInt(info));
		char cmd[MAX_STR_LEN];
		ev.StartCmd.Get(cmd, MAX_STR_LEN);
		ClientCommand(param1, cmd);
	}
	if (action == MenuAction_Cancel && param2 == MenuCancel_ExitBack)
		mn_main.Display(param1, MENU_TIME_FOREVER);
	
	return;
}

public int MenuHandler_Events(Menu menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_Select)
	{
		char info[100], name[100];
		int style;
		menu.GetItem(param2, info, 100, style, name, 100);
		
		BBEvent ev = view_as<BBEvent>(StringToInt(info));
		char cmd[MAX_STR_LEN];
		ev.StartCmd.Get(cmd, MAX_STR_LEN);
		ClientCommand(param1, cmd);
	}
	if (action == MenuAction_Cancel && param2 == MenuCancel_ExitBack)
		mn_main.Display(param1, MENU_TIME_FOREVER);
		
	return;
}

public int MenuHandler_Convars(Menu menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_Select)
	{
		if (param2 == 0 && mn_convars_gamemodes.ItemCount != 0)
		{
			mn_convars_gamemodes.Display(param1, MENU_TIME_FOREVER);
			return;
		}
		if (param2 == 1 && mn_convars_events.ItemCount != 0)
		{
			mn_convars_events.Display(param1, MENU_TIME_FOREVER);
			return;
		}
		mn_convars.Display(param1, MENU_TIME_FOREVER);
	}
	if (action == MenuAction_Cancel && param2 == MenuCancel_ExitBack)
		mn_main.Display(param1, MENU_TIME_FOREVER);
			
	return;
}

public int MenuHandler_ConvarsGamemodes(Menu menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_Select)
	{
		char info[100], name[100];
		int style;
		menu.GetItem(param2, info, 100, style, name, 100);
		
		BBEvent ev = view_as<BBEvent>(StringToInt(info));
		ev.ConVarsMenu.Display(param1, MENU_TIME_FOREVER);
	}
	if (action == MenuAction_Cancel && param2 == MenuCancel_ExitBack)
		mn_convars.Display(param1, MENU_TIME_FOREVER);
		
	return;
}

public int MenuHandler_ConvarsEvents(Menu menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_Select)
	{
		char info[100], name[100];
		int style;
		menu.GetItem(param2, info, 100, style, name, 100);
		
		BBEvent ev = view_as<BBEvent>(StringToInt(info));
		ev.ConVarsMenu.Display(param1, MENU_TIME_FOREVER);
	}
	if (action == MenuAction_Cancel && param2 == MenuCancel_ExitBack)
		mn_convars.Display(param1, MENU_TIME_FOREVER);

	return;
}

public int MenuHandler_ConvarsDynamic(Menu menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_Select)
	{
		char info[200], name[100];
		int style;
		menu.GetItem(param2, info, 200, style, name, 100);
		
		PrintToChat(param1, info);
		menu.Display(param1, MENU_TIME_FOREVER);
	}
	if (action == MenuAction_Cancel && param2 == MenuCancel_ExitBack)
	{
		char info[200], name[100];
		int style;
		menu.GetItem(0, info, 200, style, name, 100);
		if (StringToInt(info) == 0)
			mn_convars_gamemodes.Display(param1, MENU_TIME_FOREVER);
		else
			mn_convars_events.Display(param1, MENU_TIME_FOREVER);
	}
		
	return;
}

public int MenuHandler_Abort(Menu menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_Select)
	{
		if (param2 == 0 && g_pendingGamemode != null)
		{
			RemovePendingGamemodeFromMenu();
			if (g_activeGamemode == null)
				g_bCanStartEvents = true;
			g_pendingGamemode = null;
			CloseHandle(g_fwdCanStartGamemode);
		}
		mn_main.Display(param1, MENU_TIME_FOREVER);
	}
	if (action == MenuAction_End || action == MenuAction_Cancel)
		delete menu;
	
	return;
}
