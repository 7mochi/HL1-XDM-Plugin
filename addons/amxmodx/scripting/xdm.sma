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
7. Super Pistola

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

#define PLUGIN_NAME		"[HL] XDM Beta v2.0"
#define PLUGIN_NAME_SH		"[HL] XDM Beta v2.0"
#define PLUGIN_VER		"Beta 2.0 Build 12/9/2018"
#define PLUGIN_AUTHOR		"FlyingCat"

#define SIZE_WEAPONS 		14 
#define SIZE_AMMO 		11

#define CROW 			"fly_crowbar"

// Sistema restaurador de score: Array index
#define SCORE_FRAGS 		0
#define SCORE_DEATHS 		1

// HL PDatas
const m_pPlayer			= 28;
const m_fInSpecialReload 	= 34;
const m_flNextPrimaryAttack 	= 35;
const m_flNextSecondaryAttack 	= 36;
const m_flTimeWeaponIdle 	= 37;
const m_iClip 			= 40;
const m_fInReload		= 43;
const m_flNextAttack		= 148;
const m_iFOV 			= 298;

const DMG_CROSSBOW  		= (DMG_BULLET | DMG_NEVERGIB);

const XTRA_OFS_WEAPON 		= 4;

// Models
#define MDL_RUNE                "models/xdm_rune.mdl"

// Sounds
#define SND_RUNE_PICKED         "xdm.wav"
#define SND_HOOK_HIT		"weapons/xbow_hit2.wav"
#define SND_RUNE_TR_EXPLODE	"weapons/explode3.wav"

// Sprites
#define SPR_RUNE_DOT		"sprites/dot.spr"
#define SPR_RUNE_TR_SHOCKW	"sprites/shockwave.spr"
#define SPR_FC_BLOOD		"sprites/blood.spr"
#define SPR_FC_BSPRAY		"sprites/bloodspray.spr"
#define SPR_FC_TRAIL		"sprites/zbeam3.spr"

// Numero de runas
#define NUMB_RUNES              7
#define player_id 		1
#define is_player(%1) 		(player_id <= %1 <= MAX_PLAYERS)
#define InZoom(%1) 		(get_pdata_int(%1, m_iFOV) != 0)

#define RPG_SPEED 1900

// TaskIDs
enum (+=100) {
	TASK_REGENERATION = 6966,
	TASK_HUDDETAILSRUNE,
	TASK_STARTVERSUS,
	TASK_SHOWVOTE,
	TASK_DENYVOTE,
	TASK_SENDTOSPEC,
	TASK_SENDVICTIMTOSPEC,
	TASK_TIMELEFT
};  

// Sonidos de la cuenta regresiva
new const gCountSnd[][] = {
	"xdm/countdown/start.wav", // Cero
	"xdm/countdown/one.wav", 
	"xdm/countdown/two.wav", 
	"xdm/countdown/three.wav", 
	"xdm/countdown/four.wav", 
	"xdm/countdown/five.wav", 
	"xdm/countdown/six.wav", 
	"xdm/countdown/seven.wav", 
	"xdm/countdown/eight.wav", 
	"xdm/countdown/nine.wav"
};

new Trie:gTrieScoreAuthId;

new const gBeepSnd[] = "fvox/beep";

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
new gCvarAmxNextMap;
new gCvarFriendlyFire;
new gCvarTimeLimit;

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

// Runa Super Glock
new gCvarSGShootSpeed;

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

// Votacion
new gCvarVoteFailedTime;
new gCvarVoteDuration;
new gCvarXdmStartMinPlayers;

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

new const gClearFieldEntsClass[][] = {
	"bolt",
	"monster_snark",
	"monster_satchel",
	"monster_tripmine",
	"beam",
	"weaponbox"
};

new const gNameNumbRunes[NUMB_RUNES][] = {
	"xdm_numb_regen_runes",
	"xdm_numb_trap_runes",
	"xdm_numb_cloak_runes",
	"xdm_numb_sspeed_runes",
	"xdm_numb_lowgrav_runes",
	"xdm_numb_vampire_runes",
	"xdm_numb_sglock_runes"
};

new const gNameColorRunes[NUMB_RUNES][] = {
	"xdm_color_regen_runes",
	"xdm_color_trap_runes", 
	"xdm_color_cloak_runes",
	"xdm_color_sspeed_runes",
	"xdm_color_lowgrav_runes", 
	"xdm_color_vampire_runes", 
	"xdm_color_sglock_runes"
};

new const gNameTitlesRunes[NUMB_RUNES + 1][] = {
	"NAME_NONE", 
	"NAME_REGEN", 
	"NAME_TRAP", 
	"NAME_CLOAK", 
	"NAME_SSPEED",
	"NAME_LOWGRAV",
	"NAME_VAMPIRE", 
	"NAME_SGLOCK"
};

new const gNameDescRunes[NUMB_RUNES][] = {
	"DESC_REGEN", 
	"DESC_TRAP", 
	"DESC_CLOAK",
	"DESC_SSPEED",
	"DESC_LOWGRAV",
	"DESC_VAMPIRE", 
	"DESC_SGLOCK"
};

// Booleano para saber si un player tiene o no tiene una runa y de que tipo
// Ninguna runa = 0
// Runa de regeneracion = 1
// Runa de trampa = 2
// Runa Cloak = 3
// Runa Super Speed = 4
// Runa Baja Gravedad = 5
// Runa Vampiro = 6
// Runa Super Pistola = 7
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

// Sistema de ubicaciones
new gLocationName[128][32]; 		// Max locations (128) and max location name length (32);
new Float:gLocationOrigin[128][3]; 	// Max locations and origin (x, y, z)
new gNumLocations;

#define MAXVALUE_TIMELIMIT 	538214400
#define TIMELEFT_SETUNLIMITED 	-1

