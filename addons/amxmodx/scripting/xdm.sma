/*
	Xtreme DeathMatch por FlyingCat

	Information:
	Modo de juego XDM hecho plugin para AMX Mod X 1.8.3

	Requisitos:
	- HL Bugfixed v0.1.910 o superior
	- Metamod
	- AMX Mod X 1.8.3
	- Superspawns (Include Solo necesario solo para compilar el plugin)

	-> Runas disponibles:
	1. Regeneracion de vida
	2. Trampa
	3. Cloak
	4. Super Velocidad
	5. Baja gravedad
	6. Vampiro

	Agradecimientos:
	- ConnorMcLeod
	- rtxa
	- Th3-822
	- joropito
	- GHW_Chronic
	- Anonimo
	- GordonFreeman
	- Gauss
	- LetiLetiLepestok
	- Lev
	- Turanga_Leela

	Testers:
	- DarkZito
	- K3NS4N
	- Assassin
	
	Contacto: flyingcatdm@gmail.com
*/

#include <amxmisc>
#include <amxmodx>
#include <engine>
#include <fakemeta>
#include <fakemeta_util>
#include <fun>
#include <hamsandwich>
#include <hl>
#include <superspawns>
#include <xs>

#define PLUGIN_NAME		"[HL] XDM Beta v1.2"
#define PLUGIN_NAME_SH	"[HL] XDM Beta v1.2"
#define PLUGIN_VER		"Beta 1.2 Build 07/9/2018"
#define PLUGIN_AUTHOR	"FlyingCat"

#define SIZE_WEAPONS 14 
#define SIZE_AMMO 11

#define CROW 			"fly_crowbar"

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

const XTRA_OFS_WEAPON 			= 4;

// Model
#define MDL_RUNE                "models/xdm_rune.mdl"

// Sound
#define SND_RUNE_PICKED         "xdm.wav"
#define SND_HOOK_HIT			"weapons/xbow_hit2.wav"
#define SND_RUNE_TR_EXPLODE		"weapons/explode3.wav"

// Sprite
#define SPR_RUNE_DOT			"sprites/dot.spr"
#define SPR_RUNE_TR_SHOCKW		"sprites/shockwave.spr"
#define SPR_FC_BLOOD			"sprites/blood.spr"
#define SPR_FC_BSPRAY			"sprites/bloodspray.spr"
#define SPR_FC_TRAIL			"sprites/zbeam3.spr"

// Numero de runas
#define NUMB_RUNES              6
#define player_id 1
#define is_player(%1) (player_id <= %1 <= MAX_PLAYERS)
#define InZoom(%1) (get_pdata_int(%1, m_iFOV) != 0)

#define RPG_SPEED 1900

// TaskIDs
enum (+=100) {
	TASK_REGENERATION = 6966,
	TASK_HUDDETAILSRUNE
};  

// Punteros CVAR
new gCvarStartWeapons[SIZE_WEAPONS];
new gCvarStartAmmo[SIZE_AMMO];
new gCvarStartHealth;
new gCvarStartArmor;
new gCvarStartLongJump;
new gCvarPlayerMaxHealth;
new gCvarPlayerMaxArmor;
new gCvarGameName;
new gCvarPlayerSpeed;
new gCvarPlayerGravity;

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

// Runa Baja Gravedad
new gCvarLowGravityValue;

// Runa Vampiro
new gCvarVampireMaxHP;
new gCvarVampireMaxHEV;
new gCvarVampireLifestealHP;
new gCvarVampireLifestealHEV;

// Hook
new gCvarHookSpeed;
new gCvarHookEnabled;

// Daño de armas
new gCvarDamage9mmhandgun;
new gCvarDamage357;
new gCvarDamage9mmar;
new gCvarDamageShotgun;
new gCvarDamageCrossbow;

// Crowbar tirable
new gCvarCrowbarRender;
new gCvarCrowbarDamage;
new gCvarCrowbarSpeed;
new gCvarCrowbarTrail;
new gCvarCrowbarLifetime;

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

