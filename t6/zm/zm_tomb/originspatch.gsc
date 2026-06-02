#include maps\mp\zombies\_zm_utility;
#include maps\mp\zombies\_zm_weapons;
#include maps\mp\gametypes_zm\_weapons; 
#include maps\mp\zombies\_zm_weap_claymore;
#include maps\mp\zombies\_zm_audio; 
#include maps\mp\zm_tomb_dig;
#include common_scripts\utility;
#include maps\mp\_utility;

init()
{
    if (!isDefined(level.custom_zone_names))
        level.custom_zone_names = [];

    level.custom_zone_names["zone_start"] = "Lower Laboratory";
    level.custom_zone_names["zone_start_a"] = "Upper Laboratory";
    level.custom_zone_names["zone_start_b"] = "Generator 1";
    level.custom_zone_names["zone_bunker_1a"] = "Generator 3 Bunker 1";
    level.custom_zone_names["zone_fire_stairs"] = "Fire Tunnel";
    level.custom_zone_names["zone_bunker_1"] = "Generator 3 Bunker 2";
    level.custom_zone_names["zone_bunker_3a"] = "Generator 3";
    level.custom_zone_names["zone_bunker_3b"] = "Generator 3 Bunker 3";
    level.custom_zone_names["zone_bunker_2a"] = "Generator 2 Bunker 1";
    level.custom_zone_names["zone_bunker_2"] = "Generator 2 Bunker 2";
    level.custom_zone_names["zone_bunker_4a"] = "Generator 2";
    level.custom_zone_names["zone_bunker_4b"] = "Generator 2 Bunker 3";
    level.custom_zone_names["zone_bunker_4c"] = "Tank Station";
    level.custom_zone_names["zone_bunker_4d"] = "Above Tank Station";
    level.custom_zone_names["zone_bunker_tank_c"] = "Generator 2 Tank Route 1";
    level.custom_zone_names["zone_bunker_tank_c1"] = "Generator 2 Tank Route 2";
    level.custom_zone_names["zone_bunker_4e"] = "Generator 2 Tank Route 3";
    level.custom_zone_names["zone_bunker_tank_d"] = "Generator 2 Tank Route 4";
    level.custom_zone_names["zone_bunker_tank_d1"] = "Generator 2 Tank Route 5";
    level.custom_zone_names["zone_bunker_4f"] = "zone_bunker_4f";
    level.custom_zone_names["zone_bunker_5a"] = "Workshop Downstairs";
    level.custom_zone_names["zone_bunker_5b"] = "Workshop Upstairs";
    level.custom_zone_names["zone_nml_2a"] = "No Man's Land Walkway";
    level.custom_zone_names["zone_nml_2"] = "No Man's Land Entrance";
    level.custom_zone_names["zone_bunker_tank_e"] = "Generator 5 Tank Route 1";
    level.custom_zone_names["zone_bunker_tank_e1"] = "Generator 5 Tank Route 2";
    level.custom_zone_names["zone_bunker_tank_e2"] = "zone_bunker_tank_e2";
    level.custom_zone_names["zone_bunker_tank_f"] = "Generator 5 Tank Route 3";
    level.custom_zone_names["zone_nml_1"] = "Generator 5 Tank Route 4";
    level.custom_zone_names["zone_nml_4"] = "Generator 5 Tank Route 5";
    level.custom_zone_names["zone_nml_0"] = "Generator 5 Left Footstep";
    level.custom_zone_names["zone_nml_5"] = "Generator 5 Right Footstep Walkway";
    level.custom_zone_names["zone_nml_farm"] = "Generator 5";
    level.custom_zone_names["zone_nml_celllar"] = "Generator 5 Cellar";
    level.custom_zone_names["zone_bolt_stairs"] = "Lightning Tunnel";
    level.custom_zone_names["zone_nml_3"] = "No Man's Land 1st Right Footstep";
    level.custom_zone_names["zone_nml_2b"] = "No Man's Land Stairs";
    level.custom_zone_names["zone_nml_6"] = "No Man's Land Left Footstep";
    level.custom_zone_names["zone_nml_8"] = "No Man's Land 2nd Right Footstep";
    level.custom_zone_names["zone_nml_10a"] = "Generator 4 Tank Route 1";
    level.custom_zone_names["zone_nml_10"] = "Generator 4 Tank Route 2";
    level.custom_zone_names["zone_nml_7"] = "Generator 4 Tank Route 3";
    level.custom_zone_names["zone_bunker_tank_a"] = "Generator 4 Tank Route 4";
    level.custom_zone_names["zone_bunker_tank_a1"] = "Generator 4 Tank Route 5";
    level.custom_zone_names["zone_bunker_tank_a2"] = "zone_bunker_tank_a2";
    level.custom_zone_names["zone_bunker_tank_b"] = "Generator 4 Tank Route 6";
    level.custom_zone_names["zone_nml_9"] = "Generator 4 Left Footstep";
    level.custom_zone_names["zone_air_stairs"] = "Wind Tunnel";
    level.custom_zone_names["zone_nml_11"] = "Generator 4";
    level.custom_zone_names["zone_nml_12"] = "Generator 4 Right Footstep";
    level.custom_zone_names["zone_nml_16"] = "Excavation Site Front Path";
    level.custom_zone_names["zone_nml_17"] = "Excavation Site Back Path";
    level.custom_zone_names["zone_nml_18"] = "Excavation Site Level 3";
    level.custom_zone_names["zone_nml_19"] = "Excavation Site Level 2";
    level.custom_zone_names["ug_bottom_zone"] = "Excavation Site Level 1";
    level.custom_zone_names["zone_nml_13"] = "Generator 5 To Generator 6 Path";
    level.custom_zone_names["zone_nml_14"] = "Generator 4 To Generator 6 Path";
    level.custom_zone_names["zone_nml_15"] = "Generator 6 Entrance";
    level.custom_zone_names["zone_village_0"] = "Generator 6 Left Footstep";
    level.custom_zone_names["zone_village_5"] = "Generator 6 Tank Route 1";
    level.custom_zone_names["zone_village_5a"] = "Generator 6 Tank Route 2";
    level.custom_zone_names["zone_village_5b"] = "Generator 6 Tank Route 3";
    level.custom_zone_names["zone_village_1"] = "Generator 6 Tank Route 4";
    level.custom_zone_names["zone_village_4b"] = "Generator 6 Tank Route 5";
    level.custom_zone_names["zone_village_4a"] = "Generator 6 Tank Route 6";
    level.custom_zone_names["zone_village_4"] = "Generator 6 Tank Route 7";
    level.custom_zone_names["zone_village_2"] = "Church";
    level.custom_zone_names["zone_village_3"] = "Generator 6 Right Footstep";
    level.custom_zone_names["zone_village_3a"] = "Generator 6";
    level.custom_zone_names["zone_ice_stairs"] = "Ice Tunnel";
    level.custom_zone_names["zone_bunker_6"] = "Above Generator 3 Bunker";
    level.custom_zone_names["zone_nml_20"] = "Above No Man's Land";
    level.custom_zone_names["zone_village_6"] = "Behind Church";
    level.custom_zone_names["zone_chamber_0"] = "The Crazy Place Lightning Chamber";
    level.custom_zone_names["zone_chamber_1"] = "The Crazy Place Lightning & Ice";
    level.custom_zone_names["zone_chamber_2"] = "The Crazy Place Ice Chamber";
    level.custom_zone_names["zone_chamber_3"] = "The Crazy Place Fire & Lightning";
    level.custom_zone_names["zone_chamber_4"] = "The Crazy Place Center";
    level.custom_zone_names["zone_chamber_5"] = "The Crazy Place Ice & Wind";
    level.custom_zone_names["zone_chamber_6"] = "The Crazy Place Fire Chamber";
    level.custom_zone_names["zone_chamber_7"] = "The Crazy Place Wind & Fire";
    level.custom_zone_names["zone_chamber_8"] = "The Crazy Place Wind Chamber";
    level.custom_zone_names["zone_robot_head"] = "Robot's Head";
    replaceFunc( maps\mp\zm_tomb_dig::swap_weapon, ::custom_swap_weapon );
    precachemodel( "p6_zm_tm_orb_fire" );
    precachemodel( "p6_zm_tm_orb_ice" );
    level thread bank_tomb_setup();
    level thread remove_weapon_limits();
    replaceFunc( maps\mp\zm_tomb_utility::player_slow_movement_speed_monitor, ::custom_player_slow_movement_speed_monitor );

    // Prevent Origins from deleting door brushes after they open — hide instead of delete
    // so our Sprint+Melee close system can show() and moveto() them back
    replaceFunc( maps\mp\zm_tomb_utility::bunker_door_clean_up, ::custom_bunker_door_clean_up );
}