// Sistema para el tiempo restante / Tiempo limite
new gTimeLeft; // if timeleft is set to -1, it means unlimited time
new gTimeLimit;

new cvarhook:gHookCvarTimeLimit;

// Xdmstart
new bool:gVersusStarted;
new gStartVersusTime;

// Xdmpause
new bool:gIsPause;

// Gamerules flags
new bool:gBlockCmdKill;
new bool:gBlockCmdSpec;
new bool:gBlockCmdDrop;
new bool:gSendConnectingToSpec;

// Sincronizacion de los HUDs
new gHudShowVote;
new gHudShowMatch;
new gHudShowTimeLeft;

enum _:VoteValid {
	VOTE_INVALID = -1,
	VOTE_INVALID_MAP,
	VOTE_INVALID_MODE,
	VOTE_INVALID_NUMBER,
	VOTE_VALID
}

// gVoteList tiene que estar en el mismo orden
enum _:VoteList {
	VOTE_XDMABORT,
	VOTE_XDMALLOW,
	VOTE_XDMNEXTMAP,
	VOTE_XDMPAUSE,
	VOTE_XDMSTART,
	VOTE_MAP,
	VOTE_MP_FRIENDLYFIRE
}

new const gVoteList[][] = {
	"xdmabort",
	"xdmallow",
	"xdmnextmap",
	"xdmpause",
	"xdmstart",
	"xdmmap",
	"mp_friendlyfire"
};

#define VOTE_YES 		1
#define VOTE_NO 		-1

// Sistema de votaciones
new Trie:gTrieVoteList;
new bool:gVoteStarted;
new Float:gVoteFailedTime; // En segundos
new gVotePlayers[33]; // 1: Voto yes; 0: No voto; -1; Voto no; 
new gVoteCallerName[MAX_NAME_LENGTH];
new gVoteCallerUserId;
new gVoteTargetUserId;
new gVoteArg1[32];
new gVoteArg2[32];
new gVoteOption;

public plugin_init() {
	register_plugin(PLUGIN_NAME, PLUGIN_VER, PLUGIN_AUTHOR);
	
	// Cambia el nombre del juego a XDM v2.0
	register_forward(FM_GetGameDescription, "GameDesc");
	// Infinito vuelo en la RPG
	register_forward(FM_Think, "FwdRPGThink");
	
	register_concmd("+hook","Hook_On");
	register_concmd("-hook","Hook_Off");
	
	// Obtiene las ubicaciones desde el archivo /locs/<nombredelmapa>.loc
	GetLocations(gLocationName, 32, gLocationOrigin, gNumLocations);
	
	// Multilenguaje
	register_dictionary("xdm.txt");
	
	// Chat
	register_message(get_user_msgid("SayText"), "MsgSayText");
	
	// Hooks de los jugadores
	RegisterHam(Ham_Killed, "player", "FwdPlayerKilled");
	RegisterHam(Ham_Spawn, "player", "FwdPlayerPostSpawn", true);
	RegisterHam(Ham_Spawn, "player", "FwdPlayerPreSpawn");
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
	
	// Velocidad de disparo de la pistola (MOUSE1) (Solo al tener la runa de Super Glock)
	RegisterHam(Ham_Weapon_PrimaryAttack, "weapon_9mmhandgun", "Glock_Primary_Attack_Pre" , 0);
	RegisterHam(Ham_Weapon_PrimaryAttack, "weapon_9mmhandgun", "Glock_Primary_Attack_Post", 1);
	
	// Crowbar tirable
	RegisterHam(Ham_Weapon_SecondaryAttack, "weapon_crowbar", "fw_CrowbarSecondaryAttack");
	RegisterHam(Ham_Item_AddToPlayer, "weapon_crowbar", "fw_CrowbarItemAdd");
	RegisterHam(Ham_Item_AddDuplicate, "weapon_crowbar", "fw_CrowbarItemAdd");
	register_think(CROW, "FlyCrowbar_Think");
	register_touch(CROW, "*", "FlyCrowbar_Touch");
	
	// Votos
	register_concmd("xdmabort", "CmdXdmAbort", ADMIN_BAN, "HELP_XDMABORT", _, true);
	register_concmd("xdmallow", "CmdXdmAllow", ADMIN_BAN, "HELP_XDMALLOW", _, true);
	register_concmd("xdmpause", "CmdXdmPause", ADMIN_BAN, "HELP_XDMPAUSE", _, true);
	register_concmd("xdmstart", "CmdXdmStart", ADMIN_BAN, "HELP_XDMSTART", _, true);
	
	register_clcmd("vote", "CmdVote", ADMIN_ALL, "HELP_VOTE", _, true);
	register_clcmd("yes", "CmdVoteYes", ADMIN_ALL, "HELP_YES", _, true);
	register_clcmd("no", "CmdVoteNo", ADMIN_ALL, "HELP_NO", _, true);
	
	register_clcmd("spectate", "CmdSpectate"); // block spectate
	register_clcmd("drop", "CmdDrop"); // block drop
	
	// Establec pausable en 0 o elimina el acceso de administrador de cvar (Puede ser ambos)
	register_clcmd("pauseXdmUser", "CmdPauseXdmUser");
	register_clcmd("pauseXdmAdmin", "CmdPauseXdmAdmin");
	
	// Votaciones	
	StartTimeLeft();
	gBlockCmdDrop = true;
}

