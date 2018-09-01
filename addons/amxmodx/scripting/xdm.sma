/*
	Xtreme DeathMatch por FlyingCat

	Information:
	Modo de juego XDM hecho plugin para AMX Mod X 1.8.3

	Requisitos:
	- HL Bugfixed v0.1.910 o superior
	- Metamod
	- AMX Mod X 1.8.3
	- Superspawns (Include Solo necesario solo para compilar el plugin)

	Agradecimientos:
	- ConnorMcLeod
	- rtxa
	- Th3-822
	- joropito
	- GHW_Chronic
	
	Contacto: flyingcatdm@gmail.com
*/

#include <amxmisc>
#include <amxmodx>
#include <engine>
#include <fakemeta>
#include <fun>
#include <hamsandwich>
#include <hl>
#include <superspawns>

#define PLUGIN_NAME		"[HL] XDM Beta v1.1"
#define PLUGIN_NAME_SH	"[HL] XDM Beta v1.1"
#define PLUGIN_VER		"Beta 1.1 Build 31/8/2018"
#define PLUGIN_AUTHOR	"FlyingCat"

#define SIZE_WEAPONS 14 
#define SIZE_AMMO 11

// HL PDatas
const m_pPlayer					= 28;
const m_fInSpecialReload 		= 34;
const m_flNextPrimaryAttack 	= 35;
const m_flNextSecondaryAttack 	= 36;
const m_flTimeWeaponIdle 		= 37;
const m_iClip 					= 40;
const m_fInReload				= 43;
const m_flNextAttack			= 148;
const m_iFOV 					= 298;

const DMG_CROSSBOW  			= (DMG_BULLET | DMG_NEVERGIB);

// Model
#define MDL_RUNE                "models/xdm_rune.mdl"
// Sound
#define SND_RUNE_PICKED         "xdm.wav"
#define SND_HOOK_HIT			"weapons/xbow_hit2.wav"
#define SND_RUNE_TR_EXPLODE		"weapons/explode3.wav"
// Sprite
#define SPR_RUNE_DOT			"sprites/dot.spr"
#define SPR_RUNE_TR_SHOCKW		"sprites/shockwave.spr"
// Numero de runas
#define NUMB_RUNES              4 
#define player_id 1
#define is_player(%1) (player_id <= %1 <= MAX_PLAYERS)
#define InZoom(%1) (get_pdata_int(%1, m_iFOV) != 0)

// TaskIDs
enum (+=100) {
	TASK_REGENERATION = 6969,
	TASK_HUDDETAILSRUNE
};  

// Punteros CVAR
new gCvarStartWeapons[SIZE_WEAPONS];
new gCvarStartAmmo[SIZE_AMMO];
new gCvarStartHealth;
new gCvarStartArmor;
new gCvarStartLongJump;
new gCvarGameName;
new gCvarPlayerSpeed;
// Runas
new gCvarNumbRunes[NUMB_RUNES];
new gCvarColorRunes[NUMB_RUNES];
new g_RuneClassname[] = "func_rune";
// Runa de regeneracion
new gCvarRegenFrequency;
new gCvarRegenQuantityHP;
new gCvarRegenQuantityHEV;
// Runa Trap (Explosion al morir)
new gCvarTrapRadius;
new gCvarTrapDamage;
new gCvarTrapFragBonus;
new gCylinderSprite;
new gMessageDeathMsg;
// Runa Cloak (Player dificil de ver, casi invisible)
new gCvarCloakValue;
// Runa Super Speed
new gCvarSSpeedVelocity;
// Hook
new gCvarHookSpeed;
new gCvarHookEnabled;
// Daño de armas
new gCvarDamage9mmhandgun;
new gCvarDamage357;
new gCvarDamage9mmar;
new gCvarDamageShotgun;
new gCvarDamageCrossbow;

new const gNameStartWeapons[SIZE_WEAPONS][] = {
	"xdm_start_357",
	"xdm_start_9mmar",
	"xdm_start_9mmhandgun",
	"xdm_start_crossbow",
	"xdm_start_crowbar",
	"xdm_start_egon",
	"xdm_start_gauss",
	"xdm_start_hgrenade",
	"xdm_start_hornetgun",
	"xdm_start_rpg",
	"xdm_start_satchel",
	"xdm_start_shotgun",
	"xdm_start_snark",
	"xdm_start_tripmine"
};

new const gNameStartAmmo[SIZE_AMMO][] = {
	"xdm_start_ammo_shotgun",
	"xdm_start_ammo_9mm",
	"xdm_start_ammo_m203",
	"xdm_start_ammo_357",
	"xdm_start_ammo_gauss",
	"xdm_start_ammo_rpg",
	"xdm_start_ammo_crossbow",
	"xdm_start_ammo_tripmine",
	"xdm_start_ammo_satchel",
	"xdm_start_ammo_hgrenade",
	"xdm_start_ammo_snark"
};

