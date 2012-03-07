
// enforce semicolons after each code statement
#pragma semicolon 1

#define PLUGIN_VERSION "2.0.1"

#include <sourcemod>
#include <entity>
#include <clients>
#include <sdktools>
#include <smlib>

#define SF_PHYSPROP_START_ASLEEP				0x000001
#define SF_PHYSPROP_DONT_TAKE_PHYSICS_DAMAGE	0x000002		// this prop can't be damaged by physics collisions
#define SF_PHYSPROP_DEBRIS						0x000004
#define SF_PHYSPROP_MOTIONDISABLED				0x000008		// motion disabled at startup (flag only valid in spawn - motion can be enabled via input)
#define	SF_PHYSPROP_TOUCH						0x000010		// can be 'crashed through' by running player (plate glass)
#define SF_PHYSPROP_PRESSURE					0x000020		// can be broken by a player standing on it
#define SF_PHYSPROP_ENABLE_ON_PHYSCANNON		0x000040		// enable motion only if the player grabs it with the physcannon
#define SF_PHYSPROP_NO_ROTORWASH_PUSH			0x000080		// The rotorwash doesn't push these
#define SF_PHYSPROP_ENABLE_PICKUP_OUTPUT		0x000100		// If set, allow the player to +USE this for the purposes of generating an output
#define SF_PHYSPROP_PREVENT_PICKUP				0x000200		// If set, prevent +USE/Physcannon pickup of this prop
#define SF_PHYSPROP_PREVENT_PLAYER_TOUCH_ENABLE	0x000400		// If set, the player will not cause the object to enable its motion when bumped into
#define SF_PHYSPROP_HAS_ATTACHED_RAGDOLLS		0x000800		// Need to remove attached ragdolls on enable motion/etc
#define SF_PHYSPROP_FORCE_TOUCH_TRIGGERS		0x001000		// Override normal debris behavior and respond to triggers anyway
#define SF_PHYSPROP_FORCE_SERVER_SIDE			0x002000		// Force multiplayer physics object to be serverside
#define SF_PHYSPROP_RADIUS_PICKUP				0x004000		// For Xbox, makes small objects easier to pick up by allowing them to be found 
#define SF_PHYSPROP_ALWAYS_PICK_UP				0x100000		// Physcannon can always pick this up, no matter what mass or constraints may apply.
#define SF_PHYSPROP_NO_COLLISIONS				0x200000		// Don't enable collisions on spawn
#define SF_PHYSPROP_IS_GIB						0x400000		// Limit # of active gibs



/*****************************************************************


			P L U G I N   I N F O


*****************************************************************/

public Plugin:myinfo = {
	name = "Entity Spawner",
	author = "Berni, Chanz",
	description = "Entity Spawner & Tools",
	version = PLUGIN_VERSION,
	url = "http://www.mannisfunhouse.eu"
}



/*****************************************************************


			G L O B A L   V A R S


*****************************************************************/

// ConVar Handles
new Handle:spawntools_version;
new Handle:spawntools_defaultspawnlimit;
new Handle:spawntools_maxspawnlimit;

new Handle:kv;
new Handle:SetAbsOrigin;
new Handle:SetAbsAngles;
new Handle:LeaveVehicle;

new g_BeamSprite;
new g_HaloSprite;

new Handle:g_Menu = INVALID_HANDLE;
new Handle:clientMenu[MAXPLAYERS+1] = { INVALID_HANDLE };


/*****************************************************************


			F O R W A R D   P U B L I C S


*****************************************************************/

public APLRes:AskPluginLoad2(Handle:myself, bool:late, String:error[], err_max){
	
   CreateNative("ES_SpawnObject", Native_SpawnObject);
   return APLRes_Success;
}

