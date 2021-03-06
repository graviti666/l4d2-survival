#include <sourcemod>
#include <sdktools>

#pragma semicolon	1
#pragma newdecls required

#define DEBUG	0

// Get rid of these eventually
#define IS_VALID_CLIENT(%1)     (%1 > 0 && %1 <= MaxClients)
#define IS_SURVIVOR(%1)         (GetClientTeam(%1) == 2)
#define IS_INFECTED(%1)         (GetClientTeam(%1) == 3)
#define IS_VALID_INGAME(%1)     (IS_VALID_CLIENT(%1) && IsClientInGame(%1))
#define IS_VALID_SURVIVOR(%1)   (IS_VALID_INGAME(%1) && IS_SURVIVOR(%1))
#define IS_VALID_INFECTED(%1)   (IS_VALID_INGAME(%1) && IS_INFECTED(%1))

enum
{
	ZC_SMOKER = 1,
	ZC_BOOMER,
	ZC_HUNTER,
	ZC_WITCH,
	ZC_TANK
}

enum KILL_TYPE
{
	SI,
	TANK,
	CI
}

enum SI_TYPE
{
	SMOKER,
	BOOMER,
	HUNTER
}

ConVar g_hTankReportEnabled;

Handle g_hForwardSurvivalStart;

// Tracking SI alive time
int g_iSpawnTime[MAXPLAYERS + 1];

#define SI_LIFETIME_STUCK_THRESHOLD		150.0		// 2.5 min, what is a good value here?

// Hostname tracker
Handle convar_hostname;
Handle g_hTimer;

char g_sOriginalHostName[64];

int g_iTimeTick;

bool g_bRoundProgress;

int g_iSurvivalTime;
int g_iRoundEndTime;

// Tracking kills
int g_iKills[MAXPLAYERS + 1][KILL_TYPE];

int g_iGlobalKills[KILL_TYPE];
int g_iSIKillsType[SI_TYPE];

// T dmg report specific
int g_iTankDamageCache[MAXPLAYERS + 1][MAXPLAYERS + 1];
int g_iTankLastHealth[MAXPLAYERS+1];
int g_bTankIncap[MAXPLAYERS + 1];
int g_iTankHealth[MAXPLAYERS + 1];

// t dmg
int g_iTankDamage[MAXPLAYERS + 1];
int g_iTankDamageTotal;

// Health item usage
int g_iMedkitCount;

int g_iKitsUsedClient[MAXPLAYERS + 1];
int g_iKitsTotalUsed;

/*
 * Friendly Fire tracking
*/
int g_iDamageCache[MAXPLAYERS+1][MAXPLAYERS+1];		// attacker, victim

int g_iDmgTotal[MAXPLAYERS+1];
int g_iDmgReceivedTotal[MAXPLAYERS+1];

int g_iDmgTotalCache;

/*
 * Modules - Keeping things clean
*/
#include "modules/events.sp"
#include "modules/medkit_stats.sp"
#include "modules/ff_stats.sp"

public Plugin myinfo = 
{
	name = "L4D Statistical Commands",
	author = "Gravity",
	description = "Some stats for l4d1",
	version = "1.0",
	url = ""
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	EngineVersion engine = GetEngineVersion();
	if (engine != Engine_Left4Dead)
	{
		strcopy(error, err_max, "[SM] This plugin supports left 4 dead 1 only.");
		return APLRes_SilentFailure;
	}
	
	CreateNative("IsSurvivalInProgress", Native_IsSurvivalInProgress);
	CreateNative("SICurrentAliveTime", Native_SICurrentAliveTime);
	CreateNative("CurrentSIrate", Native_CurrentSIrate);
	
	g_hForwardSurvivalStart = CreateGlobalForward("OnSurvivalRoundStart", ET_Ignore);
	return APLRes_Success;
}

public void OnPluginStart()
{
	// Add this maybe someday?
	// g_hCvarTrackingType = CreateConVar("l4d_stats_track_type", "0", "How should we track player kill percentages? 1 = Track with kills | 0 = Track by damage dealt", 0, true, 0.0, true, 1.0);
	g_hTankReportEnabled = CreateConVar("l4d_stats_tankreport_enabled", "1", "Whether to display tank damage or not. \n1 = enabled \n0=disabled");
	
	RegConsoleCmd("sm_sicount", Command_DisplaySICounts);
	RegConsoleCmd("sm_stats", Command_DisplayStats);
	RegConsoleCmd("sm_stuck", Command_DisplayStuckReport);
	RegConsoleCmd("sm_medstats", Command_DisplayMedkitStats);
	RegConsoleCmd("sm_ff", Command_DisplayFFReport);
	RegConsoleCmd("sm_ffe", Command_DisplayFFExtra);
	
	HookEvent("player_spawn", Event_OnPlayerSpawn);
	HookEvent("player_death", Event_OnPlayerDeath); // Tracking SI + tank kills
	HookEvent("infected_death", Event_OnInfectedDeath); // Tracking CI kills
	HookEvent("create_panic_event", Event_OnSurvivalStart);
	HookEvent("round_end", Event_OnRoundEnd);
	HookEvent("heal_success", Event_OnPlayerHealed);
	HookEvent("player_hurt_concise", Event_OnPlayerHurtConcise);
	HookEvent("tank_spawn", Event_OnTankSpawn);
	HookEvent("player_hurt", Event_OnPlayerHurt);
}