new const gWeaponClass[][] = {
	"weapon_357",
	"weapon_9mmAR",
	"weapon_9mmhandgun",
	"weapon_crossbow",
	"weapon_crowbar",
	"weapon_egon",
	"weapon_gauss",
	"weapon_handgrenade",
	"weapon_hornetgun",
	"weapon_rpg",
	"weapon_satchel",
	"weapon_shotgun",
	"weapon_snark",
	"weapon_tripmine"
};

new const gAmmoClass[][] = {
	"ammo_357",
	"ammo_9mmAR",
	"ammo_9mmbox",
	"ammo_9mmclip",
	"ammo_ARgrenades",
	"ammo_buckshot",
	"ammo_crossbow",
	"ammo_gaussclip",
	"ammo_rpgclip"
};

new const gNameNumbRunes[NUMB_RUNES][] = {
    "xdm_numb_regen_runes",
    "xdm_numb_trap_runes",
    "xdm_numb_cloak_runes",
    "xdm_numb_sspeed_runes"
};

new const gNameColorRunes[NUMB_RUNES][] = {
    "xdm_color_regen_runes",
    "xdm_color_trap_runes", 
    "xdm_color_cloak_runes",
    "xdm_color_sspeed_runes"
};

new const gNameDescRunes[NUMB_RUNES][] = {
	"Runa de regeneracion: Te regenera HP y HEV cada cierto tiempo.", 
	"Runa de Trampa: Cuando mueres se desata una onda expansiva que hace dano.", 
	"Runa Cloak: Te vuelves semi-invisible.",
	"Runa Super Speed: Te mueves muchisimo mas rapido."
};

// Booleano para saber si un player tiene o no tiene una runa y de que tipo
// Ninguna runa = 0
// Runa de regeneracion = 1
// Runa de trampa = 2
// Runa Cloak = 3
// Runa Super Speed = 4
new g_bTieneRuna[MAX_PLAYERS + 1];

new Trie:gTrieHandleInflictorToIgnore;

new const InflictorToIgnore[][] = {
	"world",
    "worldspawn",
    "trigger_hurt",
    "door_rotating",
    "door",
    "rotating",
    "env_explosion"
};

// Armas que tendran la velocidad aumentada al recargar
new const gRSWeaponClasses[][] = {"weapon_glock", "weapon_357", "weapon_mp5", "weapon_crossbow", "weapon_rpg"};

new g_pCvarReloadSpeed;
new old_special_reload[33], old_clip[33];

// Game player equip keys
new gGamePlayerEquipKeys[32][32];

// Hook
new bool:hook[33];
new hook_to[33][3];
new bool:has_hook[33];
new beamSprite;

public plugin_init() {
	register_plugin(PLUGIN_NAME, PLUGIN_VER, PLUGIN_AUTHOR);

	// Cambia el nombre del juego a XDM v0.1
	register_forward(FM_GetGameDescription, "GameDesc");

	register_concmd("+hook","Hook_On");
	register_concmd("-hook","Hook_Off");

	// Hooks de los jugadores
	RegisterHam(Ham_Killed, "player", "FwdPlayerKilled");
	RegisterHam(Ham_Spawn, "player", "FwdPlayerPostSpawn", true);
	// Touch entre el player y la runa
    register_touch(g_RuneClassname, "player", "FwdRunePicked");

	// Da equipamiento a los jugadores al spawnear
	SetGameModePlayerEquip();	

	for (new i = 0; i < (sizeof gRSWeaponClasses); i++) {
		RegisterHam(Ham_Weapon_Reload, gRSWeaponClasses[i], "Weapon_Reload", 1);
	}

	// Daño de armas
	RegisterHam(Ham_TraceAttack, "player", "Weapons_Damages");
	RegisterHam(Ham_TraceAttack, "player", "Forward_TraceAttack");

	// Recarga de la shotgun/escopeta es en partes
	RegisterHam(Ham_Weapon_Reload, "weapon_shotgun", "Shotgun_Reload_Pre" , 0);
	RegisterHam(Ham_Weapon_Reload, "weapon_shotgun", "Shotgun_Reload_Post", 1);

	// Velocidad de la shotgun/escopeta y crossbow/ballesta al disparar (MOUSE1)
	RegisterHam(Ham_Weapon_PrimaryAttack, "weapon_shotgun", "Shotgun_Primary_Attack_Pre" , 0)
	RegisterHam(Ham_Weapon_PrimaryAttack, "weapon_shotgun", "Shotgun_Primary_Attack_Post", 1)
	RegisterHam(Ham_Weapon_PrimaryAttack, "weapon_crossbow", "Crossbow_Primary_Attack_Post", 1)
	// Velocidad de la shotgun/escopeta y crossbow/ballesta al disparar (MOUSE2)
	RegisterHam(Ham_Weapon_SecondaryAttack, "weapon_shotgun", "Shotgun_Secondary_Attack_Pre" , 0);
	RegisterHam(Ham_Weapon_SecondaryAttack, "weapon_shotgun", "Shotgun_Secondary_Attack_Post", 1);
	RegisterHam(Ham_Weapon_SecondaryAttack, "weapon_crossbow", "Crossbow_Secondary_Attack_Post", 1);
}

