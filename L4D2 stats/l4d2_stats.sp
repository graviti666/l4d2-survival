#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <l4d2stats>
#include <weapons>
#include <SteamWorks>

#define PLUGIN_VERSION "1.0"

public Plugin:myinfo =
{
	name = "Survival Stats Tracker",
	author = "khan",
	description = "Keep track of some stats within the round",
	version = PLUGIN_VERSION
};

#define IS_VALID_CLIENT(%1)     (%1 > 0 && %1 <= MaxClients)
#define IS_SURVIVOR(%1)         (GetClientTeam(%1) == 2)
#define IS_INFECTED(%1)         (GetClientTeam(%1) == 3)
#define IS_VALID_INGAME(%1)     (IS_VALID_CLIENT(%1) && IsClientInGame(%1))
#define IS_VALID_SURVIVOR(%1)   (IS_VALID_INGAME(%1) && IS_SURVIVOR(%1))
#define IS_VALID_INFECTED(%1)   (IS_VALID_INGAME(%1) && IS_INFECTED(%1))

#define ZC_SMOKER			1
#define ZC_BOOMER			2
#define ZC_HUNTER			3
#define ZC_SPITTER			4
#define ZC_JOCKEY			5
#define ZC_CHARGER			6
#define ZC_TANK				8

#define DMG_GENERIC		0
#define DMG_CRUSH			(1 << 0)
#define DMG_BULLET			(1 << 1)
#define DMG_SLASH			(1 << 2)
#define DMG_BURN			(1 << 3)
#define DMG_BLAST			(1 << 6)
#define DMG_CLUB			(1 << 7)
#define DMG_BUCKSHOT		(1 << 29)

// weapon types
#define WPTYPE_NONE		0
#define WPTYPE_SHELLS		1
#define WPTYPE_MELEE		2
#define WPTYPE_BULLETS	3

#define HITGROUP_HEAD		1

StringMap g_hTotalSI;
StringMap g_hSmokerCount;
StringMap g_hBoomerCount;
StringMap g_hHunterCount;
StringMap g_hSpitterCount;
StringMap g_hJockeyCount;
StringMap g_hChargerCount;
new g_iTotalSI;
new g_iSmokerTotal;
new g_iBoomerTotal;
new g_iHunterTotal;
new g_iSpitterTotal;
new g_iJockeyTotal;
new g_iChargerTotal;
new g_iTankTotal;

StringMap g_hTankDamageTotal;
new  g_iTankDamageTotal;
new  g_iTankDamage[MAXPLAYERS + 1][MAXPLAYERS + 1];
new  g_iTankHealth[MAXPLAYERS + 1];
new  g_iTankLastHealth[MAXPLAYERS + 1];
new bool:g_bTankIncap[MAXPLAYERS + 1];

StringMap g_hShotsFired;
StringMap g_hShotsLanded;
StringMap g_hShotsLandedHead;
StringMap g_hShotsLandedSI;
StringMap g_hShotsLandedHeadSI;

new bool:g_bCurrentShotHit[MAXPLAYERS + 1];
new bool:g_bCurrentShotHead[MAXPLAYERS + 1];
new bool:g_bCurrentShotSIHit[MAXPLAYERS + 1];
new bool:g_bCurrentShotSIHead[MAXPLAYERS + 1];

StringMap g_hCommonTotal;
new g_iCommonTotal;

StringMap g_hTotalFF;
StringMap g_hTotalFFGiven;
new g_iFFTaken[MAXPLAYERS + 1][MAXPLAYERS + 1];
new g_iFFGiven[MAXPLAYERS + 1][MAXPLAYERS + 1];


StringMap g_hUsedMedkits;
StringMap g_hUsedDefibs;
StringMap g_hUsedPills;
StringMap g_hUsedShots;
StringMap g_hUsedPipes;
StringMap g_hUsedMolotovs;
StringMap g_hUsedBiles;


new g_iRoundStart;
new Float:g_fRoundStart;
new Float:g_fSurvivalTime;
new bool:g_bRoundEnd;
new bool:g_bRoundStart;

new Handle:g_hTankReportEnabled;
new bool:g_bTankReportEnabled;
new Handle:g_hAutoDisplay;
new bool:g_bAutoDisplay;

public OnPluginStart()
{
	g_hTankReportEnabled = CreateConVar("l4d_AnnounceTankDamage", "1", "Enables stat tracking", _, true, 0.0, true, 1.0);
	HookConVarChange(g_hTankReportEnabled, EnableChange);
	
	g_hAutoDisplay = CreateConVar("l4d_AutoDisplayStats", "1", "Whether or not to automatically display stats at the end of the round", _, true, 0.0, true, 1.0);
	HookConVarChange(g_hAutoDisplay, AutoDisplayChange);
	
	// Admin Commands
	RegAdminCmd("sm_autostats", ToggleAutoDisplay, ADMFLAG_KICK, "toggle auto displaying of stats at end of the round");
	
	// Player Commands
	RegConsoleCmd("sm_tankdamage", ToggleTankReport, "toggle tank damage display");
	RegConsoleCmd("sm_td", ToggleTankReport, "toggle tank damage display");
	
	RegConsoleCmd("sm_stats", Cmd_DisplaySIStats);
	RegConsoleCmd("sm_stats2", Cmd_DetailedStats);
	RegConsoleCmd("sm_estats", Cmd_DisplayEffectiveStats);
	
	RegConsoleCmd("sm_istats", Cmd_DisplayIndividualDamageReport);
	RegConsoleCmd("sm_sicount", Cmd_DisplayIndSIReport);
	RegConsoleCmd("sm_accuracy", DisplayAccuracy);
	RegConsoleCmd("sm_acc", DisplayAccuracy);
	
	Init();
}

Init()
{
	L4D2Weapons_Init();
	
	// Hook Events
	HookEvents();
	
	// Default start time to now in case someone loads the plugin mid-round.
	g_iRoundStart = GetTime();
	g_fRoundStart = GetGameTime();
	
	g_bRoundStart = false;
	g_bRoundStart = false;
	
	g_hTotalSI = CreateTrie();
	g_hSmokerCount = CreateTrie();
	g_hBoomerCount = CreateTrie();
	g_hHunterCount = CreateTrie();
	g_hSpitterCount = CreateTrie();
	g_hJockeyCount = CreateTrie();
	g_hChargerCount = CreateTrie();
	g_hTankDamageTotal = CreateTrie();
	g_hCommonTotal = CreateTrie();
	g_hShotsFired = CreateTrie();
	g_hShotsLanded = CreateTrie();
	g_hShotsLandedHead = CreateTrie();
	g_hShotsLandedSI = CreateTrie();
	g_hShotsLandedHeadSI = CreateTrie();
	g_hTotalFF = CreateTrie();
	g_hTotalFFGiven = CreateTrie();
	g_hUsedMedkits = CreateTrie();
	g_hUsedDefibs = CreateTrie();
	g_hUsedPills = CreateTrie();
	g_hUsedShots = CreateTrie();
	g_hUsedPipes = CreateTrie();
	g_hUsedMolotovs = CreateTrie();
	g_hUsedBiles = CreateTrie();
	
	// Check if tank damage report is enabled
	CheckEnable();	
	
	// Check if auto display is turned on
	CheckAutoDisplayEnable();
	
	ResetStats();
}

HookEvents()
{
	HookEvent("tank_spawn", Event_TankSpawn, EventHookMode_Post);
	HookEvent("player_hurt", Event_PlayerHurt, EventHookMode_Post);
	HookEvent("infected_hurt", Event_InfectedHurt, EventHookMode_Post);
	HookEvent("player_death", Event_PlayerDeath, EventHookMode_Post);
	HookEvent("survival_round_start", Event_SurvivalRoundStart, EventHookMode_Post);
	HookEvent("infected_death", Event_InfectedDeath, EventHookMode_Post);
	HookEvent("round_end", Event_RoundEnd, EventHookMode_Post);
	HookEvent("weapon_fire", Event_WeaponFire, EventHookMode_Post);
	
	HookEvent("heal_success", Event_HealSuccess, EventHookMode_Post);
	HookEvent("pills_used", Event_PillsUsed, EventHookMode_Post);
	HookEvent("adrenaline_used", Event_AdrenUsed, EventHookMode_Post);
	HookEvent("defibrillator_used", Event_DefibUsed, EventHookMode_Post);
}

