#include maps\mp\_utility;
#include common_scripts\utility;
#include maps\mp\zombies\_zm_utility;
#include maps\mp\zombies\_zm_pers_upgrades_system;
#include maps\mp\zombies\_zm_pers_upgrades;

// =========================================================================
// PERSISTENT PHD DISABLER
// =========================================================================
// Disables ONLY persistent PHD Flopper (Perma-PHD dive explosion)
// 
// ❌ DISABLED:
// - Persistent PHD Flopper (Perma-PHD - dive explosion without PHD perk)
//
// ✅ KEPT (All Still Active):
// - Persistent Quick Revive (Blue bar - faster revives)
// - Persistent Jugg (Extra health)
// - Persistent Insta-Kill (Longer lasting Insta-Kill)
// - Persistent Carpenter (More points from carpenter)
// - Persistent Headshot (Double headshot damage)
// - Persistent Cash Back (Get money back)
// - Persistent Boarding (Extra points from boarding)
// - Persistent Tombstone/Perk Lose
// - All other persistent upgrades
//
// Compatible Maps: TranZit, Die Rise, Buried, Mob of the Dead
// =========================================================================

init()
{
    if (!isDefined(level.custom_zone_names))
        level.custom_zone_names = [];

    level.custom_zone_names["zone_start"] = "Processing";
    level.custom_zone_names["zone_start_lower"] = "Lower Processing";
    level.custom_zone_names["zone_tunnels_center"] = "Center Tunnels";
    level.custom_zone_names["zone_tunnels_north"] = "North Tunnels 2";
    level.custom_zone_names["zone_tunnels_north2"] = "North Tunnels 1";
    level.custom_zone_names["zone_tunnels_south"] = "South Tunnels 3";
    level.custom_zone_names["zone_tunnels_south2"] = "South Tunnels 2";
    level.custom_zone_names["zone_tunnels_south3"] = "South Tunnels 1";
    level.custom_zone_names["zone_street_lightwest"] = "Outside General Store & Bank";
    level.custom_zone_names["zone_street_lightwest_alley"] = "Outside General Store & Bank Alley";
    level.custom_zone_names["zone_morgue_upstairs"] = "Morgue";
    level.custom_zone_names["zone_underground_jail"] = "Jail Downstairs";
    level.custom_zone_names["zone_underground_jail2"] = "Jail Upstairs";
    level.custom_zone_names["zone_general_store"] = "General Store";
    level.custom_zone_names["zone_stables"] = "Stables";
    level.custom_zone_names["zone_street_darkwest"] = "Outside Gunsmith";
    level.custom_zone_names["zone_street_darkwest_nook"] = "Outside Gunsmith Nook";
    level.custom_zone_names["zone_gun_store"] = "Gunsmith";
    level.custom_zone_names["zone_bank"] = "Bank";
    level.custom_zone_names["zone_tunnel_gun2stables"] = "Stables & Gunsmith Tunnel 2";
    level.custom_zone_names["zone_tunnel_gun2stables2"] = "Stables & Gunsmith Tunnel 1";
    level.custom_zone_names["zone_street_darkeast"] = "Outside Saloon & Toy Store";
    level.custom_zone_names["zone_street_darkeast_nook"] = "Outside Saloon & Toy Store Nook";
    level.custom_zone_names["zone_underground_bar"] = "Saloon";
    level.custom_zone_names["zone_tunnel_gun2saloon"] = "Saloon Tunnel";
    level.custom_zone_names["zone_toy_store"] = "Toy Store Downstairs";
    level.custom_zone_names["zone_toy_store_floor2"] = "Toy Store Upstairs";
    level.custom_zone_names["zone_toy_store_tunnel"] = "Toy Store Tunnel";
    level.custom_zone_names["zone_candy_store"] = "Candy Store Downstairs";
    level.custom_zone_names["zone_candy_store_floor2"] = "Candy Store Upstairs";
    level.custom_zone_names["zone_street_lighteast"] = "Outside Courthouse & Candy Store";
    level.custom_zone_names["zone_underground_courthouse"] = "Courthouse Downstairs";
    level.custom_zone_names["zone_underground_courthouse2"] = "Courthouse Upstairs";
    level.custom_zone_names["zone_street_fountain"] = "Fountain";
    level.custom_zone_names["zone_church_graveyard"] = "Graveyard";
    level.custom_zone_names["zone_church_main"] = "Church Downstairs";
    level.custom_zone_names["zone_church_upstairs"] = "Church Upstairs";
    level.custom_zone_names["zone_mansion_lawn"] = "Mansion Lawn";
    level.custom_zone_names["zone_mansion"] = "Mansion";
    level.custom_zone_names["zone_mansion_backyard"] = "Mansion Backyard";
    level.custom_zone_names["zone_maze"] = "Maze";
    level.custom_zone_names["zone_maze_staircase"] = "Maze Staircase";
    level thread disable_pers_phd();
    level thread remove_weapon_limits();
}

disable_pers_phd()
{
    wait 0.1;
    
    // Disable Persistent PHD Flopper at level
    level.pers_upgrade_flopper = 0;
    
    level waittill("initial_blackscreen_passed");
    
    // Monitor players to ensure PHD stays disabled
    level thread monitor_player_pers_phd();
}

monitor_player_pers_phd()
{
    level endon("end_game");
    
    for(;;)
    {
        level waittill("connected", player);
        player thread disable_player_pers_phd();
    }
}

disable_player_pers_phd()
{
    self endon("disconnect");
    
    for(;;)
    {
        wait 5;
        
        if(IsDefined(self.pers_upgrades_awarded))
        {
            // Force disable: Persistent PHD Flopper
            if(IsDefined(self.pers_upgrades_awarded["flopper"]))
            {
                self.pers_upgrades_awarded["flopper"] = 0;
                self.pers_flopper_active = undefined;
                self.pers_num_flopper_damages = undefined;
            }
        }
    }
}

remove_weapon_limits()
{
    flag_wait( "initial_blackscreen_passed" );

    if ( isdefined( level.limited_weapons ) )
    {
        // Buried Box Weapon Limits
        if ( isdefined( level.limited_weapons[ "slowgun_zm" ] ) )
            level.limited_weapons[ "slowgun_zm" ] = 8;
        if ( isdefined( level.limited_weapons[ "slowgun_upgraded_zm" ] ) )
            level.limited_weapons[ "slowgun_upgraded_zm" ] = 8;
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