public OnPluginStart() {
	
	// ConVars
	spawntools_version = CreateConVar("spawntools_version", PLUGIN_VERSION, "Spawn tools plugin version", FCVAR_DONTRECORD|FCVAR_REPLICATED|FCVAR_NOTIFY);
	// Set it to the correct version, in case the plugin gets updated...
	SetConVarString(spawntools_version, PLUGIN_VERSION);
	
	spawntools_defaultspawnlimit = CreateConVar("spawntools_defaultspawnlimit", "5", "The default spawn limit for entities, if it isn't set in the config");
	spawntools_maxspawnlimit = CreateConVar("spawntools_maxspawnlimit", "20", "The general max spawn limit");
	
	new Handle:GameConf = LoadGameConfigFile("entity_spawner.games");
	
	StartPrepSDKCall(SDKCall_Entity);
	PrepSDKCall_SetFromConf(GameConf, SDKConf_Signature, "SetAbsOrigin");
	PrepSDKCall_AddParameter(SDKType_Vector, SDKPass_ByRef);
	SetAbsOrigin = EndPrepSDKCall();
	
	StartPrepSDKCall(SDKCall_Entity);
	PrepSDKCall_SetFromConf(GameConf, SDKConf_Signature, "SetAbsAngles");
	PrepSDKCall_AddParameter(SDKType_QAngle, SDKPass_ByRef);
	SetAbsAngles = EndPrepSDKCall();
	
	StartPrepSDKCall(SDKCall_Player);
	PrepSDKCall_SetFromConf(GameConf, SDKConf_Signature, "LeaveVehicle");
	PrepSDKCall_AddParameter(SDKType_QAngle, SDKPass_ByRef);
	PrepSDKCall_AddParameter(SDKType_QAngle, SDKPass_ByRef);
	LeaveVehicle = EndPrepSDKCall();
	
	CloseHandle(GameConf);
	
	ReadConfig();

	RegAdminCmd("sm_color", 			Command_Color, ADMFLAG_CUSTOM4);
	RegAdminCmd("sm_alpha", 			Command_Alpha, ADMFLAG_CUSTOM4);
	RegAdminCmd("sm_spawn", 			Command_Spawn,	ADMFLAG_CUSTOM4);
	RegAdminCmd("sm_remove",			Command_Remove,	ADMFLAG_CUSTOM4);
	RegAdminCmd("sm_listspawns",		Command_ListSpawns, ADMFLAG_CUSTOM4);
	RegAdminCmd("sm_spawnmenu",			Command_SpawnMenu, ADMFLAG_CUSTOM4);
	RegAdminCmd("sm_effect",			Command_Effect,	ADMFLAG_GENERIC);
	RegAdminCmd("sm_entity",			Command_Entity,	ADMFLAG_CUSTOM4);
	RegAdminCmd("sm_freezeent",			Command_FreezeEnt,	ADMFLAG_CUSTOM4);
	RegAdminCmd("sm_flyentity", 		Command_FlyEntity, ADMFLAG_CUSTOM4);
	RegAdminCmd("sm_unflyentity", 		Command_UnFlyEntity, ADMFLAG_CUSTOM4);
	RegAdminCmd("sm_exitvehicle", 		Command_ExitVehicle, ADMFLAG_CUSTOM4);
	RegAdminCmd("sm_reloadspawnlist",	Command_ReloadSpawnList, ADMFLAG_CUSTOM4);
	
	g_Menu = BuildMenu();
}

public OnMapStart() {

	//g_BeamSprite = PrecacheModel("materials/sprites/laser.vmt");
	g_BeamSprite = PrecacheModel("sprites/bluelight1.vmt");
	g_HaloSprite = PrecacheModel("materials/sprites/halo01.vmt");
	
	KvRewind(kv);
	InitializeModels();
}

/****************************************************************


			C A L L B A C K   F U N C T I O N S


****************************************************************/


public Action:Command_ExitVehicle(client, args) {
	new entity = GetClientAimTarget(client, false);
	
	if (entity <= 0) {
		PrintToChat(client, "\x04 Error: No vehicle found !");
		return Plugin_Handled;
	}


	new player = ExitVehicle(entity);
	
	if (player == -1) {
		ReplyToCommand(client, "\x04[SM] Error: This is not a vehicle !");
		return Plugin_Handled;
	}
	else if (player == 0) {
		ReplyToCommand(client, "\x04[SM] Error: There is no player in this vehicle !");
		return Plugin_Handled;
	}
	
	ReplyToCommand(client, "\x04[SM] Player %N has exited the vehicle !", player);
	
	return Plugin_Handled;
}

public Action:Command_FlyEntity(client, args) {
	
	new entity = GetClientAimTarget(client, false);
	
	if (entity < 0) {
		PrintToChat(client, "\x04 Error: no valid target found !");
		return Plugin_Handled;
	}
	else {
		AcceptEntityInput(entity, "DisableMotion");
		new m_spawnflags = GetEntProp(entity, Prop_Data, "m_spawnflags");
		m_spawnflags |= SF_PHYSPROP_ENABLE_ON_PHYSCANNON;
		SetEntProp(entity, Prop_Data, "m_spawnflags", m_spawnflags);
		HookSingleEntityOutput(entity, "OnPhysGunDrop", PropPhysics_OnPhysGunDrop);
	}
	
	return Plugin_Handled;
}

