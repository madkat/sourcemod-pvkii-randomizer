#pragma semicolon 1

#include <sourcemod>
#include <sdktools>

#define PL_VERSION "1.02"
#define SERVER_TAG "random"

public Plugin:myinfo = {
    name        = "Randomizer",
    author      = "MadKat",
    description = "Gives players random weapons and/or classes.",
    version     = PL_VERSION,
    url         = "http://www.github.com/madkat"
}

// GiveNamedItem(string classname, int subtype)
new Handle:hGiveNamedItem;
// Weapon_Equip(CBaseCombatWeapon * weapon)
new Handle:hWeapon_Equip;
// GiveAmmo(int, str, bool)
new Handle:hGiveAmmo;
// RemoveAllItems(bool remove_suit)
new Handle:hRemoveAllItems;
// SetModel(string model)
new Handle:hSetModel;

#define MAXWEAPONS 6
new client_classes[MAXPLAYERS + 1];
new client_weapons[MAXPLAYERS + 1][MAXWEAPONS];

new cvar_enabled;
new cvar_debug;
new cvar_classes;
new cvar_weapons;
new cvar_multi_melee;
new cvar_ranged;
new cvar_multi_ranged;
new cvar_special;
new cvar_hail_mary;
new cvar_blotoutthesun;

#define W_MELEE 	0
#define W_RANGED 	1
#define W_SPECIAL 	2

#define W_TYPE 		0
#define W_SLOT 		1
#define W_SPCATK	2
#define W_AMMO_QTY	3

#define W_STRING_LEN    20

#define C_TEAM 		0
#define C_HEALTH	1
#define C_ARMOR		2

static const String:weapon_names[19][W_STRING_LEN] = {
    "weapon_archersword",
    "weapon_axesword",
    "weapon_bigaxe",
    "weapon_cutlass",
    "weapon_cutlass2",
    "weapon_seaxshield",
    "weapon_spear",
    "weapon_swordshield",
    "weapon_twoaxe",
    "weapon_twosword",
    "weapon_vikingshield",
    "weapon_blunderbuss",
    "weapon_flintlock",
    "weapon_crossbow",
    "weapon_longbow",
    "weapon_javelin",
    "weapon_throwaxe",
    "weapon_powderkeg",
    "weapon_parrot"
};

static const weapon_properties[19][5] = {
    { W_MELEE	, 1 , 0 , -1 },
    { W_MELEE	, 2 , 1 , -1 },
    { W_MELEE	, 1 , 1 , -1 },
    { W_MELEE	, 1 , 1 , -1 },
    { W_MELEE	, 1 , 0 , -1 },
    { W_MELEE	, 2 , 0 , -1 },
    { W_MELEE	, 1 , 1 , -1 },
    { W_MELEE	, 2 , 0 , -1 },
    { W_MELEE	, 1 , 0 , -1 },
    { W_MELEE	, 1 , 1 , -1 },
    { W_MELEE	, 2 , 1 , -1 },
    { W_RANGED	, 2 , 1 , 4  },
    { W_RANGED	, 2 , 0 , 0  },
    { W_RANGED	, 2 , 0 , 5  },
    { W_RANGED	, 3 , 1 , 20 },
    { W_RANGED	, 3 , 0 , 2  },
    { W_RANGED	, 3 , 0 , 4  },
    { W_SPECIAL	, 3 , 0 , -1  },
    { W_SPECIAL	, 3 , 0 , 1  }
};

static const melee_count = 11;
static const ranged_count = 6;
static const special_count = 2;

static const String:class_models[8][43] = {
    "models/player/skirmisher/skirmisher.mdl",
    "models/player/captain/captain.mdl",
    "",
    "models/player/berserker/berserker.mdl",
    "models/player/huscarl/huscarl.mdl",
    "models/player/gestir/gestir.mdl",
    "models/player/heavyknight/heavyknight.mdl",
    "models/player/bowman/bowman.mdl"
};

static const String:class_names[8][13] = {
    "Skrimisher",
    "Captain",
    "",
    "Berserker",
    "Huscarl",
    "Gestir",
    "Heavy Knight",
    "Archer"
};