custom_bunker_door_clean_up()
{
    self waittill( "movedone" );
    self hide();     // Hide instead of delete — keeps the entity alive for closing
    self notsolid();
}

custom_swap_weapon( str_weapon, e_player )
{
    // Check if the dug-up weapon has a defined upgrade in the map's weapon list
    if ( IsDefined( level.zombie_weapons[str_weapon] ) && IsDefined( level.zombie_weapons[str_weapon].upgrade_name ) )
    {
        upgraded_weapon = level.zombie_weapons[str_weapon].upgrade_name;
        if ( e_player HasWeapon( upgraded_weapon ) )
        {
            e_player givemaxammo( upgraded_weapon );
            return;
        }
    }

    str_current_weapon = e_player getcurrentweapon();
    if ( str_weapon == "claymore_zm" ) 
    {
        if ( !e_player hasweapon( str_weapon ) ) 
        {
            e_player thread maps\mp\zombies\_zm_weap_claymore::show_claymore_hint( "claymore_purchased" );
            e_player thread maps\mp\zombies\_zm_weap_claymore::claymore_setup(); 
            e_player thread maps\mp\zombies\_zm_audio::create_and_play_dialog( "weapon_pickup", "grenade" ); 
        }
        else
        {
            e_player givemaxammo( str_weapon ); 
        }
        return;
    }
    if ( is_player_valid( e_player ) && !e_player.is_drinking && !is_placeable_mine( str_current_weapon ) && !is_equipment( str_current_weapon ) && level.revive_tool != str_current_weapon && str_current_weapon != "none" && !e_player hacker_active() ) 
    {
        if ( !e_player hasweapon( str_weapon ) ) 
        {
            e_player maps\mp\zm_tomb_dig::take_old_weapon_and_give_new( str_current_weapon, str_weapon );
            return;
        }
        else
        {
            e_player givemaxammo( str_weapon );
        }
    }
}

