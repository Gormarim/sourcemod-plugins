////////////////////////////////////
// start game with admin command /ex2_start
// players inside arena will automatically join the game
// death of player = new round, dead player leaves the arena
// 
// <number of players - 1> rounds, damage protection from non-participants, walls around arena
////////////////////////////////////


///!TODO
//
//1. Test with 3 players and more


#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#undef REQUIRE_PLUGIN
#include <events_manager>

public Plugin myinfo = 
{
	name = "Weakestling",
	author = "Crystal",
	description = "Event Manager example plugin №2",
	version = "0.9",
	url = ""
};

//////////////////////////////////
//								//
//		Const and Params		//
//								//
//////////////////////////////////

#define PI 3.1415926535897932384626433832795
// Arena coords for ffa_community:
//setpos_exact 1336.583862 -232.183472 196.031250
//setpos_exact 1332.539673 486.757355 196.031250

//wall 1: wlh:	 	270 8 208
//		: origin: 	1312 -236 292

//wall 2: wlh:	 	270 8 208
//		: origin: 	1312 492 292

#define ARENA_WALL_1_X 1312.0
#define ARENA_WALL_1_Y -236.0
#define ARENA_WALL_1_Z 292.0
#define ARENA_WALL_1_W 270.0
#define ARENA_WALL_1_L 8.0
#define ARENA_WALL_1_H 208.0

#define ARENA_WALL_2_X 1312.0
#define ARENA_WALL_2_Y 492.0
#define ARENA_WALL_2_Z 292.0
#define ARENA_WALL_2_W 270.0
#define ARENA_WALL_2_L 8.0
#define ARENA_WALL_2_H 208.0

#define ARENA_CENTRE_X 1312.0
#define ARENA_CENTRE_Y 128.0
#define ARENA_CENTRE_Z 135.0   // = spawn Z

#define ARENA_SPAWN_RADIUS 128.0

#define ARENA_WALL_WIDTH 4.0
#define ARENA_WALL_SEG 2 //number of brushes for 1 arena

//////////////////////////
//						//
//		Global Vars		//
//						//
//////////////////////////

int g_wall[ARENA_WALL_SEG];
//int g_round;
bool g_bMapIsCorrect;
//float vecArenaCenter[3] = {ARENA_CENTRE_X, ARENA_CENTRE_Y, ARENA_CENTRE_Z};  <- only for circle arenas
bool g_bGameStarted;
bool g_bIsPlaying[MAXPLAYERS + 1];
bool g_bManager;
int g_playerCount;



//////////////////////////////
//							//
//		Initialization		//
//							//
//////////////////////////////
public OnPluginStart() 
{ 
	RegAdminCmd("ex2_test", Test, Admin_RCON);
	RegAdminCmd("ex2_start", Start, Admin_RCON);
	
	HookEvent("player_death", PlayerDeath);
	
	g_bGameStarted = false;
}

public OnMapStart()
{
	////////test beams//
	PrecacheModel("materials/particle/dys_beam3.vmt");
	PrecacheModel("materials/particle/dys_beam_big_rect.vmt");
	/////// test beams//
	
	g_bManager = LibraryExists("bs_events_manager");
	char MapName[64];
	GetCurrentMap(MapName, sizeof(MapName));
		
	if (StrEqual("ffa_community", MapName, false))
	{
		if (g_bManager)
			RegEvent("ex2_start", "Weakestling");
		g_bMapIsCorrect = true;
	}
	else
	{
		g_bMapIsCorrect = false;
	}
}

//////////////////////
//					//
//		Main		//
//					//
//////////////////////