static const class_properties[8][3] = {
    { 2 , 100 , 90  },
    { 2 , 125 , 150 },
    { 0 , 000 , 0   },
    { 3 , 175 , 100 },
    { 3 , 130 , 160 },
    { 3 , 115 , 120 },
    { 4 , 125 , 200 },
    { 4 , 100 , 80  }
};

static const Float:class_speeds[8] = {
    260.0,
    210.0,
    0.0,
    220.0,
    200.0,
    210.0,
    190.0,
    210.0
};

new h_iMaxHealth;
new h_iHealth;
new h_iMaxArmor;
new h_ArmorValue;
new h_iPlayerClass;
new h_iTeamNum;
new h_flDefaultSpeed;
new h_flMaxspeed;

public OnPluginStart() {
    /*
	SDK
    */

    new Handle:conf = LoadGameConfigFile("randomizer.cfg");
    
    StartPrepSDKCall(SDKCall_Player);
    PrepSDKCall_SetFromConf(conf, SDKConf_Virtual, "GiveNamedItem");
    PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);
    PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
    PrepSDKCall_SetReturnInfo(SDKType_CBaseEntity, SDKPass_Plain);
    hGiveNamedItem = EndPrepSDKCall();
    
    StartPrepSDKCall(SDKCall_Player);
    PrepSDKCall_SetFromConf(conf, SDKConf_Virtual, "Weapon_Equip");
    PrepSDKCall_AddParameter(SDKType_CBaseEntity, SDKPass_Pointer);
    hWeapon_Equip = EndPrepSDKCall();

    StartPrepSDKCall(SDKCall_Player);
    PrepSDKCall_SetFromConf(conf, SDKConf_Virtual, "GiveAmmo");
    PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
    PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
    PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
    hGiveAmmo = EndPrepSDKCall();

    StartPrepSDKCall(SDKCall_Player);
    PrepSDKCall_SetFromConf(conf, SDKConf_Virtual, "RemoveAllItems");
    PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
    hRemoveAllItems = EndPrepSDKCall();
    
    StartPrepSDKCall(SDKCall_Player);
    PrepSDKCall_SetFromConf(conf, SDKConf_Virtual, "SetModel");
    PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);
    hSetModel = EndPrepSDKCall();
    
    CloseHandle(conf);

    /*
	Cvars
    */
    CreateConVar("pvkii_randomizer_version", PL_VERSION, "Randomizer for PVKII.", FCVAR_SPONLY | FCVAR_NOTIFY | FCVAR_PLUGIN);
    
    new Handle:cv_enabled 	= CreateConVar("rnd_enabled", "1", "Enables/disables PVKII Randomizer.", FCVAR_NOTIFY | FCVAR_PLUGIN, true, 0.0, true, 1.0);
    new Handle:cv_debug 	= CreateConVar("rnd_debug", "0", "Debug mode.", FCVAR_PLUGIN, true, 0.0, true, 1.0);
    new Handle:cv_classes 	= CreateConVar("rnd_classes", "1", "Enable/disabled random class support.", FCVAR_PLUGIN, true, 0.0, true, 1.0);
    new Handle:cv_weapons 	= CreateConVar("rnd_weapons", "1", "Enable/disabled random weapon support.", FCVAR_PLUGIN, true, 0.0, true, 1.0);
    new Handle:cv_multi_melee	= CreateConVar("rnd_multi_melee", "70", "Percent chance that a player will spawn with an additional random melee weapon.", FCVAR_PLUGIN, true, 0.0, true, 100.0);
    new Handle:cv_ranged	= CreateConVar("rnd_ranged", "95", "Percent chance that a player will spawn with a random ranged weapon.", FCVAR_PLUGIN, true, 0.0, true, 100.0);
    new Handle:cv_multi_ranged	= CreateConVar("rnd_multi_ranged", "40", "Percent chance that a player will spawn with an additional random ranged weapon.", FCVAR_PLUGIN, true, 0.0, true, 100.0);
    new Handle:cv_special	= CreateConVar("rnd_special", "30", "Percent chance that a player will spawn with a random special weapon.", FCVAR_PLUGIN, true, 0.0, true, 100.0);
    new Handle:cv_hail_mary	= CreateConVar("rnd_hail_mary", "0", "Enables/disables all players spawning with kegs.", FCVAR_NOTIFY | FCVAR_PLUGIN, true, 0.0, true, 1.0);
    new Handle:cv_blotoutthesun	= CreateConVar("rnd_blotoutthesun", "0", "Enables/disables all players spawning with parrots.", FCVAR_NOTIFY | FCVAR_PLUGIN, true, 0.0, true, 1.0);
    
    HookConVarChange(cv_enabled, 	cvHookEnabled);
    HookConVarChange(cv_debug,  	cvHookDebug);
    HookConVarChange(cv_classes,  	cvHookClasses);
    HookConVarChange(cv_weapons,  	cvHookWeapons);
    HookConVarChange(cv_multi_melee, 	cvHookMultiMelee);
    HookConVarChange(cv_ranged, 	cvHookRanged);
    HookConVarChange(cv_multi_ranged, 	cvHookMultiRanged);
    HookConVarChange(cv_special, 	cvHookSpecial);
    HookConVarChange(cv_hail_mary, 	cvHookHailMary);
    HookConVarChange(cv_blotoutthesun, 	cvHookBlotOutTheSun);
    
    cvar_enabled 	= GetConVarBool(cv_enabled);
    cvar_debug 		= GetConVarBool(cv_debug);
    cvar_classes	= GetConVarBool(cv_classes);
    cvar_weapons	= GetConVarBool(cv_weapons);
    cvar_multi_melee 	= GetConVarInt(cv_multi_melee);
    cvar_ranged 	= GetConVarInt(cv_ranged);
    cvar_multi_ranged 	= GetConVarInt(cv_multi_ranged);
    cvar_special 	= GetConVarInt(cv_special);
    cvar_hail_mary 	= GetConVarBool(cv_hail_mary);
    cvar_blotoutthesun 	= GetConVarBool(cv_blotoutthesun);
    
    /*
	Event Hooks
    */
    HookEvent("player_spawn", player_spawn);
    HookEvent("player_death", player_death);
    HookEvent("player_changeteam", player_changeteam);
    HookEvent("player_changeclass", player_changeclass);
    HookEvent("round_end", round_end);
    HookEvent("gamemode_roundrestart", gamemode_roundrestart);
    
    RegAdminCmd("rnd_giveitems", Command_GiveItems, ADMFLAG_SLAY);
    RegAdminCmd("rnd_giveallitems", Command_GiveAllItems, ADMFLAG_SLAY);
    RegAdminCmd("rnd_unpause", Command_Unpause, ADMFLAG_SLAY);

    AddServerTag(SERVER_TAG);

    h_iMaxHealth	= FindSendPropInfo("CPVK2Player", "m_iMaxHealth");
    h_iHealth	   	= FindSendPropInfo("CPVK2Player", "m_iHealth");
    h_iMaxArmor		= FindSendPropInfo("CPVK2Player", "m_iMaxArmor");
    h_ArmorValue	= FindSendPropInfo("CPVK2Player", "m_ArmorValue");
    h_iPlayerClass	= FindSendPropInfo("CPVK2Player", "m_iPlayerClass");
    h_iTeamNum		= FindSendPropInfo("CPVK2Player", "m_iTeamNum");
    h_flMaxspeed	= FindSendPropInfo("CPVK2Player", "m_flMaxspeed");
    h_flDefaultSpeed	= FindSendPropInfo("CPVK2Player", "m_flDefaultSpeed");
}