bank_tomb_setup()
{
    flag_wait( "initial_blackscreen_passed" );

    level.bank_deposit_max_amount = 250000;
    level.bank_deposit_ddl_increment_amount = 1000;
    level.bank_account_max = level.bank_deposit_max_amount / 100;
    level.bank_account_increment = int( level.bank_deposit_ddl_increment_amount / 100 );
    
    if ( !isdefined( level.ta_vaultfee ) )
        level.ta_vaultfee = 100;

    level.banking_map = "zm_transit";

    // Start monitors for Gen 2 (Deposit) and Gen 3 (Withdraw)
    level thread generator_orb_monitor( "generator_mid_trench", "p6_zm_tm_orb_ice", ( 140, 3982, -207 ), ( 0, -48, 0 ) );
    level thread generator_orb_monitor( "generator_tank_trench", "p6_zm_tm_orb_fire", ( 158, 3268, -169 ), ( 0, 128, 0 ) );

    deposit_spot = spawnstruct();
    deposit_spot.origin = ( 140, 3982, -170 );
    deposit_spot.angles = ( 0, -48, 0 );
    deposit_spot.script_length = 16;
    deposit_spot.targetname = "bank_deposit";

    withdraw_spot = spawnstruct();
    withdraw_spot.origin = ( 158, 3268, -169 );
    withdraw_spot.angles = ( 0, 128, 0 );
    withdraw_spot.script_length = 16;
    withdraw_spot.targetname = "bank_withdraw";

    level.bank_deposit_stub = deposit_spot bank_tomb_deposit_unitrigger();
    level.bank_withdraw_stub = withdraw_spot bank_tomb_withdraw_unitrigger();

    foreach ( player in level.players )
    {
        if ( !isdefined( player.account_value ) )
        {
            player.account_value = player maps\mp\zombies\_zm_stats::get_map_stat( "depositBox", "zm_transit" );
        }
        player thread player_bank_hud_think();
        player thread give_player_shovel();
    }
    level thread on_player_connect();
}