public plugin_precache() {
	// Precache model
    precache_model(MDL_RUNE);
    beamSprite = precache_model(SPR_RUNE_DOT);
    gCylinderSprite = precache_model(SPR_RUNE_TR_SHOCKW);	

    // Precache sound
    precache_sound(SND_RUNE_PICKED);    
	precache_sound(SND_HOOK_HIT);
	precache_sound(SND_RUNE_TR_EXPLODE);	

    create_cvar("xdm_version", PLUGIN_VER, FCVAR_SERVER);

	gCvarGameName = create_cvar("xdm_gamename", "XDM Beta v1.1", FCVAR_SERVER | FCVAR_SPONLY);

	gCvarStartHealth = create_cvar("xdm_start_health", "100");
	gCvarStartArmor = create_cvar("xdm_start_armor", "0");
	gCvarStartLongJump = create_cvar("xdm_start_longjump", "1");
	// Velocidad del player
	gCvarPlayerSpeed = create_cvar("xdm_player_speed", "300.0");
	// Hook
	gCvarHookSpeed = create_cvar("xdm_hook_speed", "5");
	gCvarHookEnabled = create_cvar("xdm_hook_enabled", "1");

	// Registrando cvar para la velocidad de recarga
	g_pCvarReloadSpeed = create_cvar("xdm_reload_speed", "0.5");

	for (new i; i < sizeof gCvarStartWeapons; i++)
		gCvarStartWeapons[i] = create_cvar(gNameStartWeapons[i], "0", FCVAR_SERVER);
	for (new i; i < sizeof gCvarStartAmmo; i++)
		gCvarStartAmmo[i] = create_cvar(gNameStartAmmo[i], "0", FCVAR_SERVER);

	// Registrando cvar para el daño de las armas
	gCvarDamage9mmhandgun = create_cvar("xdm_damage_9mmhandgun", "50.0");
	gCvarDamage357 = create_cvar("xdm_damage_357", "150.0");
	gCvarDamage9mmar = create_cvar("xdm_damage_9mmar", "40.0");
	gCvarDamageShotgun = create_cvar("xdm_damage_shotgun", "60.0");
	gCvarDamageCrossbow = create_cvar("xdm_damage_crossbow", "100.0");

	// La frecuencia en que se regenerara la HP - 1.0 = 1 segundo
    gCvarRegenFrequency = create_cvar("xdm_regen_frequency", "1.0");
    // La cantidad de HP a regenerar - 3 de HP
    gCvarRegenQuantityHP = create_cvar("xdm_regen_hp_quantity", "3");
    // La cantidad de HEV a regenerar - 1 de HEV
    gCvarRegenQuantityHEV = create_cvar("xdm_regen_hev_quantity", "1");

    // El radio de daño de la Runa Trap
    gCvarTrapRadius = create_cvar("xdm_trap_radius", "500");
    // El daño que hara la Runa Trap al explotar
	gCvarTrapDamage = create_cvar("xdm_trap_damage", "1000.0");
	// La cantidad de frags que dara al matar con una runa trap
	gCvarTrapFragBonus = create_cvar("xdm_trap_frags", "2");
	gMessageDeathMsg = get_user_msgid("DeathMsg");

	// El porcentaje de semi-invisibilidad del player con la Runa Cloak
	gCvarCloakValue = create_cvar("xdm_cloak_value", "80");

	// Velocidad del player con la runa Super Speed
	gCvarSSpeedVelocity = create_cvar("xdm_sspeed_velocity", "600.0");

	gTrieHandleInflictorToIgnore = TrieCreate();

	for (new i; i < sizeof InflictorToIgnore; i++) {
    	TrieSetCell(gTrieHandleInflictorToIgnore, InflictorToIgnore[i], i);
	}

    for (new i; i < sizeof gCvarNumbRunes; i++) {
        gCvarNumbRunes[i] = create_cvar(gNameNumbRunes[i], "1", FCVAR_SERVER);
        gCvarColorRunes[i] = create_cvar(gNameColorRunes[i], "0 255 0", FCVAR_SERVER);
    }
    
    // Cargando las cvars de XDM
	server_cmd("exec xdm.cfg");
	// Cambiando la maxspeed del server para que funcione el set_user_maxspeed
	set_cvar_num("sv_maxspeed", get_pcvar_float(gCvarSSpeedVelocity));
}