//=====================
// Define natives
//=====================

public APLRes:AskPluginLoad2(Handle:myself, bool:late, String:error[], err_max)
{
	RegPluginLibrary("l4d2_stat_tracker");
	
	CreateNative("L4D2Stat_GetClientStats", Native_GetClientStats);
	CreateNative("L4D2Stat_GetAllSurvivorStats", Native_GetFullStats);
	CreateNative("L4D2Stat_GetTeamStats", Native_GetTeamStats);
}

public Native_GetClientStats(Handle:plugin, numParams)
{
	decl String:sSteamID[64];
	GetNativeString(1, sSteamID, sizeof(sSteamID));
		
	new Handle:hTarget = CreateArray(STAT_MAX_STATS);
	for (new i = 0; i < MaxClients; i++)
	{
		if (IS_VALID_SURVIVOR(i))
		{
			decl String:sID[64];
			SteamWorks_GetClientSteamID(i, sID, sizeof(sID));
			if (StrEqual(sID, sSteamID))
			{
				GetClientStats(hTarget, i);
				return _:hTarget;
			}
		}
	}		
	return _:INVALID_HANDLE;
}

public Native_GetFullStats(Handle:plugin, numParams)
{
	new Handle:hTarget = CreateArray(STAT_MAX_STATS);
	
	for (new i = 0; i < MAXPLAYERS; i++)
	{
		if (IS_VALID_SURVIVOR(i))
		{
			GetClientStats(hTarget, i);
		}
	}	
	return _:hTarget;
}

public Native_GetTeamStats(Handle:plugin, numParams)
{
	new Handle:hTarget = CreateArray(STAT_TEAM_MAX_STATS);
		
	new Float:fSIRate = GetRatePerMinute(g_iTotalSI);
	new Float:fCommonRate = GetRatePerMinute(g_iCommonTotal);
	new Float:fTankRate = GetRatePerMinute(g_iTankTotal);
		
	// Add data to array
	new index = PushArrayCell(hTarget, g_iTotalSI);
	SetArrayCell(hTarget, index, fSIRate, STAT_TEAM_SI_RATE);
	SetArrayCell(hTarget, index, g_iBoomerTotal, STAT_TEAM_BOOMER);
	SetArrayCell(hTarget, index, g_iSmokerTotal, STAT_TEAM_SMOKER);
	SetArrayCell(hTarget, index, g_iHunterTotal, STAT_TEAM_HUNTER);
	SetArrayCell(hTarget, index, g_iJockeyTotal, STAT_TEAM_JOCKEY);
	SetArrayCell(hTarget, index, g_iChargerTotal, STAT_TEAM_CHARGER);
	SetArrayCell(hTarget, index, g_iSpitterTotal, STAT_TEAM_SPITTER);
	SetArrayCell(hTarget, index, g_iCommonTotal, STAT_TEAM_COMMON);
	SetArrayCell(hTarget, index, fCommonRate, STAT_TEAM_COMMON_RATE);
	SetArrayCell(hTarget, index, g_iTankTotal, STAT_TEAM_TANK);
	SetArrayCell(hTarget, index, fTankRate, STAT_TEAM_TANK_RATE);
	SetArrayCell(hTarget, index, g_iTankDamageTotal, STAT_TEAM_TANK_DAMAGE);
		
	return _:hTarget;
}


GetClientStats(Handle:hTarget, client)
{
	// Look up survivor stats
	new Float:fSIRate = GetRatePerMinute(GetValueFromTrie(g_hTotalSI, client));
	new Float:fCommonRate= GetRatePerMinute(GetValueFromTrie(g_hCommonTotal, client));
	
	new iTankTotalDamage = g_iTankDamageTotal == 0 ? 1 : g_iTankDamageTotal;
	new iTotalSI = g_iTotalSI == 0 ? 1 : g_iTotalSI;
	new iTotalCommon = g_iCommonTotal == 0 ? 1 : g_iCommonTotal;
	
	// Calculate the percentages for this survivor
	new Float:fTankDmgPercent = (RoundToFloor((float(GetValueFromTrie(g_hTankDamageTotal, client)) / float(iTankTotalDamage)) * 1000.0) / 10.0);
	new Float:fSIKillPercent = (RoundToFloor((float(GetValueFromTrie(g_hTotalSI, client)) / float(iTotalSI)) * 1000.0) / 10.0);
	new Float:fCommonPercent = (RoundToFloor((float(GetValueFromTrie(g_hCommonTotal, client)) / float(iTotalCommon)) * 1000.0) / 10.0);
	
	// Look up accuracy
	ResolveShot(client);
	
	new Float:fAccuracy = GetPercentage(GetValueFromTrie(g_hShotsLanded, client), GetValueFromTrie(g_hShotsFired, client));
	new Float:fHeadAcc = GetPercentage(GetValueFromTrie(g_hShotsLandedHead, client), GetValueFromTrie(g_hShotsFired, client));
	new Float:fAccSI = GetPercentage(GetValueFromTrie(g_hShotsLandedHeadSI, client), GetValueFromTrie(g_hShotsLandedSI, client));
	
	// Add the data to the array
	new index = PushArrayCell(hTarget, client);
	SetArrayCell(hTarget, index, GetValueFromTrie(g_hTotalSI, client), STAT_SI_TOTAL);
	SetArrayCell(hTarget, index, fSIRate, STAT_SI_RATE);
	SetArrayCell(hTarget, index, fSIKillPercent, STAT_SI_PERCENTAGE);
	SetArrayCell(hTarget, index, GetValueFromTrie(g_hSmokerCount, client), STAT_SI_SMOKER);
	SetArrayCell(hTarget, index, GetValueFromTrie(g_hBoomerCount, client), STAT_SI_BOOMER);
	SetArrayCell(hTarget, index, GetValueFromTrie(g_hHunterCount, client), STAT_SI_HUNTER);
	SetArrayCell(hTarget, index, GetValueFromTrie(g_hChargerCount, client), STAT_SI_CHARGER);
	SetArrayCell(hTarget, index, GetValueFromTrie(g_hJockeyCount, client), STAT_SI_JOCKEY);
	SetArrayCell(hTarget, index, GetValueFromTrie(g_hSpitterCount, client), STAT_SI_SPITTER);
	
	SetArrayCell(hTarget, index, GetValueFromTrie(g_hCommonTotal, client), STAT_COMMON_TOTAL);
	SetArrayCell(hTarget, index, fCommonRate, STAT_COMMON_RATE);
	SetArrayCell(hTarget, index, fCommonPercent, STAT_COMMON_PERCENTAGE);
	
	SetArrayCell(hTarget, index, GetValueFromTrie(g_hTankDamageTotal, client), STAT_TANK_DAMAGE);
	SetArrayCell(hTarget, index, fTankDmgPercent, STAT_TANK_PERCENTAGE);
	
	SetArrayCell(hTarget, index, fAccuracy, STAT_ACC_PERCENTAGE);
	SetArrayCell(hTarget, index, GetValueFromTrie(g_hShotsFired, client), STAT_ACC_SHOTS_FIRED);
	SetArrayCell(hTarget, index, GetValueFromTrie(g_hShotsLanded, client), STAT_ACC_SHOTS_LANDED);
	SetArrayCell(hTarget, index, fHeadAcc, STAT_ACC_HEADSHOT_PERCENTAGE);
	SetArrayCell(hTarget, index, GetValueFromTrie(g_hShotsLandedHead, client), STAT_ACC_HEADSHOT_COUNTS);
	SetArrayCell(hTarget, index, fAccSI, STAT_ACC_SI_HEADSHOT_PERCENTAGE);
	SetArrayCell(hTarget, index, GetValueFromTrie(g_hShotsLandedHeadSI, client), STAT_ACC_SI_HEADSHOT_COUNT);
	SetArrayCell(hTarget, index, GetValueFromTrie(g_hShotsLandedSI, client), STAT_ACC_SI_SHOTS_LANDED);
	SetArrayCell(hTarget, index, GetValueFromTrie(g_hTotalFF, client), STAT_FF_TAKEN);
	SetArrayCell(hTarget, index, GetValueFromTrie(g_hTotalFFGiven, client), STAT_FF_GIVEN);
}

