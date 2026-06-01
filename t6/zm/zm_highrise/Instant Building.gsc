#include common_scripts\utility;
#include maps\mp\_utility;
#include maps\mp\zombies\_zm_utility;
#include maps\mp\gametypes_zm\_hud_util;
#include maps\mp\zombies\_zm_laststand;
#include maps\mp\zombies\_zm_equipment;
#include maps\mp\zombies\_zm_unitrigger;
#include maps\mp\zombies\_zm_stats;
#include maps\mp\zombies\_zm_weapons;
#include maps\mp\zombies\_zm_buildables;

init()
{
level thread onplayerconnect();

replaceFunc( maps\mp\zombies\_zm_buildables::buildable_use_hold_think_internal, ::buildable_use_hold_think_internal );

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

buildable_use_hold_think_internal( player, bind_stub )
{
    if ( !isdefined( bind_stub ) )
        bind_stub = self.stub;

    wait 0.01;

    if ( !isdefined( self ) )
    {
        self notify( "build_failed" );

        if ( isdefined( player.buildableaudio ) )
        {
            player.buildableaudio delete();
            player.buildableaudio = undefined;
        }

        return;
    }

    self.usetime = 1; // Oder 0, aber 1 ist safer

    self.build_time = self.usetime;
    self.build_start_time = gettime();
    build_time = self.build_time;
    build_start_time = self.build_start_time;

    player disable_player_move_states( 1 );
    player increment_is_drinking();

    orgweapon = player getcurrentweapon();
    build_weapon = "zombie_builder_zm";

    if ( isdefined( bind_stub.build_weapon ) )
        build_weapon = bind_stub.build_weapon;

    player giveweapon( build_weapon );
    player switchtoweapon( build_weapon );

    slot = bind_stub.buildablestruct.buildable_slot;

    bind_stub.buildablezone buildable_set_piece_building( player player_get_buildable_piece( slot ) );


    if ( isdefined( level.buildable_build_custom_func ) )
        player thread [[ level.buildable_build_custom_func ]]( self.stub );

    wait 0.05;

    player notify( "buildable_progress_end" );
    player maps\mp\zombies\_zm_weapons::switch_back_primary_weapon( orgweapon );
    player takeweapon( "zombie_builder_zm" );

    if ( isdefined( player.is_drinking ) && player.is_drinking )
        player decrement_is_drinking();

    player enable_player_move_states();

    if ( isdefined( self ) )
    {
        buildable_clear_piece_building( player player_get_buildable_piece( slot ) );
        self notify( "build_succeed" );
    }
    else
    {
        if ( isdefined( player.buildableaudio ) )
        {
            player.buildableaudio delete();
            player.buildableaudio = undefined;
        }

        buildable_clear_piece_building( player player_get_buildable_piece( slot ) );
        self notify( "build_failed" );
    }
}