public plugin_cfg() {
	// Distancia minima entre los puntos
    SsInit(185.0);
    // Comienza a analizar el mapa
    SsScan();
    // Dump de los origines encontrados
    SsDump();
    
    // Spawneando las runas con distintos colores dependiendo del tipo de runa
    for (new i; i < sizeof gCvarNumbRunes; i++) {
        for (new j ; j < get_pcvar_num(gCvarNumbRunes[i]); j++) {
            spawn_rune(i + 1);
        }
    }	
}

// Cambia el nombre del juego a XDM v0.1
public GameDesc() {
	static gamename[32]; 
	get_pcvar_string(gCvarGameName, gamename, charsmax(gamename)); 
	forward_return(FMV_STRING, gamename); 
	return FMRES_SUPERCEDE; 
}

public client_connect(id) {
    // Si es que tiene alguna runa
    if (g_bTieneRuna[id] > 0) {
        switch (g_bTieneRuna[id]) {
            // Si la runa que tiene es la de regeneracion
            case 1: {
                remove_task(TASK_REGENERATION + id);
            }
            // Si la runa que tiene es la de Cloak
            case 3: {
            	// Volvemos a la normalidad la visibilidad del player
            	UncloakPlayer(id);
            }
        }
        g_bTieneRuna[id] = 0;
        // Se remueve el task encargado de mostrar un HUD al player con informacion de la runa
        remove_task(TASK_HUDDETAILSRUNE + id);
    }    
}

public FwdPlayerKilled(victim, attacker) {
	if (is_user_alive(attacker)) {
		GiveAmmo(attacker);
	}
	// Si es que tiene alguna runa
    if (g_bTieneRuna[victim] > 0) {
        switch (g_bTieneRuna[victim]) {
            // Si la runa que tiene es la de regeneracion
            case 1: {
                remove_task(TASK_REGENERATION + victim);
            }
            // Si la runa que tiene es la de Trampa
            case 2: {
            	new szWeapon[30];
				read_data(4, szWeapon, charsmax(szWeapon));
				
				if (victim == attacker) {
					return PLUGIN_CONTINUE;
				}
				
				if (TrieKeyExists(gTrieHandleInflictorToIgnore, szWeapon)) {
			   		return PLUGIN_CONTINUE;
				}

				new iOrigin[3];
				get_user_origin(victim, iOrigin);
					
				new iRadius = get_pcvar_num(gCvarTrapRadius);
				
				UTIL_CreateBeamCylinder(iOrigin, 120, gCylinderSprite, 0, 0, 6, 16, 0, random(255), random(255), random(255), 255, 0);
				UTIL_CreateBeamCylinder(iOrigin, 320, gCylinderSprite, 0, 0, 6, 16, 0, random(255), random(255), random(255), 255, 0 );
				UTIL_CreateBeamCylinder(iOrigin, iRadius, gCylinderSprite, 0, 0, 6, 16, 0, random(255), random(255), random(255), 255, 0 );
				
				UTIL_Blast_ExplodeDamage(victim, get_pcvar_float(gCvarTrapDamage), float(iRadius));
					
				emit_sound(victim, CHAN_BODY, SND_RUNE_TR_EXPLODE, VOL_NORM, ATTN_NORM, 0, PITCH_NORM);
            }
            // Si la runa que tiene es la de Cloak
            case 3: {
            	// Volvemos a la normalidad la visibilidad del player
            	UncloakPlayer(victim);
            }
            // Si la runa que tiene es la de Super Velocidad
            case 4: {
            	// Volvemos a la normalidad la visibilidad del player
            	set_user_maxspeed(victim, get_pcvar_float(gCvarPlayerSpeed));
            }
        }
        g_bTieneRuna[victim] = 0;
         // Se remueve el task encargado de mostrar un HUD al player con informacion de la runa
        remove_task(TASK_HUDDETAILSRUNE + victim);
    }
    return PLUGIN_HANDLED;   
}

public func_regenHPHEV(taskID) {
    new idPlayer = taskID - TASK_REGENERATION;
    // Si el player esta vivo y tiene la runa de regeneracion
    if (is_user_alive(idPlayer) && g_bTieneRuna[idPlayer] == 1) {
        hl_set_user_health(idPlayer, get_user_health(idPlayer) + get_pcvar_num(gCvarRegenQuantityHP));
        hl_set_user_armor(idPlayer, hl_get_user_armor(idPlayer) + get_pcvar_num(gCvarRegenQuantityHEV));
        if (get_user_health(idPlayer) >= 100) {
            hl_set_user_health(idPlayer, 100);
        }
        if (hl_get_user_armor(idPlayer) >= 100) {
        	hl_set_user_armor(idPlayer, 100);
        }
    }
}