//=====================
// Command Handlers
//=====================

/*
	[9/30/2020, 6:33 AM]
	Ωltra:
	I've an idea for !stats
	Maybe have something called "effective stats" listed below
	and it's basically calculated as adding up all of your stat %
*/
public Action:Cmd_DisplayEffectiveStats(client, args)
{
	DisplayEffectiveStats(client);
	return Plugin_Handled;
}

public Action:ToggleTankReport(client, args)
{
	new bool:enabled = GetConVarBool(g_hTankReportEnabled);
	if (enabled) 
	{
		SetConVarInt(g_hTankReportEnabled, 0);
	}
	else
	{
		SetConVarInt(g_hTankReportEnabled, 1);
	}
}

public Action:ToggleAutoDisplay(client, args)
{
	new bool:enabled = GetConVarBool(g_hAutoDisplay);
	if (enabled) 
	{
		SetConVarInt(g_hAutoDisplay, 0);
	}
	else
	{
		SetConVarInt(g_hAutoDisplay, 1);
	}
}


public Action:DisplayAccuracy(client, args)	//TODO: make this better...
{
	ResolveShot(client);
	
	new iShotsFired = GetValueFromTrie(g_hShotsFired, client);
	new iShotsLanded = GetValueFromTrie(g_hShotsLanded, client);
	new iShotsLandedHead = GetValueFromTrie(g_hShotsLandedHead, client);
	new iShotsLandedSI = GetValueFromTrie(g_hShotsLandedSI, client);
	new iShotsLandedHeadSI = GetValueFromTrie(g_hShotsLandedHeadSI, client);
	
	new accuracy = GetPercentageRounded(iShotsLanded, iShotsFired);
	new headAcc = GetPercentageRounded(iShotsLandedHead, iShotsFired);
	new accSI = GetPercentageRounded(iShotsLandedHeadSI, iShotsLandedSI);
	
	PrintToChat(client, "\x01== Accuracy Report ==");
	PrintToChat(client, "\x01Accuracy: \x04%i%s\x01 [\x04%i\x01 Shots - \x04%i\x01 Landed]", accuracy, "%", iShotsFired, iShotsLanded);
	PrintToChat(client, "\x01Headshots: \x04%i%s\x01 [\x04%i\x01 Headshots]", headAcc, "%", iShotsLandedHead);
	PrintToChat(client, "\x01SI Headshots: \x04%i%s\x01 [\x04%i\x01 Headshots - \x04%i\x01 Hits]", accSI, "%", iShotsLandedHeadSI, iShotsLandedSI);
	return Plugin_Handled;
}

public Action:Cmd_DisplayIndSIReport(client, args)
{
	DisplayIndSIReport(client);
	return Plugin_Handled;
}

public Action:Cmd_DisplayIndividualDamageReport(client, args)
{
	DisplayIndividualDamageReport(client);
	return Plugin_Handled;
}

public Action:Cmd_DetailedStats(client, args)
{
	DisplayDetailedStats(client);
}

public Action:Cmd_DisplaySIStats(client, args)
{
	DisplaySIStats(client);
	return Plugin_Handled;
}

//=======================
// Helper Functions
//=======================
GetPercentageRounded(landed, total)
{
	new Float:accuracy;
	if (landed == 0)
	{
		if (total == 0)
		{
			accuracy = 1.0;
		}
		else
		{
			accuracy = 0.0;
		}
	}
	else
	{
		accuracy = landed / (1.0 * total);
	}
	
	return RoundToFloor(accuracy * 100);
}

Float:GetPercentage(landed, total)
{
	new Float:accuracy;
	if (landed == 0)
	{
		if (total == 0)
		{
			accuracy = 1.0;
		}
		else
		{
			accuracy = 0.0;
		}
	}
	else
	{
		accuracy = landed / (1.0 * total);
	}
	
	return (RoundToFloor(accuracy * 1000.0) / 10.0);
}

bool:CheckAutoDisplayEnable()
{
	g_bAutoDisplay = GetConVarBool(g_hAutoDisplay);
	return g_bAutoDisplay;
}

public AutoDisplayChange(Handle:convar, const String:oldValue[], const String:newValue[])
{
	if (!StrEqual(oldValue, newValue))
	{
		if (CheckAutoDisplayEnable()) 
		{
			PrintToChatAll("\x05Stats auto display turned on");
		}
		else
		{
			PrintToChatAll("\x05Stats auto display turned off");
		}
	}
}

bool:CheckEnable()
{
	g_bTankReportEnabled = GetConVarBool(g_hTankReportEnabled);
	return g_bTankReportEnabled;	
}

public EnableChange(Handle:convar, const String:oldValue[], const String:newValue[])
{
	if (!StrEqual(oldValue, newValue))
	{
		if (CheckEnable())
		{
			PrintToChatAll("\x05Tank damage summary enabled");
		}
		else
		{
			PrintToChatAll("\x05Tank damage summary disabled");
		}
	}
}

ResetStats()
{
	for (new i = 0; i < MAXPLAYERS; i++)
	{
		for (new j = 0; j < MAXPLAYERS; j++)
		{
			g_iFFGiven[i][j] = 0;
			g_iFFTaken[i][j] = 0;
		}
	}
	
	g_iTotalSI = 0;
	g_iSmokerTotal = 0;
	g_iBoomerTotal = 0;
	g_iHunterTotal = 0;
	g_iSpitterTotal = 0;
	g_iJockeyTotal = 0;
	g_iChargerTotal = 0;
	g_iTankTotal = 0;
	g_iTankDamageTotal = 0;
	g_iCommonTotal = 0;
	
	ClearTrie(g_hTotalSI);
	ClearTrie(g_hSmokerCount);
	ClearTrie(g_hBoomerCount);
	ClearTrie(g_hHunterCount);
	ClearTrie(g_hSpitterCount);
	ClearTrie(g_hJockeyCount);
	ClearTrie(g_hChargerCount);
	ClearTrie(g_hTankDamageTotal);
	ClearTrie(g_hCommonTotal);
	ClearTrie(g_hShotsFired);
	ClearTrie(g_hShotsLanded);
	ClearTrie(g_hShotsLandedHead);
	ClearTrie(g_hShotsLandedSI);
	ClearTrie(g_hShotsLandedHeadSI);
	ClearTrie(g_hTotalFF);
	ClearTrie(g_hTotalFFGiven);
	ClearTrie(g_hUsedMedkits);
	ClearTrie(g_hUsedDefibs);
	ClearTrie(g_hUsedPills);
	ClearTrie(g_hUsedShots);
	ClearTrie(g_hUsedPipes);
	ClearTrie(g_hUsedMolotovs);
	ClearTrie(g_hUsedBiles);
}

AddValueToTrie(StringMap hMap, client, value)
{
	char sSteamID[64];
	if (IsFakeClient(client))
	{
		Format(sSteamID, sizeof(sSteamID), "%N", client);
	}
	else
	{
		SteamWorks_GetClientSteamID(client, sSteamID, sizeof(sSteamID));
	}
	
	new curVal;
	GetTrieValue(hMap, sSteamID, curVal);

	curVal += value;

	SetTrieValue(hMap, sSteamID, curVal);
}

GetValueFromTrie(StringMap hMap, client)
{
	char sSteamID[64];
	if (IsFakeClient(client))
	{
		Format(sSteamID, sizeof(sSteamID), "%N", client);
	}
	else
	{
		SteamWorks_GetClientSteamID(client, sSteamID, sizeof(sSteamID));
	}
	
	new curVal;
	GetTrieValue(hMap, sSteamID, curVal);
	
	return curVal;
}