public Action:Command_GiveItems(client, args) {
    GiveWeapons(client);
    return Plugin_Handled;
}

public Action:Command_GiveItem(client, args) {
    GiveWeapons(client);
    return Plugin_Handled;
}

public Action:Command_GiveAllItems(client, args) {
    for (new i = 1; i <= MaxClients; i++) if (IsClientInGame(i)) GiveWeapons(client);
    return Plugin_Handled;
}

public Action:Command_Unpause(client, args) {
    
    return Plugin_Handled;
}

public cvHookEnabled(Handle:cvar, const String:oldVal[], const String:newVal[]) { 
    cvar_enabled = GetConVarBool(cvar);
    if (!cvar_enabled) {
	RemoveServerTag(SERVER_TAG);
    } else {
	AddServerTag(SERVER_TAG);
    }
}
public cvHookDebug(Handle:cvar, const String:oldVal[], const String:newVal[]) { cvar_debug = GetConVarBool(cvar); }
public cvHookClasses(Handle:cvar, const String:oldVal[], const String:newVal[]) { cvar_classes = GetConVarBool(cvar); }
public cvHookWeapons(Handle:cvar, const String:oldVal[], const String:newVal[]) { cvar_weapons = GetConVarBool(cvar); }
public cvHookMultiMelee(Handle:cvar, const String:oldVal[], const String:newVal[]) { cvar_multi_melee = GetConVarInt(cvar); }
public cvHookRanged(Handle:cvar, const String:oldVal[], const String:newVal[]) { cvar_ranged = GetConVarInt(cvar); }
public cvHookMultiRanged(Handle:cvar, const String:oldVal[], const String:newVal[]) { cvar_multi_ranged = GetConVarInt(cvar); }
public cvHookSpecial(Handle:cvar, const String:oldVal[], const String:newVal[]) { cvar_special = GetConVarInt(cvar); }
public cvHookHailMary(Handle:cvar, const String:oldVal[], const String:newVal[]) { cvar_hail_mary = GetConVarBool(cvar); }
public cvHookBlotOutTheSun(Handle:cvar, const String:oldVal[], const String:newVal[]) { cvar_blotoutthesun = GetConVarBool(cvar); }