/*=========================================================
 * 					Natives
==========================================================*/

public int Native_IsSurvivalInProgress(Handle plugin, int numParams)
{
	return view_as<bool>(g_bRoundProgress);
}

public int Native_SICurrentAliveTime(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	return view_as<int>(g_iSpawnTime[client]);
}

public int Native_CurrentSIrate(Handle plugin, int numParams)
{
	float rate = GetRatePerMinute(g_iGlobalKills[SI]);
	return view_as<int>(rate);
}

public void OnMapStart()
{
	for (int i = 1; i <= MaxClients; i++)
	{
		g_iSpawnTime[i] = 0;
	}
	MedkitStats_CalculateKits();
}

public void OnConfigsExecuted()
{
	RequestFrame(GrabHostName);
}

public void GrabHostName(any data)
{
	convar_hostname = FindConVar("hostname");
	GetConVarString(convar_hostname, g_sOriginalHostName, sizeof(g_sOriginalHostName));
}

/* ========================================================
 *					Command callbacks
==========================================================*/

public Action Command_DisplayFFReport(int client, int args)
{
	FriendlyFire_ShowReport(client);
}

public Action Command_DisplayFFExtra(int client, int args)
{
	FriendlyFire_ShowReportExtra(client);
}

public Action Command_DisplaySICounts(int client, int args)
{
	SICounts(client);
	return Plugin_Handled;
}

public Action Command_DisplayMedkitStats(int client, int args)
{
	MedkitStats(client);
	return Plugin_Handled;
}

public Action Command_DisplayStats(int client, int args)
{
	StatsDisplay(client);
	return Plugin_Handled;
}

public Action Command_DisplayStuckReport(int client, int args)
{
	int count;
	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i))continue;
		
		if (GetClientTeam(i) == 3 && IsPlayerAlive(i))
		{
			if (g_iSpawnTime[i] > 0 && GetTime() - g_iSpawnTime[i] >= SI_LIFETIME_STUCK_THRESHOLD)
			{
				count++;
				int seconds = GetTime() - g_iSpawnTime[i];
				PrintToConsole(client, "%N age: [%is] could be stuck..", i, seconds);
			}
		}
	}
	PrintToChat(client, "Probably %i stuck.", count);
	return Plugin_Handled;
}

/*=============================================
				Report functions
==============================================*/

void DisplayTankReport(int victim)
{
	int percentage, dmg, client;
	
	// Reset dmgOrder
	int dmgOrder[MAXPLAYERS+1];
	for (int i = 0; i < MAXPLAYERS; i++)
	{
		dmgOrder[i] = -1;
	}
	
	// Add any survivor client that damaged the tank to the dmgOrder array
	for (int i = 1; i <= MaxClients; i++) 
	{
		if (g_iTankDamageCache[victim][i] > 0)	// This client did damage to the tank
		{
			if (IS_VALID_SURVIVOR(i)) 		// This client is a survivor
			{
				// Add client to the first available node in the dmgOrder array
				for (int j = 0; j < MAXPLAYERS; j++)	
				{
					client = dmgOrder[j];
					if (client == -1)
					{
						dmgOrder[j] = i;
						break;
					}
				}
			}
		}
	}
	
	// Sort by damage done
	int curClient,nxtClient,nxtDmg;
	for (int i = 0; i < (MAXPLAYERS-1); i++)
	{
		if (dmgOrder[i] == -1) break;
		for (int j = i+1; j<MAXPLAYERS; j++)
		{
			if (dmgOrder[j] == -1) break;
			curClient = dmgOrder[i];
			nxtClient = dmgOrder[j];
			
			dmg = g_iTankDamageCache[victim][curClient];
			nxtDmg = g_iTankDamageCache[victim][nxtClient];
			
			if (dmg < nxtDmg)
			{
				dmgOrder[i] = nxtClient;
				dmgOrder[j] = curClient;
			}
		}
	}
	
	//Display damage summary
	PrintToChatAll("[SM] Damage dealt to %N", victim);
	
	float fTankHealth;
	for (int i = 0; i < MAXPLAYERS; i++)
	{
		if (dmgOrder[i] == -1) break;
		client = dmgOrder[i];
		fTankHealth = float(g_iTankHealth[victim]);
		percentage = RoundToNearest((g_iTankDamageCache[victim][client]/fTankHealth) * 100);
		PrintToChatAll("\x05%i\x01 [\x04%i%s%\x01]: \x03%N", g_iTankDamageCache[victim][client], percentage, "%", client);
	}
}

