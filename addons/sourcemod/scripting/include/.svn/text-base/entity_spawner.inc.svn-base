/** Double-include prevention */
#if defined _entity_spawner_included_
  #endinput
#endif
#define _entity_spawner_included_


public SharedPlugin:__pl_entity_spawner = 
{
	name = "Entity Spawner",
	file = "entity_spawner.smx",
	required = 0
};


public __pl_entity_spawner_SetNTVOptional()
{
	MarkNativeAsOptional("ES_SpawnObject");
}


/**
 * Adds two numbers together.
 *
 * @param client    client index.
 * @param dataKV    the KeyValues for spawning.
 * @return        The float value of the integer and float added together.
 */
native ES_SpawnObject(client,Handle:dataKV);