public CloakPlayer(id, alphaValue) {
	set_user_rendering(id, kRenderFxGlowShell, 0, 0, 0, kRenderTransAlpha, alphaValue);
}

public UncloakPlayer(id) {
	set_user_rendering(id, kRenderFxGlowShell, 0, 0, 0, kRenderTransAlpha, 255);
}

public ShowHUDDetailsRune(taskID) {
	new idPlayer = taskID - TASK_HUDDETAILSRUNE;
	// Izquierda superior
	set_dhudmessage(0, 255, 0, 0.05, 0.02, 0, 0.0, 10.0, 0.2);
	show_dhudmessage(idPlayer, gNameDescRunes[g_bTieneRuna[idPlayer] - 1]);
}

stock SplitString(p_szOutput[][], p_nMax, p_nSize, p_szInput[], p_szDelimiter) {
    new nIdx = 0, l = strlen(p_szInput);
    new nLen = (1 + copyc(p_szOutput[nIdx], p_nSize, p_szInput, p_szDelimiter));
    while((nLen < l) && (++nIdx < p_nMax))
        nLen += (1 + copyc(p_szOutput[nIdx], p_nSize, p_szInput[nLen], p_szDelimiter));
    return;
}

stock UTIL_Blast_ExplodeDamage(entid, Float:damage, Float:range) {
	new Float:flOrigin1[3];
	entity_get_vector(entid, EV_VEC_origin, flOrigin1);

	new Float:flDistance;
	new Float:flTmpDmg;
	new Float:flOrigin2[3];

	for(new i = 1; i <= MAX_PLAYERS; i++) {
		if(is_user_alive(i) && get_user_team(entid) != get_user_team(i)) {
			entity_get_vector(i, EV_VEC_origin, flOrigin2);
			flDistance = get_distance_f(flOrigin1, flOrigin2);
			
			static const szWeaponName[] = "Blast Explosion";
		
			if(flDistance <= range) {
				flTmpDmg = damage - (damage / range) * flDistance;
				fakedamage(i, szWeaponName, flTmpDmg, DMG_BLAST);
			
				message_begin(MSG_BROADCAST, gMessageDeathMsg);
				write_byte(entid);
				write_byte(i);
				write_byte(0);
				write_string(szWeaponName);
				message_end();
			}
		}
	}

	set_user_frags(entid, get_user_frags(entid) + get_pcvar_num(gCvarTrapFragBonus));
}

stock UTIL_CreateBeamCylinder(origin[3], addrad, sprite, startfrate, framerate, life, width, amplitude, red, green, blue, brightness, speed) {
	message_begin(MSG_PVS, SVC_TEMPENTITY, origin); 
	write_byte(TE_BEAMCYLINDER);
	write_coord(origin[0]);
	write_coord(origin[1]);
	write_coord(origin[2]);
	write_coord(origin[0]);
	write_coord(origin[1]);
	write_coord(origin[2] + addrad);
	write_short(sprite);
	write_byte(startfrate);
	write_byte(framerate);
	write_byte(life);
	write_byte(width);
	write_byte(amplitude);
	write_byte(red);
	write_byte(green);
	write_byte(blue);
	write_byte(brightness);
	write_byte(speed);
	message_end();
}

public FwdPlayerPostSpawn(id) {
	if (is_user_alive(id)) {
		SetPlayerStats(id);
		// Cada player que entre modificarle la maxspeed a 300
    	set_user_maxspeed(id, get_pcvar_float(gCvarPlayerSpeed));
	}	
}

// Da equipamiento a los jugadores al spawnear
public SetGameModePlayerEquip() {
	new ent = find_ent_by_class(0, "game_player_equip");

	if (!ent)
		ent = create_entity("game_player_equip");

	for (new i; i < SIZE_WEAPONS; i++) {
		// Si el jugador ya tiene el arma en su equipamiento no crearlo de nuevo
		if (get_pcvar_num(gCvarStartWeapons[i]) && !ExistsKeyValue(gWeaponClass[i], gGamePlayerEquipKeys, sizeof gGamePlayerEquipKeys)) {
			DispatchKeyValue(ent, gWeaponClass[i], "1");
		}
	}
}

public ExistsKeyValue(const key[], source[][], size) {
	for (new i; i < size; i++) {
		if (equal(key, source[i]))
			return 1;
	}
	return 0;
}

// Get all keys of game_player_equip ent
public pfn_keyvalue(entid)  {
	new classname[32], key[32], value[4];
	copy_keyvalue(classname, sizeof classname, key, sizeof key, value, sizeof value);
	static i;
	if (equal(classname, "game_player_equip")) {
		copy(gGamePlayerEquipKeys[i], charsmax(gGamePlayerEquipKeys), key);
		i++;
	}
}

