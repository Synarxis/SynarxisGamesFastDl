#include maps\mp\_utility;
#include common_scripts\utility;
#include maps\mp\zombies\_zm_utility;

init()
{
    level thread remove_weapon_limits();
}

remove_weapon_limits()
{
    flag_wait( "initial_blackscreen_passed" );

    if ( isdefined( level.limited_weapons ) )
    {
        // Nuketown Box Weapon Limits
        if ( isdefined( level.limited_weapons[ "knife_ballistic_zm" ] ) )
            level.limited_weapons[ "knife_ballistic_zm" ] = 8;
        if ( isdefined( level.limited_weapons[ "knife_ballistic_upgraded_zm" ] ) )
            level.limited_weapons[ "knife_ballistic_upgraded_zm" ] = 8;
        if ( isdefined( level.limited_weapons[ "raygun_mark2_zm" ] ) )
            level.limited_weapons[ "raygun_mark2_zm" ] = 8;
        if ( isdefined( level.limited_weapons[ "raygun_mark2_upgraded_zm" ] ) )
            level.limited_weapons[ "raygun_mark2_upgraded_zm" ] = 8;
    }
}
