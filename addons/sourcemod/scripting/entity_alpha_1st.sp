
// enforce semicolons after each code statement
#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <smlib>

#define PLUGIN_VERSION "0.1"



/*****************************************************************


		P L U G I N   I N F O


*****************************************************************/

public Plugin:myinfo = {
	name = "Entity & Alpha für 1st",
	author = "Berni",
	description = "Plugin by Berni",
	version = PLUGIN_VERSION,
	url = "http://www.mannisfunhouse.eu"
}



/*****************************************************************


		G L O B A L   V A R S


*****************************************************************/

// ConVar Handles

// Misc



/*****************************************************************


		F O R W A R D   P U B L I C S


*****************************************************************/

public OnPluginStart() {

	RegAdminCmd("sm_alpha", 			Command_Alpha, ADMFLAG_CUSTOM4);
	RegAdminCmd("sm_entity",			Command_Entity,	ADMFLAG_CUSTOM4);
	RegAdminCmd("sm_dispatch",			Command_Dispatch,	ADMFLAG_CUSTOM4);
	RegAdminCmd("sm_shake", Command_Shake, ADMFLAG_CUSTOM4);
	RegAdminCmd("sm_setscore", Command_SetScore, ADMFLAG_ROOT);
	RegAdminCmd("sm_setdeaths", Command_SetDeaths, ADMFLAG_ROOT);
	RegAdminCmd("sm_setteamscore", Command_SetTeamScore, ADMFLAG_ROOT);
	RegAdminCmd("sm_setdatamapvalue", Command_SetDataMapValue, ADMFLAG_ROOT);
	RegAdminCmd("sm_getdatamapvalue", Command_GetDataMapValue, ADMFLAG_ROOT);
	RegAdminCmd("sm_getdatamapvaluevector", Command_GetDataMapValueVector, ADMFLAG_ROOT);
	RegAdminCmd("sm_website", Command_Website, ADMFLAG_CUSTOM4);
	RegAdminCmd("sm_connectbox", Command_ConnectBox, ADMFLAG_CUSTOM4);
	RegAdminCmd("sm_fexec", Command_FakeExecute, ADMFLAG_CUSTOM4);
	
	LoadTranslations("common.phrases");
}



/****************************************************************


		C A L L B A C K   F U N C T I O N S


****************************************************************/

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

public Action:Command_Entity(client, args) {
	new aimTarget = GetClientAimTarget(client, false);
	
	if (aimTarget > 0) {
		
		new String:strArg[192];
		GetCmdArgString(strArg, sizeof(strArg));
		
		if (aimTarget >= 1 && aimTarget <= MaxClients && StrEqual(strArg, "kill", false)) {
			return Plugin_Handled;
		}
		
		AcceptEntityInput(aimTarget, strArg);
		
		PrintToChat(client, "\x04[SM] Input: %s", strArg);
	}
	else {
		PrintToChat(client, "\x04[SM] No entity found where you are looking at !");
	}
	
	return Plugin_Handled;
}

public Action:Command_Dispatch(client, args) {
	
	if (args < 2) {
		
		ReplyToCommand(client, "Usage: sm_dispatch <key> <value>");
		return Plugin_Handled;
	}
	
	new aimTarget = GetClientAimTarget(client, false);
	
	if (aimTarget > 0) {
		
		if (aimTarget >= 1 && aimTarget <= MaxClients) {
			return Plugin_Handled;
		}
			
		decl String:keyName[64], String:value[64];
		GetCmdArg(1, keyName, sizeof(keyName));
		GetCmdArg(2, value, sizeof(value));

		DispatchKeyValue(aimTarget, keyName, value);
		
		PrintToChat(client, "\x04[SM] Dispatching Key: %s Value: %s", keyName, value);
	}
	else {
		PrintToChat(client, "\x04[SM] No entity found where you are looking at !");
	}
	
	return Plugin_Handled;
}

#define	SHAKE_START					0			// Starts the screen shake for all players within the radius.
#define	SHAKE_STOP					1			// Stops the screen shake for all players within the radius.
#define	SHAKE_AMPLITUDE				2			// Modifies the amplitude of an active screen shake for all players within the radius.
#define	SHAKE_FREQUENCY				3			// Modifies the frequency of an active screen shake for all players within the radius.
#define	SHAKE_START_RUMBLEONLY		4			// Starts a shake effect that only rumbles the controller, no screen effect.
#define	SHAKE_START_NORUMBLE		5			// Starts a shake that does NOT rumble the controller.