SetPlayerStats(id) {
	set_user_health(id, get_pcvar_num(gCvarStartHealth));
	set_user_armor(id, get_pcvar_num(gCvarStartArmor));

	if (get_pcvar_bool(gCvarStartLongJump))
		hl_set_user_longjump(id, true);

	GiveAmmo(id);
}

public GiveAmmo(id) {
	for (new i; i < sizeof gCvarStartAmmo; i++) {
		if (get_pcvar_num(gCvarStartAmmo[i]) != 0)  // some maps like bootbox dont like this if i dont put this condition
			ag_set_user_bpammo(id, 310+i, get_pcvar_num(gCvarStartAmmo[i]));
	}
}

/* 
 * Restock/remove ammo in a user's backpack.
 */
stock ag_set_user_bpammo(client, weapon, ammo) {
	if(weapon <= HLW_CROWBAR)
		return;

	set_pdata_int(client, weapon, ammo, EXTRAOFFSET);
}

public Hook_On(id,level,cid) {
	if (!has_hook[id] && !get_pcvar_num(gCvarHookEnabled)) {
		return PLUGIN_HANDLED;
	}
	if (hook[id]) {
		return PLUGIN_HANDLED;
	}
	set_user_gravity(id, 0.0);
	set_task(0.1, "hook_prethink", id+10000, "", 0, "b");
	hook[id] = true;
	hook_to[id][0] = 999999;
	hook_prethink(id + 10000);
	emit_sound(id, CHAN_VOICE, "weapons/xbow_hit2.wav", 1.0, ATTN_NORM, 0, PITCH_NORM);
	return PLUGIN_HANDLED;
}

public Hook_Off(id) {
	if(is_user_alive(id)) 
		set_user_gravity(id);

	hook[id]=false;
	return PLUGIN_HANDLED;
}

public hook_prethink(id) {
	id -= 10000;
	if(!is_user_alive(id)) {
		hook[id]=false;
	}
	if(!hook[id]) {
		remove_task(id + 10000);
		return PLUGIN_HANDLED;
	}

	//Get Id's origin
	static origin1[3];
	get_user_origin(id,origin1);

	if(hook_to[id][0]==999999) {
		static origin2[3];
		get_user_origin(id,origin2,3);
		hook_to[id][0]=origin2[0];
		hook_to[id][1]=origin2[1];
		hook_to[id][2]=origin2[2];
	}

	// Create blue beam
	message_begin(MSG_BROADCAST, SVC_TEMPENTITY);
	write_byte(1);					//TE_BEAMENTPOINT
	write_short(id);				// start entity
	write_coord(hook_to[id][0]);
	write_coord(hook_to[id][1]);
	write_coord(hook_to[id][2]);
	write_short(beamSprite);
	write_byte(1);					// framestart
	write_byte(1);					// framerate
	write_byte(2);					// life in 0.1's
	write_byte(5);					// width
	write_byte(0);					// noise
	write_byte(0);					// red
	write_byte(0);					// green
	write_byte(255);				// blue
	write_byte(200);				// brightness
	write_byte(0);					// speed
	message_end();

	// Calculate Velocity
	static Float:velocity[3];
	velocity[0] = (float(hook_to[id][0]) - float(origin1[0])) * 3.0;
	velocity[1] = (float(hook_to[id][1]) - float(origin1[1])) * 3.0;
	velocity[2] = (float(hook_to[id][2]) - float(origin1[2])) * 3.0;

	static Float:y;
	y = velocity[0]*velocity[0] + velocity[1]*velocity[1] + velocity[2]*velocity[2];

	static Float:x;
	x = (get_pcvar_float(gCvarHookSpeed) * 120.0) / floatsqroot(y);

	velocity[0] *= x;
	velocity[1] *= x;
	velocity[2] *= x;

	set_velo(id,velocity);

	return PLUGIN_CONTINUE;
}

public set_velo(id,Float:velocity[3]) {
#if defined engine
	return set_user_velocity(id,velocity);
#else
	return set_pev(id,pev_velocity,velocity);
#endif
}