public OnClientPutInServer(client) {
    if (cvar_enabled) {
        if (cvar_classes) {
            client_classes[client] = GetRandomInt(1, 7);
            if (client_classes[client] <= 2)
            	client_classes[client]--; // Classes are 0-7, no class 2 yet
        }
        if (cvar_weapons) {
            client_weapons[client][0] = -2;
        }
    }
}

/**
 * RandomizeWeapons
 *  
 * Decides which weapons a client will receive on next spawn. 
 * Uses the cvar percentages to determine extra melee, ranged, 
 * extra ranged and special. This function also forces the 
 * hail_mary and blotoutthesun gamemode options. 
 */
public RandomizeWeapons(client) {
    if (cvar_debug) { PrintToServer("RND: Client %d entering RandomizeWeapons", client); }

    new current_slot = 0;

    client_weapons[client][current_slot] = GetRandomInt(0, melee_count - 1);
    if (cvar_debug) { PrintToServer("RND: Get melee weapon: %s", weapon_names[client_weapons[client][current_slot]]); }
    current_slot++;

    if (PercentChance(cvar_multi_melee)) {
	for (;;) {
	    client_weapons[client][current_slot] = GetRandomInt(0, melee_count - 1);
	    if (client_weapons[client][current_slot] != client_weapons[client][current_slot-1]) {
		break;
	    }
	}
	if (cvar_debug) { PrintToServer("RND: Get additional melee weapon: %s", weapon_names[client_weapons[client][current_slot]]); }
	current_slot++;
    }

    if (PercentChance(cvar_ranged)) {
	client_weapons[client][current_slot] = GetRandomInt(0, ranged_count - 1) + melee_count;
	if (cvar_debug) { PrintToServer("RND: Get ranged weapon: %s", weapon_names[client_weapons[client][current_slot]]); }
	current_slot++;
	if (PercentChance(cvar_multi_ranged)) {
	    for (;;) {
		client_weapons[client][current_slot] = GetRandomInt(0, ranged_count - 1) + melee_count;
		if (client_weapons[client][current_slot] != client_weapons[client][current_slot-1]) {
		    break;
		}
	    }
	    if (cvar_debug) { PrintToServer("RND: Get additional ranged weapon: %s", weapon_names[client_weapons[client][current_slot]]); }
	    current_slot++;
	}
    }

    if (PercentChance(cvar_special)) {
	client_weapons[client][current_slot] = GetRandomInt(0, special_count - 1) + melee_count + ranged_count;
	if (cvar_debug) { PrintToServer("RND: Get special weapon: %s", weapon_names[client_weapons[client][current_slot]]); }
	current_slot++;
    }

    if (cvar_hail_mary && current_slot < MAXWEAPONS) {
	client_weapons[client][current_slot] = melee_count + ranged_count;
	if (cvar_debug) { PrintToServer("RND: Get special weapon: %s", weapon_names[client_weapons[client][current_slot]]); }
	current_slot++;
    }

    if (cvar_blotoutthesun && current_slot < MAXWEAPONS) {
	client_weapons[client][current_slot] = melee_count + ranged_count + 1;
	if (cvar_debug) { PrintToServer("RND: Get special weapon: %s", weapon_names[client_weapons[client][current_slot]]); }
	current_slot++;
    }

    for (; current_slot < MAXWEAPONS; current_slot++) {
	client_weapons[client][current_slot] = -1;
    }

    if (cvar_debug) { PrintToServer("RND: Client %d exiting RandomizeWeapons", client); }
}