public Action:Start(client, args) 
{	
	if (g_bMapIsCorrect && !g_bGameStarted)
	{
		if (g_bManager)
			StartEvent();
		g_playerCount = 0;
		for (int i = 1; i < MaxClients; i++)
		{
			g_bIsPlaying[i] = false;
			if (IsValidClient(i))
			{
				if (!IsInDuel(i))
				{
					float vecPosition[3];
					GetClientAbsOrigin(i, vecPosition);
					//PrintToServer("--DEBUG-- Dist = %3.3f", GetDistanceHor(vecArenaCenter, vecPosition));
					//if (GetDistanceHor(vecArenaCenter, vecPosition) <= ARENA_SPAWN_RADIUS*2.5)
					
					if ((vecPosition[2] <= 377.0) && (vecPosition[2] >= 116.0)
						&& (vecPosition[1] <= 480.0) && (vecPosition[1] >= -224.0)
						&& (vecPosition[0] <= 1824.0) && (vecPosition[0] >= 800.0))
					{
						if (!g_bManager || (g_bManager && GrabPlayer(i, EventType_Event)))
						{
							g_bIsPlaying[i] = true;
							SDKHook(i, SDKHook_OnTakeDamage, OnTakeDamage);
							g_playerCount++;
						}
					}
				}
			}
		}
		if (g_playerCount > 1)
		{
			g_bGameStarted = true;
			StartingTeleport();
			
			CreateWalls();
		}
		else
		{
			if (g_bManager)
				EndEvent();
			PrintToChat(client, "\x03[EX2]\x01 Not enough players on the Arena!");
		}
	}
	
	return Plugin_Handled;
}

StartingTeleport()
{
	int playerI = 0;
	for (int i = 1; i < MaxClients; i++)
	{
		if (g_bIsPlaying[i])
		{
			if (IsValidClient(i))
			{
				playerI++;
				
				float vecStartPos[3];
				float vecStartDir[3]; 
				
				vecStartPos[0] = ARENA_CENTRE_X + Cosine(2.0*PI*(playerI-1) / g_playerCount) *ARENA_SPAWN_RADIUS;
				vecStartPos[1] = ARENA_CENTRE_Y + Sine(2.0*PI*(playerI-1) / g_playerCount) *ARENA_SPAWN_RADIUS;
				vecStartPos[2] = ARENA_CENTRE_Z
				vecStartDir[0] = 10.0;
				vecStartDir[1] = float(RoundFloat(180.0 + 360.0*(i-1) / g_playerCount) % 360);
				vecStartDir[2] = 0.0;
				TeleportEntity( i, vecStartPos, vecStartDir, NULL_VECTOR );
				
				//PrintToServer("--DEBUG-- pos[%d] = <%3.3f, %3.3f, %3.3f>", i, vecStartPos[0], vecStartPos[1], vecStartPos[2]);
				//PrintToServer("--DEBUG-- dir[%d] = <%3.3f, %3.3f, %3.3f>", i, vecStartDir[0], vecStartDir[1], vecStartDir[2]);
			
				//Heal
				SetVariantInt(100);
				AcceptEntityInput(i, "SetHealth");
			}
		
		}
	}
}

public PlayerDeath(Handle:event, const String:name[], bool:dontBroadcast)
{
	int victim = GetClientOfUserId(GetEventInt(event, "userid"));
	if (g_bIsPlaying[victim])
	{
		g_bIsPlaying[victim] = false;
		NextRound(victim);
	}
}

public OnClientDisconnect(client)
{
	//PrintToServer("--DEBUG-- Disconnect!");
	if (g_bIsPlaying[client])
	{
		NextRound(client);
	}
}