// Se encarga de spawnear las runas
public spawn_rune(runeType) {
	new Float:origin[3];
    // SsGetOrigin() retornara true si se encuentra una ubicacion util
    // Sino retornara false si ya no hay mas ubicaciones utiles
    if (SsGetOrigin(origin)) {
        new iEntity = create_entity("info_target");
        if (is_valid_ent(iEntity)) {
        	// Classname de la runa
            entity_set_string(iEntity, EV_SZ_classname, g_RuneClassname);

            // Model de la runa
            entity_set_model(iEntity, MDL_RUNE);

            // Animacion de la runa
            entity_set_float(iEntity, EV_FL_framerate, 1.0);
            
            entity_set_int(iEntity, EV_INT_solid, SOLID_TRIGGER);

            // Ubicacion de la runa
            entity_set_vector(iEntity, EV_VEC_origin, origin);

            // Colores de la runa dependiendo del tipo de runa
            new sZColorString[11];
            new sZOutput[3][3];
            // Se le resta uno ya que en el array esta en la ubicacion i - 1
            get_pcvar_string(gCvarColorRunes[runeType - 1], sZColorString, charsmax(sZColorString));
            SplitString(sZOutput, 3, 3, sZColorString, ' ');

            // Tipo de runa
            entity_set_int(iEntity, EV_INT_iuser1, runeType);

            // Glow Shell
            set_rendering(iEntity, kRenderFxGlowShell, str_to_num(sZOutput[0]), str_to_num(sZOutput[1]), 
            	str_to_num(sZOutput[2]), kRenderFxNone, 100);
            drop_to_floor(iEntity);
        }
    } else {
        server_print("[XDM] No hay mas espacio para colocar mas runas");
    }
    return PLUGIN_HANDLED;
}

public FwdRunePicked(iEntityRune, iEntityPlayer) {
    if (!pev_valid(iEntityRune))
        return PLUGIN_HANDLED;

    // Si es que no tiene runa
    if (pev_valid(iEntityRune) && (g_bTieneRuna[iEntityPlayer]) < 1) {
        g_bTieneRuna[iEntityPlayer] = entity_get_int(iEntityRune, EV_INT_iuser1);
        // Reproduce el sonido
        emit_sound(iEntityPlayer, CHAN_STATIC, SND_RUNE_PICKED, 1.0, ATTN_NORM, 0, PITCH_NORM);
        switch (entity_get_int(iEntityRune, EV_INT_iuser1)) {
            // Runa de tipo regenerativa
            case 1: {
                // Muestra un HUD con la informacion sobre la runa
                set_task(0.5, "ShowHUDDetailsRune", iEntityPlayer + TASK_HUDDETAILSRUNE, _, _, "b");
                // Da el powerup al Player que toco la runa
                set_task(get_pcvar_float(gCvarRegenFrequency), "func_regenHPHEV", iEntityPlayer + TASK_REGENERATION, _, _, "b");
                // Spawnea otra runa del mismo tipo
                spawn_rune(1);
            }

            // Runa de tipo Trampa
            case 2: {
            	// Muestra un HUD con la informacion sobre la runa
                set_task(0.5, "ShowHUDDetailsRune", iEntityPlayer + TASK_HUDDETAILSRUNE, _, _, "b");
                // No es necesario dar un powerup o algo por el estilo por aca, porque ya es suficiente pasandole el tipo de runa
                // en g_bTieneRuna[iEntityPlayer]
                // Spawnea otra runa del mismo tipo
                spawn_rune(2);
            }

            // Runa de tipo Cloak
            case 3: {
            	// Muestra un HUD con la informacion sobre la runa
                set_task(0.5, "ShowHUDDetailsRune", iEntityPlayer + TASK_HUDDETAILSRUNE, _, _, "b");
            	// Hacemos semi-invisible al player
            	CloakPlayer(iEntityPlayer, get_pcvar_num(gCvarCloakValue));
            	// Spawnea otra runa del mismo tipo
            	spawn_rune(3);
            }

            // Runa de tipo Super Speed
            case 4: {
            	// Muestra un HUD con la informacion sobre la runa
                set_task(0.5, "ShowHUDDetailsRune", iEntityPlayer + TASK_HUDDETAILSRUNE, _, _, "b");
                // Modificamos la velocidad del player
                set_user_maxspeed(iEntityPlayer, get_pcvar_float(gCvarSSpeedVelocity));
                // Spawnea otra runa del mismo tipo
                spawn_rune(4);
            }
        }
        // Remueve la runa al ser tocada por un jugador    
        remove_entity(iEntityRune);
    }
    return PLUGIN_HANDLED; 
}

// Velocidad de recarga de las armas
public Weapon_Reload(iEnt) {
	if (get_pdata_int(iEnt, m_fInReload, 4)) {
		new id = get_pdata_cbase(iEnt, m_pPlayer, 4);
		new Float:flNextAttack = get_pdata_float(id, m_flNextAttack, 5) * get_pcvar_float(g_pCvarReloadSpeed);
		set_pdata_float(id, m_flNextAttack, flNextAttack, 5);
	}
}

// Velocidad de recarga de la escopeta - 1
public Shotgun_Reload_Pre(const shotgun) {
	new id = get_pdata_cbase(shotgun, m_pPlayer, 4);
	old_special_reload[id] = get_pdata_int(shotgun, m_fInSpecialReload, 4);
}