GetCurrentSurvivalTime(String:sTime[32])
{
	float fRoundTime;
	if (!g_bRoundStart && !g_bRoundEnd)
	{
		fRoundTime = 0.0;
	}
	else if (!g_bRoundEnd)
	{
		fRoundTime = GetGameTime() - g_fRoundStart;
	}
	else
	{
		fRoundTime = g_fSurvivalTime;
	}
	
	char sMilli[16];
	char sSec[16];
	char sMin[16];
	
	int iRoundTimeRounded = RoundToFloor(fRoundTime);
	int iMilli = RoundToFloor((fRoundTime - iRoundTimeRounded) * 100);
	int iMin = RoundToFloor(fRoundTime / 60);
	int iSec = iRoundTimeRounded - (iMin*60);
	
	if (iMilli < 10)
	{
		Format(sMilli, sizeof(sMilli), "0%i", iMilli);
	}
	else
	{
		Format(sMilli, sizeof(sMilli), "%i", iMilli);
	}
	
	if (iSec < 10)
	{
		Format(sSec, sizeof(sSec), "0%i", iSec);
	}
	else
	{
		Format(sSec, sizeof(sSec), "%i", iSec);
	}
	
	if (iMin < 10)
	{
		Format(sMin, sizeof(sMin), "0%i", iMin);
	}
	else
	{
		Format(sMin, sizeof(sMin), "%i", iMin);
	}
	
	Format(sTime, sizeof(sTime), "%s:%s.%s", sMin, sSec, sMilli);
}

//====================
// Report Functions
//====================

DisplayEffectiveStats(client)
{		
	PrintToChat(client, "Effective Stats:");
	
	new Float:fTankHealth = g_iTankDamageTotal == 0 ? 1.0 : float(g_iTankDamageTotal);
	new Float:fTotalSI = g_iTotalSI == 0 ? 1.0 : float(g_iTotalSI);
	new Float:fTotalCommon = g_iCommonTotal == 0 ? 1.0 : float(g_iCommonTotal);
	
	new tankDmgPercent, siKillPercent, commonPercent;
	
	// Display the report to any valid survivor
	for (new i = 0; i < MAXPLAYERS; i++)
	{
		if (IS_VALID_SURVIVOR(i))
		{
			// Calculate the percentages for this survivor
			tankDmgPercent = RoundToNearest((GetValueFromTrie(g_hTankDamageTotal, i)/fTankHealth) * 100);
			siKillPercent = RoundToNearest((GetValueFromTrie(g_hTotalSI, i)/fTotalSI) * 100);
			commonPercent = RoundToNearest((GetValueFromTrie(g_hCommonTotal, i)/fTotalCommon) * 100);
			
			int effPercent = (tankDmgPercent + siKillPercent + commonPercent);
			PrintToChat(client, "\x04%N\x01: \x05%i%s\x01", i, effPercent, "%");
		}
	}
}

DisplayIndSIReport(any:client)
{
	new Float:fRate = GetRatePerMinute(g_iTotalSI);
	
	// Display stats
	PrintToChat(client, "SI Counts [%f SI/min - %i SI - %i Tanks]:", fRate, g_iTotalSI, g_iTankTotal);
	PrintToChat(client, "\x05%i\x01 Hunters", g_iHunterTotal);
	PrintToChat(client, "\x05%i\x01 Smokers", g_iSmokerTotal);
	PrintToChat(client, "\x05%i\x01 Boomers", g_iBoomerTotal);
	PrintToChat(client, "\x05%i\x01 Chargers", g_iChargerTotal);
	PrintToChat(client, "\x05%i\x01 Jockeys", g_iJockeyTotal);
	PrintToChat(client, "\x05%i\x01 Spitters", g_iSpitterTotal);
}

DisplayIndividualDamageReport(any:client)
{
	new iTotalSI = GetValueFromTrie(g_hTotalSI, client);
	new Float:fRate = GetRatePerMinute(iTotalSI);
	
	PrintToChat(client, "Individual Damage Report [%f SI/min - %i killed]:", fRate, iTotalSI);
	
	PrintToChat(client, "\x05%i\x01 Smokers", GetValueFromTrie(g_hSmokerCount, client));
	PrintToChat(client, "\x05%i\x01 Boomers", GetValueFromTrie(g_hBoomerCount, client));
	PrintToChat(client, "\x05%i\x01 Hunters", GetValueFromTrie(g_hHunterCount, client));
	PrintToChat(client, "\x05%i\x01 Jockeys", GetValueFromTrie(g_hJockeyCount, client));
	PrintToChat(client, "\x05%i\x01 Chargers", GetValueFromTrie(g_hChargerCount, client));
	PrintToChat(client, "\x05%i\x01 Spitters", GetValueFromTrie(g_hSpitterCount, client));
}