/**
 * Remove all weapons from a client.
 */
public RemoveWeapons(client)
{
    if (cvar_debug) { PrintToServer("RND: Client %d entering RemoveWeapons", client); }
    if (!IsPlayerAlive(client)) {
	if (cvar_debug) { PrintToServer("RND: Client %d is dead, exiting RemoveWeapons", client); }
	return;
    }

    SDKCall(hRemoveAllItems, client, false);
    
    if (cvar_debug) { PrintToServer("RND: Client %d exiting RemoveWeapons", client); }
}

/**
 * RandomizeWeapons should have already been called for this
 * client. Now to actually assign the weapons to the client.
 */
public GiveWeapons(client)
{
    if (cvar_debug) { PrintToServer("RND: Client %d entering GiveWeapons", client); }
    if (!IsPlayerAlive(client)) {
	if (cvar_debug) { PrintToServer("RND: Client %d is dead, exiting GiveWeapons", client); }
	return;
    }

    new current_weapon;
    new weapon_id;
    new weapon_object;
    decl String:name[W_STRING_LEN];

    for (current_weapon = 0; current_weapon < MAXWEAPONS; current_weapon++) {
	weapon_id = client_weapons[client][current_weapon];
	if (weapon_id == -1) {
	    // No weapon in slot
	    continue;
	}
	name = weapon_names[weapon_id];
	if (cvar_debug) { PrintToServer("RND: Giving %s to client %d", name, client); }
	weapon_object = SDKCall(hGiveNamedItem, client, name, 0);
	if (weapon_object == -1) {
	    // Client probably already had it
	    if (cvar_debug) { PrintToServer("RND: Bad weapon object, give failed"); }
	}
	else {
	    if (weapon_properties[weapon_id][W_AMMO_QTY] > -1) {
		if (cvar_debug) { PrintToServer("RND: Need to give %d ammo to client", weapon_properties[weapon_id][W_AMMO_QTY]); }
		new ammo_type = GetEntProp(weapon_object, Prop_Data, "m_iPrimaryAmmoType", 4);
		SDKCall(hGiveAmmo, client, weapon_properties[weapon_id][W_AMMO_QTY], ammo_type, true);
	    }
	    SDKCall(hWeapon_Equip, client, weapon_object);
	    // You have weapon
	}
    }
    
    if (cvar_debug) { PrintToServer("RND: Client %d exiting GiveWeapons", client); }
}