new const gNameNumbRunes[NUMB_RUNES][] = {
    "xdm_numb_regen_runes",
    "xdm_numb_trap_runes",
    "xdm_numb_cloak_runes",
    "xdm_numb_sspeed_runes",
    "xdm_numb_lowgrav_runes",
    "xdm_numb_vampire_runes"
};

new const gNameColorRunes[NUMB_RUNES][] = {
    "xdm_color_regen_runes",
    "xdm_color_trap_runes", 
    "xdm_color_cloak_runes",
    "xdm_color_sspeed_runes",
    "xdm_color_lowgrav_runes", 
    "xdm_color_vampire_runes"
};

new const gNameTitlesRunes[NUMB_RUNES + 1][] = {
	"Ninguna", 
	"Regeneracion", 
	"Trampa", 
	"Cloak", 
	"Super Speed",
	"Baja Gravedad",
	"Vampiro"
};

new const gNameDescRunes[NUMB_RUNES][] = {
	"Runa de regeneracion: Te regenera HP y HEV cada cierto tiempo.", 
	"Runa de Trampa: Cuando mueres se desata una onda expansiva que hace dano.", 
	"Runa Cloak: Te vuelves semi-invisible.",
	"Runa Super Speed: Te mueves muchisimo mas rapido.",
	"Runa Baja Gravedad: Disminuye la gravedad solo para ti.",
	"Runa Vampiro: Recuperas vida y escudo con el dano que hagas. +Max HP"
};

// Booleano para saber si un player tiene o no tiene una runa y de que tipo
// Ninguna runa = 0
// Runa de regeneracion = 1
// Runa de trampa = 2
// Runa Cloak = 3
// Runa Super Speed = 4
// Runa Baja Gravedad = 5
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

new gCvarReloadSpeed;
new old_special_reload[33], old_clip[33];

// Game player equip keys
new bool:gGamePlayerEquipExists;
new gGamePlayerEquipKeys[32][32];

// Hook
new bool:hook[33];
new hook_to[33][3];
new bool:has_hook[33];
new beamSprite;

// Crowbar tirable
new bdropSprite;
new bspraySprite;
new trailSprite;

// Location system
new gLocationName[128][32]; 		// Max locations (128) and max location name length (32);
new Float:gLocationOrigin[128][3]; 	// Max locations and origin (x, y, z)
new gNumLocations;

public plugin_init() {
	register_plugin(PLUGIN_NAME, PLUGIN_VER, PLUGIN_AUTHOR);

	// Cambia el nombre del juego a XDM v0.1
	register_forward(FM_GetGameDescription, "GameDesc");
	// Infinito vuelo en la RPG
	register_forward(FM_Think, "FwdRPGThink");

	register_concmd("+hook","Hook_On");
	register_concmd("-hook","Hook_Off");

	// Get locations from locs/<mapname>.loc file
	GetLocations(gLocationName, 32, gLocationOrigin, gNumLocations);

	// Chat
	register_message(get_user_msgid("SayText"), "MsgSayText");

	// Hooks de los jugadores
	RegisterHam(Ham_Killed, "player", "FwdPlayerKilled");
	RegisterHam(Ham_Spawn, "player", "FwdPlayerPostSpawn", true);
	RegisterHam(Ham_TakeDamage, "player", "FwdOnDamagePre");

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

	// Crowbar tirable
	RegisterHam(Ham_Weapon_SecondaryAttack, "weapon_crowbar", "fw_CrowbarSecondaryAttack");
	RegisterHam(Ham_Item_AddToPlayer, "weapon_crowbar", "fw_CrowbarItemAdd");
	RegisterHam(Ham_Item_AddDuplicate, "weapon_crowbar", "fw_CrowbarItemAdd");
	register_think(CROW, "FlyCrowbar_Think");
	register_touch(CROW, "*", "FlyCrowbar_Touch");
}