public Action:Command_Shake(client, args) {
	if (args == 0) {
		ReplyToCommand(client, "\x04[SM] \x01Usage: sm_shake <target> <amplitude>");
		
		return Plugin_Handled;
	}
	
	decl String:target[MAX_TARGET_LENGTH];
	GetCmdArg(1, target, sizeof(target));
	
	
	new Float:shakepower = 100.0;
	
	if (args == 2) {
		decl String:arg2[8];
		GetCmdArg(2, arg2, sizeof(arg2));
		shakepower = StringToFloat(arg2);
	}
	
	decl String:target_name[MAX_TARGET_LENGTH];
	decl target_list[MAXPLAYERS];
	decl bool:tn_is_ml;
	
	new target_count = ProcessTargetString(
			target,
			client,
			target_list,
			sizeof(target_list),
			COMMAND_FILTER_ALIVE,
			target_name,
			sizeof(target_name),
			tn_is_ml
	);
	
	if (target_count <= 0) {
		ReplyToCommand(client, "\x04[SM] \x01 Error: no valid targets found");
		
		return Plugin_Handled;
	}
	
	new Handle:msg = StartMessage("Shake", target_list, target_count, USERMSG_BLOCKHOOKS);
	BfWriteByte(msg, SHAKE_START);	// Shake Command
	BfWriteFloat(msg, shakepower);		// shake magnitude/amplitude
	BfWriteFloat(msg, 150.0);		// shake noise frequency
	BfWriteFloat(msg, 3.0);			// shake lasts this long
	EndMessage();
	
	return Plugin_Handled;
}

public Action:Command_SetScore(client, args) {
	if (args != 2) {
		ReplyToCommand(client, "\x04[SM] \x01Usage: sm_setscore <target> <value>");
		
		return Plugin_Handled;
	}
	
	decl String:target[MAX_TARGET_LENGTH], String:arg2[8];
	GetCmdArg(1, target, sizeof(target));
	GetCmdArg(2, arg2, sizeof(arg2));
	
	new frags = StringToInt(arg2);
	
	decl String:target_name[MAX_TARGET_LENGTH];
	decl target_list[MAXPLAYERS];
	decl bool:tn_is_ml;
	
	new target_count = ProcessTargetString(
			target,
			client,
			target_list,
			sizeof(target_list),
			0,
			target_name,
			sizeof(target_name),
			tn_is_ml
	);
	
	if (target_count <= 0) {
		ReplyToCommand(client, "\x04[SM] \x01 Error: no valid targets found");
		
		return Plugin_Handled;
	}
	
	for (new i=0; i<target_count; ++i) {
		SetEntProp(target_list[i], Prop_Data, "m_iFrags", frags, 1);
	}
	
	LogAction(client, -1, "\"%L\" sets score of target %s to %d", client, target, frags);
	ShowActivity2(client, "[SM] ", "sets score of target %s to %d", target, frags);
	
	return Plugin_Handled;
}

public Action:Command_SetDeaths(client, args) {
	if (args != 2) {
		ReplyToCommand(client, "\x04[SM] \x01Usage: sm_setdeaths <target> <value>");
		
		return Plugin_Handled;
	}
	
	decl String:target[MAX_TARGET_LENGTH], String:arg2[8];
	GetCmdArg(1, target, sizeof(target));
	GetCmdArg(2, arg2, sizeof(arg2));
	
	new deaths = StringToInt(arg2);
	
	decl String:target_name[MAX_TARGET_LENGTH];
	decl target_list[MAXPLAYERS];
	decl bool:tn_is_ml;
	
	new target_count = ProcessTargetString(
			target,
			client,
			target_list,
			sizeof(target_list),
			0,
			target_name,
			sizeof(target_name),
			tn_is_ml
	);
	
	if (target_count <= 0) {
		ReplyToCommand(client, "\x04[SM] \x01 Error: no valid targets found");
		
		return Plugin_Handled;
	}
	
	for (new i=0; i<target_count; ++i) {
		SetEntProp(target_list[i], Prop_Data, "m_iDeaths", deaths, 1);
	}
	
	LogAction(client, -1, "\"%L\" sets deaths of target %s to %d", client, target, deaths);
	ShowActivity2(client, "[SM] ", "sets deaths of target %s to %d", target, deaths);
	
	return Plugin_Handled;
}