public bool:ReassignClass(client) {
    if (cvar_debug) { PrintToServer("RND: Client %d entering ReassignClass", client); }

    new bool:reassigned = false;
    new client_class = GetEntData(client, h_iPlayerClass);
    if (cvar_debug) { PrintToServer("RND: iPlayerClass: %d", client_class); }
    
    
    if (client_class == -1) {
    	reassigned = true;
    }
    else {
        if (client_class != client_classes[client]) {
    	    SetEntData(client, h_iPlayerClass, client_classes[client], 4, true);
    	    SDKCall(hSetModel, client, class_models[client_classes[client]]);
    	    SetEntData(client, h_iMaxHealth, class_properties[client_classes[client]][C_HEALTH], 4, true);
            SetEntData(client, h_iHealth, class_properties[client_classes[client]][C_HEALTH], 4, true);
    	    SetEntData(client, h_iMaxArmor, class_properties[client_classes[client]][C_ARMOR], 4, true);
            SetEntData(client, h_ArmorValue, class_properties[client_classes[client]][C_ARMOR], 4, true);
    	    SetEntDataFloat(client, h_flMaxspeed, class_speeds[client_classes[client]], true);
    	    SetEntDataFloat(client, h_flDefaultSpeed, class_speeds[client_classes[client]], true);
            reassigned = true;
        }
    }

    if (cvar_debug) { PrintToServer("RND: Client %d exiting ReassignClass, reassigned = %d", client, reassigned); }
    return reassigned;
}

public bool:PercentChance(percent) {
    return GetRandomInt(1, 100) <= percent;
}

public OnMapStart() {	
    if (cvar_debug) { PrintToServer("RND: Map Started"); }
    for (new i = 1; i <= MaxClients; i++) if (IsClientInGame(i)) OnClientPutInServer(i);
}

public player_spawn(Handle:event, const String:name[], bool:dontBroadcast) {
    new client = GetClientOfUserId(GetEventInt(event, "userid"));
    if (!client || !IsPlayerAlive(client) || !IsClientInGame(client) || !cvar_enabled)
	return;

    if (cvar_classes) {
        if (ReassignClass(client)) {
            //return;
        }
    }

    if (cvar_weapons) {
        if (client_weapons[client][0] == -2) {
            RandomizeWeapons(client);
        }
        RemoveWeapons(client);
        GiveWeapons(client);
    }

    // For debugging class randomization. Spit out player spawn data
    // to the server
    if (cvar_debug) {
	decl String:client_name[MAX_NAME_LENGTH];
	decl String:client_model[64];
	GetClientName(client, client_name, sizeof(client_name));
	GetClientModel(client, client_model, sizeof(client_model));
	new max_health = GetEntData(client, h_iMaxHealth);
	new max_armor = GetEntData(client, h_iMaxArmor);
	new client_class = GetEntData(client, h_iPlayerClass);
	new client_team = GetEntData(client, h_iTeamNum);
	new Float:max_speed = GetEntDataFloat(client, h_flMaxspeed);
	PrintToServer("RND: Player %s has spawned", client_name);
	PrintToServer("       Model   : %s", client_model);
	PrintToServer("	      Class   : %d", client_class);
	PrintToServer("	      Team    : %d", client_team);
	PrintToServer("	      Health  : %d", max_health);
	PrintToServer("	      Armor   : %d", max_armor);
	PrintToServer("	      Speed   : %f", max_speed);
    }
}

public player_changeteam(Handle:event, const String:name[], bool:dontBroadcast) {
    new client = GetClientOfUserId(GetEventInt(event, "userid"));
    if (!client) return;
    OnClientPutInServer(client);
}
public player_changeclass(Handle:event, const String:name[], bool:dontBroadcast) {
    new client = GetClientOfUserId(GetEventInt(event, "userid"));
    if (!client) return;
    OnClientPutInServer(client);
}
public player_death(Handle:event, const String:name[], bool:dontBroadcast) {
    new client = GetClientOfUserId(GetEventInt(event, "userid"));
    new attacker = GetClientOfUserId(GetEventInt(event, "attacker"));
    // Don't reset on suicide
    if (attacker && attacker != client) OnClientPutInServer(client);
}
public round_end(Handle:event, const String:name[], bool:dontBroadcast) {
    for (new i = 1; i <= MaxClients; i++) if (IsClientInGame(i)) OnClientPutInServer(i);
}
public gamemode_roundrestart(Handle:event, const String:name[], bool:dontBroadcast) {
    for (new i = 1; i <= MaxClients; i++) if (IsClientInGame(i)) OnClientPutInServer(i);
}