public plugin_precache() {
	// Precache model
    precache_model(MDL_RUNE);
    beamSprite = precache_model(SPR_RUNE_DOT);
    gCylinderSprite = precache_model(SPR_RUNE_TR_SHOCKW);
    bdropSprite = precache_model(SPR_FC_BLOOD);	
    bspraySprite = precache_model(SPR_FC_BSPRAY);
    trailSprite = precache_model(SPR_FC_TRAIL);

    // Precache sound
    precache_sound(SND_RUNE_PICKED);    
	precache_sound(SND_HOOK_HIT);
	precache_sound(SND_RUNE_TR_EXPLODE);	

    create_cvar("xdm_version", PLUGIN_VER, FCVAR_SERVER);

	gCvarGameName = create_cvar("xdm_gamename", "XDM Beta v1.2", FCVAR_SERVER | FCVAR_SPONLY);

	gCvarStartHealth = create_cvar("xdm_start_health", "100");
	gCvarStartArmor = create_cvar("xdm_start_armor", "0");
	gCvarStartLongJump = create_cvar("xdm_start_longjump", "1");

	// Maximo HP y HEV del player
	gCvarPlayerMaxHealth = create_cvar("xdm_player_maxhealth", "100");
	gCvarPlayerMaxArmor = create_cvar("xdm_player_maxarmor", "100");

	// Velocidad del player
	gCvarPlayerSpeed = create_cvar("xdm_player_speed", "300.0");
	// Gravedad del player
	gCvarPlayerGravity = get_cvar_pointer("sv_gravity");

	// Hook
	gCvarHookSpeed = create_cvar("xdm_hook_speed", "5");
	gCvarHookEnabled = create_cvar("xdm_hook_enabled", "1");

	// Registrando cvar para la velocidad de recarga
	gCvarReloadSpeed = create_cvar("xdm_reload_speed", "0.5");

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

	// Gravedad del player con la runa Baja Gravedad
	gCvarLowGravityValue = create_cvar("xdm_lowgravity_value", "400");

	// Vida maxima del player con la runa Vampiro
	gCvarVampireMaxHP = create_cvar("xdm_vampire_maxhp", "150");
	// Escudo maximo del player con la runa Vampiro
	gCvarVampireMaxHEV = create_cvar("xdm_vampire_maxhev", "150");
	// Recuperacion del x.xx% del daño hecho directo a la HP (Default: 15% = 0.15)
	gCvarVampireLifestealHP = create_cvar("xdm_vampire_lifestealhp", "0.15");
	// Recuperacion del x.xx% del daño hecho directo al escudo (Default: 5% = 0.05)
	gCvarVampireLifestealHEV = create_cvar("xdm_vampire_lifestealhev", "0.05");

	// Crowbar tirable
	gCvarCrowbarLifetime = create_cvar("xdm_flycrowbar_time", "15.0");
	gCvarCrowbarSpeed = create_cvar("xdm_flycrowbar_speed", "1300");
	gCvarCrowbarRender = create_cvar("xdm_flycrowbar_render", "1");
	gCvarCrowbarTrail = create_cvar("xdm_flycrowbar_trail", "1");
	gCvarCrowbarDamage = create_cvar("xdm_flycrowbar_damage", "240.0");

	gTrieHandleInflictorToIgnore = TrieCreate();

	for (new i; i < sizeof InflictorToIgnore; i++) {
    	TrieSetCell(gTrieHandleInflictorToIgnore, InflictorToIgnore[i], i);
	}

    for (new i; i < sizeof gCvarNumbRunes; i++) {
        gCvarNumbRunes[i] = create_cvar(gNameNumbRunes[i], "1", FCVAR_SERVER);
        gCvarColorRunes[i] = create_cvar(gNameColorRunes[i], "0", FCVAR_SERVER);
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

/*
* AG Say
*/
public MsgSayText(msg_id, msg_dest, receiver) {
	// 192 crasheara el server por desbordamiento si alguien manda un mensaje largo con muchos %l, %w, etc...
	new text[191]; 
	
	// Obtieniendo el mensaje del player
	get_msg_arg_string(2, text, charsmax(text)); 
	
	if (text[0] == '*') // Ignora los mensajes del servidor
		return PLUGIN_CONTINUE;

	new sender = get_msg_arg_int(1);
	new isReceiverSpec = hl_get_user_spectator(receiver);

	// Añadimos o cambiamos los tags 	
	if (hl_get_user_spectator(sender)) {
		if (contain(text, "^x02(TEAM)") != -1) {
			if (!isReceiverSpec) // Solo muestra mensajes al espectador
				return PLUGIN_HANDLED;
			else
				replace(text, charsmax(text), "(TEAM)", "(ST)"); // Spectator Team
		} else {
			format(text, charsmax(text), "^x02(S)%s", text); // Spectator
		}
	} else {
		if (contain(text, "^x02(TEAM)") != -1) { // Team
			if (isReceiverSpec)
				return PLUGIN_HANDLED;
			else
				replace(text, charsmax(text), "(TEAM)", "(T)"); 
		} else
			format(text, charsmax(text), "^x02(A)%s", text); // All
	}

	// Reemplazar todos los %h con la vida actual del player
	replace_string(text, charsmax(text), "%h", fmt("%i", get_user_health(sender)), false);

	// Reemplazar todos los %a con el escudo actual del player
	replace_string(text, charsmax(text), "%a", fmt("%i", get_user_armor(sender)), false);

	// Reemplazar todos los %p con disponibilidad de longjump 
	replace_string(text, charsmax(text), "%p", hl_get_user_longjump(sender) ? "Si" : "No", false);

	// Reemplazar todos los %l con la ubicacion del player
	replace_string(text, charsmax(text), "%l", gLocationName[FindNearestLocation(sender, gLocationOrigin, gNumLocations)], false);

	// Reemplazar todos los %r con el nombre de la runa actual
	replace_string(text, charsmax(text), "%r", gNameTitlesRunes[g_bTieneRuna[sender]]);

	// Reemplazar todos los %w con el nombre del arma actual
	new ammo, bpammo, weaponid = get_user_weapon(sender, ammo, bpammo);

	if (weaponid) {
		new weaponName[32];
		get_weaponname(weaponid, weaponName, charsmax(weaponName));
		replace_string(weaponName, charsmax(weaponName), "weapon_", "");
		replace_string(text, charsmax(text), "%w", weaponName, false);
	}

	// replace all %q with total ammo (ammo and backpack ammo) of current weapon
	replace_string(text, charsmax(text), "%q", fmt("%i", ammo < 0 ? bpammo : ammo + bpammo), false); // if the weapon only has bpammo, ammo will return -1, replace it with 0

	// send final message
	set_msg_arg_string(2, text);

	return PLUGIN_CONTINUE;
}

public FwdRPGThink(ent) {
	if(!pev_valid(ent))
		return FMRES_IGNORED;
        
	static entname[32];
	pev(ent, pev_classname, entname, 31);
    
	if(!equal(entname, "rpg_rocket") || pev(ent, pev_movetype) != MOVETYPE_FLY || pev(ent, pev_waterlevel) != 0)
		return FMRES_IGNORED;
        
	if(!pev(ent, pev_iuser4)) {
		set_pev(ent, pev_iuser4, 1);
		return FMRES_IGNORED;
	}
    
	static Float:velocity[3];
	static Float:speed;
	static Float:xv;

	pev(ent, pev_velocity, velocity);
	speed  = vector_length(velocity);

	if(speed < RPG_SPEED) {
		xv = RPG_SPEED/speed;
		velocity[0] *= xv;
		velocity[1] *= xv;
		velocity[2] *= xv;
		set_pev(ent, pev_velocity, velocity);
	}
	
	return FMRES_HANDLED;
}

/*
* Location System
*/
public GetLocations(name[][], size, Float:origin[][], &numLocs) {
	new file[128], map[32], text[2048];

	get_mapname(map, charsmax(map));
	formatex(file, charsmax(file), "locs/%s.loc", map);
	
	if (file_exists(file))
		read_file(file, 0, text, charsmax(text));

	new i, j, nLen;
	j = -1;

	while (nLen < strlen(text)) {
		if (j == -1) {
			nLen += 1 + copyc(name[i], size, text[nLen], '#'); // you must plus one to skip #
			j++;
			numLocs++;
		} else {
			new number[16];
			
			nLen += 1 + copyc(number, sizeof number, text[nLen], '#'); // you must plus one to skip #
			origin[i][j] = str_to_float(number);
			
			j++;

			// if we finish to copy origin, then let's start with next location
			if (j > 2) {
				i++;
				j = -1;
			}
		}
	}
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
	// Descomentar esto si se desea volver a recargar las municaciones del player que mato
	//if (is_user_alive(attacker)) {
	//	GiveAmmo(attacker);
	//}
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
				
				// Descomentar esto si se desea que el player no pierda la runa al suicidarse
				//if (victim == attacker) {
				//	return PLUGIN_CONTINUE;
				//}
				
				if (TrieKeyExists(gTrieHandleInflictorToIgnore, szWeapon)) {
			   		return PLUGIN_CONTINUE;
				}

				new iOrigin[3];
				get_user_origin(victim, iOrigin);
					
				new iRadius = get_pcvar_num(gCvarTrapRadius);
				
				UTIL_CreateBeamCylinder(iOrigin, 120, gCylinderSprite, 0, 0, 6, 16, 0, random(255), random(255), random(255), 255, 0);
				UTIL_CreateBeamCylinder(iOrigin, 320, gCylinderSprite, 0, 0, 6, 16, 0, random(255), random(255), random(255), 255, 0 );
				UTIL_CreateBeamCylinder(iOrigin, iRadius, gCylinderSprite, 0, 0, 6, 16, 0, random(255), random(255), random(255), 255, 0 );
				
				UTIL_Blast_ExplodeDamage(victim, attacker, get_pcvar_float(gCvarTrapDamage), float(iRadius));
					
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
            // Si la runa que tiene es la de Super Velocidad
            case 5: {
            	// Volvemos a la normalidad la gravedad del player
            	new Float:Gravity = get_pcvar_float(gCvarPlayerGravity) / 800.0;
            	set_user_gravity(victim, Gravity);
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
        set_user_health(idPlayer, get_user_health(idPlayer) + get_pcvar_num(gCvarRegenQuantityHP));
        set_user_armor(idPlayer, get_user_armor(idPlayer) + get_pcvar_num(gCvarRegenQuantityHEV));
        if (get_user_health(idPlayer) >= get_pcvar_num(gCvarPlayerMaxHealth)) {
            set_user_health(idPlayer, get_pcvar_num(gCvarPlayerMaxHealth));
        }
        if (get_user_armor(idPlayer) >= get_pcvar_num(gCvarPlayerMaxArmor)) {
        	set_user_armor(idPlayer, get_pcvar_num(gCvarPlayerMaxArmor));
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

stock UTIL_Blast_ExplodeDamage(entid, entid2, Float:damage, Float:range) {
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
	// Para evitar que al suicidarse obtenga el bonus de score
	if (entid != entid2) {
		set_user_frags(entid, get_user_frags(entid) + get_pcvar_num(gCvarTrapFragBonus));
	}
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
	if (is_user_alive(id) && !gGamePlayerEquipExists) {
		SetPlayerStats(id);
		// Cada player que entre modificarle la maxspeed a 300
    	set_user_maxspeed(id, get_pcvar_float(gCvarPlayerSpeed));
    	// Cada player que entre modificarle la gravedad a la default del server por si acaso
    	set_user_gravity(id, (get_pcvar_float(gCvarPlayerGravity) / 800.0));
	}	
}

// Usado para la Runa Vampiro
public FwdOnDamagePre(victim, ent, agressor, Float:damage, bits) {		
	// si es que tiene la Runa Vampiro
	if (g_bTieneRuna[agressor] == 6) {
		if(agressor == 0 || damage < 1.0 || !is_user_alive(victim)) return;
	
		new mode, realDamage;
		
		if (victim && ent && agressor && victim != agressor)
			mode = 1;
		else if (victim && !ent && !agressor)
			mode = 2;
		else if (victim == agressor)
			mode = 0;
		
		if (mode == 1) {
			new Float:dd = damage;
			new Float:value = float(get_user_armor(victim) * 2);
			
			if (value < dd){
				dd -= value;
			} else if (value >= dd) {
				dd *= 0.2;
			}		
			realDamage = floatround(dd);
		} else if (mode == 2) {
			realDamage = floatround(damage);
		} else {
			return;
		}
		// Robo de vida (HP)
		new Float:newHP = get_pcvar_float(gCvarVampireLifestealHP) * realDamage;
		if (get_user_health(agressor) >= get_pcvar_num(gCvarVampireMaxHP)) {
			set_user_health(agressor, get_pcvar_num(gCvarVampireMaxHP));
		} else if(get_user_health(agressor) <= get_pcvar_num(gCvarVampireMaxHP)) {
			set_user_health(agressor, get_user_health(agressor) + floatround(newHP));
		}

		// Robo de vida (HP)
		new Float:newHEV = get_pcvar_float(gCvarVampireLifestealHEV) * realDamage;
		if (get_user_armor(agressor) >= get_pcvar_num(gCvarVampireMaxHEV)) {
			set_user_armor(agressor, get_pcvar_num(gCvarVampireMaxHEV));
		} else if(get_user_armor(agressor) <= get_pcvar_num(gCvarVampireMaxHEV)) {
			set_user_armor(agressor, get_user_armor(agressor) + floatround(newHEV));
		}
	}	
}


// Da equipamiento a los jugadores al spawnear
SetGameModePlayerEquip() {
	new ent = find_ent_by_class(0, "game_player_equip");

	if (!ent) {
		ent = create_entity("game_player_equip");
	} else {
		gGamePlayerEquipExists = true;
		return;
	}

	for (new i; i < SIZE_WEAPONS; i++) {
		// If the map has a game_player_equip, ignore gamemode cvars (this will avoid problems in maps like 357_box or bootbox)
		if (get_pcvar_num(gCvarStartWeapons[i]))
			DispatchKeyValue(ent, gWeaponClass[i], "1");
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

            // Color/Skin de la runa
            entity_set_int(iEntity, EV_INT_skin, get_pcvar_num(gCvarColorRunes[runeType - 1]));

            // Tipo de runa
            entity_set_int(iEntity, EV_INT_iuser1, runeType);

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
            case 5: {
            	// Muestra un HUD con la informacion sobre la runa
                set_task(0.5, "ShowHUDDetailsRune", iEntityPlayer + TASK_HUDDETAILSRUNE, _, _, "b");
                // Modificamos la gravedad del player
                new Float:Gravity = get_pcvar_float(gCvarLowGravityValue) / 800.0;
                set_user_gravity(iEntityPlayer, Gravity);
                // Spawnea otra runa del mismo tipo
                spawn_rune(5);
            }
            case 6: {
            	// Muestra un HUD con la informacion sobre la runa
                set_task(0.5, "ShowHUDDetailsRune", iEntityPlayer + TASK_HUDDETAILSRUNE, _, _, "b");
                // Spawnea otra runa del mismo tipo
                spawn_rune(6);
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
		new Float:flNextAttack = get_pdata_float(id, m_flNextAttack, 5) * get_pcvar_float(gCvarReloadSpeed);
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
				new Float:flNextAttack = get_pdata_float(id, m_flNextAttack, 5) * get_pcvar_float(gCvarReloadSpeed);
				set_pdata_float(id , m_flNextAttack, flNextAttack, 5);
				set_pdata_float(shotgun, m_flTimeWeaponIdle, 0.1, 4);
				set_pdata_float(shotgun, m_flNextPrimaryAttack, 0.60, 4);
				set_pdata_float(shotgun, m_flNextSecondaryAttack, 0.80, 4);
			}
		}

		case 1 : {
			if(get_pdata_int(shotgun, m_fInSpecialReload, 4) == 2) {
				set_pdata_float(shotgun, m_flTimeWeaponIdle, 0.1, 4);
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

// Crowbar tirable
public fw_CrowbarSecondaryAttack(ent) {
	new id = get_pdata_cbase(ent,m_pPlayer, XTRA_OFS_WEAPON);
	
	if(!FlyCrowbar_Spawn(id))
		return HAM_IGNORED;
	
	set_pdata_float(ent, m_flNextSecondaryAttack, 0.5, XTRA_OFS_WEAPON);
	ExecuteHam(Ham_RemovePlayerItem, id, ent);
	user_has_weapon(id, HLW_CROWBAR, 0);
	ExecuteHamB(Ham_Item_Kill, ent);
	
	return HAM_IGNORED;
}

public fw_CrowbarItemAdd(ent, id) {
	remove_task(ent);
}

public FlyCrowbar_Think(ent){
	new Float:vec[3];
	pev(ent,pev_angles,vec);
	vec[0] = floatadd(vec[0],-15.0);
	set_pev(ent,pev_angles,vec);
	
	set_pev(ent,pev_nextthink,get_gametime()+0.01);
}

public FlyCrowbar_Touch(toucher,touched) {
	new Float:origin[3],Float:angles[3];
	pev(toucher, pev_origin, origin);
	pev(toucher, pev_angles, angles);
	
	if (!is_player(touched)){
		emit_sound(toucher, CHAN_WEAPON, "weapons/cbar_hit1.wav", 0.9, ATTN_NORM, 0, PITCH_NORM);
		
		engfunc(EngFunc_MessageBegin, MSG_PVS,SVC_TEMPENTITY, origin, 0);
		write_byte(TE_SPARKS);
		engfunc(EngFunc_WriteCoord, origin[0]);
		engfunc(EngFunc_WriteCoord, origin[1]);
		engfunc(EngFunc_WriteCoord, origin[2]);
		message_end();
	} else {
		ExecuteHamB(Ham_TakeDamage, touched, toucher, pev(toucher, pev_owner), get_pcvar_float(gCvarCrowbarDamage), DMG_CLUB);
		emit_sound(toucher, CHAN_WEAPON, "weapons/cbar_hitbod1.wav", 0.9, ATTN_NORM, 0, PITCH_NORM);
		
		engfunc(EngFunc_MessageBegin, MSG_PVS, SVC_TEMPENTITY, origin, 0);
		write_byte(TE_BLOODSPRITE);
		engfunc(EngFunc_WriteCoord, origin[0]+random_num(-20,20));
		engfunc(EngFunc_WriteCoord, origin[1]+random_num(-20,20));
		engfunc(EngFunc_WriteCoord, origin[2]+random_num(-20,20));
		write_short(bspraySprite);
		write_short(bdropSprite);
		write_byte(248);
		write_byte(15);
		message_end();
	}
	
	engfunc(EngFunc_RemoveEntity, toucher);
	
	new crow = engfunc(EngFunc_CreateNamedEntity, engfunc(EngFunc_AllocString, "weapon_crowbar"));
		
	DispatchSpawn(crow);
	set_pev(crow, pev_spawnflags, SF_NORESPAWN);	
	
	angles[0] = 0.0;
	angles[2] = 0.0;
	
	set_pev(crow, pev_origin, origin);
	set_pev(crow, pev_angles, angles);
	
	if (get_pcvar_num(gCvarCrowbarRender))
		fm_set_rendering(crow, kRenderFxGlowShell, 55+random(200), 55+random(200), 55+random(200), kRenderNormal);
	
	set_task(get_pcvar_float(gCvarCrowbarLifetime), "Crowbar_Think", crow);
}

public FlyCrowbar_Spawn(id) {
	new crowbar = engfunc(EngFunc_CreateNamedEntity,engfunc(EngFunc_AllocString,"info_target"));
	
	if(!pev_valid(crowbar))
		return 0;
	
	set_pev(crowbar,pev_classname,CROW);
	engfunc(EngFunc_SetModel,crowbar,"models/w_crowbar.mdl");
	engfunc(EngFunc_SetSize,crowbar,Float:{-4.0, -4.0, -4.0} , Float:{4.0, 4.0, 4.0});
	
	new Float:vec[3];
	get_projective_pos(id,vec);
	engfunc(EngFunc_SetOrigin,crowbar,vec);
	
	
	pev(id,pev_v_angle,vec);
	vec[0] = 90.0;
	vec[2] = floatadd(vec[2],-90.0);
	
	set_pev(crowbar,pev_owner,id);
	set_pev(crowbar,pev_angles,vec);
	
	velocity_by_aim(id,get_pcvar_num(gCvarCrowbarSpeed)+get_speed(id),vec);
	set_pev(crowbar,pev_velocity,vec);
	
	set_pev(crowbar,pev_nextthink,get_gametime()+0.1);
	
	DispatchSpawn(crowbar);
	
	if(get_pcvar_num(gCvarCrowbarTrail)){
		message_begin(MSG_BROADCAST,SVC_TEMPENTITY);
		write_byte(TE_BEAMFOLLOW);
		write_short(crowbar);
		write_short(trailSprite);
		write_byte(15);
		write_byte(2);
		write_byte(55+random(200));
		write_byte(55+random(200));
		write_byte(55+random(200));
		write_byte(255);
		message_end();
	}
	
	set_pev(crowbar,pev_movetype,MOVETYPE_TOSS);
	set_pev(crowbar,pev_solid,SOLID_BBOX);
	
	emit_sound(id,CHAN_WEAPON,"weapons/cbar_miss1.wav",0.9,ATTN_NORM,0,PITCH_NORM);
	set_task(0.1,"FlyCrowbar_Whizz",crowbar);
	
	return crowbar;
}

public FlyCrowbar_Whizz(crowbar){
	if (pev_valid(crowbar)){
		emit_sound(crowbar,CHAN_WEAPON,"weapons/cbar_miss1.wav",0.9,ATTN_NORM,0,PITCH_NORM);		
		set_task(0.2,"FlyCrowbar_Whizz",crowbar);
	}
}

public Crowbar_Think(ent) {
	if(pev_valid(ent))
		engfunc(EngFunc_RemoveEntity,ent);
}

get_projective_pos(player,Float:origin[3]) {
	new Float:v_forward[3];
	new Float:v_right[3];
	new Float:v_up[3];
	
	GetGunPosition(player,origin);
	
	global_get(glb_v_forward,v_forward);
	global_get(glb_v_right,v_right);
	global_get(glb_v_up,v_up);
	
	xs_vec_mul_scalar(v_forward,6.0,v_forward);
	xs_vec_mul_scalar(v_right,2.0,v_right);
	xs_vec_mul_scalar(v_up,-2.0,v_up);
	
	xs_vec_add(origin,v_forward,origin);
	xs_vec_add(origin,v_right,origin);
	xs_vec_add(origin,v_up,origin);
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

// return the index of the nearest location from an array
public FindNearestLocation(id, Float:locOrigin[][3], numLocs) {
	new Float:userOrigin[3], Float:nearestOrigin[3], idxNearestLoc;
	
	pev(id, pev_origin, userOrigin);
	
	for (new i; i < numLocs; i++) {
		if (vector_distance(userOrigin, locOrigin[i]) <= vector_distance(userOrigin, nearestOrigin)) {
			nearestOrigin = locOrigin[i];
			idxNearestLoc = i;
		}
	}

	return idxNearestLoc;
}

stock GetGunPosition(const player,Float:origin[3]){
	new Float:viewOfs[3];
	
	pev(player,pev_origin,origin);
	pev(player,pev_view_ofs,viewOfs);
	
	xs_vec_add(origin,viewOfs,origin);
}