public plugin_precache() {
	gHudShowVote = CreateHudSyncObj();
	gHudShowMatch = CreateHudSyncObj();
	gHudShowTimeLeft = CreateHudSyncObj();
	
	// Guarda los scores de los jugadores que esten jugando una partida, si alguien se
	// desconecta por alguna razon, el score sera restaurado cuando el vuelva
	gTrieScoreAuthId = TrieCreate();
	
	CreateVoteSystem();
	
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
	//  Cuenta regresiva
	for (new i; i < sizeof gCountSnd; i++) {
		precache_sound(gCountSnd[i]);
	}
	
	create_cvar("xdm_version", PLUGIN_VER, FCVAR_SERVER);
	
	gCvarGameName = create_cvar("xdm_gamename", "XDM Beta v2.0", FCVAR_SERVER | FCVAR_SPONLY);
	
	gCvarStartHealth = create_cvar("xdm_start_health", "100");
	gCvarStartArmor = create_cvar("xdm_start_armor", "0");
	gCvarStartLongJump = create_cvar("xdm_start_longjump", "1");
	
	// Votaciones
	gCvarXdmStartMinPlayers = create_cvar("xdm_vote_start_minplayers", "2", FCVAR_SERVER);
	gCvarVoteFailedTime = create_cvar("xdm_vote_failed_time", "15", FCVAR_SERVER | FCVAR_SPONLY, "", true, 0.0, true, 999.0);
	gCvarVoteDuration = create_cvar("xdm_vote_duration", "30", FCVAR_SERVER, "", true, 0.0, true, 999.0);
	
	gCvarFriendlyFire = get_cvar_pointer("mp_friendlyfire");
	gCvarTimeLimit = get_cvar_pointer("mp_timelimit");
	
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
	gCvarDamage9mmhandgun = create_cvar("xdm_damage_9mmhandgun", "12.0");
	gCvarDamage357 = create_cvar("xdm_damage_357", "40.0");
	gCvarDamage9mmar = create_cvar("xdm_damage_9mmar", "12.0");
	gCvarDamageShotgun = create_cvar("xdm_damage_shotgun", "20.0");
	gCvarDamageCrossbow = create_cvar("xdm_damage_crossbow", "100.0");
	
	// La frecuencia en que se regenerara la HP - 1.0 = 1 segundo
	gCvarRegenFrequency = create_cvar("xdm_regen_frequency", "1.0");
	// La cantidad de HP a regenerar - 3 de HP
	gCvarRegenQuantityHP = create_cvar("xdm_regen_hp_quantity", "3");
	// La cantidad de HEV a regenerar - 1 de HEV
	gCvarRegenQuantityHEV = create_cvar("xdm_regen_hev_quantity", "1");
	
	// El radio de daÃ±o de la Runa Trap
	gCvarTrapRadius = create_cvar("xdm_trap_radius", "500");
	// El daÃ±o que hara la Runa Trap al explotar
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
	// Recuperacion del x.xx% del daÃ±o hecho directo a la HP (Default: 15% = 0.15)
	gCvarVampireLifestealHP = create_cvar("xdm_vampire_lifestealhp", "0.15");
	// Recuperacion del x.xx% del daÃ±o hecho directo al escudo (Default: 5% = 0.05)
	gCvarVampireLifestealHEV = create_cvar("xdm_vampire_lifestealhev", "0.05");
	
	// Velocidad de disparo de la runa Super Pistola
	gCvarSGShootSpeed = create_cvar("xdm_sglock_shootspeed", "9999.0");
	
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
	gCvarAmxNextMap = get_cvar_pointer("amx_nextmap");
	// Distancia minima entre los puntos
	// Anterior distancia 185.0
	// Nueva distancia 125.0
	SsInit(125.0);
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
	
	// Limpiando las coordenadas usadas
	SsClean();
}

public plugin_end() {
	disable_cvar_hook(gHookCvarTimeLimit);
	set_pcvar_num(gCvarTimeLimit, gTimeLimit);
}

// Cambia el nombre del juego a XDM v2.0
public GameDesc() {
	static gamename[32]; 
	get_pcvar_string(gCvarGameName, gamename, charsmax(gamename)); 
	forward_return(FMV_STRING, gamename); 
	return FMRES_SUPERCEDE; 
}

public client_putinserver(id) {
	new authid[32];
	get_user_authid(id, authid, charsmax(authid));
	
	// Restaurando el puntaje por Authid
	if (ScoreExists(authid))
		// Retraso para evitar algun glitch en la lista de puntajes
		set_task(1.0, "RestoreScore", id, authid, sizeof authid);
	else if (gSendConnectingToSpec)
		// Retraso para evitar algun glitch en la lista de puntajes
		set_task(0.1, "SendToSpec", id + TASK_SENDTOSPEC);
}