on_player_connect()
{
    level endon( "end_game" );
    while ( true )
    {
        level waittill( "connected", player );
        player.account_value = player maps\mp\zombies\_zm_stats::get_map_stat( "depositBox", "zm_transit" );
        player thread player_bank_hud_think();
        player thread give_player_shovel();
    }
}

is_generator_powered( zone_name )
{
    if ( isdefined( level.zone_capture ) && isdefined( level.zone_capture.zones ) && isdefined( level.zone_capture.zones[ zone_name ] ) )
    {
        zone = level.zone_capture.zones[ zone_name ];
        if ( zone ent_flag( "zone_initialized" ) )
        {
            return zone ent_flag( "player_controlled" );
        }
    }
    return false;
}

generator_orb_monitor( zone_name, model_name, origin, angles )
{
    level endon( "end_game" );
    
    orb_ent = undefined;
    
    while ( true )
    {
        powered = is_generator_powered( zone_name );
        
        if ( powered && !isdefined( orb_ent ) )
        {
            // Spawn the orb floating slightly above ground (z + 45)
            spawn_pos = origin + ( 0, 0, 45 );
            orb_ent = spawn( "script_model", spawn_pos );
            orb_ent.angles = angles;
            orb_ent setmodel( model_name );
            
            // Start animations
            orb_ent thread float_orb();
            orb_ent thread rotate_orb();
            
            // Refresh unitriggers visibility
            if ( isdefined( level.bank_deposit_stub ) )
                level.bank_deposit_stub maps\mp\zombies\_zm_unitrigger::run_visibility_function_for_all_triggers();
            if ( isdefined( level.bank_withdraw_stub ) )
                level.bank_withdraw_stub maps\mp\zombies\_zm_unitrigger::run_visibility_function_for_all_triggers();
        }
        else if ( !powered && isdefined( orb_ent ) )
        {
            orb_ent delete();
            orb_ent = undefined;
            
            // Refresh unitriggers visibility
            if ( isdefined( level.bank_deposit_stub ) )
                level.bank_deposit_stub maps\mp\zombies\_zm_unitrigger::run_visibility_function_for_all_triggers();
            if ( isdefined( level.bank_withdraw_stub ) )
                level.bank_withdraw_stub maps\mp\zombies\_zm_unitrigger::run_visibility_function_for_all_triggers();
        }
        
        wait 1.0;
    }
}

float_orb()
{
    self endon( "death" );
    while ( true )
    {
        self movez( 6, 1.2, 0.3, 0.3 );
        wait 1.2;
        self movez( -6, 1.2, 0.3, 0.3 );
        wait 1.2;
    }
}

rotate_orb()
{
    self endon( "death" );
    while ( true )
    {
        self rotateyaw( 360, 4.0 );
        wait 4.0;
    }
}

bank_tomb_deposit_unitrigger()
{
    return bank_tomb_create_unitrigger( "bank_deposit", ::trigger_tomb_deposit_update_prompt, ::trigger_tomb_deposit_think, 64 );
}

bank_tomb_withdraw_unitrigger()
{
    return bank_tomb_create_unitrigger( "bank_withdraw", ::trigger_tomb_withdraw_update_prompt, ::trigger_tomb_withdraw_think, 64 );
}

bank_tomb_create_unitrigger( name, prompt_fn, think_fn, override_radius )
{
    unitrigger_stub = spawnstruct();
    unitrigger_stub.origin = self.origin;
    unitrigger_stub.angles = self.angles;
    unitrigger_stub.script_angles = unitrigger_stub.angles;

    if ( isdefined( override_radius ) )
        unitrigger_stub.radius = override_radius;
    else
        unitrigger_stub.radius = 64;

    unitrigger_stub.script_height = 64;
    unitrigger_stub.script_unitrigger_type = "unitrigger_radius_use";

    unitrigger_stub.cursor_hint = "HINT_NOICON";
    unitrigger_stub.targetname = name;
    maps\mp\zombies\_zm_unitrigger::unitrigger_force_per_player_triggers( unitrigger_stub, 1 );
    unitrigger_stub.prompt_and_visibility_func = prompt_fn;
    maps\mp\zombies\_zm_unitrigger::register_static_unitrigger( unitrigger_stub, think_fn );
    return unitrigger_stub;
}