void SICounts(int client)
{
	float rate = GetRatePerMinute(g_iGlobalKills[SI]);
	
	float fTotalSIKills = g_iGlobalKills[SI] == 0 ? 1.0 : float(g_iGlobalKills[SI]);
	
	int smoker_pct = RoundToNearest((g_iSIKillsType[SMOKER] / fTotalSIKills) * 100);
	int boomer_pct = RoundToNearest((g_iSIKillsType[BOOMER] / fTotalSIKills) * 100);
	int hunter_pct = RoundToNearest((g_iSIKillsType[HUNTER] / fTotalSIKills) * 100);
	
	PrintToChat(client, "SI Counts [%f SI/min - %i killed | %i tanks | %i CI]:", rate, g_iGlobalKills[SI], g_iGlobalKills[TANK], g_iGlobalKills[CI]);
	PrintToChat(client, "\x01Smokers: \x03%i\x01 (%i%s)", g_iSIKillsType[SMOKER], smoker_pct, "%");
	PrintToChat(client, "\x01Boomers: \x03%i\x01 (%i%s)", g_iSIKillsType[BOOMER], boomer_pct, "%");
	PrintToChat(client, "\x01Hunters: \x03%i\x01 (%i%s)", g_iSIKillsType[HUNTER], hunter_pct, "%");
}

void StatsDisplay(int client)
{
	float rate = GetRatePerMinute(g_iGlobalKills[SI]);
	
	if (client == -1)
	{
		PrintToChatAll("Damage report [%f SI/min - %i killed | %i tanks]:", rate, g_iGlobalKills[SI], g_iGlobalKills[TANK]);		
	}
	else
	{
		PrintToChat(client, "Damage report [%f SI/min - %i killed | %i tanks]:", rate, g_iGlobalKills[SI], g_iGlobalKills[TANK]);
	}
	
	float fTankHealth = g_iTankDamageTotal == 0 ? 1.0 : float(g_iTankDamageTotal);
	float fTotalSI = g_iGlobalKills[SI] == 0 ? 1.0 : float(g_iGlobalKills[SI]);
	float fTotalCommon = g_iGlobalKills[CI] == 0 ? 1.0 : float(g_iGlobalKills[CI]);
	
	int tankDmgPercent, siKillPercent, commonPercent;
	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i))continue;
		if (GetClientTeam(i) == 2)
		{
			// Calculate the percentages for this survivor
			tankDmgPercent = RoundToNearest((g_iTankDamage[i] / fTankHealth) * 100);
			siKillPercent = RoundToNearest((g_iKills[i][SI] / fTotalSI) * 100);
			commonPercent = RoundToNearest((g_iKills[i][CI] / fTotalCommon) * 100);
			
			if (client == -1)
			{
				PrintToChatAll("\x05%N\x01: \x03%i%s\x01 (S), \x03%i%s\x01 (T), \x03%i%s\x01 (C)", i, siKillPercent, "%", tankDmgPercent, "%", commonPercent, "%");
			}
			else
			{
				PrintToChat(client, "\x05%N\x01: \x03%i%s\x01 (S), \x03%i%s\x01 (T), \x03%i%s\x01 (C)", i, siKillPercent, "%", tankDmgPercent, "%", commonPercent, "%");
			}
		}
	}
}

/*===============================================
				Stocks, misc
================================================*/

void ResetStatsArrays()
{
	for (int i = 1; i <= MaxClients; i++)
	{
		g_iTankDamage[i] = 0;
		g_iKills[i][SI] = 0;
		g_iKills[i][CI] = 0;
	}
	g_iTankDamageTotal = 0;
	
	g_iGlobalKills[SI] = 0;
	g_iGlobalKills[CI] = 0;
	g_iGlobalKills[TANK] = 0;
	
	g_iSIKillsType[SMOKER] = 0;
	g_iSIKillsType[BOOMER] = 0;
	g_iSIKillsType[HUNTER] = 0;
}

float GetRatePerMinute(int iCount)
{
	float fRate, fMin, fSec;
	
	if (g_bRoundProgress)
	{
		fSec = float(GetTime() - g_iSurvivalTime);
	}
	else
	{
		fSec = float(g_iRoundEndTime);
	}
	
	fMin = fSec/60.0;
	if (fMin == 0) 
	{
		fRate = 0.0;
	}
	else
	{
		fRate = iCount/fMin;
	}
	return fRate;
}

bool IsSurvivor(int client)
{
	return (client > 0 && client <= MaxClients && IsClientInGame(client) && GetClientTeam(client) == 2);
}