public Action:Command_UnFlyEntity(client, args) {
	
	new entity = GetClientAimTarget(client, false);
	
	if (entity < 0) {
		PrintToChat(client, "\x04 Error: no valid target found !");
		return Plugin_Handled;
	}
	else {
		AcceptEntityInput(entity, "EnableMotion");
		new m_spawnflags = GetEntProp(entity, Prop_Data, "m_spawnflags");
		m_spawnflags &= ~SF_PHYSPROP_ENABLE_ON_PHYSCANNON;
		SetEntProp(entity, Prop_Data, "m_spawnflags", m_spawnflags);
		UnhookSingleEntityOutput(entity, "OnPhysGunDrop", PropPhysics_OnPhysGunDrop);
	}
	
	return Plugin_Handled;
}


public PropPhysics_OnPhysGunDrop(const String:output[], caller, activator, Float:delay) {
	AcceptEntityInput(caller, "DisableMotion");
}

public Action:Command_Entity(client, args) {
	new aimTarget = GetClientAimTarget(client, false);
	
	if (aimTarget > 0) {
			
		new String:strArg[192];
		
		GetCmdArgString(strArg, sizeof(strArg));
		
		AcceptEntityInput(aimTarget, strArg);
		
		PrintToChat(client, "\x04[SM] Input: %s", strArg);
	}
	else {
		PrintToChat(client, "\x04[SM] No entity found where you are looking at !");
	}
	
	return Plugin_Handled;
}

public Action:Command_FreezeEnt(client, args) {

	new aimTarget = GetClientAimTarget(client, false);
	
	if (aimTarget > 0) {
			
		new String:strArg[192];
		
		GetCmdArgString(strArg, sizeof(strArg));
		
		new m_spawnflags = GetEntProp(aimTarget, Prop_Data, "m_spawnflags");
		if (m_spawnflags & SF_PHYSPROP_MOTIONDISABLED) {
			AcceptEntityInput(aimTarget, "enablemotion");
			SetEntProp(aimTarget, Prop_Data, "m_spawnflags", m_spawnflags & ~SF_PHYSPROP_MOTIONDISABLED);
			PrintToChat(client, "\x04[SM] Entity %d unfreezed !", aimTarget);
		}
		else {
			AcceptEntityInput(aimTarget, "disablemotion");
			SetEntProp(aimTarget, Prop_Data, "m_spawnflags", m_spawnflags | SF_PHYSPROP_MOTIONDISABLED);
			ChangeEdictState(aimTarget);
			
			PrintToChat(client, "\x04[SM] Entity %d freezed !", aimTarget);
		}
	}
	else {
		PrintToChat(client, "\x04[SM] No entity found where you are looking at !");
	}
	
	return Plugin_Handled;
}

public Action:Command_Effect(client, args) {
	/*new String:effect[64];
	
	GetCmdArg(1, effect, sizeof(effect));*/
	
	new Float:startorigin[3];
	new Float:stoporigin[3];
	GetClientAbsOrigin(client, startorigin);
	GetClientAbsOrigin(client, stoporigin);
	startorigin[0] += 70.0;
	stoporigin[0] += 70.0;
	stoporigin[2] += 2000.0;
	
	new sprite_beam = PrecacheModel("sprites/blueglow1.vmt", true);
	
	/*TE_SetupBeamPoints(
		startorigin,
		stoporigin,
		sprite_beam,
		0,
		0,
		10,
		20, 
        5.0,
		50.0,
		0,
		1.0,
		{ 255, 255, 255, 255 },
		10
	);*/
	
	TE_SetupGlowSprite(
		startorigin,
		sprite_beam,
		10.0,
		5.0,
		255
	);
	
	TE_SendToAll();
	
	return Plugin_Handled;
}

public Action:Command_Color(client, args) {
	
	if (args == 0 || args > 3) {
		PrintToChat(client, "\x04[SM] Usage: sm_color <red> <green> <blue>");
		
		return Plugin_Handled;
	}
	
	new String:arg[8], String:arg2[8], String:arg3[8];
	new r, g, b;
	
	GetCmdArg(1, arg, sizeof(arg));
	GetCmdArg(2, arg2, sizeof(arg2));
	GetCmdArg(3, arg3, sizeof(arg3));
	
	
	r = StringToInt(arg);
	g = StringToInt(arg2);
	b = StringToInt(arg3);
	
	new entity = GetClientAimTarget(client, false);
	
	if (entity > 0) {
	
		new offset = GetEntSendPropOffs(entity, "m_clrRender");
		SetEntData(entity, offset, r, 1, true);
		SetEntData(entity, offset + 1, g, 1, true);
		SetEntData(entity, offset + 2, b, 1, true);
	}
	
	
	return Plugin_Handled;
}