NextRound(client)
{
	//client - player who died first
	g_bIsPlaying[client] = false;
	if (g_bManager)
		FreePlayer(client, EventType_Event);
	g_playerCount--;
	SDKUnhook(client, SDKHook_OnTakeDamage, OnTakeDamage);
	
	if (IsValidClient(client))
	{
		char clientName[64];
		GetClientName(client, clientName, sizeof(clientName));
		for (int i = 1; i < MaxClients; i++)
		{
			if (g_bIsPlaying[i])
			{
				PrintToChat(i, "\x03[EX2] %s died", clientName);
			}
		}
	}
	
	if (g_playerCount > 1)
	{
		StartingTeleport();
	}
	else
	{
		//find winner
		for (int i = 1; i < MaxClients; i++)
		{
			if (g_bIsPlaying[i])
			{
				char winner[32];
				GetClientName(i, winner, sizeof(winner));
				PrintToChatAll("\x03[EX2]\x01 %s wins!", winner);
				g_bGameStarted = false;
				break;
			}
		}
		
		if (g_bManager)
			EndEvent();
		RemoveWalls();
	}
	
}
CreateWalls()
{
	//wall 1
	{
		float maxBounds[3];
		maxBounds[0] = ARENA_WALL_1_W/2.0;
		maxBounds[1] = ARENA_WALL_1_L/2.0;
		maxBounds[2] = ARENA_WALL_1_H/2.0;
		float minBounds[3];
		minBounds[0] = - ARENA_WALL_1_W/2.0;
		minBounds[1] = - ARENA_WALL_1_L/2.0;
		minBounds[2] = - ARENA_WALL_1_H/2.0;
		float vecOrigin[3] = { ARENA_WALL_1_X, ARENA_WALL_1_Y, ARENA_WALL_1_Z};
			
		g_wall[0] = CreateBrush(vecOrigin, /*vecDir,*/ minBounds, maxBounds);
	}
	//wall 2
	{
		float maxBounds[3];
		maxBounds[0] = ARENA_WALL_2_W/2.0;
		maxBounds[1] = ARENA_WALL_2_L/2.0;
		maxBounds[2] = ARENA_WALL_2_H/2.0;
		float minBounds[3];
		minBounds[0] = - ARENA_WALL_2_W/2.0;
		minBounds[1] = - ARENA_WALL_2_L/2.0;
		minBounds[2] = - ARENA_WALL_2_H/2.0;
		
		float vecOrigin[3] = { ARENA_WALL_2_X, ARENA_WALL_2_Y, ARENA_WALL_2_Z};
			
		g_wall[1] = CreateBrush(vecOrigin, /*vecDir,*/ minBounds, maxBounds);
	}
}

RemoveWalls()
{
	for (int i; i < ARENA_WALL_SEG; i++)
	{	
		if (g_wall[i] > 32)
			if (IsValidEdict(g_wall[i]))
			{
				AcceptEntityInput(g_wall[i], "Deactivate");
				AcceptEntityInput(g_wall[i], "Kill");
			}
	}
		
}
//Block damage from external sources
public Action:OnTakeDamage(victim, &attacker, &inflictor, &Float:damage, &damagetype, &weapon, Float:damageForce[3], Float:damagePosition[3], damagecustom)
{
	if (damage <= 0.0)
		return Plugin_Continue;
	
	if (!g_bGameStarted)
		return Plugin_Continue;
	
	if (!g_bIsPlaying[victim])
		return Plugin_Continue;
	
	if (1 <= attacker && attacker <= MaxClients)
	{
		if (!g_bIsPlaying[attacker])
		{
			// if attacker could be a player and he is not in this event
			damage = 0.0;
			return Plugin_Handled;
		}
	}
	return Plugin_Continue;
}

//Block duels for participants
public Action:OnClientCommand(client, args)
{
	if (g_bGameStarted)
	{
		if (g_bIsPlaying[client])
		{
			char command[15];
			GetCmdArg(0, command, 15);
			
			if (StrEqual(command, "vs_challenge", false))
			{
				return Plugin_Handled;
			}
		}
		else
		{
			//здесь можно было бы проверить, не вызывают ли участвующего, но они всё равно за забором
		}
	}
	return Plugin_Continue;
}

//////////////////////
//					//
//		Misc		//
//					//
//////////////////////

