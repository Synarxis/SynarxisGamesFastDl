#include common_scripts\utility;
#include maps\mp\_utility;
#include maps\mp\zombies\_zm_utility;
#include maps\mp\gametypes_zm\_hud_util;
#include maps\mp\zombies\_zm_laststand;
#include maps\mp\zombies\_zm_equipment;
#include maps\mp\zombies\_zm_unitrigger;
#include maps\mp\zombies\_zm_stats;
#include maps\mp\zombies\_zm_weapons;
#include maps\mp\zombies\_zm_craftables;

init()
{
level thread onplayerconnect();
replaceFunc( maps\mp\zombies\_zm_craftables::craftable_use_hold_think_internal, ::craftable_use_hold_think_internal );

}

onplayerconnect()
{
	for(;;)
	{
	level waittill( "connected", player );
	player thread onplayerspawned();	
	}
}

onplayerspawned()
{
	self endon( "disconnect" );
	for(;;)
	{
	self waittill( "spawned_player" );
	}
}

craftable_use_hold_think_internal( player )
{
    wait 0.01;

    if ( !isdefined( self ) )
    {
        self notify( "craft_failed" );

        if ( isdefined( player.craftableaudio ) )
        {
            player.craftableaudio delete();
            player.craftableaudio = undefined;
        }

        return;
    }

    self.usetime = 0; 
    self.craft_time = 0;
    self.craft_start_time = gettime();

    orgweapon = player getcurrentweapon();
    player giveweapon( "zombie_builder_zm" );
    player switchtoweapon( "zombie_builder_zm" );

    self.stub.craftablespawn craftable_set_piece_crafting( player.current_craftable_piece );

    if ( isdefined( level.craftable_craft_custom_func ) )
        player thread [[ level.craftable_craft_custom_func ]]( self.stub );

    player notify( "craftable_progress_end" );
    player maps\mp\zombies\_zm_weapons::switch_back_primary_weapon( orgweapon );
    player takeweapon( "zombie_builder_zm" );

    self.stub.craftablespawn craftable_clear_piece_crafting( player.current_craftable_piece );
    self notify( "craft_succeed" );
}

craftable_set_piece_crafting( piecespawn_check )
{
    craftablespawn_check = get_actual_craftablespawn();

    foreach ( piecespawn in craftablespawn_check.a_piecespawns )
    {
        if ( isdefined( piecespawn_check ) )
        {
            if ( piecespawn.piecename == piecespawn_check.piecename && piecespawn.craftablename == piecespawn_check.craftablename )
                piecespawn.crafting = 1;
        }

        if ( isdefined( piecespawn.is_shared ) && piecespawn.is_shared && ( isdefined( piecespawn.in_shared_inventory ) && piecespawn.in_shared_inventory ) )
            piecespawn.crafting = 1;
    }
}

craftable_clear_piece_crafting( piecespawn_check )
{
    if ( isdefined( piecespawn_check ) )
        piecespawn_check.crafting = 0;

    craftablespawn_check = get_actual_craftablespawn();

    foreach ( piecespawn in craftablespawn_check.a_piecespawns )
    {
        if ( isdefined( piecespawn.is_shared ) && piecespawn.is_shared && ( isdefined( piecespawn.in_shared_inventory ) && piecespawn.in_shared_inventory ) )
            piecespawn.crafting = 0;
    }
}

get_actual_craftablespawn()
{
    if ( self.craftable_name == "open_table" && self.stub.n_open_craftable_choice != -1 && isdefined( self.stub.a_uts_open_craftables_available[self.stub.n_open_craftable_choice].craftablespawn ) )
        return self.stub.a_uts_open_craftables_available[self.stub.n_open_craftable_choice].craftablespawn;
    else
        return self;
}