public Action:Command_Alpha(client, args) {
	if (args == 0) {
		PrintToChat(client, "\x04[SM] Usage: sm_color <alpha>");
		
		return Plugin_Handled;
	}
	
	new String:arg[8];
	new a;
	
	GetCmdArg(1, arg, sizeof(arg));
	a = StringToInt(arg);
	
	new entity = GetClientAimTarget(client, false);
	
	if (entity > 0) {
		SetEntityRenderMode(entity, RENDER_TRANSCOLOR);
		
		new offset = GetEntSendPropOffs(entity, "m_clrRender");
		SetEntData(entity, offset + 3, a, 1, true);
	}
	
	
	return Plugin_Handled;
}

public Action:Command_Spawn(client, args) {
	
	if (client == 0) {
		ReplyToCommand(client, "[SM] Sorry, atm this is not possible from within the console.");
		
		return Plugin_Handled;
	}

	if (args < 1) {
		decl String:cmd[32];
		GetCmdArg(0, cmd, sizeof(cmd));

		ReplyToCommand(client, "[SM] Usage: %s <name>", cmd);
		
		return Plugin_Handled;
	}
	
	decl String:entClass[64];
	decl String:name[64];
	
	GetCmdArg(1, name, sizeof(name));
	
	KvRewind(kv);
	
	new found = false;
	
	if (FindSpawnObject(name)) {
		KvGetString(kv, "class", entClass, sizeof(entClass), "");
		
		if (!StrEqual(entClass, "")) {
			found = true;
		}
	}
	
	if (!found) {
		ReplyToCommand(client, "\x04[SM] Sorry %N, I can't find object %s in my entity list :(", client, name);
		
		return Plugin_Handled;
	}
	
	SpawnObject(client,kv);

	return Plugin_Handled;
}

public Action:Command_Remove(client, args) {
	
	new entity;
	new String:arg[32];
	
	if (args == 1) {
		GetCmdArg(1, arg, sizeof(arg));
		entity = StringToInt(arg);
	}
	else {
		decl Float:pos[3];
		entity = GetClientAimTargetEx(client, pos);
	}
	
	if (!IsValidEntity(entity)) {
		ReplyToCommand(client, "\x4[SM] No entity found !");
		return Plugin_Handled;
	}
		
	if (entity <= MAXPLAYERS) {
		ReplyToCommand(client, "\x4[SM] No entity found that can be removed !");
		return Plugin_Handled;
	}
	
	/*new AdminId:aid = GetUserAdmin(client);
	if (aid  == INVALID_ADMIN_ID || !GetAdminFlag(aid , Admin_Root)) {
		
		decl String:auth[32];
		new owner = FindEntityOwner(entity, auth, sizeof(auth));
		
		if (StrContains(auth, "STEAM_") != 0) {
			ReplyToCommand(client, "\x4[SM] Error: You can't remove this entity because it doesn't belong to you !");
			return Plugin_Handled;
		}
	
		decl String:clientAuth[32];
		GetClientAuthString(client, clientAuth, sizeof(clientAuth));
		
		if (!StrEqual(auth, clientAuth)) {
			new AdminId:owner_aid = FindAdminByIdentity(AUTHMETHOD_STEAM, auth);
			
			if (owner_aid != INVALID_ADMIN_ID || !CanAdminTarget(aid, owner_aid)) {
				
				if (owner == -1) {
					decl String:adminUserName[64];
					GetAdminUsername(owner_aid, adminUserName, sizeof(adminUserName));
					ReplyToCommand(client, "\x4[SM] Error: You can't remove this entity because it belongs to %s", adminUserName);
				}
				else {
					ReplyToCommand(client, "\x4[SM] Error: You can't remove this entity because it belongs to %N !", owner);
				}
				
				return Plugin_Handled;
			}
		}
	}*/
	
	Effect_FadeOut(entity, true);
	
	return Plugin_Handled;
}

public Action:Command_ListSpawns(client, args) {
	KvRewind(kv);
	
	ReplyToCommand(client, "[SM] Listing available entity spawns:");
	ListSpawnObjects(client);
	ReplyToCommand(client, "[SM] End of spawnlist");
	
	return Plugin_Handled;
}

public Action:Command_SpawnMenu(client, args) {
	DisplayMenu(g_Menu, client, MENU_TIME_FOREVER);
	
	return Plugin_Handled;
}

public bool:TraceEntityFilterPlayer(entity, contentsMask) {
 	return entity > MaxClients;
}

public Action:Command_ReloadSpawnList(client, args) {
	
	ReadConfig();
	ReplyToCommand(client, "[SM] Reloading Spawnlist... done !");
	
	InitializeModels();
	
	return Plugin_Handled;
}