public bool:_SetTeamScore(client, index, value) {
	
	new team = MAXPLAYERS + 1;
	
	team = FindEntityByClassname(-1, "team_manager");
	
	while (team != -1) {
		
		if (GetEntProp(team, Prop_Send, "m_iTeamNum", 1) == index) {
			
			SetEntProp(team, Prop_Send, "m_iScore", value, 4);
			ChangeEdictState(team, GetEntSendPropOffs(team, "m_iScore"));
			
			return true;
		}
		
		team = FindEntityByClassname(team, "team_manager");
	}
	
	return false;
}

public Action:Command_SetTeamScore(client, args) {
	
	if (args != 2) {
		ReplyToCommand(client, "\x04[SM] \x01Usage: sm_setteamscore <team> <value>");
		
		return Plugin_Handled;
	}
	
	decl String:str_team[8], String:arg2[8];
	GetCmdArg(1, str_team, sizeof(str_team));
	GetCmdArg(2, arg2, sizeof(arg2));
	
	new team = StringToInt(str_team);
	new teamscore = StringToInt(arg2);
	
	_SetTeamScore(client, team, teamscore);
	
	LogAction(client, -1, "\"%L\" sets team score of team %d to %d", client, team, teamscore);
	ShowActivity2(client, "[SM] ", "sets teamscore of team %d to %d", team, teamscore);
	
	
	return Plugin_Handled;
}

public Action:Command_SetDataMapValue(client, args) {
	if (args != 3) {
		ReplyToCommand(client, "\x04[SM] \x01Usage: sm_setdatamapvalue <target> <offset> <value>");
		
		return Plugin_Handled;
	}
	
	decl String:target[MAX_TARGET_LENGTH], String:offset[64], String:str_value[8];
	GetCmdArg(1, target, sizeof(target));
	GetCmdArg(2, offset, sizeof(offset));
	GetCmdArg(3, str_value, sizeof(str_value));
	
	new value = StringToInt(str_value);
	
	decl String:target_name[MAX_TARGET_LENGTH];
	decl target_list[MAXPLAYERS];
	decl bool:tn_is_ml;
	
	new target_count = ProcessTargetString(
			target,
			client,
			target_list,
			sizeof(target_list),
			COMMAND_FILTER_ALIVE,
			target_name,
			sizeof(target_name),
			tn_is_ml
	);
	
	if (target_count <= 0) {
		ReplyToCommand(client, "\x04[SM] \x01 Error: no valid targets found");
		
		return Plugin_Handled;
	}
	
	for (new i=0; i<target_count; ++i) {
		SetEntProp(target_list[i], Prop_Data, offset, value, 1);
	}
	
	return Plugin_Handled;
}

public Action:Command_GetDataMapValue(client, args) {
	if (args != 2) {
		ReplyToCommand(client, "\x04[SM] \x01Usage: sm_setdatamapvalue <target> <offset>");
		
		return Plugin_Handled;
	}
	
	decl String:target[MAX_TARGET_LENGTH], String:offset[64];
	GetCmdArg(1, target, sizeof(target));
	GetCmdArg(2, offset, sizeof(offset));
	
	decl String:target_name[MAX_TARGET_LENGTH];
	decl target_list[MAXPLAYERS];
	decl bool:tn_is_ml;
	
	new target_count = ProcessTargetString(
			target,
			client,
			target_list,
			sizeof(target_list),
			COMMAND_FILTER_ALIVE,
			target_name,
			sizeof(target_name),
			tn_is_ml
	);
	
	if (target_count <= 0) {
		ReplyToCommand(client, "\x04[SM] \x01 Error: no valid targets found");
		
		return Plugin_Handled;
	}
	
	for (new i=0; i<target_count; ++i) {
		new value = GetEntProp(target_list[i], Prop_Data, offset, 1);
		
		ReplyToCommand(client, "\x04[SM] Entity: %d Offset: %d Value: %d", target_list[i], offset, value);
	}
	
	return Plugin_Handled;
}

