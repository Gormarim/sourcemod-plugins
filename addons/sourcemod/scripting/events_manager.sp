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


#define CREATE_NATIVE(%1) CreateNative(#%1, __%1)
#define NATIVE(%1) public int __%1(Handle plugin, int num_params)
#define MAX_STR_LEN 64

#include "events_manager/structs.sp"

ArrayList g_pluginsList;
StringMap g_pluginsMap;

BBEvent g_players[33];
BBEvent g_activeGamemode;
BBEvent g_pendingGamemode;
ArrayList g_activeEvents;
bool g_bCanStartEvents;

Handle g_fwdCheckStatus;
Handle g_fwdOnPlayerFree;
Handle g_fwdOnPlayerBusy;
Handle g_fwdCanStartGamemode;

Handle g_timerCheckStatus;

Menu mn_convars;
Menu mn_convars_gamemodes;
Menu mn_convars_events;


public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{	
	CREATE_NATIVE(RegPlugin);
	CREATE_NATIVE(UnloadPlugin);
	CREATE_NATIVE(RegEvent);
	CREATE_NATIVE(SetEventName);
	CREATE_NATIVE(SetEventMainCmd);
	CREATE_NATIVE(SetEventInfoCmd);
	CREATE_NATIVE(RegEventConVar);
	CREATE_NATIVE(StartEvent);
	CREATE_NATIVE(EndEvent);
	CREATE_NATIVE(IsPlayerFree);
	CREATE_NATIVE(GrabPlayer);
	CREATE_NATIVE(FreePlayer);
	CREATE_NATIVE(FreeAllPlayers);
	
	CREATE_NATIVE(EMValid);
	
	RegPluginLibrary("bs_events_manager");
	return APLRes_Success;
}

public void OnPluginStart()
{
	g_bCanStartEvents = false;
	
	g_pluginsList = new ArrayList();
	g_pluginsMap = new StringMap();
	
	g_activeEvents = new ArrayList();
	g_activeGamemode = null;
	g_pendingGamemode = null;
	
	for (int i = 0; i < 33; ++i)
		g_players[i] = null;
	
	g_fwdCheckStatus = CreateForward(ET_Ignore);
	g_fwdOnPlayerFree = CreateGlobalForward("OnPlayerFree", ET_Ignore, Param_Cell);
	g_fwdOnPlayerBusy = CreateGlobalForward("OnPlayerBusy", ET_Ignore, Param_Cell);
	
	InitMenus();
	
	RegConsoleCmd("sm_events", EventsMenu);
}

public void OnMapStart()
{
	g_bCanStartEvents = true;
	g_timerCheckStatus = CreateTimer(5.0, CheckStatus, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
}

public void OnMapEnd()
{
	g_bCanStartEvents = false;
	g_activeGamemode = null;
	g_pendingGamemode = null;
	
	BBEvent ev;
	int len = g_activeEvents.Length;
	for (int i = 0; i < len; ++i)
	{
		ev = g_activeEvents.Get(i);
		ev.Active = false;
	}
	
	for (int i = 0; i < 33; ++i)
		g_players[i] = null;
}

public Action EventsMenu(int client, int args)
{
	if (client == 0 || !IsValidEntity(client) || !IsClientInGame(client) || IsFakeClient(client))
		return Plugin_Handled;
		
	GetMainMenu(client).Display(client, MENU_TIME_FOREVER);
		
	return Plugin_Handled;
}

/**
 * Status check 
**/

public Action CheckStatus(Handle timer)
{
	Call_StartForward(g_fwdCheckStatus);
	Call_Finish();
	
	PluginData pd;
	int pos = g_pluginsList.Length - 1;
	while (pos >= 0)
	{
		pd = g_pluginsList.Get(pos);
		if (pd.Status)
			pd.Status = false;
		else
		{	
			char str_plugin[12];
			Format(str_plugin, 12, "%d", pd.Plugin);
			g_pluginsMap.Remove(str_plugin);
			g_pluginsList.Erase(pos);
			DeletePluginData(pd);
		}	
		--pos;
	}

	return Plugin_Continue;
}

NATIVE(EMValid)
{
	char str_plugin[12];
	Format(str_plugin, 12, "%d", plugin);
	PluginData pd;
	
	if (g_pluginsMap.GetValue(str_plugin, pd))
		pd.Status = true;
	
	return;
}

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
			g_pluginsList.Push(pd);
			AddToForward(g_fwdCheckStatus, plugin, GetFunctionByName(plugin, "EMCheckStatus"));
		}
	}
	
	return pd;
}