public Menu_Spawn(Handle:menu, MenuAction:action, param1, param2) {

	if (action == MenuAction_Select) {
		decl String:info[12];
 
		/* Get item info */
		new bool:found = GetMenuItem(menu, param2, info, sizeof(info));
		
		if (found) {
			decl String:class[64];

			new id = StringToInt(info);
			
			KvRewind(kv);
			kvFindNode(kv, id);
			
			KvGetString(kv, "class", class, sizeof(class));
			
			if (StrEqual(class, "")) {
				DisplaySpawnMenu(param1);
			}
			else {
				SpawnObject(param1,kv);
			}
		}
	}
	
	if (action == MenuAction_End) {
		
		if (param1 == MenuEnd_ExitBack) {
			new client;
			new bool:exists = false;
			for (client=1; client<=MAXPLAYERS; ++client) {
				if (clientMenu[client] == menu) {
					exists = true;
					break;
				}
			}
		
			if (exists) {
				decl String:info[12];
	 
				/* Get item info */
				GetMenuItem(menu, param2, info, sizeof(info));
				new id = StringToInt(info);
			
				KvRewind(kv);
				kvFindNode(kv, id);
				KvGoBack(kv);
				KvGoBack(kv);
				
				DisplaySpawnMenu(client);
			}
		}
	}
}


/*****************************************************************


			P L U G I N   F U N C T I O N S


*****************************************************************/

Handle:BuildMenu() {
 
	/* Create the menu Handle */
	new Handle:menu = CreateMenu(Menu_Spawn);

	SpawnMenuList(menu);
 
	/* Finally, set the title */
	SetMenuTitle(menu, "Spawn Menu:");
 
	return menu;
}

ReadConfig() {
	new String:ConfigFile[PLATFORM_MAX_PATH];

	BuildPath(Path_SM, ConfigFile, sizeof(ConfigFile), "configs/entity_spawner.cfg");
	
	if(!FileExists(ConfigFile)) {
		LogMessage("%s not parsed...file doesnt exist!", ConfigFile);
		
		return;
	}

	kv = CreateKeyValues("Entitylist");
	FileToKeyValues(kv, ConfigFile);
	
}

CountEntitesForOwner(owner, String:name[] = "") {
	new count = 0;
	decl String:clientAuth[32];
	decl String:m_iName[128];
	decl String:m_iGlobalname[128];
	
	GetClientAuthString(owner, clientAuth, sizeof(clientAuth));
	
	new maxentites = GetMaxEntities();
	for (new entity=MAXPLAYERS+1; entity<=maxentites; entity++) {
		if (IsValidEntity(entity)) {
			GetEntPropString(entity, Prop_Data, "m_iName", m_iName, sizeof(m_iName));
			GetEntPropString(entity, Prop_Data, "m_iGlobalname", m_iGlobalname, sizeof(m_iGlobalname));

			if (StrEqual(clientAuth, m_iGlobalname)) {
				if (StrEqual(name, "")) {
					count++;
				}
				else {
					if (StrEqual(m_iName, name, false)) {
						count++;
					}
				}
			}
		}
	}
	
	return count;
}

bool:ListSpawnObjects(client, depth=0) {

	if (!KvGotoFirstSubKey(kv)) {
		return false;
	}

	do {
		
		decl String:buffer[64];
		decl String:class[64];
		decl String:blanks[32] = "";
		
		KvGetSectionName(kv, buffer, sizeof(buffer));
		KvGetString(kv, "class", class, sizeof(class));
		
		for (new i=0; i<depth; ++i) {
			StrCat(blanks, sizeof(blanks), "\t");
		}
		
		if (StrEqual(class, "")) {
			ReplyToCommand(client, "[SM] %s[%s]:", blanks, buffer);
		}
		else {
			ReplyToCommand(client, "[SM] %s%s", blanks, buffer);
		}

		depth++;
		ListSpawnObjects(client, depth);
		depth--;
	}
	while (KvGotoNextKey(kv));
		
	KvGoBack(kv);
	
	return false;
}

stock FindEntityOwner(entity, String:auth[], size) {
	decl String:clientAuth[32];

	GetEntPropString(entity, Prop_Data, "m_iGlobalname", auth, size);
	
	new maxclients = GetMaxClients();
	for (new client=1; client<maxclients; ++client) {
		if (IsClientInGame(client) && !IsFakeClient(client)) {
			GetClientAuthString(client, clientAuth, sizeof(clientAuth));
			if (StrEqual(clientAuth, auth)) {
				return client;
			}
		}
	}
	
	return -1;
}