trigger_tomb_deposit_update_prompt( player )
{
    if ( !isdefined( player.account_value ) )
    {
        player.account_value = player maps\mp\zombies\_zm_stats::get_map_stat( "depositBox", "zm_transit" );
        if ( !isdefined( player.account_value ) )
            player.account_value = 0;
    }

    if ( !is_generator_powered( "generator_mid_trench" ) )
    {
        self sethintstring( "Generator 3 must be active" );
        return true;
    }

    if ( player.account_value >= level.bank_account_max )
    {
        self sethintstring( "Bank Account Full" );
        return true;
    }

    self sethintstring( &"ZOMBIE_BANK_DEPOSIT_PROMPT", level.bank_deposit_ddl_increment_amount );
    return true;
}

trigger_tomb_deposit_think()
{
    self endon( "kill_trigger" );

    while ( true )
    {
        self waittill( "trigger", player );

        if ( !is_player_valid( player ) )
            continue;

        if ( !is_generator_powered( "generator_mid_trench" ) )
            continue;

        if ( !isdefined( player.account_value ) )
        {
            player.account_value = player maps\mp\zombies\_zm_stats::get_map_stat( "depositBox", "zm_transit" );
            if ( !isdefined( player.account_value ) )
                player.account_value = 0;
        }

        if ( player.score >= level.bank_deposit_ddl_increment_amount && player.account_value < level.bank_account_max )
        {
            player playsoundtoplayer( "zmb_vault_bank_deposit", player );
            player.score = player.score - level.bank_deposit_ddl_increment_amount;
            player.account_value = player.account_value + level.bank_account_increment;
            player maps\mp\zombies\_zm_stats::set_map_stat( "depositBox", player.account_value, level.banking_map );

            if ( isdefined( level.custom_bank_deposit_vo ) )
                player thread [[ level.custom_bank_deposit_vo ]]();

            if ( player.account_value >= level.bank_account_max )
                self sethintstring( "" );
        }
    }
}

trigger_tomb_withdraw_update_prompt( player )
{
    if ( !isdefined( player.account_value ) )
    {
        player.account_value = player maps\mp\zombies\_zm_stats::get_map_stat( "depositBox", "zm_transit" );
        if ( !isdefined( player.account_value ) )
            player.account_value = 0;
    }

    if ( !is_generator_powered( "generator_tank_trench" ) )
    {
        self sethintstring( "Generator 2 must be active" );
        return true;
    }

    if ( player.account_value <= 0 )
    {
        self sethintstring( "" );
        return false;
    }

    self sethintstring( &"ZOMBIE_BANK_WITHDRAW_PROMPT", level.bank_deposit_ddl_increment_amount, level.ta_vaultfee );
    return true;
}

trigger_tomb_withdraw_think()
{
    self endon( "kill_trigger" );

    while ( true )
    {
        self waittill( "trigger", player );

        if ( !is_player_valid( player ) )
            continue;

        if ( !is_generator_powered( "generator_tank_trench" ) )
            continue;

        if ( !isdefined( player.account_value ) )
        {
            player.account_value = player maps\mp\zombies\_zm_stats::get_map_stat( "depositBox", "zm_transit" );
            if ( !isdefined( player.account_value ) )
                player.account_value = 0;
        }

        if ( player.account_value >= level.bank_account_increment )
        {
            player playsoundtoplayer( "zmb_vault_bank_withdraw", player );
            player.score = player.score + level.bank_deposit_ddl_increment_amount;
            level notify( "bank_withdrawal" );
            player.account_value = player.account_value - level.bank_account_increment;
            player maps\mp\zombies\_zm_stats::set_map_stat( "depositBox", player.account_value, level.banking_map );

            if ( isdefined( level.custom_bank_withdrawl_vo ) )
                player thread [[ level.custom_bank_withdrawl_vo ]]();

            player thread player_tomb_withdraw_fee();

            if ( player.account_value < level.bank_account_increment )
                self sethintstring( "" );
        }
    }
}

player_tomb_withdraw_fee()
{
    self endon( "disconnect" );
    wait_network_frame();
    self.score = self.score - level.ta_vaultfee;
}