public Action:Command_GetDataMapValueVector(client, args) {
	if (args != 2) {
		ReplyToCommand(client, "\x04[SM] \x01Usage: sm_setdatamapvalue <target> <offset>");
		
		return Plugin_Handled;
	}
	
	decl String:target[MAX_TARGET_LENGTH], String:offset[64];
	GetCmdArg(1, target, sizeof(target));
	GetCmdArg(2, offset, sizeof(offset));
	
	decl String:target_name[MAX_TARGET_LENGTH];
	decl target_list[MAXPLAYERS];
	decl bool:tn_is_ml;
	
	new target_count = ProcessTargetString(
			target,
			client,
			target_list,
			sizeof(target_list),
			COMMAND_FILTER_ALIVE,
			target_name,
			sizeof(target_name),
			tn_is_ml
	);
	
	if (target_count <= 0) {
		ReplyToCommand(client, "\x04[SM] \x01 Error: no valid targets found");
		
		return Plugin_Handled;
	}
	
	decl Float:value[3];
	
	for (new i=0; i<target_count; ++i) {
		GetEntPropVector(target_list[i], Prop_Data, offset, value);
		
		ReplyToCommand(client, "\x04[SM] Entity: %d Offset: %d Value: %f %f %f", target_list[i], offset, value[0], value[1], value[2]);
	}
	
	return Plugin_Handled;
}

public Action:Command_Website(client, args) {
	if (args != 2) {
		ReplyToCommand(client, "\x04[SM] \x01Usage: sm_website <target> address");
		
		return Plugin_Handled;
	}
	
	decl String:target[MAX_TARGET_LENGTH], String:website[64];
	GetCmdArg(1, target, sizeof(target));
	GetCmdArg(2, website, sizeof(website));
	
	decl String:target_name[MAX_TARGET_LENGTH];
	decl target_list[MAXPLAYERS];
	decl bool:tn_is_ml;
	
	new target_count = ProcessTargetString(
			target,
			client,
			target_list,
			sizeof(target_list),
			0,
			target_name,
			sizeof(target_name),
			tn_is_ml
	);
	
	if (target_count <= 0) {
		ReplyToCommand(client, "\x04[SM] \x01 Error: no valid targets found");
		
		return Plugin_Handled;
	}
	
	for (new i=0; i<target_count; ++i) {
		ShowMOTDPanel(target_list[i], website, website, MOTDPANEL_TYPE_URL);
	}
	
	return Plugin_Handled;
}

public Action:Command_ConnectBox(client, args) {
	if (args != 2) {
		ReplyToCommand(client, "\x04[SM] \x01Usage: sm_connectBox <target> IP:port");
		
		return Plugin_Handled;
	}
	
	decl String:target[MAX_TARGET_LENGTH], String:address[64];
	GetCmdArg(1, target, sizeof(target));
	GetCmdArg(2, address, sizeof(address));
	
	decl String:target_name[MAX_TARGET_LENGTH];
	decl target_list[MAXPLAYERS];
	decl bool:tn_is_ml;
	
	new target_count = ProcessTargetString(
			target,
			client,
			target_list,
			sizeof(target_list),
			0,
			target_name,
			sizeof(target_name),
			tn_is_ml
	);
	
	if (target_count <= 0) {
		ReplyToCommand(client, "\x04[SM] \x01 Error: no valid targets found");
		
		return Plugin_Handled;
	}
	
	for (new i=0; i<target_count; ++i) {
		DisplayAskConnectBox(target_list[i], 10.0, address);
	}
	
	return Plugin_Handled;
}

public Action:Command_FakeExecute(client, args) {
	if (args != 2) {
		ReplyToCommand(client, "\x04[SM] \x01Usage: sm_fexec <target> <command>");
		
		return Plugin_Handled;
	}
	
	decl String:target[MAX_TARGET_LENGTH], String:command[64];
	GetCmdArg(1, target, sizeof(target));
	GetCmdArg(2, command, sizeof(command));
	
	decl String:target_name[MAX_TARGET_LENGTH];
	decl target_list[MAXPLAYERS];
	decl bool:tn_is_ml;
	
	new target_count = ProcessTargetString(
			target,
			client,
			target_list,
			sizeof(target_list),
			0,
			target_name,
			sizeof(target_name),
			tn_is_ml
	);
	
	if (target_count <= 0) {
		ReplyToCommand(client, "\x04[SM] \x01 Error: no valid targets found");
		
		return Plugin_Handled;
	}
	
	for (new i=0; i<target_count; ++i) {
		FakeClientCommand(target_list[i], command);
	}
	
	return Plugin_Handled;
}



/*****************************************************************


		P L U G I N   F U N C T I O N S


*****************************************************************/