GetClientAimTargetEx(client, Float:pos[3], Float:limitDistance=0.0) {
	if(client < 1) {
		return -1;
	}

	decl Float:vAngles[3], Float:vOrigin[3];
	
	GetClientEyePosition(client,vOrigin);
	GetClientEyeAngles(client, vAngles);
	
	new Handle:trace = INVALID_HANDLE;
	
	if(limitDistance != 0.0){
		
		decl Float:vEnd[3];
		
		vEnd[0] = (vOrigin[0] + ((limitDistance/2) * Cosine(DegToRad(vAngles[1]))));
		vEnd[1] = (vOrigin[1] + ((limitDistance/2) * Sine(DegToRad(vAngles[1]))));
		vEnd[2] = (vOrigin[2] + 80);
		
		trace = TR_TraceRayFilterEx(vOrigin, vEnd, MASK_ALL, RayType_EndPoint, TraceEntityFilterPlayer);
	}
	else {
		
		trace = TR_TraceRayFilterEx(vOrigin, vAngles, MASK_ALL, RayType_Infinite, TraceEntityFilterPlayer);
	}
	
	TR_GetEndPosition(pos, trace);
	
	if(TR_DidHit(trace)){
		
		new entity = TR_GetEntityIndex(trace);
		
		CloseHandle(trace);
		
		return entity;
	}
	
	CloseHandle(trace);
	
	return -1;
}

GetClientAimHullTarget(client, Float:mins[3], Float:maxs[3], Float:pos[3], Float:result[3]) {

	decl Float:vEyePosition[3];
	
	if (pos[0] == 0.0 && pos[1] == 0.0 && pos[2] == 0.0) {
		GetClientAimTargetEx(client, pos);
	}
	
	GetClientEyePosition(client, vEyePosition);
	
	new Handle:trace = TR_TraceHullEx(vEyePosition, pos, mins, maxs, MASK_ALL);
	
	TR_GetEndPosition(result, trace);
	
	if(TR_DidHit(trace)){
		
		new entity = TR_GetEntityIndex(trace);
		
		CloseHandle(trace);
		
		return entity;
	}
	
	CloseHandle(trace);
	
	return -1;
}

ExitVehicle(vehicle) {
	decl String:netClass[32], String:class[32];
	GetEntityNetClass(vehicle, netClass, sizeof(netClass));
	GetEdictClassname(vehicle, class, sizeof(class));

	if (StrContains(class, "prop_vehicle_") == 0) {
		
		new offset_m_hPlayer = FindSendPropOffs(netClass, "m_hPlayer");
		new m_hPlayer = GetEntDataEnt2(vehicle, offset_m_hPlayer);
		
		if (m_hPlayer <= 0) {
			return 0;
		}

		decl Float:vec[3];
		decl Float:ang[3];
		
		GetEntPropVector(vehicle, Prop_Send, "m_vecOrigin", vec);
		GetEntPropVector(vehicle, Prop_Send, "m_angRotation", ang);
		
		SDKCall(LeaveVehicle, m_hPlayer, vec, ang);
		
		return m_hPlayer;
	}
	
	return -1;
}

bool:FindSpawnObject(String:name[]) {

	if (!KvGotoFirstSubKey(kv)) {
		return false;
	}
	
	decl String:buffer[255];

	do {
	
		KvGetSectionName(kv, buffer, sizeof(buffer));
		
		if (StrEqual(buffer, name, false)) {
			return true;
		}
	
		if (FindSpawnObject(name)) {
			return true;
		}
	}
	while (KvGotoNextKey(kv));
		
	KvGoBack(kv);
	
	return false;
}

bool:SpawnMenuList(Handle:menu) {

	if (!KvGotoFirstSubKey(kv)) {
		return false;
	}
	
	decl String:buffer[255];
	new id;
	decl String:id_str[12];

	do {
		KvGetSectionName(kv, buffer, sizeof(buffer));
		KvGetSectionSymbol(kv, id);

		IntToString(id, id_str, sizeof(id_str));
		AddMenuItem(menu, id_str, buffer);
	}
	while (KvGotoNextKey(kv));
		
	KvGoBack(kv);
	
	return false;
}

bool:kvFindNode(Handle:keyvalue, id) {
	
	if (!KvGotoFirstSubKey(keyvalue)) {
		return false;
	}

	new _id;

	do {
		
		KvGetSectionSymbol(keyvalue, _id);
		
		if (id == _id) {
			return true;
		}
	
		if (kvFindNode(keyvalue, id)) {
			return true;
		}
	}
	while (KvGotoNextKey(keyvalue));
		
	KvGoBack(keyvalue);
	
	return false;
}

public Native_SpawnObject(Handle:plugin, numParams){

	return SpawnObject(GetNativeCell(1),GetNativeCell(2));
}