player_bank_hud_think()
{
    self endon( "disconnect" );

    if ( !isdefined( self.account_value ) )
    {
        self.account_value = self maps\mp\zombies\_zm_stats::get_map_stat( "depositBox", "zm_transit" );
        if ( !isdefined( self.account_value ) )
            self.account_value = 0;
    }

    hud = newClientHudElem( self );
    hud.alignx = "center";
    hud.aligny = "middle";
    hud.horzalign = "center";
    hud.vertalign = "bottom";
    hud.y = -100;
    hud.foreground = 1;
    hud.hidewheninmenu = 1;
    hud.font = "default";
    hud.fontscale = 1.3;
    hud.alpha = 0;
    hud.color = ( 1, 1, 1 );
    hud.label = &"Account Balance: $";

    while ( true )
    {
        dist_dep = distance( self.origin, ( 140, 3982, -170 ) );
        dist_with = distance( self.origin, ( 158, 3268, -169 ) );

        show_hud = false;
        if ( dist_dep < 80 && is_generator_powered( "generator_mid_trench" ) )
        {
            show_hud = true;
        }
        else if ( dist_with < 80 && is_generator_powered( "generator_tank_trench" ) )
        {
            show_hud = true;
        }

        if ( show_hud )
        {
            hud.alpha = 1;
            hud setValue( self.account_value * 100 );
        }
        else
        {
            hud.alpha = 0;
        }

        wait 0.1;
    }
}

remove_weapon_limits()
{
    flag_wait( "initial_blackscreen_passed" );

    if ( isdefined( level.limited_weapons ) )
    {
        // Origins Box Weapon Limits
        if ( isdefined( level.limited_weapons[ "raygun_mark2_zm" ] ) )
            level.limited_weapons[ "raygun_mark2_zm" ] = 8;
        if ( isdefined( level.limited_weapons[ "raygun_mark2_upgraded_zm" ] ) )
            level.limited_weapons[ "raygun_mark2_upgraded_zm" ] = 8;
    }
}

give_player_shovel()
{
    self endon( "disconnect" );

    while ( !isdefined( self.dig_vars ) )
        wait 0.05;

    self.dig_vars[ "has_shovel" ] = 1;
    n_player = self getentitynumber() + 1;
    if ( n_player <= 4 )
    {
        level setclientfield( "shovel_player" + n_player, 1 );
    }
}

custom_player_slow_movement_speed_monitor()
{
    self endon( "disconnect" );
    n_movescale_delta_no_perk = 0.4 / 4.0;
    n_movescale_delta_staminup = 0.3 / 6.0;
    n_new_move_scale = 1.0;
    n_move_scale_delta = 1.0;
    self.n_move_scale = n_new_move_scale;
    while ( true )
    {
        is_player_slowed = 0;
        self.is_player_slowed = 0;
        foreach ( area in level.a_e_slow_areas )
        {
            if ( self istouching( area ) )
            {
                self setclientfieldtoplayer( "sndMudSlow", 1 );
                is_player_slowed = 1;
                self.is_player_slowed = 1;
                if ( !self hasperk( "specialty_longersprint" ) && !( isdefined( self.played_mud_vo ) && self.played_mud_vo ) && !( isdefined( self.dontspeak ) && self.dontspeak ) )
                    self thread maps\mp\zm_tomb_vo::struggle_mud_vo();
                if ( self hasperk( "specialty_longersprint" ) )
                {
                    n_new_move_scale = 1.0; 
                    n_move_scale_delta = n_movescale_delta_staminup;
                }
                else
                {
                    n_new_move_scale = 0.6;
                    n_move_scale_delta = n_movescale_delta_no_perk;
                }
                break;
            }
        }
        if ( !is_player_slowed )
        {
            self setclientfieldtoplayer( "sndMudSlow", 0 );
            self notify( "mud_slowdown_cleared" );
            n_new_move_scale = 1.0;
        }
        if ( self.n_move_scale != n_new_move_scale )
        {
            if ( self.n_move_scale > n_new_move_scale + n_move_scale_delta )
                self.n_move_scale = self.n_move_scale - n_move_scale_delta;
            else
                self.n_move_scale = n_new_move_scale;
            self setmovespeedscale( self.n_move_scale );
        }
        wait 0.1;
    }
}