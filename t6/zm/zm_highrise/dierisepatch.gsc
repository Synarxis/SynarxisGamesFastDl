#include maps\mp\_utility;
#include common_scripts\utility;
#include maps\mp\zombies\_zm_utility;

init()
{
    if (!isDefined(level.custom_zone_names))
        level.custom_zone_names = [];

    level.custom_zone_names["zone_green_start"] = "Green Highrise Level 3b";
    level.custom_zone_names["zone_green_escape_pod"] = "Escape Pod";
    level.custom_zone_names["zone_green_escape_pod_ground"] = "Escape Pod Shaft";
    level.custom_zone_names["zone_green_level1"] = "Green Highrise Level 3a";
    level.custom_zone_names["zone_green_level2a"] = "Green Highrise Level 2a";
    level.custom_zone_names["zone_green_level2b"] = "Green Highrise Level 2b";
    level.custom_zone_names["zone_green_level3a"] = "Green Highrise Restaurant";
    level.custom_zone_names["zone_green_level3b"] = "Green Highrise Level 1a";
    level.custom_zone_names["zone_green_level3c"] = "Green Highrise Level 1b";
    level.custom_zone_names["zone_green_level3d"] = "Green Highrise Behind Restaurant";
    level.custom_zone_names["zone_orange_level1"] = "Upper Orange Highrise Level 2";
    level.custom_zone_names["zone_orange_level2"] = "Upper Orange Highrise Level 1";
    level.custom_zone_names["zone_orange_elevator_shaft_top"] = "Elevator Shaft Level 3";
    level.custom_zone_names["zone_orange_elevator_shaft_middle_1"] = "Elevator Shaft Level 2";
    level.custom_zone_names["zone_orange_elevator_shaft_middle_2"] = "Elevator Shaft Level 1";
    level.custom_zone_names["zone_orange_elevator_shaft_bottom"] = "Elevator Shaft Bottom";
    level.custom_zone_names["zone_orange_level3a"] = "Lower Orange Highrise Level 1a";
    level.custom_zone_names["zone_orange_level3b"] = "Lower Orange Highrise Level 1b";
    level.custom_zone_names["zone_blue_level5"] = "Lower Blue Highrise Level 1";
    level.custom_zone_names["zone_blue_level4a"] = "Lower Blue Highrise Level 2a";
    level.custom_zone_names["zone_blue_level4b"] = "Lower Blue Highrise Level 2b";
    level.custom_zone_names["zone_blue_level4c"] = "Lower Blue Highrise Level 2c";
    level.custom_zone_names["zone_blue_level2a"] = "Upper Blue Highrise Level 1a";
    level.custom_zone_names["zone_blue_level2b"] = "Upper Blue Highrise Level 1b";
    level.custom_zone_names["zone_blue_level2c"] = "Upper Blue Highrise Level 1c";
    level.custom_zone_names["zone_blue_level2d"] = "Upper Blue Highrise Level 1d";
    level.custom_zone_names["zone_blue_level1a"] = "Upper Blue Highrise Level 2a";
    level.custom_zone_names["zone_blue_level1b"] = "Upper Blue Highrise Level 2b";
    level.custom_zone_names["zone_blue_level1c"] = "Upper Blue Highrise Level 2c";
    
    // Default fallback logic can be mapped per map directly if desired, but 
    // for exact 1:1, we can add a check in zonemgr or just let the notifier handle substring.
    // For now, these explicit keys are added.


	precacheshader( "zom_hud_icon_epod_key" );

	replaceFunc( maps\mp\zombies\_zm_weap_slipgun::add_slippery_spot, ::custom_add_slippery_spot );

	level thread on_player_connect();
	level thread elevator_call();
	level thread escape_pod_call();
	level thread remove_weapon_limits();
	level thread prebuild_trample_steam();
	level thread suppress_key_buildable_triggers();
}