SpawnObject(client,Handle:dataKV){
	
	decl String:name[64];
	decl String:entModel[256];
	decl String:entClass[64];
	decl String:entTargetName[64];
	decl String:entVehicleScript[64];
	decl String:meleeScripNname[64];
	decl String:solid[4];
	new r, g, b, a;
	new spawnlimit;
	
	KvGetSectionName(dataKV, name, sizeof(name));

	PrintToChat(client, "\x04[SM] You spawned: %s", name);
	
	KvGetString(dataKV, "class", entClass, sizeof(entClass), "prop_physics");
	KvGetString(dataKV, "targetname", entTargetName, sizeof(entTargetName), "");
	KvGetString(dataKV, "vehiclescript", entVehicleScript, sizeof(entVehicleScript), "");
	KvGetString(dataKV, "melee_script_name", meleeScripNname, sizeof(meleeScripNname), "");
	KvGetString(dataKV, "model", entModel, sizeof(entModel));
	KvGetString(dataKV, "solid", solid, sizeof(solid), "6");
	new Float:minPitch = KvGetFloat(dataKV, "minpitch", 0.0);
	new Float:maxPitch = KvGetFloat(dataKV, "maxpitch", 0.0);
	new Float:maxYaw = KvGetFloat(dataKV, "maxyaw", 0.0);
	new Float:spawnDistance = KvGetFloat(dataKV, "spawnDistance");
	new m_takedamage = KvGetNum(dataKV, "takedamage", 2);
	new m_spawnflags = KvGetNum(dataKV, "spawnflags", -1);
	new m_iHealth = KvGetNum(dataKV, "health", -1);

	KvGetColor(dataKV, "color", r, g, b, a);
	spawnlimit = KvGetNum(dataKV, "spawnlimit", GetConVarInt(spawntools_defaultspawnlimit));
	
	if (StrEqual(entModel, "")) {
		
		PrintToChat(client, "\x04[SM] Error, no model set for this entity in the config !");
		return -1;
	}
	
	/*if (KvJumpToKey(dataKV, "keyvalues")) {
	
		if (KvGotoFirstSubKey(dataKV)) {

			do {
				KvGetSectionName(dataKV, name, sizeof(name));
				PrintToServer("Debug: name: %s", name);
			}
			while (KvGotoNextKey(dataKV));
				
			KvGoBack(dataKV);
		}
	}*/
	
	
	new count_general = CountEntitesForOwner(client);
	new count_entity = CountEntitesForOwner(client, name);
	new AdminId:admin = GetUserAdmin(client);
	
	if (admin == INVALID_ADMIN_ID || !GetAdminFlag(admin, Admin_Root)) {
		
		if (count_general >= GetConVarInt(spawntools_maxspawnlimit)) {
			
			PrintToChat(client, "\04[SM] Error: Your general spawn limit is already reached ! (%d/%d)", count_general, GetConVarInt(spawntools_maxspawnlimit));
			return -2;
		}
		
		if (count_entity >= spawnlimit) {
			
			PrintToChat(client, "\04[SM] Error: Your spawn limit for this entity is already reached ! (%d/%d)", count_entity, spawnlimit);
			return -3;
		}
	}
	
	//PrintToChat(client,"spawnlimit for this item is: %d and you spawned already of this: %d - and general: %d",spawnlimit,count_entity,count_general);

	// Create our entity
	new entity = CreateEntityByName(entClass);
	
	if (entity == -1) {
		PrintToChat(client, "\x04[SM] Failed to create object ! Invalid config ?");
		return -4;
	}
	
	new Float:vOrigin[3], Float:vAbsAngles[3];

	// Get the view
	GetClientAimTargetEx(client, vOrigin, spawnDistance);
	GetClientAbsAngles(client, vAbsAngles);
	
	vAbsAngles[1] += 180.0;
	
	if (vAbsAngles[1] > 180) {
		vAbsAngles[1] -= 360;
	}

	SDKCall(SetAbsOrigin, entity, vOrigin);
	SDKCall(SetAbsAngles, entity, vAbsAngles);

	if (!StrEqual(entModel, "none")) {

		// Give it a model so we can see it
		PrecacheModel(entModel, true);

		DispatchKeyValue(entity, "model", entModel);
	}
		
	if (!StrEqual(entTargetName, "")) {
		DispatchKeyValue(entity, "targetname", entTargetName);
	}
	
	if (!StrEqual(entVehicleScript, "")) {
		DispatchKeyValue(entity, "vehiclescript", entVehicleScript);
	}
	
	if (!StrEqual(meleeScripNname, "")) {
		DispatchKeyValue(entity, "melee_script_name", meleeScripNname);
	}
	
	if (m_spawnflags != -1) {
		SetEntProp(entity, Prop_Data, "m_spawnflags", m_spawnflags);
	}
	
	if (m_iHealth != -1) {
		SetEntProp(entity, Prop_Data, "m_iHealth", m_iHealth);
	}
	
	if (minPitch != 0.0) {
		DispatchKeyValueFloat (entity, "MinPitch", -360.00);
	}
	
	if (maxPitch != 0.0) {
		DispatchKeyValueFloat (entity, "MaxPitch", 360.00);
	}
	
	if (maxYaw != 0.0) {
		DispatchKeyValueFloat (entity, "maxYaw", 90.00);
	}
	
	SetEntProp(entity, Prop_Data, "m_takedamage", m_takedamage, 1);
	
	DispatchKeyValue(entity, "solid", "6");
	
	DispatchSpawn(entity);
	
	// Hull Calculaction (Anti-stuck)	
	decl Float:m_vecMins[3], Float:m_vecMaxs[3];
	GetEntPropVector(entity, Prop_Send, "m_vecMins", m_vecMins);
	GetEntPropVector(entity, Prop_Send, "m_vecMaxs", m_vecMaxs);
	
	GetClientAimHullTarget(client, m_vecMins, m_vecMaxs, vOrigin, vOrigin);
	
	decl Float:clientOrigin[3];
	GetClientAbsOrigin(client, clientOrigin);
	//ReplyToCommand(client, "\x04[Entity-Spawner] Distance: %f", GetVectorDistance(clientOrigin, vOrigin));
	
	if (GetVectorDistance(clientOrigin, vOrigin) > 64) {
		TeleportEntity(entity, vOrigin, NULL_VECTOR, NULL_VECTOR);
	}
	// Hull Calculation end
	
	ActivateEntity(entity);
	
	decl String:clientAuth[32];
	GetClientAuthString(client, clientAuth, sizeof(clientAuth));
	DispatchKeyValue(entity, "globalname", clientAuth);
	DispatchKeyValue(entity, "targetname", name);
	
	SetEntityRenderMode(entity, RENDER_TRANSCOLOR);
	
	new m_clrRender = GetEntSendPropOffs(entity, "m_clrRender");
	
	if (r != 0 || g != 0 || b != 0) {	
		
		SetEntData(entity, m_clrRender,		r, 1, true);
		SetEntData(entity, m_clrRender + 1, g, 1, true);
		SetEntData(entity, m_clrRender + 2, b, 1, true);
	}
	
	if (a == 0) {
		Effect_FadeIn(entity);
	}
	else {
		SetEntData(entity, m_clrRender + 3, a, 1, true);
	}
	
	decl Float:End_Radius;
	
	if (m_vecMaxs[0] > m_vecMaxs[1]) {
		End_Radius = m_vecMaxs[0];
	}
	else {
		End_Radius = m_vecMaxs[1];
	}
	
	End_Radius += 100;
	
	TE_SetupBeamRingPoint(vOrigin, 0.0, End_Radius, g_BeamSprite, g_HaloSprite, 0, 10, 0.6, 10.0, 0.5, {75, 255, 75, 255}, 10, 0);
	TE_SendToAll();
	
	return entity;
}