void DeletePluginData(PluginData pd)
{
	BBEvent ev;
	ArrayList list = pd.EventsList;
	int len = list.Length;
	for (int i = 0; i < len; ++i)
	{
		ev = list.Get(i);
		if (ev == g_pendingGamemode)
		{
			if (g_activeGamemode == null)
				g_bCanStartEvents = true;
			g_pendingGamemode = null;
			CloseHandle(g_fwdCanStartGamemode);
		}
		else if (ev == g_activeGamemode)
		{
			if (g_pendingGamemode != null && ev.Plugin != g_pendingGamemode.Plugin)
			{
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
		
		FreeEvent(ev);
		
		if (ev.ConVars != null)
		{
			if (ev.Name != null)
			{
				char str_ev[20];
				Format(str_ev, 20, "%d", ev);
				if (ev.Type == EventType_Gamemode)
					RemoveItem(mn_convars_gamemodes, str_ev);
				else
					RemoveItem(mn_convars_events, str_ev);
			}
			
			delete ev.ConVarsMenu;
			delete ev.ConVars;
		}
		
		if (ev.Name != null)
			delete ev.Name;
		if (ev.MainCmd != null)
			delete ev.MainCmd;
		if (ev.InfoCmd != null)
			delete ev.InfoCmd;
		
		delete ev;
	}
	
	delete list;
	delete pd.EventsMap;
	delete pd;
}

BBEvent GetEvent(Handle plugin, int id)
{
	PluginData pd = GetPluginData(plugin);
	if (pd == null)
		return null;
	
	char str_id[12];
	Format(str_id, 12, "%d", id);
	BBEvent ev = null;
	pd.EventsMap.GetValue(str_id, ev);
		
	return ev;
}

/**
 * Natives
 *
 * native bool:RegPlugin();
**/
NATIVE(RegPlugin)
{
	bool exist;
	GetPluginData(plugin, true, exist);
	return !exist;
}

/**
 * native bool:UnloadPlugin();
**/
NATIVE(UnloadPlugin)
{	
	PluginData pd = GetPluginData(plugin);
	if (pd == null)
		return false;
	
	char str_plugin[12];
	Format(str_plugin, 12, "%d", plugin);
	
	g_pluginsMap.Remove(str_plugin);
	g_pluginsList.Erase(g_pluginsList.FindValue(pd));
	DeletePluginData(pd);
	return true;
}

/**
 * native bool:RegEvent(EventType:type, id, const String:name[] = "")
**/
NATIVE(RegEvent)
{	
	PluginData pd = GetPluginData(plugin);
	if (pd == null)
		return -1;
	
	int len;
	GetNativeStringLength(2, len);
	
	char name[MAX_STR_LEN];
	GetNativeString(2, name, MAX_STR_LEN);
	
	EventType type = GetNativeCell(1);
	int id = (pd.CurrentId)++;
	
	BBEvent ev = new BBEvent(plugin, type, id);
	
	char str_id[12];
	Format(str_id, 12, "%d", id);
	pd.EventsMap.SetValue(str_id, ev);
	pd.EventsList.Push(ev);
	
	if (len != 0)
		ev.Name = new StringProp(name);
	
	return id;
}

/**
 * native bool:SetEventName(id, const String:name[])
**/
NATIVE(SetEventName)
{
	int id = GetNativeCell(1);
	BBEvent ev = GetEvent(plugin, id);
	if (ev == null)
		return false;
		
	int len;
	GetNativeStringLength(2, len);
	if (len == 0)
	{
		if (ev.Name == null)
			return true;
			
		delete ev.Name;
		ev.Name = null;
		
		if (ev.ConVars != null)
			RemoveEventFromConvarsMenu(ev);
		
		return true;
	}
	
	char name[MAX_STR_LEN];
	GetNativeString(2, name, MAX_STR_LEN);
	
	if (ev.Name == null)
		ev.Name = new StringProp(name);
	else
	{
		ev.Name.Set(name);
		RemoveEventFromConvarsMenu(ev);
	}
		
	AddEventToConvarsMenu(ev);
	
	return true;
}

/**
 * native bool:RegEventMainCmd(id, const String:cmd[])
**/
NATIVE(SetEventMainCmd)
{
	int id = GetNativeCell(1);
	BBEvent ev = GetEvent(plugin, id);
	if (ev == null)
		return false;
	
	int len;
	GetNativeStringLength(2, len);
	
	if (len == 0)
	{
		if (ev.MainCmd == null)
			return true;
			
		delete ev.MainCmd;
		ev.MainCmd = null;
		return true;
	}
	
	char cmd[MAX_STR_LEN];
	GetNativeString(2, cmd, MAX_STR_LEN);
	
	if (ev.MainCmd == null)
		ev.MainCmd = new StringProp(cmd);
	else
		ev.MainCmd.Set(cmd);
	
	return true;
}

/**
 * native bool:RegEventInfoCmd(id, const String:cmd[])
**/
NATIVE(SetEventInfoCmd)
{
	int id = GetNativeCell(1);
	BBEvent ev = GetEvent(plugin, id);
	if (ev == null)
		return false;
		
	int len;
	GetNativeStringLength(2, len);
	if (len == 0)
	{
		if (ev.InfoCmd == null)
			return true;
		
		delete ev.InfoCmd;
		ev.InfoCmd = null;
		return true;
	}
	
	char cmd[MAX_STR_LEN];
	GetNativeString(2, cmd, MAX_STR_LEN);
	
	if (ev.InfoCmd == null)
		ev.InfoCmd = new StringProp(cmd);
	else
		ev.InfoCmd.Set(cmd);
	
	return true;
}

/**
 * native bool:RegEventConVar(id, const String:name[], const String:description[])
**/
NATIVE(RegEventConVar)
{
	int len;
	GetNativeStringLength(2, len);
	if (len == 0)
		return false;
		
	char name[MAX_STR_LEN], description[500];
	GetNativeString(2, name, MAX_STR_LEN);
	GetNativeString(3, description, 500);
	
	ConVar cv = FindConVar(name);
	if (cv == null)
		return false;
	
	int id = GetNativeCell(1);
	BBEvent ev = GetEvent(plugin, id);
	if (ev == null)
		return false;
		
	if (ev.ConVars == null)
	{
		ev.ConVars = new ArrayList();
		
		char ev_name[MAX_STR_LEN], title[200];
		ev.Name.Get(ev_name, MAX_STR_LEN);
		Format(title, 200, "%s ConVars:", ev_name);
		
		Menu mn_cvs = new Menu(MenuHandler_ConvarsDynamic, MENU_ACTIONS_DEFAULT);
		mn_cvs.SetTitle(title);
		mn_cvs.ExitBackButton = true;
	
		ev.ConVarsMenu = mn_cvs;
		if (ev.Name != null)
			AddEventToConvarsMenu(ev);
	}
	
	if (ev.ConVars.FindValue(cv) != -1)
		return false;
	
	ev.ConVarsMenu.AddItem(description, name);
	ev.ConVarsMenu.Cancel();
	ev.ConVars.Push(cv);
	
	return true;
}

/**
 * native bool:StartEvent(id, StartGamemodeCB:callback = INVALID_FUNCTION)
**/
typedef StartGamemodeCB = function void ();

NATIVE(StartEvent)
{
	int id = GetNativeCell(1);
	BBEvent ev = GetEvent(plugin, id);
	if (ev == null)
		return false;
	
	StartGamemodeCB callback = view_as<StartGamemodeCB>(GetNativeFunction(2));
	
	if (ev.Type == EventType_Gamemode)
	{
		if (callback == INVALID_FUNCTION)
			return false;
			
		return StartGamemode(callback, ev, plugin);
	}
	
	if (!g_bCanStartEvents)
		return false;
	
	if (ev.Active)
		return false;
		
	ev.Active = true;
	g_activeEvents.Push(ev);
	
	return true;
}

bool StartGamemode(StartGamemodeCB callback, BBEvent ev, Handle plugin)
{
	if (g_pendingGamemode != null)
		return false;
	
	if (g_activeGamemode == ev)
		return false;
	
	g_bCanStartEvents = false;
	if (g_activeGamemode == null && g_activeEvents.Length == 0)
	{
		g_activeGamemode = ev;
		Call_StartFunction(plugin, callback);
		Call_Finish();
	}
	else
	{
		g_pendingGamemode = ev;
		g_fwdCanStartGamemode = CreateForward(ET_Ignore);
		AddToForward(g_fwdCanStartGamemode, plugin, callback);
	}
	
	return true;
}

/**
 * native bool:EndEvent(id)
**/
NATIVE(EndEvent)
{
	int id = GetNativeCell(1);
	BBEvent ev = GetEvent(plugin, id);
	if (ev == null)
		return false;
	
	if (ev.Type == EventType_Gamemode)
		return EndGamemode(ev);
	
	if (!ev.Active)
		return false;
	
	ev.Active = false;
	g_activeEvents.Erase(g_activeEvents.FindValue(ev));
	FreeEvent(ev);
	
	if (g_pendingGamemode != null && g_activeGamemode == null && g_activeEvents.Length == 0)
	{
		g_activeGamemode = g_pendingGamemode;
		g_pendingGamemode = null;
		Call_StartForward(g_fwdCanStartGamemode);
		Call_Finish();
		CloseHandle(g_fwdCanStartGamemode);
	}
	
	return true;
}

bool EndGamemode(BBEvent ev)
{
	if (ev != g_activeGamemode)
		return false;
	
	if (g_pendingGamemode != null)
	{
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
	
	return true;
}

/**
 * native bool:IsPlayerFree(client);
**/
NATIVE(IsPlayerFree)
{
	int client = GetNativeCell(1);
	if (client < 1 || client > MaxClients)
		return false;
		
	return g_players[client] == null;
}

/**
 * native bool:GrabPlayer(id, client)
**/
NATIVE(GrabPlayer)
{
	int client = GetNativeCell(2);
	if (client < 1 || client > MaxClients)
		return false;
		
	if (g_players[client] != null)
		return false;
	
	int id = GetNativeCell(1);
	BBEvent ev = GetEvent(plugin, id);
	if (ev == null)
		return false;
	
	if (!ev.Active)
		return false;
	
	g_players[client] = ev;
	Call_StartForward(g_fwdOnPlayerBusy);
	Call_PushCell(client);
	Call_Finish();
	
	return true;
}

/**
 * native bool:FreePlayer(id, client)
**/
NATIVE(FreePlayer)
{
	int client = GetNativeCell(2);
	if (client < 1 || client > MaxClients)
		return false;
	
	int id = GetNativeCell(1);
	BBEvent ev = GetEvent(plugin, id);
	if (ev == null || g_players[client] != ev)
		return false;
		
	if (!ev.Active)
		return false;
		
	FreeClient(client);
	return true;
}

/**
 * native bool:FreeAllPlayers(id);
**/
NATIVE(FreeAllPlayers)
{
	int id = GetNativeCell(1);
	BBEvent ev = GetEvent(plugin, id);
	if (ev == null)
		return false;
		
	if (!ev.Active)
		return false;
	
	FreeEvent(ev);
	return true;
}

void FreeClient(int client)
{
	g_players[client] = null;
		
	Call_StartForward(g_fwdOnPlayerFree);
	Call_PushCell(client);
	Call_Finish();
}

void FreeEvent(BBEvent ev)
{
	for (int i = 1; i <= MaxClients; ++i)
		if (g_players[i] == ev)
			FreeClient(i);
}

/**
 * MENUS
**/
void InitMenus()
{	
	mn_convars = new Menu(MenuHandler_Convars, MENU_ACTIONS_DEFAULT);
	mn_convars.SetTitle("ConVars description:");
	mn_convars.ExitBackButton = true;
	mn_convars.AddItem("0", "Gamemodes");
	mn_convars.AddItem("1", "Events");
	
	mn_convars_gamemodes = new Menu(MenuHandler_ConvarsEvents, MENU_ACTIONS_DEFAULT);
	mn_convars_gamemodes.SetTitle("Gamemodes:");
	mn_convars_gamemodes.ExitBackButton = true;
	
	mn_convars_events = new Menu(MenuHandler_ConvarsEvents, MENU_ACTIONS_DEFAULT);
	mn_convars_events.SetTitle("Events:");
	mn_convars_events.ExitBackButton = true;
}

void AddEventToConvarsMenu(BBEvent ev)
{
	char str_ev[20], name[MAX_STR_LEN];
	Format(str_ev, 20, "%d", ev);
	ev.Name.Get(name, MAX_STR_LEN);
	if (ev.Type == EventType_Gamemode)
		mn_convars_gamemodes.AddItem(str_ev, name);
	else
		mn_convars_events.AddItem(str_ev, name);		
}

void RemoveEventFromConvarsMenu(BBEvent ev)
{
	char str_ev[20];
	Format(str_ev, 20, "%d", ev);
	if (ev.Type == EventType_Gamemode)
		RemoveItem(mn_convars_gamemodes, str_ev);
	else
		RemoveItem(mn_convars_events, str_ev);
}
		
void RemoveItem(Menu menu, char[] unique_item_info)
{
	char item_info[50], buff[50];
	int style;
	int sz = menu.ItemCount - 1;
	
	while (sz >= 0)
	{
		menu.GetItem(sz, item_info, 50, style, buff, 50);
		
		if (StrEqual(unique_item_info, item_info, false))
		{
			menu.RemoveItem(sz);
			break;
		}
		--sz;
	}
	
	menu.Cancel();
}

Menu GetMainMenu(int client)
{
	Menu mn_main = new Menu(MenuHandler_Main, MENU_ACTIONS_DEFAULT);
	mn_main.SetTitle("Events menu:");
	mn_main.Pagination = false;
	mn_main.ExitButton = true;
	
	mn_main.AddItem("0", "Gamemodes");
	mn_main.AddItem("1", "Events");
	if (g_activeEvents.Length != 0 || g_activeGamemode != null || g_pendingGamemode != null)
		mn_main.AddItem("2", "Active Events");
	AdminId adm = GetUserAdmin(client);
	if (adm != INVALID_ADMIN_ID && GetAdminFlag(adm, Admin_Convars))
		mn_main.AddItem("3", "Convars");
	
	return mn_main;
}

Menu GetEventsMenu(EventType type, int client)
{
	Menu menu = new Menu(MenuHandler_Events, MENU_ACTIONS_DEFAULT);
	menu.ExitBackButton = true;
	menu.ExitButton = false;
	if (type == EventType_Gamemode)
		menu.SetTitle("Gamemodes:");
	else
		menu.SetTitle("Events:");
	
	char name[MAX_STR_LEN], cmd[MAX_STR_LEN];
	PluginData pd;
	BBEvent ev;
	ArrayList events;
	int len_events;
	int len_plugins = g_pluginsList.Length;
	
	for (int i = 0; i < len_plugins; ++i)
	{
		pd = g_pluginsList.Get(i);
		events = pd.EventsList;
		len_events = events.Length;
		
		for (int j = 0; j < len_events; ++j)
		{
			ev = events.Get(j);
			if (ev.Type != type || ev.Name == null || ev.MainCmd == null)
				continue;
			
			ev.MainCmd.Get(cmd, MAX_STR_LEN);
			
			if (!CheckCommandAccess(client, cmd, ADMFLAG_GENERIC))
				continue;
			
			ev.Name.Get(name, MAX_STR_LEN);
			
			menu.AddItem(cmd, name);
		}
	}
	
	if (menu.ItemCount == 0)
	{
		delete menu;
		return null;
	}
	
	return menu;
}

Menu GetActiveEventsMenu(int client)
{
	Menu menu = new Menu(MenuHandler_ActiveEvents, MENU_ACTIONS_DEFAULT);
	menu.SetTitle("Active events:");
	menu.ExitButton = false;
	menu.ExitBackButton = true;
	
	char name[MAX_STR_LEN], cmd[MAX_STR_LEN];
	if (g_pendingGamemode != null && g_pendingGamemode.Name != null && g_pendingGamemode.InfoCmd != null)
	{
		g_pendingGamemode.InfoCmd.Get(cmd, MAX_STR_LEN);
		
		if (CheckCommandAccess(client, cmd, ADMFLAG_GENERIC))
		{
			g_pendingGamemode.Name.Get(name, MAX_STR_LEN);
		
			char display[200];
			Format(display, 200, "Pending gamemode:\n%s", name);
			menu.AddItem(cmd, display);
		}
	}
	
	if (g_activeGamemode != null && g_activeGamemode.Name != null && g_activeGamemode.InfoCmd != null)
	{
		g_activeGamemode.InfoCmd.Get(cmd, MAX_STR_LEN);
		if (CheckCommandAccess(client, cmd, ADMFLAG_GENERIC))
		{
			g_activeGamemode.Name.Get(name, MAX_STR_LEN);
			
			char display[100];
			Format(display, 100, "Active gamemode:\n%s", name);
			
			if (menu.ItemCount == 0)
				menu.AddItem(cmd, display);
			else
				menu.InsertItem(0, cmd, display);
		}
	}
	
	BBEvent ev;
	int len = g_activeEvents.Length;
	for (int i = 0; i < len; ++i)
	{
		ev = g_activeEvents.Get(i);
		if (ev.Name == null || ev.InfoCmd == null)
			continue;
		
		ev.InfoCmd.Get(cmd, MAX_STR_LEN);
		if (!CheckCommandAccess(client, cmd, ADMFLAG_GENERIC))
			continue;
		
		ev.Name.Get(name, MAX_STR_LEN);
		menu.AddItem(cmd, name);
	}
	
	if (menu.ItemCount == 0)
	{
		delete menu;
		return null;
	}
	
	return menu;
}
			
public int MenuHandler_Main(Menu menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_Select)
	{
		char info[10], name[10];
		int style;
		menu.GetItem(param2, info, 10, style, name, 10);
		
		int id = StringToInt(info);
		if (id == 0 || id == 1)
		{
			Menu mn_events = GetEventsMenu(view_as<EventType>(id), param1);
			if (mn_events == null)
				menu.Display(param1, MENU_TIME_FOREVER);
			else
				mn_events.Display(param1, MENU_TIME_FOREVER);
		}
		else if (id == 2)
		{
			Menu mn_active_events = GetActiveEventsMenu(param1);
			if (mn_active_events == null)
				menu.Display(param1, MENU_TIME_FOREVER);
			else
				mn_active_events.Display(param1, MENU_TIME_FOREVER);
		}
		else
			mn_convars.Display(param1, MENU_TIME_FOREVER);
	}
	
	return;
}

public int MenuHandler_Events(Menu menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_Select)
	{
		char cmd[100], name[100];
		int style;
		menu.GetItem(param2, cmd, 100, style, name, 100);
		
		ClientCommand(param1, cmd);
	}
	if (action == MenuAction_Cancel && param2 == MenuCancel_ExitBack)
		GetMainMenu(param1).Display(param1, MENU_TIME_FOREVER);
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
		GetMainMenu(param1).Display(param1, MENU_TIME_FOREVER);
			
	return;
}

public int MenuHandler_ConvarsEvents(Menu menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_Select)
	{
		char str_ev[100], name[100];
		int style;
		menu.GetItem(param2, str_ev, 100, style, name, 100);
		
		BBEvent ev = view_as<BBEvent>(StringToInt(str_ev));
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
		char desc[200], name[100];
		int style;
		menu.GetItem(param2, desc, 200, style, name, 100);
		
		PrintToChat(param1, desc);
		menu.Display(param1, MENU_TIME_FOREVER);
	}
	if (action == MenuAction_Cancel && param2 == MenuCancel_ExitBack)
		mn_convars.Display(param1, MENU_TIME_FOREVER);
		
	return;
}

public int MenuHandler_ActiveEvents(Menu menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_Select)
	{
		char cmd[100], name[100];
		int style;
		menu.GetItem(param2, cmd, 100, style, name, 100);
		
		ClientCommand(param1, cmd);
	}
	if (action == MenuAction_Cancel && param2 == MenuCancel_ExitBack)
		GetMainMenu(param1).Display(param1, MENU_TIME_FOREVER);
	
	return;
}