elevator_call()
{
	trigs = getentarray( "elevator_key_console_trigger", "targetname" );

	foreach (trig in trigs)
	{
		elevatorname = trig.script_noteworthy;

		if ( isdefined( elevatorname ) && isdefined( trig.script_parameters ) )
		{
			elevator = level.elevators[elevatorname];
			floor = int( trig.script_parameters );
			flevel = elevator maps\mp\zm_highrise_elevators::elevator_level_for_floor( floor );
			trig.elevator = elevator;
			trig.floor = flevel;
		}

		trig.cost = 0;
		trig usetriggerrequirelookat();
		trig sethintstring( &"ZOMBIE_NEED_POWER" );
	}

	flag_wait( "power_on" );

	foreach (trig in trigs)
	{
		if ( !isdefined( trig.elevator ) )
		{
			continue;
		}

		trig thread elevator_call_think();
		trig thread watch_elevator_prompt();
		trig thread watch_elevator_body_prompt();
	}

	foreach (elevator in level.elevators)
	{
		if ( !isdefined( elevator.body ) )
		{
			continue;
		}

		elevator thread watch_elevator_lights();
	}
}

elevator_call_think()
{
	self notify( "elevator_call_think" );
	self endon( "elevator_call_think" );

	while ( 1 )
	{
		cost_active = 0;
		if ( !self.elevator.body.is_moving && self.elevator maps\mp\zm_highrise_elevators::elevator_is_on_floor( self.floor ) && !is_true( self.elevator.body.start_location_wait ) )
		{
			if ( !is_true( self.elevator.body.elevator_stop ) )
			{
				self sethintstring( "Hold ^3[{+activate}]^7 to lock elevator [Requires Key]" );
			}
			else
			{
				self sethintstring( "Hold ^3[{+activate}]^7 to unlock elevator [Requires Key]" );
			}
		}
		else
		{
			if ( self.elevator maps\mp\zm_highrise_elevators::elevator_is_on_floor( self.floor ) && !is_true( self.elevator.body.start_location_wait ) )
			{
				self sethintstring( "The elevator is on the way" );
				return;
			}

			cost_active = 1;
			self sethintstring( "Hold ^3[{+activate}]^7 to call elevator [Requires Key]" );
		}

		self trigger_on();

		self waittill( "trigger", who );

		if ( !is_player_valid( who ) )
        {
			continue;
		}

		if ( !player_has_key( who ) )
		{
			play_sound_at_pos( "no_purchase", self.origin );
			who maps\mp\zombies\_zm_audio::create_and_play_dialog( "general", "door_deny" );
			who iprintlnbold( "You need the elevator key!" );
			continue;
		}

		self playsound( "zmb_elevator_ding" );

		if ( !self.elevator.body.is_moving && self.elevator maps\mp\zm_highrise_elevators::elevator_is_on_floor( self.floor ) && !is_true( self.elevator.body.start_location_wait ) )
		{
			if ( !is_true( self.elevator.body.elevator_stop ) )
			{
				self.elevator.body setanim( level.perk_elevators_anims[self.elevator.body.perk_type][1] );
				self.elevator.body.elevator_stop = 1;
			}
			else
			{
				self.elevator.body.elevator_stop = 0;
			}

			continue;
		}

		self.elevator.body.elevator_stop = 0;
		self.elevator.body.elevator_force_go = 1;
		self maps\mp\zm_highrise_buildables::onuseplantobject_elevatorkey( who );

		if ( is_true( self.elevator.body.start_location_wait ) && self.elevator maps\mp\zm_highrise_elevators::elevator_is_on_floor( self.floor ) )
		{
			self sethintstring( "Hold ^3[{+activate}]^7 to lock elevator [Requires Key]" );

			while ( is_true( self.elevator.body.start_location_wait ) )
			{
				wait 0.05;
			}

			continue;
		}

		self sethintstring( "The elevator is on the way" );

		return;
	}
}