// Velocidad de recarga de la escopeta - 2
public Shotgun_Reload_Post(const shotgun) {
	new id = get_pdata_cbase(shotgun, m_pPlayer, 4);
	
	switch(old_special_reload[id]) {
		case 0: {
			if(get_pdata_int(shotgun, m_fInSpecialReload, 4) == 1) {
				new Float:flNextAttack = get_pdata_float(id, m_flNextAttack, 5) * get_pcvar_float(g_pCvarReloadSpeed);
				set_pdata_float(id , m_flNextAttack, flNextAttack, 5);
				set_pdata_float(shotgun, m_flTimeWeaponIdle, 0.1, 4);
				set_pdata_float(shotgun, m_flNextPrimaryAttack, 0.60, 4);
				set_pdata_float(shotgun, m_flNextSecondaryAttack, 0.80, 4);
			}
		}

		case 1 : {
			if(get_pdata_int(shotgun, m_fInSpecialReload, 4) == 2) {
				set_pdata_float(shotgun, m_flTimeWeaponIdle, 0.1, 4)
			}
		}
	}
}

// Velocidad de disparo de la escopeta (MOUSE1) - 1
public Shotgun_Primary_Attack_Pre(const shotgun) {
	new player = get_pdata_cbase(shotgun, m_pPlayer, 4);
	old_clip[player] = get_pdata_int(shotgun, m_iClip, 4);
}

// Velocidad de disparo de la escopeta (MOUSE1) - 2
public Shotgun_Primary_Attack_Post(const shotgun) {
	new player = get_pdata_cbase(shotgun, m_pPlayer, 4);

	if(old_clip[player] <= 0)
		return

	set_pdata_float(shotgun, m_flNextPrimaryAttack  , 0.50, 4);

	if(get_pdata_int(shotgun, m_iClip, 4) != 0)
		set_pdata_float(shotgun, m_flTimeWeaponIdle, 2.0, 4);
	else
		set_pdata_float(shotgun, m_flTimeWeaponIdle, 0.3, 4);
}

// Velocidad de disparo de la escopeta (MOUSE2) - 1
public Shotgun_Secondary_Attack_Pre(const shotgun) {
	new player = get_pdata_cbase(shotgun, m_pPlayer, 4);
	old_clip[player] = get_pdata_int(shotgun, m_iClip, 4);
}

// Velocidad de disparo de la escopeta (MOUSE2) - 2
public Shotgun_Secondary_Attack_Post(const shotgun) {
	new player = get_pdata_cbase(shotgun, m_pPlayer, 4);

	if(old_clip[player] <= 1)
		return

	set_pdata_float(shotgun, m_flNextSecondaryAttack, 0.80, 4);

	if(get_pdata_int(shotgun, m_iClip, 4) != 0)
		set_pdata_float(shotgun, m_flTimeWeaponIdle, 3.0, 4);
	else
		set_pdata_float(shotgun, m_flTimeWeaponIdle, 0.85, 4);
}

// Velocidad de disparo de la ballesta (MOUSE1)
public Crossbow_Primary_Attack_Post(const crossbow) {
	set_pdata_float(crossbow, m_flNextPrimaryAttack, 0.50, 4);
}

// Velocidad de disparo de la ballesta (MOUSE2)
public Crossbow_Secondary_Attack_Post(const crossbow) {
	set_pdata_float(crossbow, m_flNextSecondaryAttack, 0.50, 4);
}

// Daño de armas
public Weapons_Damages(victim, inflictor, Float:damage, Float:direction[3], traceresult, damagebits) {
	if(!(1 <= inflictor <= MAX_PLAYERS))
		return HAM_IGNORED;

	if(get_user_weapon(inflictor) == HLW_GLOCK)
		SetHamParamFloat(3, get_pcvar_float(gCvarDamage9mmhandgun));

	if(get_user_weapon(inflictor) == HLW_PYTHON)
		SetHamParamFloat(3, get_pcvar_float(gCvarDamage357));

	if(get_user_weapon(inflictor) == HLW_SHOTGUN)
		SetHamParamFloat(3, get_pcvar_float(gCvarDamageShotgun));

	if(get_user_weapon(inflictor) == HLW_MP5)
		SetHamParamFloat(3, get_pcvar_float(gCvarDamage9mmar));

	return HAM_IGNORED;
}

// Daño de las armas (Ballesta con zoom)
public Forward_TraceAttack(const Victim, const Attacker, Float:Damage, const Float:Direction[3],
								const TraceResult, const Damagebits) {
	// Si esta usando una ballesta y esta usando el zoom para disparar
	if (is_player(Attacker) && (Damagebits & DMG_CROSSBOW) && get_user_weapon(Attacker) == HLW_CROSSBOW) {
		if (InZoom(Attacker)) {
			SetHamParamFloat(3, get_pcvar_float(gCvarDamageCrossbow));
			return HAM_HANDLED;
		}
	}
	return HAM_IGNORED;
}