/*
	//Distances are for circle arena
float GetDistanceHor(Float:A[3], Float:B[3])
{
	return SquareRoot( (A[0] - B[0])*(A[0] - B[0]) + (A[1] - B[1])*(A[1] - B[1]));
}

float GetDistance(float A[3], float B[3])
{
	return SquareRoot( (A[0] - B[0])*(A[0] - B[0]) + (A[1] - B[1])*(A[1] - B[1]) + (A[2] - B[2])*(A[2] - B[2]));
}*/
bool IsValidClient(int client)
{
	return (client >= 1 && client <= MaxClients && IsValidEntity(client) && IsClientInGame(client));
}
int CreateBrush(float vecPos[3],/* float vecDir[3],*/ float minBounds[3], float maxBounds[3])
{
	// * CreateInvisibleBrush	
	int ent = CreateEntityByName("func_brush");
	DispatchSpawn(ent);
	ActivateEntity(ent);
	TeleportEntity(ent, vecPos, NULL_VECTOR, NULL_VECTOR);
	//TeleportEntity(ent, NULL_VECTOR, vecVec, NULL_VECTOR);  not working:(
	
	///! 
	SetEntityModel(ent, "models/extras/info_speech.mdl");
	
	SetEntPropVector(ent, Prop_Data, "m_vecMins", minBounds);
	SetEntPropVector(ent, Prop_Data, "m_vecMaxs", maxBounds);
	
	SetEntProp(ent, Prop_Send, "m_nSolidType", 2);
	
	int enteffects = GetEntProp(ent, Prop_Send, "m_fEffects");
	enteffects |= 32;
	SetEntProp(ent, Prop_Send, "m_fEffects", enteffects);
	
	return ent;
}
bool:IsInDuel(client)
{
	
	if(!IsClientInGame(client))
	{
		return false;
	}
	
	new g_DuelState[MAXPLAYERS+1];
	new m_Offset = FindSendPropInfo("CBerimbauPlayerResource", "m_iDuel");
	new ResourceManager = FindEntityByClassname(-1, "berimbau_player_manager");

	GetEntDataArray(ResourceManager, m_Offset, g_DuelState, 34, 4);
	
	if(g_DuelState[client] != 0)
	{
		return true;
	}
	
	return false;
}
//////////////////////
//					//
//		Tests		//
//					//
//////////////////////


public Action Test(client, args)
{
//
}
/*
DrawBeam(Float:PointFrom[3], Float:PointTo[3])
{
	new tar = CreateEntityByName("env_sprite"); 
    SetEntityModel( tar, "materials/particle/dys_beam_big_rect.vmt" );
    DispatchKeyValue( tar, "renderamt", "255" );
    DispatchKeyValue( tar, "rendercolor", "255 255 255" ); 
    DispatchSpawn( tar );
    AcceptEntityInput(tar,"ShowSprite");
    ActivateEntity(tar);
    TeleportEntity( tar, PointFrom, NULL_VECTOR, NULL_VECTOR );
	
	new beam = CreateEntityByName( "env_beam" );
	SetEntityModel( beam, "materials/particle/dys_beam_big_rect.vmt" );
					
					DispatchKeyValue( beam, "rendermode", "0" );
				
					
					DispatchKeyValue( beam, "renderamt", "100" );
					DispatchKeyValue( beam, "rendermode", "0" );
					DispatchKeyValue( beam, "rendercolor", "0 0 255" );  
					DispatchKeyValue( beam, "life", "0" ); 
					
					TeleportEntity( beam, PointTo, NULL_VECTOR, NULL_VECTOR ); 
					
					DispatchSpawn(beam);
					SetEntPropEnt( beam, Prop_Send, "m_hAttachEntity", EntIndexToEntRef(beam) );
					SetEntPropEnt( beam, Prop_Send, "m_hAttachEntity", EntIndexToEntRef(tar), 1 );
					SetEntProp( beam, Prop_Send, "m_nNumBeamEnts", 2);
					SetEntProp( beam, Prop_Send, "m_nBeamType", 2);
					
					SetEntPropFloat( beam, Prop_Data, "m_fWidth",  1.0 );
					SetEntPropFloat( beam, Prop_Data, "m_fEndWidth", 1.0 );
					ActivateEntity(beam);
					AcceptEntityInput(beam,"TurnOn");
					
	
}*/