watch_elevator_prompt()
{
    while ( 1 )
    {
        self.elevator waittill( "floor_changed" );

		self thread do_watch_elevator_prompt();
    }
}

do_watch_elevator_prompt()
{
	self notify( "do_watch_elevator_prompt" );
	self endon( "do_watch_elevator_prompt" );
	self endon( "do_watch_elevator_body_prompt" );

	if ( is_true( self.elevator.body.elevator_force_go ) )
	{
		while ( !is_true( self.elevator.body.is_moving ) && !is_true( self.elevator.body.start_location_wait ) )
		{
			wait 0.05;
		}

		if ( is_true( self.elevator.body.start_location_wait ) )
		{
			while ( is_true( self.elevator.body.start_location_wait ) )
			{
				wait 0.05;
			}

			self.elevator.body.elevator_force_go = 0;
			self thread elevator_call_think();
		}
		else
		{
			self thread elevator_call_think();
		}
	}
	else
	{
		self thread elevator_call_think();
	}
}

watch_elevator_body_prompt()
{
    while ( 1 )
    {
        msg = self.elevator.body waittill_any_return( "movedone", "startwait" );

		self thread do_watch_elevator_body_prompt( msg );
    }
}

do_watch_elevator_body_prompt( msg )
{
	self notify( "do_watch_elevator_body_prompt" );
	self endon( "do_watch_elevator_body_prompt" );
	self endon( "do_watch_elevator_prompt" );

	if ( msg == "movedone" )
	{
		while ( is_true( self.elevator.body.is_moving ) )
		{
			wait 0.05;
		}

		self.elevator.body.elevator_force_go = 0;
		self thread elevator_call_think();
	}
	else
	{
		self thread elevator_call_think();
	}
}

watch_elevator_lights()
{
	set = 1;
	dir = "_d";

	while ( 1 )
	{
		if ( is_true( self.body.elevator_stop ) )
		{
			if ( set )
			{
				set = 0;

				dir = self.dir;
			}

			clientnotify( self.name + dir );

			if ( dir == "_d" )
			{
				dir = "_u";
			}
			else
			{
				dir = "_d";
			}
		}
		else if ( !set )
		{
			set = 1;

			clientnotify( self.name + self.dir );
		}

		wait 0.1;
	}
}

escape_pod_call()
{
	trig = getent( "escape_pod_key_console_trigger", "targetname" );

	trig.cost = 0;
	trig usetriggerrequirelookat();

	trig thread escape_pod_call_think();
}

escape_pod_call_think()
{
	while ( 1 )
	{
		flag_wait( "escape_pod_needs_reset" );

		self sethintstring( "Hold ^3[{+activate}]^7 to call escape pod [Requires Key]" );

		self waittill( "trigger", who );

		if ( !is_player_valid( who ) )
        {
			continue;
		}

		if ( !player_has_key( who ) )
		{
			play_sound_at_pos( "no_purchase", self.origin );
			who maps\mp\zombies\_zm_audio::create_and_play_dialog( "general", "door_deny" );
			who iprintlnbold( "You need the elevator key!" );
			continue;
		}

		self playsound( "zmb_buildable_complete" );

		self sethintstring( "The elevator is on the way" );

		self maps\mp\zm_highrise_buildables::onuseplantobject_escapepodkey( who );

		flag_waitopen( "escape_pod_needs_reset" );
	}
}