DisplaySpawnMenu(client) {
	decl String:category[32];

	KvGetSectionName(kv, category, sizeof(category));
				
	new Handle:catmenu = CreateMenu(Menu_Spawn);

	SpawnMenuList(catmenu);
 
	/* Finally, set the title */
	SetMenuTitle(catmenu, "%s:", category);
	
	SetMenuExitBackButton(catmenu, true);
	
	DisplayMenu(catmenu, client, MENU_TIME_FOREVER);
	
	clientMenu[client] = catmenu;
}

InitializeModels() {

	if (!KvGotoFirstSubKey(kv)) {
		return;
	}

	do {

		decl String:model[PLATFORM_MAX_PATH];
		decl String:downloadName[12];
		decl String:download[PLATFORM_MAX_PATH];
		
		KvGetString(kv, "model", model, sizeof(model));
		
		if (!StrEqual(model, "")) {
		
			File_AddToDownloadsTable(model);
			PrecacheModel(model, true);

			new x=1;
			do {
				Format(downloadName, sizeof(downloadName), "download%d", x);
				KvGetString(kv, downloadName, download, sizeof(download));
				
				if (StrEqual(download, "")) {
					break;
				}
				else {
					File_AddToDownloadsTable(download);
				}
				
				x++;
			} while (x < 1000);
		}

		InitializeModels();
	}
	while (KvGotoNextKey(kv));
		
	KvGoBack(kv);
	
	return;
}