public client_disconnected(id) {
	new authid[32];
	get_user_authid(id, authid, charsmax(authid));
	
	remove_task(TASK_SENDTOSPEC + id);
	remove_task(TASK_SENDVICTIMTOSPEC + id);
	
	// Guardando el score del player desconectado por authid si es que el Versus se inicio
	if (gVersusStarted && ScoreExists(authid)) {
		new frags = get_user_frags(id);
		new deaths = hl_get_user_deaths(id);
		SaveScore(id, frags, deaths);
		console_print(0, "%L", LANG_PLAYER, "MATCH_LEAVE", authid, frags, deaths);
	}
	
	return PLUGIN_HANDLED;
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
	
	// AÃ±adimos o cambiamos los tags 	
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
	
	// Reemplazar todos los %r con el nombre de la runa actual (Multilenguaje)
	replace_string(text, charsmax(text), "%r", fmt("%L", LANG_PLAYER, gNameTitlesRunes[g_bTieneRuna[sender]]));
	
	// Reemplazar todos los %w con el nombre del arma actual
	new ammo, bpammo, weaponid = get_user_weapon(sender, ammo, bpammo);
	
	if (weaponid) {
		new weaponName[32];
		get_weaponname(weaponid, weaponName, charsmax(weaponName));
		replace_string(weaponName, charsmax(weaponName), "weapon_", "");
		replace_string(text, charsmax(text), "%w", weaponName, false);
	}
	
	// Reemplazar todos los %q con la municion total (ammo and backpack ammo) del arma actual
	replace_string(text, charsmax(text), "%q", fmt("%i", ammo < 0 ? bpammo : ammo + bpammo), false); // if the weapon only has bpammo, ammo will return -1, replace it with 0
	
	// Enviar mensaje final
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
* Sistema de ubicaciones
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
			nLen += 1 + copyc(name[i], size, text[nLen], '#');
			j++;
			numLocs++;
			} else {
			new number[16];
			
			nLen += 1 + copyc(number, sizeof number, text[nLen], '#');
			origin[i][j] = str_to_float(number);
			
			j++;
			
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

public PlayerKill(id) {
	if (gBlockCmdKill)
		return FMRES_SUPERCEDE;
	return FMRES_IGNORED;
}

public FwdPlayerKilled(victim, attacker) {
	// Descomentar esto si se desea volver a recargar las municiones del player que mato
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
	// show_dhudmessage(idPlayer, gNameDescRunes[g_bTieneRuna[idPlayer] - 1]);
	// Multilenguaje
	show_dhudmessage(idPlayer, "%L", LANG_PLAYER, gNameDescRunes[g_bTieneRuna[idPlayer] - 1]);
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
	if (gVoteStarted)
		// Cuando haces respawn, el HUD se resetea, entonces mostramos el voto despues del reseteo del HUD
		set_task(0.1, "ShowVote", TASK_SHOWVOTE);
	
	if (is_user_alive(id) && !gGamePlayerEquipExists) {
		SetPlayerStats(id);
		// Cada player que entre modificarle la maxspeed a 300
		set_user_maxspeed(id, get_pcvar_float(gCvarPlayerSpeed));
		// Cada player que entre modificarle la gravedad a la default del server por si acaso
		set_user_gravity(id, (get_pcvar_float(gCvarPlayerGravity) / 800.0));
	}
	
}

public FwdPlayerPreSpawn(id) {
	// Si un jugador tiene que espectar, no lo dejamos spawnear
	if (task_exists(TASK_SENDVICTIMTOSPEC + id))
		return HAM_SUPERCEDE;
	return HAM_IGNORED;
}

// Usado para la Runa Vampiro
public FwdOnDamagePre(victim, ent, agressor, Float:damage, bits) {		
	// Si es que tiene la Runa Vampiro
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
		if (get_pcvar_num(gCvarStartAmmo[i]) != 0) 
			ag_set_user_bpammo(id, 310+i, get_pcvar_num(gCvarStartAmmo[i]));
	}
}

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
	
	// Obtenemos el origen del player
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
	write_byte(1);					// TE_BEAMENTPOINT
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
	
	// Calculando velocidad del hook
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
		// Limpiamos anteriores coordenadas de las runas
		SsClean();
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
			case 7: {
				// Muestra un HUD con la informacion sobre la runa
				set_task(0.5, "ShowHUDDetailsRune", iEntityPlayer + TASK_HUDDETAILSRUNE, _, _, "b");
				// Spawnea otra runa del mismo tipo
				spawn_rune(7);
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

// Velocidad de disparo de la pistola (MOUSE1) - 1 (Solo con runa Super Glock)
public Glock_Primary_Attack_Pre(const glock) {
	new player = get_pdata_cbase(glock, m_pPlayer, 4);
	if (g_bTieneRuna[player] == 7) {
		old_clip[player] = get_pdata_int(glock, m_iClip, 4);
	}	
}

// Velocidad de disparo de la pistola (MOUSE1) - 2 (Solo con runa Super Glock)
public Glock_Primary_Attack_Post(const glock) {
	new player = get_pdata_cbase(glock, m_pPlayer, 4);
	// Si tiene la runa Super Glock
	if (g_bTieneRuna[player] == 7) {
		set_pdata_float(glock, m_flNextSecondaryAttack, get_pcvar_num(gCvarSGShootSpeed), 4);
		
		if(old_clip[player] <= 0)
			return;
		
		set_pdata_float(glock, m_flNextPrimaryAttack  , 0.10, 4);
		
		if(get_pdata_int(glock, m_iClip, 4) != 0)
			set_pdata_float(glock, m_flTimeWeaponIdle, 2.0, 4);
		else
			set_pdata_float(glock, m_flTimeWeaponIdle, 0.3, 4);
	}
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

// DaÃ±o de armas
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

// DaÃ±o de las armas (Ballesta con zoom)
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

// Sistema de votaciones
public CmdVote(id) {
	new Float:timeleft = gVoteFailedTime - get_gametime();
	
	if (timeleft > 0.0) {	
		console_print(id, "%L", LANG_PLAYER, "VOTE_DELAY", floatround(timeleft, floatround_floor));
		return PLUGIN_HANDLED;
		} else if (gVoteStarted) {
		console_print(id, "%L", LANG_PLAYER, "VOTE_RUNNING");
		return PLUGIN_HANDLED;
	}
	
	new arg1[32], arg2[32];
	
	read_argv(1, arg1, charsmax(arg1));
	read_argv(2, arg2, charsmax(arg2));
	
	gVoteOption = GetUserVote(id, arg1, arg2, charsmax(arg2));
	
	if (gVoteOption == VOTE_INVALID) // Voto invalido
		return PLUGIN_HANDLED;
	
	gVoteArg1 = arg1;
	gVoteArg2 = arg2;
	
	gVoteStarted = true;
	
	gVotePlayers[id] = VOTE_YES;
	gVoteCallerUserId = get_user_userid(id);
	
	get_user_name(id, gVoteCallerName, charsmax(gVoteCallerName));
	
	// Cancela el voto despues de x segundos (set_task no funca en pausa)
	set_task(get_pcvar_float(gCvarVoteDuration), "DenyVote", TASK_DENYVOTE); 
	
	// Muestra el voto
	ShowVote();
	
	return PLUGIN_HANDLED;
}

public CmdVoteYes(id) {
	if (gVoteStarted) {
		gVotePlayers[id] = VOTE_YES;
		ShowVote();
	}
	
	return PLUGIN_HANDLED;
}

public CmdVoteNo(id) {
	if (gVoteStarted) {
		gVotePlayers[id] = VOTE_NO;
		ShowVote();
	}
	
	return PLUGIN_HANDLED;
}

public DoVote() {
	// Mostramos si el voto es aceptado
	set_hudmessage(0, 255, 0, 0.05, 0.125, 0, 0.0, 10.0);
	ShowSyncHudMsg(0, gHudShowVote, "%L", LANG_PLAYER, "VOTE_ACCEPTED", gVoteArg1, gVoteArg2, gVoteCallerName);
	
	// A veces el hud no se muestra, entonces mostramos de la manera antigua
	client_print(0, print_center, "%L", LANG_PLAYER, "VOTE_ACCEPTED", gVoteArg1, gVoteArg2, gVoteCallerName);
	
	RemoveVote();
	
	new caller = find_player_ex(FindPlayer_MatchUserId, gVoteCallerUserId);
	new target = find_player_ex(FindPlayer_MatchUserId, gVoteTargetUserId);
	
	// Si no esta conectado el que hizo el voto, cancelarlo...
	if (!caller)
		return;
	
	switch (gVoteOption) {
		case VOTE_XDMABORT: 		AbortVersus();
		case VOTE_XDMALLOW: 		AllowPlayer(target);
		case VOTE_XDMNEXTMAP:		set_pcvar_string(gCvarAmxNextMap, gVoteArg2);
		case VOTE_XDMPAUSE: 		PauseGame(caller);
		case VOTE_XDMSTART: 		StartVersus();
		case VOTE_MAP: 			ChangeMap(gVoteArg2);
		case VOTE_MP_FRIENDLYFIRE:	set_pcvar_string(gCvarFriendlyFire, gVoteArg2);
	}
}

public DenyVote() {
	RemoveVote();
	
	gVoteFailedTime = get_gametime() + get_pcvar_num(gCvarVoteFailedTime);
	
	set_hudmessage(0, 255, 0, 0.05, 0.125, 0, 0.0, 10.0);
	ShowSyncHudMsg(0, gHudShowVote, "%L", LANG_PLAYER, "VOTE_DENIED", gVoteArg1, gVoteArg2, gVoteCallerName);
	
	// A veces el hud no se muestra, entonces mostramos de la manera antigua
	client_print(0, print_center, "%L", LANG_PLAYER, "VOTE_DENIED", gVoteArg1, gVoteArg2, gVoteCallerName);
}

public RemoveVote() {
	gVoteStarted = false;
	
	remove_task(TASK_DENYVOTE);
	remove_task(TASK_SHOWVOTE);
	
	// Reseteamos los votos del usuario
	arrayset(gVotePlayers, 0, sizeof gVotePlayers);
}

public ShowVote() {
	new numVoteFor, numVoteAgainst, numUndecided;
	
	// Contador de votos
	for (new id = 1; id <= MaxClients; id++) {
		switch (gVotePlayers[id]) {
			case VOTE_YES: numVoteFor++;
			case VOTE_NO: numVoteAgainst++;
		}
	}
	
	numUndecided = get_playersnum() - (numVoteFor + numVoteAgainst);
	
	// Mostramos el HUD de las votaciones
	if (numVoteFor > numVoteAgainst && numVoteFor > numUndecided) { // Aceptado
		DoVote();
	} else if (numVoteAgainst > numVoteFor && numVoteAgainst > numUndecided) { // Denegado
		DenyVote();
	} else { // En curso
		set_hudmessage(0, 255, 0, 0.05, 0.125, 0, 0.0, get_pcvar_float(gCvarVoteDuration) * 2, 0.2);
		ShowSyncHudMsg(0, gHudShowVote, "%L", LANG_PLAYER, "VOTE_START", gVoteArg1, gVoteArg2, gVoteCallerName, numVoteFor, numVoteAgainst, numUndecided);
	}
}

CreateVoteSystem() {
	gTrieVoteList = TrieCreate();
	
	for (new i; i < sizeof gVoteList; i++)
		TrieSetCell(gTrieVoteList, gVoteList[i], i);
}

// Obtiene el voto del jugador desde un String
// Obtiene el voto si es valido. -1 si el voto no es valido.
GetUserVote(id, arg1[], arg2[], len) {
	new player, vote = VOTE_INVALID;
	new valid = TrieGetCell(gTrieVoteList, arg1, vote) ? VOTE_VALID : VOTE_INVALID;
	
	switch (vote) {
		case VOTE_MAP, VOTE_XDMNEXTMAP: 
			valid = is_map_valid(arg2) ? VOTE_VALID : VOTE_INVALID_MAP;
		case VOTE_MP_FRIENDLYFIRE:
			valid = is_str_num(arg2) ? VOTE_VALID : VOTE_INVALID_NUMBER;
		case VOTE_XDMALLOW:
			if (equal(arg2, "")) { // Allow a ti mismo
				get_user_name(id, arg2, len);
				gVoteTargetUserId = get_user_userid(id);
			} else if ((player = cmd_target(id, arg2, CMDTARGET_ALLOW_SELF))) {
				get_user_name(player, arg2, len);
				gVoteTargetUserId = get_user_userid(player);
			} else {
				return VOTE_INVALID; // cmd_target muestra su propio mensaje de error
			}
	}
	
	switch (valid) {
		case VOTE_INVALID: 		console_print(id, "%L", LANG_PLAYER, "VOTE_INVALID");
		case VOTE_INVALID_MAP: 		console_print(id, "%L", LANG_PLAYER, "INVALID_MAP");
		case VOTE_INVALID_NUMBER: 	console_print(id, "%L", LANG_PLAYER, "INVALID_NUMBER");
	}
	
	return valid == VOTE_VALID ? vote : VOTE_INVALID;
}

/* 
* XdmAbort
*/
public AbortVersus() {
	gVersusStarted = false;
	
	// Borramos los authids para que este listo para la siguiente partida
	TrieClear(gTrieScoreAuthId);
	
	remove_task(TASK_STARTVERSUS);
	
	// Restauramos los gamerules
	gBlockCmdSpec = false;
	gBlockCmdDrop = false;
	gBlockCmdKill = false;
	gSendConnectingToSpec = false;
	
	for (new id = 1; id <= MaxClients; id++) {
		if (is_user_alive(id)) {
			//ClearSyncHud(0, gHudShowMatch);
			FreezePlayer(id, false);
		} else if (hl_get_user_spectator(id))
			ag_set_user_spectator(id, false);
	}
}

public AllowPlayer(id) {
	if (!is_user_connected(id) || !gVersusStarted)
		return PLUGIN_HANDLED;
	
	if (hl_get_user_spectator(id)) {
		new authid[32], name[32];
		get_user_authid(id, authid, charsmax(authid));
		
		// Creamos una nueva llave para este nuevo player. Asi podemos guardar su score en caso de desconexion...
		SaveScore(id, 0, 0);
		
		ag_set_user_spectator(id, false);
		
		ResetScore(id);
		
		get_user_name(id, name, charsmax(name));
		
		client_print(0, print_chat,"* %L", LANG_PLAYER, "MATCH_ALLOW", name);
		
		set_hudmessage(0, 255, 0, -1.0, -1.0, 0, 0.0, 5.0); 
		ShowSyncHudMsg(0, gHudShowMatch, "%L", LANG_PLAYER, "MATCH_ALLOW", name);	
	}
	
	return PLUGIN_HANDLED;
}

PauseGame(id) {
	RemoveVote();
	
	set_cvar_num("pausable", 1);
	
	if (get_user_flags(id) & ADMIN_CVAR) {
		client_cmd(id, "pause; pauseXdmAdmin");
	} else {
		set_user_flags(id, ADMIN_CVAR);
		client_cmd(id, "pause; pauseXdmUser");
	}
	
	if (gIsPause)
		gIsPause = false;
	else
		gIsPause = true;
}

public CmdPauseXdmUser(id) {
	remove_user_flags(id, ADMIN_CVAR);
	set_cvar_num("pausable", 0);	
	return PLUGIN_HANDLED;
}

public CmdPauseXdmAdmin(id) {
	set_cvar_num("pausable", 0);
	return PLUGIN_HANDLED;
}

/*
* Timeleft/Timelimit
*/
public StartTimeLeft() {
	// Desde ahora usaremos nuestro propio timeleft and timelimit
	gTimeLimit = get_pcvar_num(gCvarTimeLimit);
	
	if (gTimeLimit >= MAXVALUE_TIMELIMIT)
		gTimeLimit = 0;
	
	gTimeLeft = gTimeLimit > 0 ? gTimeLimit * 60 : TIMELEFT_SETUNLIMITED;
	
	set_pcvar_num(gCvarTimeLimit, MAXVALUE_TIMELIMIT);
	gHookCvarTimeLimit = hook_cvar_change(gCvarTimeLimit, "CvarTimeLimitHook");
	
	// Iniciamos nuestro propio timeleft
	set_task(1.0, "TimeLeftCountdown", TASK_TIMELEFT, _, _, "b");
}

public TimeLeftCountdown() {
	if (task_exists(TASK_STARTVERSUS)) // Cuando un jugador manda xdmstart, congelamos el timer
		return;
	
	if (gTimeLeft > 0)
		gTimeLeft--;
	else if (gTimeLeft == 0)
		StartIntermissionMode();
	
	ShowTimeLeft();
}

public ShowTimeLeft() {
	new r = 0;
	new g = 255;
	new b = 0;
	
	if (gTimeLeft >= 0) {
		
		if (gTimeLeft < 60) { // Color rojo
			r = 255; 
			g = 50;
			b = 50; 
		}
		
		set_hudmessage(r, g, b, -1.0, 0.02, 0, 0.01, 600.0, 0.01, 0.01);
		
		if (gTimeLeft > 3600)
			ShowSyncHudMsg(0, gHudShowTimeLeft, "%i:%02i:%02i", gTimeLeft / 3600, (gTimeLeft / 60) % 60, gTimeLeft % 60);
		else
			ShowSyncHudMsg(0, gHudShowTimeLeft, "%i:%02i", gTimeLeft / 60, gTimeLeft % 60);
		} else {
		set_hudmessage(r, g, b, -1.0, 0.02, 0, 0.01, 600.0, 0.01, 0.01);
		ShowSyncHudMsg(0, gHudShowTimeLeft, "%L", LANG_PLAYER, "TIMER_UNLIMITED");
	}
	
	return PLUGIN_CONTINUE;
}

public CvarTimeLimitHook(pcvar, const old_value[], const new_value[]) {
	disable_cvar_hook(gHookCvarTimeLimit);
	
	new timeLimit = str_to_num(new_value);
	
	if (timeLimit == 0) {
		gTimeLeft = TIMELEFT_SETUNLIMITED;
		gTimeLimit = timeLimit;
		} else {
		gTimeLeft =  timeLimit * 60;
		gTimeLimit = timeLimit;
	}
	
	set_pcvar_num(pcvar, MAXVALUE_TIMELIMIT);
	
	enable_cvar_hook(gHookCvarTimeLimit);
}

/* 
* XdmStart
*/
public StartVersus() {
	if (get_playersnum() < get_pcvar_num(gCvarXdmStartMinPlayers)) {
		client_print(0, print_center, "%L", LANG_PLAYER, "MATCH_MINPLAYERS", get_pcvar_num(gCvarXdmStartMinPlayers));
		return;
	}
	
	// Eliminamos un anterior inicio de xdmstrart incluso si no existe
	remove_task(TASK_STARTVERSUS);
	
	// Borramos la lista de AuthIDs
	TrieClear(gTrieScoreAuthId);
	
	// Gamerules
	gBlockCmdSpec = true;
	gBlockCmdDrop = true;
	gBlockCmdKill = true;
	gSendConnectingToSpec = true;
	
	// Reseteamos los scores de los jugadores y congelamos a los jugadores que jugaran versus
	for (new id = 1; id <= MaxClients; id++) {
		if (!is_user_connected(id))
			continue;
		
		if (IsInWelcomeCam(id)) // Mandamos a espectador a los jugadores que esten en la welcome cam 
			ag_set_user_spectator(id);
		else if (!hl_get_user_spectator(id)) {
			ResetScore(id);
			FreezePlayer(id);
		}
	}
	
	// Preparamos el mapa donde se jugara versus
	ClearField();
	RespawnAll();
	ResetChargers();
	
	gStartVersusTime = 10;
	StartVersusCountdown();
	set_task(1.0, "StartVersusCountdown", TASK_STARTVERSUS, _, _,"b");
}

public ChangeMap(const map[]) {
	set_pcvar_string(gCvarAmxNextMap, map);
	StartIntermissionMode();
} 

public StartIntermissionMode() {
	new ent = create_entity("game_end");
	if (is_valid_ent(ent))
		ExecuteHamB(Ham_Use, ent, 0, 0, 1.0, 0.0);
}

public EventIntermissionMode() {
	gBlockCmdKill = true;
	gBlockCmdSpec = true;
	gBlockCmdDrop = true;
	
	for (new id = 1; id < MaxClients; id++) {
		if (is_user_connected(id))
			FreezePlayer(id);
	}
}

FreezePlayer(id, bool:freeze=true) {
	new flags = pev(id, pev_flags);
	if (freeze) {
		set_pev(id, pev_flags, flags | FL_FROZEN);
		set_pev(id, pev_solid, SOLID_NOT);
	} else {
		set_pev(id, pev_flags, flags & ~FL_FROZEN);
		set_pev(id, pev_solid, SOLID_BBOX);
	}
}

public SendToSpec(taskid) {
	new id = taskid - TASK_SENDTOSPEC;
	if (is_user_connected(id))
		ag_set_user_spectator(id, true);
}

stock ag_set_user_spectator(client, bool:spectator = true) {
	if (hl_get_user_spectator(client) == spectator)
		return;
	
	if (spectator) {
		static AllowSpectatorsCvar;
		if (AllowSpectatorsCvar || (AllowSpectatorsCvar = get_cvar_pointer("allow_spectators"))) {
			if (!get_pcvar_num(AllowSpectatorsCvar))
				set_pcvar_num(AllowSpectatorsCvar, 1);
			
			engclient_cmd(client, "spectate");
		}
	} else {
		hl_user_spawn(client);
		
		set_pev(client, pev_iuser1, 0);
		set_pev(client, pev_iuser2, 0);
		
		set_pdata_int(client, OFFSET_HUD, 0);
		
		client_print(client, print_center, "");
		
		static szTeam[16];
		hl_get_user_team(client, szTeam, charsmax(szTeam));
		
		static Spectator;
		if (Spectator || (Spectator = get_user_msgid("Spectator"))) {
			message_begin(MSG_ALL, Spectator);
			write_byte(client);
			write_byte(0);
			message_end();
		}
		
		static TeamInfo;
		if (TeamInfo || (TeamInfo = get_user_msgid("TeamInfo"))) {
			message_begin(MSG_ALL, TeamInfo);
			write_byte(client);
			write_string(szTeam);
			message_end();
		}
	}
}

/*
* Restaurar puntaje
*/
public bool:ScoreExists(const authid[]) {
	return TrieKeyExists(gTrieScoreAuthId, authid);
}

public GetScore(const authid[], &frags, &deaths) {
	new score[2];
	TrieGetArray(gTrieScoreAuthId, authid, score, sizeof score);
	
	frags = score[SCORE_FRAGS];
	deaths = score[SCORE_DEATHS];
}

public RestoreScore(authid[], id) {	
	new frags, deaths;
	
	if (ScoreExists(authid)) {
		GetScore(authid, frags, deaths);
		set_user_frags(id, frags);
		hl_set_user_deaths(id, deaths);
	}
}

// Guardar score por AuthID
SaveScore(id, frags = 0, deaths = 0) {
	new authid[32], score[2];
	
	get_user_authid(id, authid, charsmax(authid));
	
	score[SCORE_FRAGS] = frags;
	score[SCORE_DEATHS] = deaths;
	
	TrieSetArray(gTrieScoreAuthId, authid, score, sizeof score);
}

ResetScore(id) {
	set_user_frags(id, 0);
	hl_set_user_deaths(id, 0);
}

bool:IsInWelcomeCam(id) {
	return IsObserver(id) && !hl_get_user_spectator(id) && get_pdata_int(id, OFFSET_HUD) & (1 << 5 | 1 << 3);
}

bool:IsObserver(id) {
	return get_pdata_int(id, 193) & (1 << 5) > 0 ? true : false;
}

public ClearField() {
	for (new i; i < sizeof gClearFieldEntsClass; i++)
		remove_entity_name(gClearFieldEntsClass[i]);
	
	new entid;
	while ((entid = find_ent_by_class(entid, "rpg_rocket")))
		set_pev(entid, pev_dmg, 0);
	
	entid = 0;
	while ((entid = find_ent_by_class(entid, "grenade")))
		set_pev(entid, pev_dmg, 0);
}

public RespawnAll() {
	new classname[32];
	for (new i; i < global_get(glb_maxEntities); i++) {
		if (pev_valid(i)) {
			pev(i, pev_classname, classname, charsmax(classname));
			if (contain(classname, "weapon_") != -1 || contain(classname, "ammo_") != -1 || contain(classname, "item_") != -1) {
				set_pev(i, pev_nextthink, get_gametime());
			}
		}
	}
}

public ResetChargers() {
	new classname[32];
	for (new i; i < global_get(glb_maxEntities); i++) {
		if (pev_valid(i)) {
			pev(i, pev_classname, classname, charsmax(classname));
			if (equal(classname, "func_recharge")) {
				set_pev(i, pev_frame, 0);
				set_pev(i, pev_nextthink, 0);
				set_pdata_int(i, 62, 30); // m_iJuice = 62
				} else if (equal(classname, "func_healthcharger")) {
				set_pev(i, pev_frame, 0);
				set_pev(i, pev_nextthink, 0);
				set_pdata_int(i, 62, 75); // m_iJuice = 62
			}
		}
	}
}

public StartVersusCountdown() {
	gStartVersusTime--;
	
	PlaySound(0, gCountSnd[gStartVersusTime]);
	
	if (gStartVersusTime == 0) {
		remove_task(TASK_STARTVERSUS); // Parar la cuenta regresiva
		
		gVersusStarted = true;
		
		gBlockCmdDrop = false;
		gBlockCmdKill = false;
		
		ClearSyncHud(0, gHudShowMatch);
		
		for (new id = 1; id <= MaxClients; id++) {
			if (is_user_connected(id) && !hl_get_user_spectator(id)) {
				SaveScore(id);
				hl_user_spawn(id);
			}
		}
		
		gTimeLeft = gTimeLimit == 0 ? TIMELEFT_SETUNLIMITED : gTimeLimit * 60;
		
		return;
	}
	
	PlaySound(0, gBeepSnd);
	
	set_hudmessage(0, 255, 0, -1.0, 0.2, 0, 3.0, 15.0, 0.2, 0.5);
	ShowSyncHudMsg(0, gHudShowMatch, "%L", LANG_PLAYER, "MATCH_START", gStartVersusTime);
}

PlaySound(id, const sound[]) {
	client_cmd(id, "spk %s", sound);
}

public CmdXdmStart(id, level, cid) {
	if (!cmd_access(id, level, cid, 0))
		return PLUGIN_HANDLED;
	
	new name[32], authid[32];
	get_user_name(id, name, charsmax(name));
	get_user_authid(id, authid, charsmax(authid));
	
	log_amx("Agstart: ^"%s<%d><%s>^"", name, get_user_userid(id), authid);
	
	new arg[32];
	read_argv(1, arg, charsmax(arg));
	
	if (equal(arg, "")) { 
		StartVersus();
		return PLUGIN_HANDLED;
	}
	
	// Obtemos que jugadores van a jugar versus
	new target[33], player;
	
	for (new i = 1; i < read_argc(); i++) {
		read_argv(i, arg, charsmax(arg));
		player = cmd_target(id, arg, CMDTARGET_ALLOW_SELF);
		if (player)
			target[player] = player;
		else
			return PLUGIN_HANDLED;
	}
	
	for (new i = 1; i <= MaxClients; i++) {
		if (is_user_connected(i)) {
			if (i == target[i])
				ag_set_user_spectator(i, false);
			else {
				ag_set_user_spectator(i, true);
				set_pev(id, pev_flags, pev(id, pev_flags) & ~FL_FROZEN);
			}
		}		
	}
	
	StartVersus();
	
	return PLUGIN_HANDLED;
}

public CmdXdmAbort(id, level, cid) {
	if (!cmd_access(id, level, cid, 0))
		return PLUGIN_HANDLED;
	
	new name[32], authid[32];
	get_user_name(id, name, charsmax(name));
	get_user_authid(id, authid, charsmax(authid));
	
	log_amx("Agabort: ^"%s<%d><%s>^"", name, get_user_userid(id), authid);
	
	AbortVersus();
	
	return PLUGIN_CONTINUE;
}

public CmdXdmAllow(id, level, cid) {
	if (!cmd_access(id, level, cid, 0))
		return PLUGIN_HANDLED;
	
	if (!gVersusStarted)
		return PLUGIN_HANDLED;
	
	new arg[32], player;
	read_argv(1, arg, charsmax(arg));
	
	if (equal(arg, ""))
		player = id;
	else 
		player = cmd_target(id, arg, CMDTARGET_ALLOW_SELF);
	
	if (!player)
		return PLUGIN_HANDLED;
	
	AllowPlayer(player);
	
	new name[32], authid[32];
	get_user_name(id, name, charsmax(name));
	get_user_authid(id, authid, charsmax(authid));
	
	log_amx("Agallow: ^"%s<%d><%s>^"", name, get_user_userid(id), authid);
	
	return PLUGIN_HANDLED;
}

public CmdXdmPause(id, level, cid) {
	if (!cmd_access(id, level, cid, 0))
		return PLUGIN_HANDLED;
	
	new name[32], authid[32];
	get_user_name(id, name, charsmax(name));
	get_user_authid(id, authid, charsmax(authid));
	
	log_amx("Agpause: ^"%s<%d><%s>^"", name, get_user_userid(id), authid);
	
	RemoveVote();
	PauseGame(id);
	return PLUGIN_CONTINUE;	
}

public CmdSpectate(id) {
	new authid[32];
	get_user_authid(id, authid, charsmax(authid));
	
	if (ScoreExists(authid)) {
		if (!hl_get_user_spectator(id)) 
			ResetScore(id);
	} else if (gBlockCmdSpec)
	return PLUGIN_HANDLED;
	
	if (gVoteStarted)
		set_task(0.1, "ShowVote", TASK_SHOWVOTE);
	
	return PLUGIN_CONTINUE;
}

public CmdDrop() {
	if (gBlockCmdDrop)
		return PLUGIN_HANDLED;
	return PLUGIN_CONTINUE;
}