remove_weapon_limits()
{
    flag_wait( "initial_blackscreen_passed" );

    if ( isdefined( level.limited_weapons ) )
    {
        // Die Rise Box Weapon Limits
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

prebuild_trample_steam()
{
	flag_wait( "start_zombie_round_logic" );
	wait 0.5;

	stub = undefined;
	foreach ( s in level.buildable_stubs )
	{
		if ( isdefined( s.equipname ) && s.equipname == "springpad_zm" )
		{
			stub = s;
			break;
		}
	}

	if ( isdefined( stub ) )
	{
		maps\mp\zombies\_zm_unitrigger::unregister_unitrigger( stub );

		stub.built = 1;
		stub.buildablezone.built = 1;
		level.buildables_built["springpad_zm"] = 1;

		for ( i = 0; i < stub.buildablezone.pieces.size; i++ )
		{
			stub.buildablezone.pieces[i].built = 1;
		}

		if ( isdefined( stub.model ) )
		{
			stub.model show();
			stub.model notsolid();
		}

		foreach ( piece in stub.buildablezone.pieces )
		{
			if ( isdefined( piece.model ) )
			{
				piece.model delete();
			}
			if ( isdefined( piece.unitrigger ) )
			{
				maps\mp\zombies\_zm_unitrigger::unregister_unitrigger( piece.unitrigger );
			}
		}

		maps\mp\zombies\_zm_unitrigger::register_static_unitrigger( stub, maps\mp\zombies\_zm_buildables::bptrigger_think_persistent );
	}
}

suppress_key_buildable_triggers()
{
	// Null out the triggerthink callbacks for both key buildables BEFORE they
	// fire. This prevents ekeysbuildable() and keysbuildable() from wrapping the
	// elevator_key_console_trigger and escape_pod_key_console_trigger entities as
	// buildable unit-triggers — leaving them as plain map triggers that our custom
	// elevator_call_think() loop can exclusively control.
	wait 0.05;

	if ( isdefined( level.zombie_include_buildables ) )
	{
		if ( isdefined( level.zombie_include_buildables[ "keys_zm" ] ) )
			level.zombie_include_buildables[ "keys_zm" ].triggerthink = ::nop_triggerthink;

		if ( isdefined( level.zombie_include_buildables[ "ekeys_zm" ] ) )
			level.zombie_include_buildables[ "ekeys_zm" ].triggerthink = ::nop_triggerthink;
	}
}

nop_triggerthink()
{
	// Intentional no-op: prevents the buildable system from registering
	// elevator/escape-pod console triggers as buildable unit-triggers.
}

player_has_key( player )
{
	// All players "have" a key at all times
	return 1;
}

on_player_connect()
{
	while ( 1 )
	{
		level waittill( "connected", player );
		player thread give_illusion_key_hud();
	}
}

give_illusion_key_hud()
{
	self endon( "disconnect" );

	self.illusion_key_hud = newclienthudelem( self );
	self.illusion_key_hud.alignx = "right";
	self.illusion_key_hud.aligny = "bottom";
	self.illusion_key_hud.horzalign = "right";
	self.illusion_key_hud.vertalign = "bottom";
	self.illusion_key_hud.x = -15;
	self.illusion_key_hud.y = -65;
	self.illusion_key_hud.alpha = 0;
	self.illusion_key_hud setshader( "zom_hud_icon_epod_key", 32, 32 );
	self.illusion_key_hud.hidewheninmenu = 1;

	while ( 1 )
	{
		self waittill( "spawned_player" );
		self.illusion_key_hud.alpha = 1;
		
		self waittill( "death" );
		self.illusion_key_hud.alpha = 0;
	}
}

// ============================================================================
// STAMIN-UP SLIPGUN IMMUNITY
// ============================================================================
custom_add_slippery_spot( origin, duration, startpos )
{
    wait 0.5;
    level.slippery_spot_count++;
    hit_norm = vectornormalize( startpos - origin );
    hit_from = 6 * hit_norm;
    trace_height = 120;
    trace = bullettrace( origin + hit_from, origin + hit_from + ( 0, 0, trace_height * -1 ), 0, undefined );

    if ( isdefined( trace["entity"] ) )
    {
        parent = trace["entity"];

        if ( is_true( parent.can_move ) )
            return;
    }

    fxorigin = origin + hit_from;

    if ( trace["fraction"] == 1 )
        return;

    moving_parent = undefined;
    moving_parent_start = ( 0, 0, 0 );

    if ( isdefined( trace["entity"] ) )
    {
        parent = trace["entity"];

        if ( is_true( parent.can_move ) )
            return;
    }

    origin = trace["position"];
    self thread maps\mp\zombies\_zm_weap_slipgun::pool_of_goo( fxorigin, duration );

    if ( !isdefined( level.slippery_spots ) )
        level.slippery_spots = [];

    level.slippery_spots[level.slippery_spots.size] = origin;
    radius = 60;
    height = 48;

    slicked_players = [];
    slicked_zombies = [];
    lifetime = duration;
    radius2 = radius * radius;

    while ( lifetime > 0 )
    {
        oldlifetime = lifetime;

        foreach ( player in get_players() )
        {
            num = player getentitynumber();
            morigin = origin;

            if ( isdefined( moving_parent ) )
                morigin = origin + ( moving_parent.origin - moving_parent_start );

            should_be_slick = distance2dsquared( player.origin, morigin ) < radius2 && abs( player.origin[2] - morigin[2] ) < height;
            
            // --- CUSTOM PATCH: STAMIN-UP SLIP IMMUNITY ---
            if ( player HasPerk( "specialty_longersprint" ) )
            {
                should_be_slick = false;
            }
            // ---------------------------------------------

            is_slick = isdefined( slicked_players[num] );

            if ( should_be_slick != is_slick )
            {
                if ( !isdefined( player.slick_count ) )
                    player.slick_count = 0;

                if ( should_be_slick )
                {
                    player.slick_count++;
                    slicked_players[num] = player;
                }
                else
                {
                    player.slick_count--;
                    assert( player.slick_count >= 0 );
                    slicked_players[num] = undefined;
                }

                player forceslick( player.slick_count );
            }

            lifetime = maps\mp\zombies\_zm_weap_slipgun::slippery_spot_choke( lifetime );
        }

        zombies = get_round_enemy_array();

        if ( isdefined( zombies ) )
        {
            foreach ( zombie in zombies )
            {
                if ( isdefined( zombie ) )
                {
                    num = zombie getentitynumber();
                    morigin = origin;

                    if ( isdefined( moving_parent ) )
                        morigin = origin + ( moving_parent.origin - moving_parent_start );

                    should_be_slick = distance2dsquared( zombie.origin, morigin ) < radius2 && abs( zombie.origin[2] - morigin[2] ) < height;

                    if ( should_be_slick && !zombie maps\mp\zombies\_zm_weap_slipgun::zombie_can_slip() )
                        should_be_slick = 0;

                    is_slick = isdefined( slicked_zombies[num] );

                    if ( should_be_slick != is_slick )
                    {
                        if ( !isdefined( zombie.slick_count ) )
                            zombie.slick_count = 0;

                        if ( should_be_slick )
                        {
                            zombie.slick_count++;
                            slicked_zombies[num] = zombie;
                        }
                        else
                        {
                            if ( zombie.slick_count > 0 )
                                zombie.slick_count--;

                            slicked_zombies[num] = undefined;
                        }

                        zombie maps\mp\zombies\_zm_weap_slipgun::zombie_set_slipping( zombie.slick_count > 0 );
                    }

                    lifetime = maps\mp\zombies\_zm_weap_slipgun::slippery_spot_choke( lifetime );
                }
            }
        }

        if ( oldlifetime == lifetime )
        {
            lifetime = lifetime - 0.05;
            wait 0.05;
        }
    }

    foreach ( player in slicked_players )
    {
        player.slick_count--;
        assert( player.slick_count >= 0 );
        player forceslick( player.slick_count );
    }

    foreach ( zombie in slicked_zombies )
    {
        if ( isdefined( zombie ) )
        {
            if ( zombie.slick_count > 0 )
                zombie.slick_count--;

            zombie maps\mp\zombies\_zm_weap_slipgun::zombie_set_slipping( zombie.slick_count > 0 );
        }
    }

    arrayremovevalue( level.slippery_spots, origin, 0 );
    level.slippery_spot_count--;
}