Float:GetRatePerMinute(iCount)
{
	new Float:fRate, Float:fMin;
	new Float:fSec;
	if (!g_bRoundEnd)
	{
		fSec = float(GetTime() - g_iRoundStart);
	}
	else
	{
		fSec = g_fSurvivalTime;
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

DisplaySIStats(any:client)
{	
	new Float:fRate = GetRatePerMinute(g_iTotalSI);
	
	// Display the overall percentages and count
	if (client == -1)
	{
		PrintToChatAll("Damage report [%f SI/min - %i killed]:", fRate, g_iTotalSI);
	}
	else
	{
		PrintToChat(client, "Damage report [%f SI/min - %i killed]:", fRate, g_iTotalSI);
	}
	
	new Float:fTankHealth = g_iTankDamageTotal == 0 ? 1.0 : float(g_iTankDamageTotal);
	new Float:fTotalSI = g_iTotalSI == 0 ? 1.0 : float(g_iTotalSI);
	new Float:fTotalCommon = g_iCommonTotal == 0 ? 1.0 : float(g_iCommonTotal);
	
	new tankDmgPercent, siKillPercent, commonPercent;
	
	// Display the report to any valid survivor
	for (new i = 0; i < MAXPLAYERS; i++)
	{
		if (IS_VALID_SURVIVOR(i))
		{
			// Calculate the percentages for this survivor
			tankDmgPercent = RoundToNearest((GetValueFromTrie(g_hTankDamageTotal, i)/fTankHealth) * 100);
			siKillPercent = RoundToNearest((GetValueFromTrie(g_hTotalSI, i)/fTotalSI) * 100);
			commonPercent = RoundToNearest((GetValueFromTrie(g_hCommonTotal, i)/fTotalCommon) * 100);
			
			// Display to client
			if (client == -1)
			{
				PrintToChatAll("\x04%N\x01: \x05%i%s\x01 (S), \x05%i%s\x01 (T), \x05%i%s\x01 (C)", i, siKillPercent, "%",  tankDmgPercent, "%", commonPercent, "%");
			}
			else
			{
				PrintToChat(client, "\x04%N\x01: \x05%i%s\x01 (S), \x05%i%s\x01 (T), \x05%i%s\x01 (C)", i, siKillPercent, "%",  tankDmgPercent, "%", commonPercent, "%");
			}
		}
	}
}

DisplayTankReport(victim)
{
	new percentage, dmg, client;
	
	// Reset dmgOrder
	new dmgOrder[MAXPLAYERS + 1];
	for (new i = 0; i < MAXPLAYERS; i++)
	{
		dmgOrder[i] = -1;
	}
	
	// Add any survivor client that damaged the tank to the dmgOrder array
	for (new i = 0; i < MAXPLAYERS; i++) 
	{
		if (g_iTankDamage[victim][i] > 0)	// This client did damage to the tank
		{
			if (IS_VALID_SURVIVOR(i)) 		// This client is a survivor
			{
				// Add client to the first available node in the dmgOrder array
				for (new j = 0; j < MAXPLAYERS; j++)	
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
	new curClient,nxtClient,nxtDmg;
	for (new i = 0; i < (MAXPLAYERS-1); i++)
	{
		if (dmgOrder[i] == -1) break;
		for (new j = i+1; j<MAXPLAYERS; j++)
		{
			if (dmgOrder[j] == -1) break;
			curClient = dmgOrder[i];
			nxtClient = dmgOrder[j];
			
			dmg = g_iTankDamage[victim][curClient];
			nxtDmg = g_iTankDamage[victim][nxtClient];
			
			if (dmg < nxtDmg)
			{
				dmgOrder[i] = nxtClient;
				dmgOrder[j] = curClient;
			}
		}
	}
	
	//Display damage summary
	PrintToChatAll("[SM] Damage dealt to %N", victim);
	new Float:fTankHealth
	for (new i = 0; i < MAXPLAYERS; i++)
	{
		if (dmgOrder[i] == -1) break;
		client = dmgOrder[i];
		fTankHealth = float(g_iTankHealth[victim]);
		percentage = RoundToNearest((g_iTankDamage[victim][client]/fTankHealth) * 100);
		PrintToChatAll("\x05%i\x01 [\x04%i%s%\x01]: \x03%N", g_iTankDamage[victim][client], percentage, "%", client);
	}
}

DisplayStatsToConsole()
{
	for (new i = 0; i < MAXPLAYERS; i++)
	{
		if (IS_VALID_INGAME(i) && !IsFakeClient(i))
		{
			DisplayDetailedStats(i);
		}
	}
}

public DisplayDetailedStats(client)
{
	PrintToConsole(client, "│===============================================================================================================│");
	PrintToConsole(client, "│                                      Survival Round Stats                                                     │");
	PrintToConsole(client, "│===============================================================================================================│");
	
	char sTotalTank[7];
	char sTotalCommon[7];
	char sTotalHunter[7];
	char sTotalSmoker[7];
	char sTotalBoomer[7];
	char sTotalCharger[7];
	char sTotalJockey[7];
	char sTotalSpitter[7];
	GetPaddedNumber(g_iTankTotal, sTotalTank, sizeof(sTotalTank))
	GetPaddedNumber(g_iCommonTotal, sTotalCommon, sizeof(sTotalCommon))
	GetPaddedNumber(g_iHunterTotal, sTotalHunter, sizeof(sTotalHunter))
	GetPaddedNumber(g_iSmokerTotal, sTotalSmoker, sizeof(sTotalSmoker))
	GetPaddedNumber(g_iBoomerTotal, sTotalBoomer, sizeof(sTotalBoomer))
	GetPaddedNumber(g_iChargerTotal, sTotalCharger, sizeof(sTotalCharger))
	GetPaddedNumber(g_iJockeyTotal, sTotalJockey, sizeof(sTotalJockey))
	GetPaddedNumber(g_iSpitterTotal, sTotalSpitter, sizeof(sTotalSpitter))
	
	char sTotalTankRate[8];
	char sTotalCommonRate[8];
	char sTotalHunterRate[8];
	char sTotalSmokerRate[8];
	char sTotalBoomerRate[8];
	char sTotalChargerRate[8];
	char sTotalJockeyRate[8];
	char sTotalSpitterRate[8];
	GetRatePerMinutePadded(g_iTankTotal, sTotalTankRate);
	GetRatePerMinutePadded(g_iCommonTotal, sTotalCommonRate);
	GetRatePerMinutePadded(g_iHunterTotal, sTotalHunterRate);
	GetRatePerMinutePadded(g_iSmokerTotal, sTotalSmokerRate);
	GetRatePerMinutePadded(g_iBoomerTotal, sTotalBoomerRate);
	GetRatePerMinutePadded(g_iChargerTotal, sTotalChargerRate);
	GetRatePerMinutePadded(g_iJockeyTotal, sTotalJockeyRate);
	GetRatePerMinutePadded(g_iSpitterTotal, sTotalSpitterRate);
	
	float fRate = GetRatePerMinute(g_iTotalSI);
	char sSurvivalTime[32];
	GetCurrentSurvivalTime(sSurvivalTime)
	char sStatus[14];
	if (!g_bRoundEnd && !g_bRoundStart)
	{
		sStatus = "Pre-round...";
		sSurvivalTime = "";
	}
	else if (g_bRoundStart)
	{
		sStatus = "In Progress:";
	}
	else
	{
		sStatus = "Round Time:";
	}
	PadRight(sStatus, sizeof(sStatus));
	
	PrintToConsole(client, "");
	PrintToConsole(client, "%s %s", sStatus, sSurvivalTime);
	PrintToConsole(client, "SI Rates:     %f SI/min", fRate);
	PrintToConsole(client, "");
	
	PrintToConsole(client, "┌────────── Totals ────────────┐");
	PrintToConsole(client, "│ Type    │  Kills  │   Rate   │");
	PrintToConsole(client, "├──────────────────────────────┤")
	PrintToConsole(client, "│ Tank    │ %s  │ %s  │", sTotalTank, sTotalTankRate);
	PrintToConsole(client, "│ Common  │ %s  │ %s  │", sTotalCommon, sTotalCommonRate);
	PrintToConsole(client, "├──────────────────────────────┤")
	PrintToConsole(client, "│ Hunter  │ %s  │ %s  │", sTotalHunter, sTotalHunterRate);
	PrintToConsole(client, "│ Smoker  │ %s  │ %s  │", sTotalSmoker, sTotalSmokerRate);
	PrintToConsole(client, "│ Boomer  │ %s  │ %s  │", sTotalBoomer, sTotalBoomerRate);
	PrintToConsole(client, "│ Charger │ %s  │ %s  │", sTotalCharger, sTotalChargerRate);
	PrintToConsole(client, "│ Jockey  │ %s  │ %s  │", sTotalJockey, sTotalJockeyRate);
	PrintToConsole(client, "│ Spitter │ %s  │ %s  │", sTotalSpitter, sTotalSpitterRate);
	PrintToConsole(client, "└──────────────────────────────┘");
	
	PrintToConsole(client, "┌───────────────────────────────────── Individual Stats ────────────────────────────────────────────────────────┐");
	PrintToConsole(client, "│ Player          │ Tank %s │  SI %s │ Common %s ││ Hunter │ Smoker │ Boomer │ Charger │ Jockey │ Spitter │ Common │", "%", "%", "%");
	PrintToConsole(client, "├───────────────────────────────────────────────────────────────────────────────────────────────────────────────┤");
	
	float fTankHealth = g_iTankDamageTotal == 0 ? 1.0 : float(g_iTankDamageTotal);
	float fTotalSI = g_iTotalSI == 0 ? 1.0 : float(g_iTotalSI);
	float fTotalCommon = g_iCommonTotal == 0 ? 1.0 : float(g_iCommonTotal);
	
	for (new i = 0; i < MAXPLAYERS; i++)
	{
		if (IS_VALID_SURVIVOR(i))
		{
			char sPadName[16];
			GetPaddedName(i, sPadName)
			
			// Calculate the percentages for this survivor
			char sTankPer[7];
			char sSIPer[6];
			char sCommonPer[9];
			GetPaddedKillPercent(GetValueFromTrie(g_hTankDamageTotal, i), fTankHealth, sTankPer, sizeof(sTankPer));
			GetPaddedKillPercent(GetValueFromTrie(g_hTotalSI, i), fTotalSI, sSIPer, sizeof(sSIPer));
			GetPaddedKillPercent(GetValueFromTrie(g_hCommonTotal, i), fTotalCommon, sCommonPer, sizeof(sCommonPer));
			
			char sIndHunterKill[7];
			char sIndSmokerKill[7];
			char sIndBoomerKill[7];
			char sIndChargerKill[8];
			char sIndJockeyKill[7];
			char sIndSpitterKill[8];
			char sIndCommonKill[7];
			GetPaddedNumber(GetValueFromTrie(g_hHunterCount, i), sIndHunterKill, sizeof(sIndHunterKill));
			GetPaddedNumber(GetValueFromTrie(g_hSmokerCount, i), sIndSmokerKill, sizeof(sIndSmokerKill));
			GetPaddedNumber(GetValueFromTrie(g_hBoomerCount, i), sIndBoomerKill, sizeof(sIndBoomerKill));
			GetPaddedNumber(GetValueFromTrie(g_hChargerCount, i), sIndChargerKill, sizeof(sIndChargerKill));
			GetPaddedNumber(GetValueFromTrie(g_hJockeyCount, i), sIndJockeyKill, sizeof(sIndJockeyKill));
			GetPaddedNumber(GetValueFromTrie(g_hSpitterCount, i), sIndSpitterKill, sizeof(sIndSpitterKill));
			GetPaddedNumber(GetValueFromTrie(g_hCommonTotal, i), sIndCommonKill, sizeof(sIndCommonKill));
			
			PrintToConsole(client, "│ %s │ %s │ %s │ %s ││ %s │ %s │ %s │ %s │ %s │ %s │ %s │", sPadName, sTankPer, sSIPer, sCommonPer, sIndHunterKill, sIndSmokerKill, sIndBoomerKill, sIndChargerKill, sIndJockeyKill, sIndSpitterKill, sIndCommonKill);
		}
	}
	
	PrintToConsole(client, "└───────────────────────────────────────────────────────────────────────────────────────────────────────────────┘");
	
	// Delay displaying stuff to avoid the console from exploding...
	CreateTimer(0.1, Timer_DelayStats, client);
}

public Action:Timer_DelayStats(Handle:hTimer, any:client)
{
	int iSurvCount = 0;
	int iSurvA = -1;
	int iSurvB = -1;
	int iSurvC = -1;
	int iSurvD = -1;
	char sSurvivorA[16];
	char sSurvivorB[16];
	char sSurvivorC[16];
	char sSurvivorD[16];
	
	for (int i = 0; i < MAXPLAYERS; i++)
	{
		if (IS_VALID_SURVIVOR(i))
		{
			//
			// Cache info about this individual survivor for later1
			//			
			switch (iSurvCount)
			{
				case 0:
				{
					iSurvA = i;
					GetPaddedName(i, sSurvivorA);
				}
				case 1:
				{
					iSurvB = i;
					GetPaddedName(i, sSurvivorB);
				}
				case 2:
				{
					iSurvC = i;
					GetPaddedName(i, sSurvivorC);
				}
				case 3:
				{
					iSurvD = i;
					GetPaddedName(i, sSurvivorD);
					break;
				}
			}
			iSurvCount++;
		}
	}
	
	char sKits[8];
	char sDefibs[7];
	char sPills[6];
	char sShots[5];
	char sPipes[6];
	char sMolotovs[9];
	char sBiles[6];
	char sAcc[9];
	char sHeadshotAcc[9];
	char sSIHeadshot[12];
	
	PrintToConsole(client, "┌────────────────────────────────── Item Usage ────────────────────────────────┐┌───────────── Accuracy ────────────┐");
	PrintToConsole(client, "│                 │ Medkits │ Defibs │ Pills │ Shot │ Pipes │ Molotovs │ Biles ││ Accuracy │ Headshot │ SI Headshot │");
	PrintToConsole(client, "├──────────────────────────────────────────────────────────────────────────────┤├───────────────────────────────────┤");
	GetItemUsageSummary(iSurvA, sKits, sDefibs, sPills, sShots, sPipes, sMolotovs, sBiles);
	GetAccSummary(iSurvA, sAcc, sHeadshotAcc, sSIHeadshot);
	PrintToConsole(client, "│ %s │ %s │ %s │ %s │ %s │ %s │ %s │ %s ││ %s │ %s │ %s │", sSurvivorA, sKits, sDefibs, sPills, sShots, sPipes, sMolotovs, sBiles, sAcc, sHeadshotAcc, sSIHeadshot);
	//PrintToConsole(client, "├──────────────────────────────────────────────────────────────────────────────┤");
	GetItemUsageSummary(iSurvB, sKits, sDefibs, sPills, sShots, sPipes, sMolotovs, sBiles);
	GetAccSummary(iSurvB, sAcc, sHeadshotAcc, sSIHeadshot);
	PrintToConsole(client, "│ %s │ %s │ %s │ %s │ %s │ %s │ %s │ %s ││ %s │ %s │ %s │", sSurvivorB, sKits, sDefibs, sPills, sShots, sPipes, sMolotovs, sBiles, sAcc, sHeadshotAcc, sSIHeadshot);
	//PrintToConsole(client, "├──────────────────────────────────────────────────────────────────────────────┤");
	GetItemUsageSummary(iSurvC, sKits, sDefibs, sPills, sShots, sPipes, sMolotovs, sBiles);
	GetAccSummary(iSurvC, sAcc, sHeadshotAcc, sSIHeadshot);
	PrintToConsole(client, "│ %s │ %s │ %s │ %s │ %s │ %s │ %s │ %s ││ %s │ %s │ %s │", sSurvivorC, sKits, sDefibs, sPills, sShots, sPipes, sMolotovs, sBiles, sAcc, sHeadshotAcc, sSIHeadshot);
	//PrintToConsole(client, "├──────────────────────────────────────────────────────────────────────────────┤");
	GetItemUsageSummary(iSurvD, sKits, sDefibs, sPills, sShots, sPipes, sMolotovs, sBiles);
	GetAccSummary(iSurvD, sAcc, sHeadshotAcc, sSIHeadshot);
	PrintToConsole(client, "│ %s │ %s │ %s │ %s │ %s │ %s │ %s │ %s ││ %s │ %s │ %s │", sSurvivorD, sKits, sDefibs, sPills, sShots, sPipes, sMolotovs, sBiles, sAcc, sHeadshotAcc, sSIHeadshot);
	PrintToConsole(client, "└──────────────────────────────────────────────────────────────────────────────┘└───────────────────────────────────┘");
	
	CreateTimer(0.1, Timer_DelayStats2, client);
}

public Action:Timer_DelayStats2(Handle:hTimer, any:client)
{
	int iSurvCount = 0;
	int iSurvA = -1;
	int iSurvB = -1;
	int iSurvC = -1;
	int iSurvD = -1;
	char sSurvivorA[16];
	char sSurvivorB[16];
	char sSurvivorC[16];
	char sSurvivorD[16];
	
	for (int i = 0; i < MAXPLAYERS; i++)
	{
		if (IS_VALID_SURVIVOR(i))
		{
			//
			// Cache info about this individual survivor for later1
			//
			ResolveShot(i);
			
			switch (iSurvCount)
			{
				case 0:
				{
					iSurvA = i;
					GetPaddedName(i, sSurvivorA);
				}
				case 1:
				{
					iSurvB = i;
					GetPaddedName(i, sSurvivorB);
				}
				case 2:
				{
					iSurvC = i;
					GetPaddedName(i, sSurvivorC);
				}
				case 3:
				{
					iSurvD = i;
					GetPaddedName(i, sSurvivorD);
					break;
				}
			}
			iSurvCount++;
		}
	}
	
	
	char sFF1[16];
	char sFF2[16];
	char sFF3[16];
	char sFF4[16];
	
	PrintToConsole(client, "┌───────────────────────────────────── Friendly Fire ──────────────────────────────────────┐");
	PrintToConsole(client, "│                 ││ %s │ %s │ %s │ %s │", sSurvivorA, sSurvivorB, sSurvivorC, sSurvivorD);
	PrintToConsole(client, "├──────────────────────────────────────────────────────────────────────────────────────────┤");
	GetFFSummary(iSurvA, iSurvA, iSurvB, iSurvC, iSurvD, sFF1, sFF2, sFF3, sFF4);
	
	PrintToConsole(client, "│ %s ││ %s │ %s │ %s │ %s │", sSurvivorA, sFF1, sFF2, sFF3, sFF4);
	//PrintToConsole(client, "├──────────────────────────────────────────────────────────────────────────────────────────┤├───────────────────────────────────┤");
	GetFFSummary(iSurvB, iSurvA, iSurvB, iSurvC, iSurvD, sFF1, sFF2, sFF3, sFF4);
	
	PrintToConsole(client, "│ %s ││ %s │ %s │ %s │ %s │", sSurvivorB, sFF1, sFF2, sFF3, sFF4);
	//PrintToConsole(client, "├──────────────────────────────────────────────────────────────────────────────────────────┤├───────────────────────────────────┤");
	GetFFSummary(iSurvC, iSurvA, iSurvB, iSurvC, iSurvD, sFF1, sFF2, sFF3, sFF4);
	
	PrintToConsole(client, "│ %s ││ %s │ %s │ %s │ %s │", sSurvivorC, sFF1, sFF2, sFF3, sFF4);
	//PrintToConsole(client, "├──────────────────────────────────────────────────────────────────────────────────────────┤├───────────────────────────────────┤");
	GetFFSummary(iSurvD, iSurvA, iSurvB, iSurvC, iSurvD, sFF1, sFF2, sFF3, sFF4);
	
	PrintToConsole(client, "│ %s ││ %s │ %s │ %s │ %s │", sSurvivorD, sFF1, sFF2, sFF3, sFF4);
	PrintToConsole(client, "└──────────────────────────────────────────────────────────────────────────────────────────┘");
}

GetItemUsageSummary(client, char sKits[8], char sDefibs[7], char sPills[6], char sShots[5], char sPipes[6], char sMolotovs[9], char sBiles[6])
{
	int iMedkits = GetValueFromTrie(g_hUsedMedkits, client);
	GetPaddedNumber(iMedkits, sKits, sizeof(sKits));
	
	int iDefibs = GetValueFromTrie(g_hUsedDefibs, client);
	GetPaddedNumber(iDefibs, sDefibs, sizeof(sDefibs));
	
	int iPills = GetValueFromTrie(g_hUsedPills, client);
	GetPaddedNumber(iPills, sPills, sizeof(sPills));
	
	int iShots = GetValueFromTrie(g_hUsedShots, client);
	GetPaddedNumber(iShots, sShots, sizeof(sShots));
	
	int iPipes = GetValueFromTrie(g_hUsedPipes, client);
	GetPaddedNumber(iPipes, sPipes, sizeof(sPipes));
	
	int iMolotovs = GetValueFromTrie(g_hUsedMolotovs, client);
	GetPaddedNumber(iMolotovs, sMolotovs, sizeof(sMolotovs));
	
	int iBiles = GetValueFromTrie(g_hUsedBiles, client);
	GetPaddedNumber(iBiles, sBiles, sizeof(sBiles));
}

GetAccSummary(client, char sAccuracy[9], char sHeadshotAcc[9], char sSIHeadshot[12])
{
	int iShotsFired = GetValueFromTrie(g_hShotsFired, client);
	int iShotsLanded = GetValueFromTrie(g_hShotsLanded, client);
	int iShotsLandedHead = GetValueFromTrie(g_hShotsLandedHead, client);
	int iShotsLandedSI = GetValueFromTrie(g_hShotsLandedSI, client);
	int iShotsLandedHeadSI = GetValueFromTrie(g_hShotsLandedHeadSI, client);
	
	int iAccuracy = GetPercentageRounded(iShotsLanded, iShotsFired);
	int iHeadAcc = GetPercentageRounded(iShotsLandedHead, iShotsFired);
	int iAccSI = GetPercentageRounded(iShotsLandedHeadSI, iShotsLandedSI);
	
	GetPaddedRoundedPercent(iAccuracy, sAccuracy, sizeof(sAccuracy));
	GetPaddedRoundedPercent(iHeadAcc, sHeadshotAcc, sizeof(sHeadshotAcc));
	GetPaddedRoundedPercent(iAccSI, sSIHeadshot, sizeof(sSIHeadshot));
}

GetFFSummary(int iSurvIndex, int iSurv1, int iSurv2, int iSurv3, int iSurv4, char sFF1[16], char sFF2[16], char sFF3[16], char sFF4[16])
{
	if (IS_VALID_SURVIVOR(iSurvIndex))
	{
		if (IS_VALID_SURVIVOR(iSurv1))
		{
			GetPaddedNumber(g_iFFGiven[iSurvIndex][iSurv1], sFF1, sizeof(sFF1));
		}
		else
		{
			GetPaddedNumber(0, sFF1, sizeof(sFF1));
		}
		
		if (IS_VALID_SURVIVOR(iSurv2))
		{
			GetPaddedNumber(g_iFFGiven[iSurvIndex][iSurv2], sFF2, sizeof(sFF2));
		}
		else
		{
			GetPaddedNumber(0, sFF2, sizeof(sFF2));
		}
		
		if (IS_VALID_SURVIVOR(iSurv3))
		{
			GetPaddedNumber(g_iFFGiven[iSurvIndex][iSurv3], sFF3, sizeof(sFF3));
		}
		else
		{
			GetPaddedNumber(0, sFF3, sizeof(sFF3));
		}
		
		if (IS_VALID_SURVIVOR(iSurv4))
		{
			GetPaddedNumber(g_iFFGiven[iSurvIndex][iSurv4], sFF4, sizeof(sFF4));
		}
		else
		{
			GetPaddedNumber(0, sFF4, sizeof(sFF4));
		}
	}
	else
	{
		GetPaddedNumber(0, sFF1, sizeof(sFF1));
		GetPaddedNumber(0, sFF2, sizeof(sFF2));
		GetPaddedNumber(0, sFF3, sizeof(sFF3));
		GetPaddedNumber(0, sFF4, sizeof(sFF4));
	}
}

GetRatePerMinutePadded(iCount, char sRate[8])
{
	float fRate = GetRatePerMinute(iCount);
	
	Format(sRate, sizeof(sRate), "%.2f", fRate);
	
	PadLeft(sRate, sizeof(sRate));
}

GetPaddedKillPercent(int iTotalInd, float fTotal, String:buffer[], maxlength)
{
	int iRate = RoundToNearest((iTotalInd / fTotal) * 100);
	Format(buffer, maxlength, "%i%s", iRate, "%");
	
	PadLeft(buffer, maxlength);
}

GetPaddedRoundedPercent(int iCount, String:sBuffer[], maxlength)
{
	Format(sBuffer, maxlength, "%i%s", iCount, "%");
	
	PadLeft(sBuffer, maxlength);
}

GetPaddedNumber(int iCount, String:sBuffer[], maxlength)
{
	Format(sBuffer, maxlength, "%i", iCount);
	
	PadLeft(sBuffer, maxlength);
}

GetPaddedName(client, char sPadName[16])
{
	Format(sPadName, sizeof(sPadName), "%.15N", client);
	
	PadRight(sPadName, sizeof(sPadName));
}

PadRight(String:buffer[], maxlength)
{
	int iPadLength = maxlength - strlen(buffer) - 1;
	
	char[] sPad = new char[maxlength];
	for (new i = 0; i < iPadLength; i++)
	{
		Format(sPad, maxlength, "%s ", sPad);
	}
	
	Format(buffer, maxlength, "%s%s", buffer, sPad);
}

PadLeft(String:buffer[], maxlength)
{
	int iPadLength = maxlength - strlen(buffer) - 1;
	
	char[] sPad = new char[maxlength];
	for (new i = 0; i < iPadLength; i++)
	{
		Format(sPad, maxlength, "%s ", sPad);
	}
	
	Format(buffer, maxlength, "%s%s", sPad, buffer);
}

//==========================
// Event Hooks
//==========================

public Action:Event_SurvivalRoundStart(Handle:hEvent, const String:name[], bool:dontBroadcast)
{
	g_iRoundStart = GetTime();
	g_fRoundStart = GetGameTime();
	g_bRoundEnd = false;
	g_bRoundStart = true;
	
	ResetStats();
}

public Action:Event_RoundEnd(Handle:hEvent, const String:name[], bool:dontBroadcast)
{
	if (!g_bRoundEnd)
	{
		g_fSurvivalTime = GetEventFloat(hEvent, "time");
		g_bRoundEnd = true;
		g_bRoundStart = false;
		
		DisplayStatsToConsole();
		
		if (g_bAutoDisplay)
		{
			DisplaySIStats(-1);
		}
	}
}

public Action:Event_TankSpawn(Handle:hEvent, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId( GetEventInt(hEvent, "userid") );
	if (!IS_VALID_INFECTED(client)) return;
	
	// Reset the damage done to this tank for each survivor
	for (new i = 1; i < MAXPLAYERS; i++)
	{
		if (IS_VALID_SURVIVOR(i)) 
		{
			g_iTankDamage[client][i] = 0;
		}
	}
	
	// Track how much health this new tank has
	new fHealth = GetClientHealth(client);
	g_iTankLastHealth[client] = fHealth;
	g_bTankIncap[client] = false;
	g_iTankHealth[client] = fHealth;
}

public Action:Event_HealSuccess(Handle:hEvent, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(hEvent, "subject"));
	
	AddValueToTrie(g_hUsedMedkits, client, 1);
}

public Action:Event_DefibUsed(Handle:hEvent, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(hEvent, "subject"));
	
	AddValueToTrie(g_hUsedDefibs, client, 1);
}

public Action:Event_AdrenUsed(Handle:hEvent, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(hEvent, "userid"));
	
	AddValueToTrie(g_hUsedShots, client, 1);
}

public Action:Event_PillsUsed(Handle:hEvent, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(hEvent, "subject"));
	
	AddValueToTrie(g_hUsedPills, client, 1);
}

public Action:Event_WeaponFire(Handle:hEvent, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId( GetEventInt(hEvent, "userid"));
	new iWeaponId = GetEventInt(hEvent, "weaponid");
	
	if (iWeaponId == _:WEPID_PIPE_BOMB || iWeaponId == _:WEPID_MOLOTOV || iWeaponId == _:WEPID_VOMITJAR)
	{
		HandleThrownExplosive(client, iWeaponId);
	}
	else
	{
		// Increment number of shots taken
		AddValueToTrie(g_hShotsFired, client, 1);
		
		// Determine if the previous shot hit anything
		ResolveShot(client);
	}
}

ResolveShot(client)
{
	// Check if previous shot landed
	if (g_bCurrentShotHit[client])
	{
		AddValueToTrie(g_hShotsLanded, client, 1);
		if (g_bCurrentShotHead[client])
		{
			AddValueToTrie(g_hShotsLandedHead, client, 1);
		}
		
		if (g_bCurrentShotSIHit[client])
		{
			AddValueToTrie(g_hShotsLandedSI, client, 1);
			if (g_bCurrentShotSIHead[client])
			{
				AddValueToTrie(g_hShotsLandedHeadSI, client, 1);
			}
		}
	}
	
	// Clear status of last shot
	g_bCurrentShotHit[client] = false;
	g_bCurrentShotHead[client] = false;
	g_bCurrentShotSIHit[client] = false;
	g_bCurrentShotSIHead[client] = false;
}

public Action:Event_InfectedHurt(Handle:hEvent, const String:name[], bool:dontBroadcast)
{
	new dmgType = GetEventInt(hEvent, "type");
	if (dmgType & DMG_BURN)
	{
		// Don't include fire damage when determining accuracy
		return Plugin_Continue;
	}
	
	new attacker = GetClientOfUserId( GetEventInt(hEvent, "attacker") );
	
	g_bCurrentShotHit[attacker] = true;
	new hitgroup = GetEventInt(hEvent, "hitgroup");
	if (hitgroup == HITGROUP_HEAD)
	{
		g_bCurrentShotHead[attacker] = true;
	}
	
	return Plugin_Continue;
}


public Action:Event_PlayerHurt(Handle:hEvent, const String:name[], bool:dontBroadcast)
{
	new victim = GetClientOfUserId( GetEventInt(hEvent, "userid") );
	new attacker = GetClientOfUserId( GetEventInt(hEvent, "attacker") );
	
	if (IS_VALID_SURVIVOR(victim) && IS_VALID_SURVIVOR(attacker) && victim != attacker)
	{
		new dmg = GetEventInt(hEvent, "dmg_health");
		
		AddValueToTrie(g_hTotalFF, victim, dmg);
		g_iFFTaken[victim][attacker] += dmg;
		
		AddValueToTrie(g_hTotalFFGiven, attacker, dmg);
		g_iFFGiven[attacker][victim] += dmg;
		return Plugin_Continue;
	}
	
	if (!IS_VALID_INFECTED(victim)) return Plugin_Continue;
	
	new dmgType = GetEventInt(hEvent, "type");

	if (!(dmgType & DMG_BURN))
	{
		// Only consider non-fire damage for accuracy calculation
		g_bCurrentShotHit[attacker] = true;
		g_bCurrentShotSIHit[attacker] = true;
		
		new hitgroup = GetEventInt(hEvent, "hitgroup");
		if (hitgroup == HITGROUP_HEAD)
		{
			g_bCurrentShotSIHead[attacker] = true;
			g_bCurrentShotHead[attacker] = true;
		}
	}
	
	
	new zClass = GetEntProp(victim, Prop_Send, "m_zombieClass");
	
	// Track tank damage
	switch (zClass)
	{
		case ZC_TANK:
		{
			if (IS_VALID_SURVIVOR(attacker))
			{
				// Track how much damage the survivor did to the tank
				new dmg = GetEventInt(hEvent, "dmg_health");
				new incap = GetEntProp(victim, Prop_Send, "m_isIncapacitated");
				
				new nxtHealth = GetEventInt(hEvent, "health");
				
				if (!g_bTankIncap[victim])
				{
					if (incap) 
					{
						dmg = g_iTankLastHealth[victim];
						g_bTankIncap[victim] = true;
					}
					g_iTankDamage[victim][attacker] += dmg;
					g_iTankLastHealth[victim] = nxtHealth;
					g_iTankDamageTotal += dmg;
					AddValueToTrie(g_hTankDamageTotal, attacker, dmg);
				}
			}
		}	
	}
	
	return Plugin_Continue;
}

public Action:Event_InfectedDeath(Handle:hEvent, const String:name[], bool:dontBroadcast)
{
	if (!g_bRoundEnd)
	{
		new attacker = GetClientOfUserId( GetEventInt(hEvent, "attacker") );
		
		if (!IS_VALID_SURVIVOR(attacker)) return Plugin_Continue;
		
		// Track how many common the survivor killed
		g_iCommonTotal += 1;
		AddValueToTrie(g_hCommonTotal, attacker, 1);
	}
	return Plugin_Continue;
}

public Action:Event_PlayerDeath(Handle:hEvent, const String:name[], bool:dontBroadcast)
{
	new victim = GetClientOfUserId( GetEventInt(hEvent, "userid") );
	new attacker = GetClientOfUserId( GetEventInt(hEvent, "attacker") );

	if (!IS_VALID_INFECTED(victim) || !IS_VALID_SURVIVOR(attacker)) return Plugin_Continue;
	
	new zClass = GetEntProp(victim, Prop_Send, "m_zombieClass");
	
	// Track which survivor killed the SI and display the tank report if enabled
	switch (zClass)
	{
		case ZC_TANK:
		{
			// Keep track of how many tanks were killed. Only count tank if a survivor killed it since that's how the game does it.
			g_iTankTotal++;
			
			if (g_bTankReportEnabled)
			{
				// Display tank report
				DisplayTankReport(victim);
			}
		}
		case ZC_SMOKER:
		{
			g_iSmokerTotal += 1;
			g_iTotalSI += 1;
			AddValueToTrie(g_hSmokerCount, attacker, 1);
			AddValueToTrie(g_hTotalSI, attacker, 1);
		}
		case ZC_BOOMER:
		{
			g_iBoomerTotal += 1;
			g_iTotalSI += 1;
			AddValueToTrie(g_hBoomerCount, attacker, 1);
			AddValueToTrie(g_hTotalSI, attacker, 1);
		}
		case ZC_HUNTER:
		{
			g_iHunterTotal += 1;
			g_iTotalSI += 1;
			AddValueToTrie(g_hHunterCount, attacker, 1);
			AddValueToTrie(g_hTotalSI, attacker, 1);
		}
		case ZC_SPITTER:
		{
			g_iSpitterTotal += 1;
			g_iTotalSI += 1;
			AddValueToTrie(g_hSpitterCount, attacker, 1);
			AddValueToTrie(g_hTotalSI, attacker, 1);
		}
		case ZC_JOCKEY:
		{
			g_iJockeyTotal += 1;
			g_iTotalSI += 1;
			AddValueToTrie(g_hJockeyCount, attacker, 1);
			AddValueToTrie(g_hTotalSI, attacker, 1);
		}
		case ZC_CHARGER:
		{
			g_iChargerTotal += 1;
			g_iTotalSI += 1;
			AddValueToTrie(g_hChargerCount, attacker, 1);
			AddValueToTrie(g_hTotalSI, attacker, 1);
		}
	}
	return Plugin_Continue;
}


HandleThrownExplosive(client, iWeaponId)
{
	switch (iWeaponId)
	{
		case WEPID_PIPE_BOMB:
		{
			AddValueToTrie(g_hUsedPipes, client, 1);
		}
		case WEPID_MOLOTOV:
		{
			AddValueToTrie(g_hUsedMolotovs, client, 1);
		}
		case WEPID_VOMITJAR:
		{
			AddValueToTrie(g_hUsedBiles, client, 1);
		}
	}
}


