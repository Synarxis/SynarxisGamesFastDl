#include common_scripts\utility;
#include maps\mp\_utility;
#include maps\mp\gametypes_zm\_hud_util;
#include maps\mp\zombies\_zm_perks;
#include maps\mp\zombies\_zm_powerups;
#include maps\mp\zombies\_zm_utility;
#include maps\mp\zombies\_zm_weapons;
#include maps\mp\zombies\_zm_laststand;
#include maps\mp\zombies\_zm_score;
#include maps\mp\zombies\_zm;
#include maps\mp\gametypes_zm\_weapons;
#include maps\mp\gametypes_zm\_hud_message;
#include maps\mp\zombies\_zm_magicbox;
#include maps\mp\zombies\_zm_unitrigger;
#include maps\mp\_zm_tomb_capture_zones;
#include maps\mp\zombies\_zm_playerhealth;
#include maps\mp\_visionset_mgr;
#include maps\mp\zombies\_zm_chugabud;
#include maps\mp\zombies\_zm_stats;
#include maps\mp\_demo;
#include maps\mp\zombies\_zm_audio;
#include maps\mp\zombies\_zm_pers_upgrades_functions;
#include maps\mp\zombies\_zm_power;


init()
{
    // HRpatch: Global settings
    if(!IsDefined(level.my_patch_start_time))
        level.my_patch_start_time = GetTime();

    level.player_out_of_playable_area_monitor = false;
    setdvar("player_backSpeedScale", 1);
    setdvar("player_strafeSpeedScale", 1);
    setDvar("player_sprintStrafeSpeedScale", 1);
    level.perk_purchase_limit = 9; 
    create_dvar( "afk_cooldown_duration", 900 );
    create_dvar( "afk_announce_status", 1);
    level thread new_pap_trigger();
    create_dvar("pap_price", 5000);
	create_dvar("repap_price", 2000);
	level.zombiemode_reusing_pack_a_punch = 1;
    
    // Safety check for Dvar input
    if(getDvarInt("afk_cooldown_duration") < 0)
        setDvar("afk_cooldown_duration", 0);
    
    level.zombie_vars["slipgun_max_kill_round"] = 255;
    level.slowgun_damage_ug = maps\mp\zombies\_zm::ai_zombie_health(255);
    level.cmpowerupnukeshouldwaittokillzombies = getdvarintdefault("cmPowerupNukeShouldWaitToKillZombies", 0);
	level.cmpowerupnukemintimetokill = getdvarfloatdefault("cmPowerupNukeMinTimeToKill", 0);
	level.cmpowerupnukemaxtimetokill = getdvarfloatdefault("cmPowerupNukeMaxTimeToKill", 0);
    
    // Function replacements
    replaceFunc( maps\mp\zombies\_zm_score::add_to_player_score, ::add_to_player_score_override );
    replaceFunc( maps\mp\zombies\_zm::actor_damage_override_wrapper, ::custom_actor_damage_override_wrapper );
    replaceFunc( maps\mp\zombies\_zm_score::player_add_points_kill_bonus, ::custom_player_add_points_kill_bonus );
    replaceFunc( maps\mp\zombies\_zm_weapons::ammo_give, ::new_ammo_give );
    replacefunc(maps\mp\zombies\_zm::round_over, ::new_round_over);
    replaceFunc( maps\mp\zombies\_zm_blockers::debris_init, ::custom_debris_init );
    replaceFunc( maps\mp\zombies\_zm_audio::create_and_play_dialog, ::custom_create_and_play_dialog );
    
    // Sharedbox: Initialize
    if(getdvar( "mapname" ) == "zm_tomb" )
        thread monitor_boxes();
    else
        thread CheckForCurrentBox();
        
    level.shared_box = 0;
    add_zombie_hint( "default_shared_box", "Hold ^3&&1^7 for weapon");
    level.player_starting_health = 150;
    // Level threads (run once, not per player)
    level thread zombie_health_cap();
    level thread disable_map_staminup_logic_on_load();   
    level thread patch_wallbuys();
    level thread onsayPlayer();	 
    level thread monitor_doors();
    level.ragestarted = 0;
	level thread watch_round_count();
    level thread custom_survival_bank_setup();
    // Single player connect handler for everything
    level thread onPlayerConnect();
    level thread command_thread();
}


// ============================================================================
// PLAYER CONNECTION & SPAWN - Single unified handler
// ============================================================================

onPlayerConnect()
{
    for(;;)
    {
        level waittill("connected", player);
        
        // Initialize player variables
        player.timer_running = false;
        player.counter_running = false;
        player.downtimer_running = false;
        player.mule_monitor_running = false;
        
        player.account_value = player maps\mp\zombies\_zm_stats::get_map_stat( "depositBox", "zm_transit" );
        if ( !isdefined( player.account_value ) )
            player.account_value = 0;

        player thread player_bank_hud_think();

         // Initialize AFK variables
        player.isafk = 0;
        player.afkcooldown = 0;
        player.canafk = 1;
        player.afk_casting = false;
        
        // Mule Kick variables
        player.last_known_mule_weapon = undefined;
        player.retain_mule_weapon = undefined;
        
        // Advanced Doors
        player thread watch_melee_pay();

        // Zone Notifier Init
        player.currentzone = "";

        player thread onPlayerSpawned();
    }
}

onPlayerSpawned()
{
    level endon("end_game");
    self endon("disconnect");

    self thread monitor_base_health();

    for(;;)
    {
        self waittill("spawned_player");
        flag_wait("initial_blackscreen_passed");
        wait 0.1;
        if (!self HasPerk("specialty_armorvest"))
        {
            self.maxhealth = 150;
            self.health = self.maxhealth;
        }
        else
        {
            self.maxhealth = 250;
            self.health = self.maxhealth;
        }
        // === HUD THREADS (5 threads - can't easily combine) ===
        if(!self.timer_running)
            self thread timer();
        
        if(!self.health_bar_hud_running)
            self thread health_bar_hud();

         if(!self.shield_bar_hud_running)
             self thread shield_bar_hud();    
        
        if(!self.counter_running)
            self thread zombie_counter();
        
        if(!self.downtimer_running)
            self thread watchForDown_Downtimer();
        
        // === PERK BUFFS (1 thread - combined from 3!) ===
        if(!IsDefined(self.perk_buffs_running) || !self.perk_buffs_running)
            self thread perk_buffs_combined();

         // === QUICK REVIVE DOWN BUFF ===
        if ( !isDefined( self.qr_preservation_running ) || !self.qr_preservation_running )
            self thread watch_quick_revive_down_preservation();
        
        // === QOL THREADS (5 threads - event driven) ===
        if(!IsDefined(self.maxammo_running) || !self.maxammo_running)
            self thread maxammo();
        
        if(!IsDefined(self.carpenter_running) || !self.carpenter_running)
            self thread carpenter();
        
        if(!IsDefined(self.drop_weapon_running) || !self.drop_weapon_running)
            self thread drop_weapon();

        if(!IsDefined(self.nuke_running) || !self.nuke_running)
            self thread nuke_monitor();
        
        if(!IsDefined(self.sprint_melee_monitor_running) || !self.sprint_melee_monitor_running)
            self thread monitor_sprint_melee();

        // === MULE KICK (2 threads - combined from 4!) ===
        if(!self.mule_monitor_running)
            self thread mule_kick_monitor_combined();
        
        if(!IsDefined(self.mule_down_running) || !self.mule_down_running)
            self thread mule_on_player_downed();

         // === ZONE NOTIFIER ===
        if(!IsDefined(self.zone_notifier_running) || !self.zone_notifier_running)
        {
            self.zone_notifier_running = true;
            self thread zoneCheck();
        }    
    }
}

// ============================================================================
// HUD FUNCTIONS
// ============================================================================

timer()
{
    self endon( "disconnect" );
    flag_wait( "initial_blackscreen_passed" );

    
    self.timer_running = true;
    
    if(IsDefined(self.timer_hud))
    {
        self.timer_hud destroy();
        self.timer_hud = undefined;
    }
    
    self.timer_hud = newclienthudelem( self );
    self.timer_hud.alignx = "left";
    self.timer_hud.aligny = "top";
    self.timer_hud.horzalign = "left";
    self.timer_hud.vertalign = "user_top";
    self.timer_hud.x = self.timer_hud.x - 1;
    self.timer_hud.y = self.timer_hud.y + -2;
    self.timer_hud.fontscale = 1.4;
    self.timer_hud.alpha = 0;
    self.timer_hud.hidewheninmenu = 1;
    self.timer_hud.alpha = 1;
    self.timer_hud settimerup( 0 );
}

health_bar_hud()
{
    level endon("end_game");
    self endon("disconnect");
    flag_wait("initial_blackscreen_passed");

    self.health_bar_hud_running = true;
    
    if(IsDefined(self.health_bar_hud))
    {
        self.health_bar_hud destroy();
        self.health_bar_hud= undefined;
    }

	x = 5;
	y = -104;
	if (level.script == "zm_buried")
	{
		y -= 25;
	}
	else if (level.script == "zm_tomb")
	{
		y -= 28;
	}

	hud = self createbar((1, 1, 1), level.primaryprogressbarwidth - 10, level.primaryprogressbarheight);
	hud.alignx = "left";
	hud.bar.alignx = "left";
	hud.barframe.alignx = "left";
	hud.aligny = "middle";
	hud.bar.aligny = "middle";
	hud.barframe.aligny = "middle";
	hud.horzalign = "user_left";
	hud.bar.horzalign = "user_left";
	hud.barframe.horzalign = "user_left";
	hud.vertalign = "user_bottom";
	hud.bar.vertalign = "user_bottom";
	hud.barframe.vertalign = "user_bottom";
	hud.x += x;
	hud.bar.x += x + ((hud.width + 4) / 2);
	hud.barframe.x += x;
	hud.y += y;
	hud.bar.y += y;
	hud.barframe.y += y;
	hud.hidewheninmenu = 1;
	hud.bar.hidewheninmenu = 1;
	hud.barframe.hidewheninmenu = 1;
	hud.foreground = 1;
	hud.bar.foreground = 1;
	hud.barframe.foreground = 1;
	hud.sort = 1;
	hud.bar.sort = 2;
	hud.barframe.sort = 3;
	hud.barframe destroy();

	hud_text = createfontstring("objective", 1.2);
	hud_text.alignx = "left";
	hud_text.aligny = "middle";
	hud_text.horzalign = "user_left";
	hud_text.vertalign = "user_bottom";
	hud_text.x += x + hud.width + 7;
	hud_text.y += y;
	hud_text.hidewheninmenu = 1;
	hud_text.foreground = 1;

	hud endon("death");

	while (1)
	{
		if (is_true(self.afterlife))
		{
			hud hideelem();
			hud_text hideelem();

			while (is_true(self.afterlife))
			{
				wait 0.05;
			}

			hud showelem();
			hud_text showelem();
		}
		health_ratio = self.health / self.maxhealth;
		if (health_ratio > 0.50)
			hud.bar.color = (0.0, 1.0, 0.0);
		else if (health_ratio > 0.25)
			hud.bar.color = (1.0, 1.0, 0.0);
		else
			hud.bar.color = (1.0, 0.0, 0.0);

		hud updatebar(health_ratio);
		hud_text setvalue(self.health);

		wait 0.05;
	}
}

shield_bar_hud()
{
    level endon("end_game");
    self endon("disconnect");
    flag_wait("initial_blackscreen_passed");

    self.shield_bar_hud_running = true;
    
    if(IsDefined(self.health_bar_hud))
    {
        self.shield_bar_hud destroy();
        self.shield_bar_hud= undefined;
    }

	x = 5;
	y = -104;
	if (level.script == "zm_buried")
	{
		y -= 25;
	}
	else if (level.script == "zm_tomb")
	{
		y -= 28;
	}

	hud = self createbar((0.5, 0.5, 0.5), level.primaryprogressbarwidth - 10, int(level.primaryprogressbarheight / 2));
	hud.alignx = "left";
	hud.bar.alignx = "left";
	hud.barframe.alignx = "left";
	hud.aligny = "middle";
	hud.bar.aligny = "middle";
	hud.barframe.aligny = "middle";
	hud.horzalign = "user_left";
	hud.bar.horzalign = "user_left";
	hud.barframe.horzalign = "user_left";
	hud.vertalign = "user_bottom";
	hud.bar.vertalign = "user_bottom";
	hud.barframe.vertalign = "user_bottom";
	hud.x += x;
	hud.bar.x += x + ((hud.width + 4) / 2);
	hud.barframe.x += x;
	hud.y += y - 2;
	hud.bar.y += y - 2;
	hud.barframe.y += y - 2;
	hud.hidewheninmenu = 1;
	hud.bar.hidewheninmenu = 1;
	hud.barframe.hidewheninmenu = 1;
	hud.foreground = 1;
	hud.bar.foreground = 1;
	hud.barframe.foreground = 1;
	hud.sort = 2;
	hud.bar.sort = 3;
	hud.barframe.sort = 4;
	hud.alpha = 0;
	hud.barframe destroy();

	hud_text = createfontstring("objective", 1.2);
	hud_text.alignx = "left";
	hud_text.aligny = "middle";
	hud_text.horzalign = "user_left";
	hud_text.vertalign = "user_bottom";
	hud_text.label = &"| ";
	hud_text.x += x + hud.width + 11;
	hud_text.y += y;
	hud_text.hidewheninmenu = 1;
	hud_text.foreground = 1;

	hud_text_x = hud_text.x;

	hud endon("death");

	while (1)
	{
		if (!is_true(self.hasriotshield) || (isDefined(self.shielddamagetaken) && self.shielddamagetaken >= level.zombie_vars["riotshield_hit_points"]) || is_true(self.afterlife))
		{
			hud.bar.alpha = 0;
			hud_text hideelem();

			while (!is_true(self.hasriotshield) || (isDefined(self.shielddamagetaken) && self.shielddamagetaken >= level.zombie_vars["riotshield_hit_points"]) || is_true(self.afterlife))
			{
				wait 0.05;
			}

			hud.bar.alpha = 1;
			hud_text showelem();
		}

		health = level.zombie_vars["riotshield_hit_points"] - self.shielddamagetaken;
		if (health < 0)
		{
			health = 0;
		}

		health_ratio = health / level.zombie_vars["riotshield_hit_points"];

		offset_x = 0;
		health_str = "" + self.health;
		for(i = 0; i < health_str.size; i++)
		{
			if (health_str[i] == "1")
			{
				offset_x += 4;
			}
			else
			{
				offset_x += 5;
			}
		}

		hud_text.x = hud_text_x + offset_x;

		hud updatebar(health_ratio);
		hud_text setvalue(int(health_ratio * 100));

		wait 0.05;
	}
}

zombie_counter()
{
    level endon( "game_ended" );
    self endon("disconnect");
    flag_wait( "initial_blackscreen_passed" );

    
    self.counter_running = true;
    
    if(IsDefined(self.zombiecounter))
    {
        self.zombiecounter destroy();
        self.zombiecounter = undefined;
    }
    
    
    self.zombiecounter = createfontstring( "Objective", 1.7 );
    self.zombiecounter setpoint( "CENTER", "TOP", 0, -20 );
    self.zombiecounter.alpha = 1;
    self.zombiecounter.hidewheninmenu = 1;
    self.zombiecounter.hidewhendead = 1;
    self.zombiecounter.label = &"Zombies: ^1";
    self.zombiecounter.color = (1.0, 1.0, 1.0);
    
    for(;;)
    {
        if(IsDefined(self.afterlife) && self.afterlife)
            self.zombiecounter.alpha = 0.2;
        else 
            self.zombiecounter.alpha = 1.0;
        
        self.zombiecounter setvalue( level.zombie_total + get_current_zombie_count() );
        wait 0.5;
    }
}

watchForDown_Downtimer()
{
    self endon("disconnect");
    self endon("death");
    
    if(self.downtimer_running)
        return;
    self.downtimer_running = true;
    
    flag_wait("initial_blackscreen_passed");
    
    for(;;)
    {
        self waittill("entering_last_stand");
        self thread displayBleedoutTimer();
    }
}

displayBleedoutTimer()
{
    self endon("disconnect");
    self endon("death");            
    self endon("player_revived");
    
    if(IsDefined(self.bleedout_timer_hud))
    {
        self.bleedout_timer_hud destroy();
        self.bleedout_timer_hud = undefined;
    }
    
    self.bleedout_timer_hud = self createfontstring("objective", 1.8);
    self.bleedout_timer_hud setpoint("CENTER", "BOTTOM", 0, -100);
    self.bleedout_timer_hud.color = (1, 0.2, 0.2);
    self.bleedout_timer_hud.glowColor = (0.3, 0, 0);   
    self.bleedout_timer_hud.glowAlpha = 1;
    self.bleedout_timer_hud.alpha = 1; 

    self thread watch_for_revive_or_death();

    bleedoutTime_str = getDvar( "player_lastStandBleedoutTime" );
    if ( !IsDefined(bleedoutTime_str) || bleedoutTime_str == "" || bleedoutTime_str == "0" )
        bleedoutTime = 45;
    else
        bleedoutTime = int(float(bleedoutTime_str) + 0.5);
    
    bleedout_timer = bleedoutTime;
    self.bleedout_timer_hud settext("Bleeding Out: " + bleedout_timer + "s");
    while(bleedout_timer > 0)
    {
        if(!IsDefined(self.bleedout_timer_hud)) return;
        bleedout_timer--;
        self.bleedout_timer_hud settext("Bleeding Out: " + bleedout_timer + "s");
        wait 1;
    }
    
    if(IsDefined(self.bleedout_timer_hud))
    {
        self.bleedout_timer_hud destroy();
        self.bleedout_timer_hud = undefined;
    }
}

watch_for_revive_or_death()
{
    self endon("disconnect");
    self waittill_any("player_revived", "death");
    
    if(IsDefined(self.bleedout_timer_hud))
    {
        self.bleedout_timer_hud destroy();
        self.bleedout_timer_hud = undefined;
    }
    
    self.downtimer_running = false;
}

// ============================================================================
// PERK BUFFS - COMBINED (was 4 threads, now 1!)
// ============================================================================

perk_buffs_combined()
{
    level endon("end_game");
    self endon("disconnect");
    
    if(IsDefined(self.perk_buffs_running) && self.perk_buffs_running)
        return;
    self.perk_buffs_running = true;
    
    // Start separate Quick Revive healing thread
    self thread quick_revive_health_regen_monitor();
    
    for (;;)
    {
        self waittill_any( "perk_acquired", "perk_lost" );
        if (!self HasPerk("specialty_armorvest"))
        {
            self.maxhealth = 150;
            if (self.health > 150)
                self.health = 150;
        }
        // Staminup buff
        if (self HasPerk("specialty_longersprint"))
        {
            self SetPerk("specialty_movefaster");
            self SetPerk("specialty_unlimitedsprint");
            self SetPerk("specialty_stalker");
        }
        else
        {
            self UnsetPerk("specialty_movefaster");
            self UnsetPerk("specialty_unlimitedsprint"); 
            self UnsetPerk("specialty_stalker");
        }
        
        // Speed Cola buff
        if ( self HasPerk( "specialty_fastreload" ) )
        {
            if ( !self HasPerk( "specialty_fastads" ) ) self SetPerk( "specialty_fastads" );
            if ( !self HasPerk( "specialty_fastweaponswitch" ) ) self SetPerk( "specialty_fastweaponswitch" );
            if ( !self HasPerk( "specialty_fastequipmentuse" ) ) self SetPerk( "specialty_fastequipmentuse" );
        }
        else
        {
            if ( self HasPerk( "specialty_fastads" ) ) self UnsetPerk( "specialty_fastads" );
            if ( self HasPerk( "specialty_fastweaponswitch" ) ) self UnsetPerk( "specialty_fastweaponswitch" );
            if ( self HasPerk( "specialty_fastequipmentuse" ) ) self UnsetPerk( "specialty_fastequipmentuse" );
        }
        
        // Deadshot buff
        if (self HasPerk("specialty_deadshot")) 
        {
            self setclientdvar("bg_recoilViewKickScale", 0);
            self setclientdvar("bg_recoilSpreadScale", 0);
        }
        else
        {
            self setclientdvar("bg_recoilViewKickScale", 1);
            self setclientdvar("bg_recoilSpreadScale", 1);
        }
    }
}

quick_revive_health_regen_monitor()
{
    level endon("end_game");
    self endon("disconnect");
    
    for (;;)
    {
        self waittill("damage");
        if (self HasPerk("specialty_quickrevive") && self.health < self.maxHealth)
        {
            wait 2;
            self notify("stop_quickrevive_regen");
			self thread quickrevivehpregen();
		}
		wait 0.05;
	}
}

quickrevivehpregen()
{
	level endon("end_game");
	self endon("disconnect");
	self endon("player_downed");
	self endon("bled_out");
	self endon("stop_quickrevive_regen");
	if (self.health < self.maxhealth)
	{
		while(1)
		{
			if (!isAlive(self))
				return;
			self.currenthealth = self.health;
			self.health += 20;
			wait(0.1);
			if (self.health >= self.maxhealth)
			{
				self.health = self.maxhealth;
				break;
			}
			if (self.health < self.currenthealth)
			{
				break;
			}
		}
	}
}

disable_map_staminup_logic_on_load()
{
    level waittill("connected");    
    wait 0.05;
    level.zombie_perk_staminup_func = undefined;
}

patch_wallbuys()
{
    level endon( "game_ended" );
    
    // Wait for the map to finish spawning and initializing entities
    wait 1; 
    
    // Loop through all spawned wallbuy trigger entities (works for static wallbuys on all maps)
    if ( isDefined( level._spawned_wallbuys ) )
    {
        for ( i = 0; i < level._spawned_wallbuys.size; i++ )
        {
            wallbuy = level._spawned_wallbuys[i];
            if ( isDefined( wallbuy.zombie_weapon_upgrade ) )
            {
                new_weapon = undefined;
                if ( wallbuy.zombie_weapon_upgrade == "ak74u_zm" )
                    new_weapon = "ak74u_extclip_zm";
                else if ( wallbuy.zombie_weapon_upgrade == "beretta93r_zm" )
                    new_weapon = "beretta93r_extclip_zm";
                else if ( wallbuy.zombie_weapon_upgrade == "mp40_zm" )
                    new_weapon = "mp40_stalker_zm";
                
                if ( isDefined( new_weapon ) )
                {
                    wallbuy.zombie_weapon_upgrade = new_weapon;
                    if ( isDefined( wallbuy.trigger_stub ) )
                    {
                        wallbuy.trigger_stub.zombie_weapon_upgrade = new_weapon;
                        wallbuy.trigger_stub.weapon_upgrade = new_weapon;
                    }
                }
            }
        }
    }

    // Special patch for Buried (zm_buried) where AK-74u and B23R are dynamic chalk drawings
    if ( isDefined( level.script ) && level.script == "zm_buried" )
    {
        // 1. Update level.buildable_wallbuy_weapons (tells add_dynamic_wallbuy the new weapon names)
        if ( isDefined( level.buildable_wallbuy_weapons ) )
        {
            for ( i = 0; i < level.buildable_wallbuy_weapons.size; i++ )
            {
                if ( level.buildable_wallbuy_weapons[i] == "ak74u_zm" )
                    level.buildable_wallbuy_weapons[i] = "ak74u_extclip_zm";
                else if ( level.buildable_wallbuy_weapons[i] == "beretta93r_zm" )
                    level.buildable_wallbuy_weapons[i] = "beretta93r_extclip_zm";
                else if ( level.buildable_wallbuy_weapons[i] == "mp40_zm" )
                    level.buildable_wallbuy_weapons[i] = "mp40_stalker_zm";
            }
        }

        // 2. Intercept the chalk piece template's onspawn callback
        // This ensures that when a chalk piece is spawned dynamically as its zone is activated,
        // we rewrite its script_noteworthy to the extended clip variant before piece_spawn_chalk runs.
        if ( isDefined( level.zombie_include_buildables ) && isDefined( level.zombie_include_buildables["chalk"] ) )
        {
            buildable = level.zombie_include_buildables["chalk"];
            if ( isDefined( buildable.buildablepieces ) && buildable.buildablepieces.size > 0 )
            {
                level.original_piece_spawn_chalk = buildable.buildablepieces[0].onspawn;
                buildable.buildablepieces[0].onspawn = ::custom_piece_spawn_chalk;
            }
        }

        // 3. Update level.buildable_wallbuy_weapon_hints and level.buildable_wallbuy_pickup_hints
        if ( isDefined( level.buildable_wallbuy_weapon_hints ) )
        {
            level.buildable_wallbuy_weapon_hints["ak74u_extclip_zm"] = level.buildable_wallbuy_weapon_hints["ak74u_zm"];
            level.buildable_wallbuy_weapon_hints["beretta93r_extclip_zm"] = level.buildable_wallbuy_weapon_hints["beretta93r_zm"];
            level.buildable_wallbuy_weapon_hints["mp40_stalker_zm"] = level.buildable_wallbuy_weapon_hints["mp40_zm"];
        }
        if ( isDefined( level.buildable_wallbuy_pickup_hints ) )
        {
            level.buildable_wallbuy_pickup_hints["ak74u_extclip_zm"] = level.buildable_wallbuy_pickup_hints["ak74u_zm"];
            level.buildable_wallbuy_pickup_hints["beretta93r_extclip_zm"] = level.buildable_wallbuy_pickup_hints["beretta93r_zm"];
            level.buildable_wallbuy_pickup_hints["mp40_stalker_zm"] = level.buildable_wallbuy_pickup_hints["mp40_zm"];
        }

        // 4. Update level._effect for chalk fx
        if ( isDefined( level._effect ) )
        {
            if ( isDefined( level._effect["ak74u_zm_chalk_fx"] ) )
                level._effect["ak74u_extclip_zm_chalk_fx"] = level._effect["ak74u_zm_chalk_fx"];
            if ( isDefined( level._effect["beretta93r_zm_chalk_fx"] ) )
                level._effect["beretta93r_extclip_zm_chalk_fx"] = level._effect["beretta93r_zm_chalk_fx"];
            if ( isDefined( level._effect["mp40_zm_chalk_fx"] ) )
                level._effect["mp40_stalker_zm_chalk_fx"] = level._effect["mp40_zm_chalk_fx"];
        }
    }
}

custom_piece_spawn_chalk()
{
    if ( isDefined( self.script_noteworthy ) )
    {
        if ( self.script_noteworthy == "ak74u_zm" )
            self.script_noteworthy = "ak74u_extclip_zm";
        else if ( self.script_noteworthy == "beretta93r_zm" )
            self.script_noteworthy = "beretta93r_extclip_zm";
        else if ( self.script_noteworthy == "mp40_zm" )
            self.script_noteworthy = "mp40_stalker_zm";
    }

    if ( isDefined( level.original_piece_spawn_chalk ) )
    {
        self [[ level.original_piece_spawn_chalk ]]();
    }
}

// ============================================================================
// QOL FUNCTIONS
// ============================================================================

maxammo()
{
    level endon("end_game");
    self endon("disconnect");
    
    if(IsDefined(self.maxammo_running) && self.maxammo_running)
        return;
    self.maxammo_running = true;
    
    for(;;) 
    {
        self waittill("zmb_max_ammo");
        weaps = self getweaponslist(1);
        foreach (weap in weaps) 
        {
            self givemaxammo(weap); 
            self setweaponammoclip(weap, weaponclipsize(weap));
        }
    }
}

carpenter()
{
    level endon("end_game");
    self endon("disconnect");
    
    if(IsDefined(self.carpenter_running) && self.carpenter_running)
        return;
    self.carpenter_running = true;
    
    for(;;)
    {
        level waittill( "carpenter_finished" );
        self.shielddamagetaken = 0;
    }
}

drop_weapon()
{
    level endon("end_game");
    self endon("disconnect");
    
    if(IsDefined(self.drop_weapon_running) && self.drop_weapon_running)
        return;
    self.drop_weapon_running = true;
    
    for (;;) 
    {
        if (self meleebuttonpressed()) 
        {
            duration = 0;
            while (self meleebuttonpressed()) 
            {
                duration += 1;
                if (duration == 25) 
                {
                    weap = self getCurrentWeapon();
                    self dropItem(weap);
                    break;
                }
                wait 0.05;
            }
        }
        wait 0.05;
    }
}

new_ammo_give( weapon ) 
{
    give_ammo = 0;
    fill_clip = 0;
    if ( !is_offhand_weapon( weapon ) )
    {
        weapon = get_weapon_with_attachments( weapon );
        if ( IsDefined( weapon ) )
        {
            stockmax = weaponstartammo( weapon );
            clipmax = weaponclipsize( weapon );
            clipcount = self getweaponammoclip( weapon );
            currstock = self getammocount( weapon );
            stockleft = currstock - clipcount;
            
            if ( stockleft < stockmax ) give_ammo = 1;
            if ( clipcount < clipmax ) fill_clip = 1;
        }
    }
    else if ( self has_weapon_or_upgrade( weapon ) )
    {
        if ( self getammocount( weapon ) < weaponmaxammo( weapon ) ) give_ammo = 1;
    }

    if ( give_ammo || fill_clip )
    {
        self play_sound_on_ent( "purchase" );
        if ( give_ammo )
        {
            self givemaxammo( weapon );
            alt_weap = weaponaltweaponname( weapon );
            if ( alt_weap != "none" ) self givemaxammo( alt_weap );
        }
        if ( fill_clip ) self setweaponammoclip( weapon, clipmax );
        return 1;
    }
    return 0;
}

add_to_player_score_override( points, add_to_total )
{
    if ( !isDefined( add_to_total ) )
    {
        add_to_total = 1;
    }
    if ( !isDefined( points ) || level.intermission )
    {
        return;
    }
        self.score += points;
    self.pers[ "score" ] = self.score;
    if ( add_to_total )
    {
        self.score_total += points;
    }
    self incrementplayerstat( "score", points );
} 

onsayPlayer()
{
    level endon("game_ended");    
    for(;;)
    {
        level waittill( "say", message, player );
        sayText = strtok(tolower(message), " ");        
        if ( isdefined( sayText ) && sayText.size > 0 )
        {
            if(sayText[0]==".send" || sayText[0]=="/.send") //GivePoints
            {
                if(sayText.size>1)
                {
                    for( i = 0; i < level.players.size; i++ )
                    {
                        if( isSubStr( tolower( getPlayerName( level.players[ i ] )), tolower(sayText[ 1 ] ) ))
                        {
                            value = int( sayText[ ( sayText.size - 1 ) ] );
                            if( value < 0 )
                                value = ( value * -1 );
                            player give_points( level.players[ i ], int( value ));
                        }                    
                    }
                }else
                {
                    player iPrintLn("Use ^2.send ^1name ^2amount");
                }
            }       
            else if ( sayText[0] == ".join" || sayText[0] == "/.join" )
            {
                if ( player.sessionstate == "spectator" )
                {
                    if ( !isdefined( player.spectator_respawn ) )
                    {
                        spawnpoints = getstructarray( "initial_spawn_points", "targetname" );
                        if ( isdefined( spawnpoints ) && spawnpoints.size > 0 )
                        {
                            player.spectator_respawn = spawnpoints[0];
                        }
                    }

                    if ( isdefined( player.spectator_respawn ) )
                    {
                        player [[ level.spawnplayer ]]();
                        
                        foreach ( p in level.players )
                        {
                            p iPrintLn( "^2" + getPlayerName( player ) + " ^7has respawned using ^2.join" );
                        }
                    }
                    else
                    {
                        player iPrintLn( "^1Error: No spawn point found." );
                    }
                }
                else
                {
                    player iPrintLn( "^1You must be spectating to use this command." );
                }
            }
        }
    }
}

give_points( player, var )
{
	if( !isDefined( self.giving_points ) )
	{
		self.giving_points = true;
		if ( player.score == 1000000 )
			self iPrintLn( getPlayerName( player ) + " already has ^51000000 ^7points" );
		else if( self.score >= var )
		{
			self maps\mp\zombies\_zm_score::minus_to_player_score( var, 1 );
			self iPrintLn( "^1Gave ^7" + getPlayerName( player ) + " ^1" + var + " ^7points" );
			player maps\mp\zombies\_zm_score::add_to_player_score( var, 1 );
			player iPrintLn( "^2" + getPlayerName( self ) + " ^7gave you ^2" + var + " ^7points" );
		}
		else
			self iPrintLn( "^1You don't have enough points for that" );
		wait 1;
		self.giving_points = undefined;
	}
}

getPlayerName( player )
{
    playerName = getSubStr( player.name, 0, player.name.size );
    for( i = 0; i < playerName.size; i++ )
    {
		if( playerName[ i ] == "]" )
			break;
    }
    if( playerName.size != i )
		playerName = getSubStr( playerName, i + 1, playerName.size );
		
    return playerName;
}

nuke_monitor()
{
    level endon("end_game");
    self endon("disconnect");
    
    if(IsDefined(self.nuke_running) && self.nuke_running)
        return;
    self.nuke_running = true;

    while(1)
    {
        self waittill("nuke_triggered");
        
        self.nukekills = (maps\mp\zombies\_zm_utility::get_round_enemy_array().size);
        self.kills += self.nukekills;
        self.nukekills = self.nukekills * 50;
        
        // Use the local score override function directly
        self add_to_player_score_override(self.nukekills, 1);
        
        level thread killallzombies();
    }
}

killallzombies()
{
    ai = getaiarray(level.zombie_team);
    foreach(zombie in ai)
    {
        if(isdefined(zombie))
        {
            zombie dodamage(zombie.maxhealth * 2, zombie.origin, zombie, zombie, "none", "MOD_SUICIDE");
        }
    }
}

getdvarintdefault(dvarname, defaultvalue)
{
    value = GetDvar(dvarname);
    if(value != "")
    {
        return int(value);
    }
    return defaultvalue;
}

getdvarfloatdefault(dvarname, defaultvalue)
{
    value = GetDvar(dvarname);
    if(value != "")
    {
        return float(value);
    }
    return defaultvalue;
}

new_pap_trigger()
{
    level waittill("Pack_A_Punch_on");
    wait 2;
    
	if( getdvar( "mapname" ) == "zm_transit" && getdvar ( "g_gametype")  == "zstandard" )
	{	
	}
	else
	{
		level notify("Pack_A_Punch_off");
		level thread pap_off();
	}
    if( getdvar( "mapname" ) == "zm_nuked" )
    {
        level waittill( "Pack_A_Punch_on" );
    }
	perk_machine = getent( "vending_packapunch", "targetname" );
	weapon_upgrade_trigger = getentarray( "specialty_weapupgrade", "script_noteworthy" );
	weapon_upgrade_trigger[0] trigger_off();
	if( getdvar( "mapname" ) == "zm_transit" && getdvar ( "g_gametype")  == "zclassic" )
	{
		if(!level.buildables_built[ "pap" ])
		{
			level waittill("pap_built");
		}
	}
	wait 1;
	self.perk_machine = perk_machine;
	perk_machine_sound = getentarray( "perksacola", "targetname" );
	packa_rollers = spawn( "script_origin", perk_machine.origin );
	packa_timer = spawn( "script_origin", perk_machine.origin );
	packa_rollers linkto( perk_machine );
	packa_timer linkto( perk_machine );
	if( getdvar( "mapname" ) == "zm_highrise" )
	{
		trigger = spawn( "trigger_radius", perk_machine.origin, 1, 60, 80 );
		Trigger enableLinkTo();
		Trigger linkto(self.perk_machine);
	}
	else
	{
		trigger = spawn( "trigger_radius", perk_machine.origin, 1, 35, 80 );
	}
	Trigger SetCursorHint( "HINT_NOICON" );
    Trigger sethintstring( "			Hold ^3&&1^7 for Pack-a-Punch [Cost: " + getDvarInt("pap_price") + "]" );
	Trigger usetriggerrequirelookat();
	perk_machine thread maps\mp\zombies\_zm_perks::activate_packapunch();
	for(;;)
	{
		Trigger waittill("trigger", player);
		current_weapon = player getcurrentweapon();
		
		if ( !can_upgrade_weapon( current_weapon ) )
		{
			Trigger sethintstring( "" );
		}
		else
		{
			is_upgraded = is_weapon_upgraded( current_weapon );
			cost = getDvarInt( "pap_price" );
			if ( is_upgraded )
			{
				cost = getDvarInt( "repap_price" );
				Trigger sethintstring( "			Hold ^3&&1^7 for Repack-a-Punch [Cost: " + cost + "]" );
			}
			else
			{
				Trigger sethintstring( "			Hold ^3&&1^7 for Pack-a-Punch [Cost: " + cost + "]" );
			}
		}
		
		if(player UseButtonPressed() && player.score >= cost && current_weapon != "riotshield_zm" && player can_buy_weapon() && !player.is_drinking && !is_placeable_mine( current_weapon ) && !is_equipment( current_weapon ) && level.revive_tool != current_weapon && current_weapon != "none" && can_upgrade_weapon( current_weapon ))
        {
			player.score -= cost;
            player thread maps\mp\zombies\_zm_audio::play_jingle_or_stinger( "mus_perks_packa_sting" );
			trigger setinvisibletoall();
			upgrade_as_attachment = will_upgrade_weapon_as_attachment( current_weapon );
            
            clip_ammo = player getweaponammoclip( current_weapon );
            stock_ammo = player getweaponammostock( current_weapon );
            
			wait .1;
			player takeWeapon(current_weapon);
			current_weapon = player maps\mp\zombies\_zm_weapons::switch_from_alt_weapon( current_weapon );
			self.current_weapon = current_weapon;
			
			if ( is_upgraded )
			{
				upgrade_name = maps\mp\zombies\_zm_weapons::get_upgrade_weapon( current_weapon, true );
			}
			else
			{
				upgrade_name = maps\mp\zombies\_zm_weapons::get_upgrade_weapon( current_weapon, upgrade_as_attachment );
			}
			
			player pap_effects( current_weapon, upgrade_name, packa_rollers, perk_machine, self );
			player giveweapon(upgrade_name, 0 , player maps\mp\zombies\_zm_weapons::get_pack_a_punch_weapon_options( upgrade_name ));
			
			if ( is_upgraded )
			{
				new_clip_size = weaponclipsize( upgrade_name );
				if ( clip_ammo > new_clip_size )
					clip_ammo = new_clip_size;
				
				player setweaponammoclip( upgrade_name, clip_ammo );
				player setweaponammostock( upgrade_name, stock_ammo );
			}
			
			player switchtoweapon (upgrade_name);

			self playsound("zmb_perks_packa_upgrade");

			player playsound("zmb_perks_packa_ready");
			player playsound("zmb_cha_ching");

			if ( isDefined( player ) )
			{
				trigger setinvisibletoall();
				trigger setvisibletoplayer( player );
			}
			wait .1;
			self.current_weapon = "";
			trigger setinvisibletoplayer( player );
			wait 1.5;
			trigger setvisibletoall();
			self.pack_player = undefined;
			flag_clear( "pack_machine_in_use" );
		}
		
		if ( isDefined( player ) )
		{
			current_weapon = player getcurrentweapon();
			if ( !can_upgrade_weapon( current_weapon ) )
			{
				Trigger sethintstring( "" );
			}
			else
			{
				cost = getDvarInt( "pap_price" );
				if ( is_weapon_upgraded( current_weapon ) )
				{
					cost = getDvarInt( "repap_price" );
					Trigger sethintstring( "			Hold ^3&&1^7 for Repack-a-Punch [Cost: " + cost + "]" );
				}
				else
				{
					Trigger sethintstring( "			Hold ^3&&1^7 for Pack-a-Punch [Cost: " + cost + "]" );
				}
			}
		}
		
		wait .1;
	}
}

pap_off()
{
	wait 5;
	for(;;)
	{
		level waittill("Pack_A_Punch_on");
		wait 1;
		level notify("Pack_A_Punch_off");
	}
}

pap_effects( current_weapon, upgrade_weapon, packa_rollers, perk_machine, trigger )
{
    level endon( "Pack_A_Punch_off" );
    trigger endon( "pap_player_disconnected" );
    rel_entity = trigger.perk_machine;
    origin_offset = ( 0, 0, 0 );
    angles_offset = ( 0, 0, 0 );
    origin_base = self.origin;
    angles_base = self.angles;

    if ( isdefined( rel_entity ) )
    {
        if ( isdefined( level.pap_interaction_height ) )
            origin_offset = ( 0, 0, level.pap_interaction_height );
        else
            origin_offset = vectorscale( ( 0, 0, 1 ), 35.0 );

        angles_offset = vectorscale( ( 0, 1, 0 ), 90.0 );
        origin_base = rel_entity.origin;
        angles_base = rel_entity.angles;
    }
    else
        rel_entity = self;

    forward = anglestoforward( angles_base + angles_offset );
    interact_offset = origin_offset + forward * -25;

    if ( !isdefined( perk_machine.fx_ent ) )
    {
        perk_machine.fx_ent = spawn( "script_model", origin_base + origin_offset + ( 0, 1, -34 ) );
        perk_machine.fx_ent.angles = angles_base + angles_offset;
        perk_machine.fx_ent setmodel( "tag_origin" );
        perk_machine.fx_ent linkto( perk_machine );
    }

    if ( isdefined( level._effect["packapunch_fx"] ) )
        fx = playfxontag( level._effect["packapunch_fx"], perk_machine.fx_ent, "tag_origin" );

}

// ============================================================
//  Door & Debris Initialization
// ============================================================

monitor_doors()
{
    // Wait for the game to actually place the doors
    level waittill("start_zombie_round_logic");

    // Give the engine's door_think time to populate self.doors and finalize zombie_cost
    // on all triggers before we capture original values (fixes Origins timing race)
    wait 0.5;

    zombie_doors = getentarray("zombie_door", "targetname");
    zombie_debris = getentarray("zombie_debris", "targetname");

    level.custom_doors_and_debris = [];
    
    foreach(door in zombie_doors)
    {
        level.custom_doors_and_debris[level.custom_doors_and_debris.size] = door;
        
        door.original_origin = door.origin;
        door._is_debris = false;

        // Capture original origin/angles on physical door models
        if ( isdefined( door.doors ) )
        {
            for ( j = 0; j < door.doors.size; j++ )
            {
                d = door.doors[j];
                if ( !isdefined( d.og_origin ) )
                    d.og_origin = d.origin;
                if ( !isdefined( d.og_angles ) )
                    d.og_angles = d.angles;
            }
        }
        else if ( isdefined( door.target ) )
        {
            // Fallback: engine hasn't populated door.doors yet, look up brushes directly
            // and populate door.doors so custom_set_door_state can find them later
            brushes = getentarray( door.target, "targetname" );
            if ( isdefined( brushes ) && brushes.size > 0 )
            {
                door.doors = [];
                for ( j = 0; j < brushes.size; j++ )
                {
                    if ( !isdefined( brushes[j].og_origin ) )
                        brushes[j].og_origin = brushes[j].origin;
                    if ( !isdefined( brushes[j].og_angles ) )
                        brushes[j].og_angles = brushes[j].angles;
                    door.doors[door.doors.size] = brushes[j];
                }
            }
        }

        door thread init_custom_door();
        door thread watch_door_open_for_prompt();
    }

    foreach(debris in zombie_debris)
    {
        level.custom_doors_and_debris[level.custom_doors_and_debris.size] = debris;
        
        debris._is_debris = true;
        debris.original_origin = debris.origin;
        debris thread save_debris_siblings_and_pieces();
    }

    wait 0.1;

    for ( i = 0; i < zombie_debris.size; i++ )
    {
        // Give each debris a UNIQUE fake target so getentarray can never find any other entities
        zombie_debris[i].target = "_adv_debris_" + i;
        zombie_debris[i] thread init_custom_door();
        zombie_debris[i] thread watch_door_open_for_prompt();
    }
}

init_custom_door()
{
    if ( !isDefined( self.zombie_cost ) )
    {
        if ( isdefined( self._is_debris ) && self._is_debris )
            self.zombie_cost = 1000;
        else
            return;
    }
    
    if ( self.zombie_cost <= 0 )
        return;

    if ( isDefined( self.script_noteworthy ) && ( self.script_noteworthy == "electric_door" || self.script_noteworthy == "afterlife_door" ) )
        return;

    self.is_half_bought = false;
    self.real_cost = self.zombie_cost;
    self.original_cost = self.zombie_cost;

    // Set engine cost to max so the engine's debris_think/door_think always fails the cost check
    // and never reaches the deletion code. Our watch_use_press handles the real purchase.
    self.zombie_cost = 999999;

    // Default Colors: ^7 (White) for text, ^3 (Orange) for keys/prices
    self sethintstring("^7Press ^3[{+activate}] ^7for ^7" + self.real_cost + "\n^7Press ^3[{+melee}] ^7to Pay Half: ^7" + int(self.real_cost/2));

    self thread watch_use_press();
}

watch_use_press()
{
    self endon("death");
    self endon("trigger_activated");

    while(isDefined(self))
    {
        self waittill("trigger", player);

        if(player.score >= self.real_cost)
        {
            player.score -= self.real_cost;
            self.real_cost = 0;

            // Sync with sibling triggers
            doors = getentarray( "zombie_door", "targetname" );
            debris = getentarray( "zombie_debris", "targetname" );
            foreach ( other in doors )
            {
                if ( other != self && ( (isDefined( self.target ) && isDefined( other.target ) && other.target == self.target) || (isDefined( self.script_flag ) && isDefined( other.script_flag ) && other.script_flag == self.script_flag) ) )
                {
                    other.real_cost = 0;
                    other.zombie_cost = 0;
                    other notify("trigger", player);
                }
            }
            foreach ( other in debris )
            {
                if ( other != self && ( (isDefined( self.target ) && isDefined( other.target ) && other.target == self.target) || (isDefined( self.script_flag ) && isDefined( other.script_flag ) && other.script_flag == self.script_flag) ) )
                {
                    other.real_cost = 0;
                }
            }

            // For debris: intercept the purchase entirely so the engine doesn't delete the triggers
            // IMPORTANT: Do NOT set zombie_cost = 0 here! The engine's debris_think also receives
            // this trigger simultaneously, and if zombie_cost is 0, the engine will pass the cost
            // check and delete all our saved pieces and sibling triggers.
            if ( isdefined( self._is_debris ) && self._is_debris )
            {
                self trigger_off(); // Immediately disable to prevent engine's debris_think from reacting
                self thread custom_open_debris( player );
                return;
            }

            self.zombie_cost = 0; // Temporarily 0 so the engine opens doors
            self notify("trigger", player); // Tell the engine the door was "bought"
            return;
        }
        else
        {
            player playlocalsound( "no_purchase" );
        }
    }
}

// ============================================================
//  Half-Buy via Melee
// ============================================================

watch_melee_pay()
{
    self endon("disconnect");

    while(1)
    {
        // Check if player is pressing the Melee button
        if(self meleebuttonpressed())
        {
            trig = self get_touching_or_closest_trigger();

            // Only allow if it's a valid door, not already open, hasn't been half-bought yet (and not currently holding sprint or recently closed a door)
            if(isDefined(trig) && isDefined(trig.real_cost) && !trig.is_half_bought && !self sprintbuttonpressed() && ( !isDefined( trig._door_open ) || !trig._door_open ) && ( !isDefined( self.last_door_close_time ) || ( gettime() - self.last_door_close_time ) >= 1000 ))
            {
                half_price = int(trig.real_cost / 2);

                if(self.score >= half_price)
                {
                    self.score -= half_price;
                    trig.real_cost -= half_price;
                    trig.is_half_bought = true;

                    // Update hint string to show remaining balance in Orange/White
                    trig sethintstring("^7Press ^3[{+activate}] ^7to pay remaining: ^7" + trig.real_cost);

                    // Sync cost and half-bought state with other triggers sharing the same target
                    if ( isDefined( trig.target ) )
                    {
                        doors = getentarray( "zombie_door", "targetname" );
                        debris = getentarray( "zombie_debris", "targetname" );

                        foreach ( other in doors )
                        {
                            if ( other != trig && ( (isDefined( trig.target ) && isDefined( other.target ) && other.target == trig.target) || (isDefined( trig.script_flag ) && isDefined( other.script_flag ) && other.script_flag == trig.script_flag) ) )
                            {
                                other.real_cost = trig.real_cost;
                                other.is_half_bought = true;
                                other sethintstring( "^7Press ^3[{+activate}] ^7to pay remaining: ^7" + other.real_cost );
                            }
                        }
                        foreach ( other in debris )
                        {
                            if ( other != trig && ( (isDefined( trig.target ) && isDefined( other.target ) && other.target == trig.target) || (isDefined( trig.script_flag ) && isDefined( other.script_flag ) && other.script_flag == trig.script_flag) ) )
                            {
                                other.real_cost = trig.real_cost;
                                other.is_half_bought = true;
                                other sethintstring( "^7Press ^3[{+activate}] ^7to pay remaining: ^7" + other.real_cost );
                            }
                        }
                    }

                    location = self get_origins_zone_name(trig);

                    // Broadcast to everyone in the match
                    players = get_players();
                    foreach(p in players)
                    {
                        p iprintln(self.name + " ^2Paid Half for " + location + "! ^7" + trig.real_cost + " ^7left.");
                    }

                    self playlocalsound("zmb_points_spent");

                    // Debounce: Wait for player to release the melee button
                    while(self meleebuttonpressed()) wait 0.05;
                }
                else
                {
                    self playlocalsound( "no_purchase" );
                    while(self meleebuttonpressed()) wait 0.05;
                }
            }
        }
        wait 0.05;
    }
}

// ============================================================
//  Close Door/Debris Prompt
// ============================================================

watch_door_open_for_prompt()
{
    self endon("death");

    for(;;)
    {
        // Wait until this door/debris is opened
        self waittill("door_opened");

        // Wait 1.5 seconds, but exit if closed during this time
        for ( i = 0; i < 30; i++ )
        {
            wait 0.05;
            if ( !isdefined( self._door_open ) || !self._door_open )
                break;
        }

        // Only show close prompt if the door is STILL open!
        if ( isdefined( self._door_open ) && self._door_open )
        {
            self trigger_on();
            if ( isdefined( self._is_debris ) && self._is_debris )
                self sethintstring("^7Press ^3[Sprint + Melee] ^7to Close Debris");
            else
                self sethintstring("^7Press ^3[Sprint + Melee] ^7to Close Door");

            // Wait until it is closed again
            while ( isdefined( self._door_open ) && self._door_open )
            {
                wait 0.1;
            }
        }
    }
}

// ============================================================
//  Sprint + Melee to Close Door/Debris
// ============================================================

monitor_sprint_melee()
{
    self notify("end_monitor_sprint_melee");
    self endon("end_monitor_sprint_melee");
    self endon("disconnect");
    self endon("death");

    for(;;)
    {
        // Check if player is pressing Sprint and Melee buttons
        if ( self sprintbuttonpressed() && self meleebuttonpressed() )
        {
            // Find closest trigger
            closest_door = undefined;
            closest_dist = 150;

            if ( isdefined( level.custom_doors_and_debris ) )
            {
                for ( i = 0; i < level.custom_doors_and_debris.size; i++ )
                {
                    trig = level.custom_doors_and_debris[i];
                    if ( !isdefined( trig ) ) continue;

                    if ( self istouching( trig ) )
                    {
                        closest_door = trig;
                        break;
                    }

                    dist = distance( self.origin, trig.origin );
                    if ( dist < closest_dist )
                    {
                        closest_dist = dist;
                        closest_door = trig;
                    }
                }
            }

            if ( isdefined( closest_door ) )
            {
                // Only allow closing doors/debris that are currently open
                if ( isdefined( closest_door._door_open ) && closest_door._door_open )
                {
                    self.last_door_close_time = gettime();

                    // Calculate how many points to refund
                    refund_cost = 0;
                    if ( isdefined( closest_door.original_cost ) )
                    {
                        // Use original cost or what was left after half buying
                        refund_cost = closest_door.original_cost;
                        if ( isdefined( closest_door.is_half_bought ) && closest_door.is_half_bought )
                        {
                            // If they only paid half
                            refund_cost = int( closest_door.original_cost / 2 );
                        }
                        if ( isdefined( closest_door.real_cost ) )
                        {
                            refund_cost = closest_door.original_cost - closest_door.real_cost;
                        }
                    }
                    else if ( isdefined( closest_door.zombie_cost ) && closest_door.zombie_cost > 0 && closest_door.zombie_cost < 999999 )
                    {
                        refund_cost = closest_door.zombie_cost;
                    }

                    if ( refund_cost > 0 )
                    {
                        self maps\mp\zombies\_zm_score::add_to_player_score( refund_cost );
                        self playlocalsound( "zmb_point_earn_barrier" ); // Play a light feedback sound
                    }

                    // ---- DEBRIS CLOSE PATH ----
                    if ( isdefined( closest_door._is_debris ) && closest_door._is_debris )
                    {
                        closest_door custom_close_debris();
                        wait 1.5;
                    }
                    // ---- DOOR CLOSE PATH ----
                    else
                    {
                        cost = 1000;
                        if ( isdefined( closest_door.original_cost ) )
                            cost = closest_door.original_cost;
                        else if ( isdefined( closest_door.zombie_cost ) )
                            cost = closest_door.zombie_cost;

                        // Check if it is a Mob of the Dead Afterlife Door
                        if ( isdefined( closest_door.script_noteworthy ) && closest_door.script_noteworthy == "afterlife_door" )
                        {
                            closest_door custom_set_door_state( false );
                            closest_door notify( "door_closed" ); // Signal to any old monitors

                            s_struct = getstruct( closest_door.target, "targetname" );
                            if ( isdefined( s_struct ) )
                            {
                                m_shockbox = getent( s_struct.target, "targetname" );
                                if ( isdefined( m_shockbox ) )
                                {
                                    // Reset shock box visuals
                                    m_shockbox setmodel( "p6_zm_al_shock_box_off" );
                                    if ( isdefined( level.shockbox_anim ) )
                                    {
                                        m_shockbox setanim( level.shockbox_anim["off"] );
                                    }

                                    // Re-spawn the afterlife trigger radius for the shock box
                                    t_bump = spawn( "trigger_radius", m_shockbox.origin, 0, 28, 64 );
                                    t_bump.origin = m_shockbox.origin + anglestoforward( m_shockbox.angles ) * 0 + anglestoright( m_shockbox.angles ) * 28 + anglestoup( m_shockbox.angles ) * 0;
                                    t_bump setcursorhint( "HINT_NOICON" );
                                    t_bump sethintstring( &"ZM_PRISON_AFTERLIFE_INTERACT" );

                                    // Start monitor threads to handle shocking and trigger cleanups
                                    level thread monitor_shockbox_reopen( closest_door, m_shockbox, t_bump );
                                    level thread watch_t_bump_cleanup( closest_door, t_bump );
                                }
                            }
                        }
                        else
                        {
                            // Handle standard map doors
                            all_trigs = [];
                            if ( isdefined( closest_door.target ) )
                            {
                                targets = getentarray( closest_door.target, "target" );
                                if ( isdefined( targets ) )
                                {
                                    for( i=0; i<targets.size; i++ ) all_trigs[all_trigs.size] = targets[i];
                                }
                            }
                            if ( isdefined( closest_door.script_flag ) )
                            {
                                doors = getentarray( "zombie_door", "targetname" );
                                for( i=0; i<doors.size; i++ )
                                {
                                    if ( isdefined( doors[i].script_flag ) && doors[i].script_flag == closest_door.script_flag )
                                    {
                                        is_dup = false;
                                        for( j=0; j<all_trigs.size; j++ ) { if( all_trigs[j] == doors[i] ) { is_dup = true; break; } }
                                        if ( !is_dup ) all_trigs[all_trigs.size] = doors[i];
                                    }
                                }
                            }

                            if ( all_trigs.size > 0 )
                            {
                                for ( i = 0; i < all_trigs.size; i++ )
                                {
                                    trig = all_trigs[i];

                                    // Physically close the door
                                    trig custom_set_door_state( false );

                                    // Restore original origin in case trigger_off offset got stacked
                                    if ( isdefined( trig.original_origin ) )
                                    {
                                        trig.origin = trig.original_origin;
                                        trig.realorigin = trig.original_origin; // Force alignment
                                        trig.trigger_off = undefined;
                                    }

                                    trig trigger_on();

                                    if ( isdefined( trig.original_cost ) )
                                    {
                                        // Reset shared doors script status
                                        trig.real_cost = trig.original_cost;
                                        trig.zombie_cost = 999999;
                                        trig.is_half_bought = false;
                                        trig sethintstring("^7Press ^3[{+activate}] ^7for ^7" + trig.real_cost + "\n^7Press ^3[{+melee}] ^7to Pay Half: ^7" + int(trig.real_cost/2));

                                        trig notify("trigger_activated");
                                        trig thread watch_shared_door_use_press( closest_door );
                                    }
                                    else if ( isdefined( trig.script_noteworthy ) && ( trig.script_noteworthy == "electric_door" || trig.script_noteworthy == "local_electric_door" ) )
                                    {
                                        trig sethintstring( "Press [Use] or ADS + Melee to Open" );
                                        trig thread monitor_manual_reopen( closest_door );
                                    }
                                    else
                                    {
                                        cost = 1000;
                                        if ( isdefined( closest_door.original_cost ) ) cost = closest_door.original_cost;
                                        else if ( isdefined( closest_door.zombie_cost ) ) cost = closest_door.zombie_cost;
                                        trig sethintstring( "Hold [{+activate}] to buy door [Cost: " + cost + "]" );
                                        trig thread monitor_manual_reopen( closest_door );
                                    }
                                }
                            }
                        }

                        // Cooldown to prevent spam / double-triggering
                        wait 1.5;
                    }
                }
            }
        }
        wait 0.05;
    }
}

// ============================================================
//  Door Reopen Helpers
// ============================================================

/// Allows the player to reopen a standard closed door by pressing the normal Use button
monitor_manual_reopen( door_trig )
{
    self endon( "door_opened" );
    self endon( "kill_door_think" );

    self waittill( "trigger", player );

    door_trig custom_set_door_state( true );
}

// Intercepts Use activations for shared doors to process point logic and pay mechanics
watch_shared_door_use_press( door )
{
    self endon( "death" );
    self endon( "door_opened" );

    while ( isdefined( self ) )
    {
        self waittill( "trigger", player );

        if ( player.score >= self.real_cost )
        {
            player.score -= self.real_cost;
            self.real_cost = 0;

            // Sync with sibling triggers
            doors = getentarray( "zombie_door", "targetname" );
            debris = getentarray( "zombie_debris", "targetname" );
            foreach ( other in doors )
            {
                if ( other != self && ( (isDefined( self.target ) && isDefined( other.target ) && other.target == self.target) || (isDefined( self.script_flag ) && isDefined( other.script_flag ) && other.script_flag == self.script_flag) ) )
                {
                    other.real_cost = 0;
                    other.zombie_cost = 0;
                    other notify("trigger", player);
                }
            }
            foreach ( other in debris )
            {
                if ( other != self && ( (isDefined( self.target ) && isDefined( other.target ) && other.target == self.target) || (isDefined( self.script_flag ) && isDefined( other.script_flag ) && other.script_flag == self.script_flag) ) )
                {
                    other.real_cost = 0;
                }
            }

            // Play purchase confirmation and points-spent sounds
            play_sound_at_pos( "purchase", self.origin );
            player playlocalsound( "zmb_points_spent" );

            self.zombie_cost = 0; // Temp 0 so default code understands it's paid

            door custom_set_door_state( true );
            return;
        }
        
    }
}

// ============================================================
//  Debris Save / Open Detection / Close / Reopen
// ============================================================

// Replaces the engine's default debris_init to set up costs and flags
// without starting the default debris_think thread loop.
custom_debris_init()
{
    self.zombie_cost = 1000;

    if ( isdefined( self.script_noteworthy ) )
    {
        cost = int( self.script_noteworthy );
        if ( cost > 0 )
            self.zombie_cost = cost;
    }

    if ( isdefined( self.script_flag ) && !isdefined( level.flag[self.script_flag] ) )
        flag_init( self.script_flag );
}

// Detours create_and_play_dialog to suppress character deny quotes when they touch
// a door or debris blocker that they actually have enough score to purchase.
custom_create_and_play_dialog( category, type, response, force_variant, override )
{
    if ( isdefined( type ) && type == "door_deny" )
    {
        trig = self get_touching_or_closest_trigger();
        if ( isdefined( trig ) )
        {
            cost = trig.real_cost;
            if ( !isdefined( cost ) )
                cost = trig.zombie_cost;
            if ( isdefined( trig.original_cost ) )
                cost = trig.original_cost;

            if ( self.score >= cost )
            {
                return; // Suppress character complain dialog
            }
        }
    }

    waittime = 0.25;

    if ( !isdefined( self.zmbvoxid ) )
    {
        return;
    }

    if ( isdefined( self.dontspeak ) && self.dontspeak )
        return;

    isresponse = 0;
    alias_suffix = undefined;
    index = undefined;
    prefix = undefined;

    if ( !isdefined( level.vox.speaker[self.zmbvoxid].alias[category][type] ) )
        return;

    prefix = level.vox.speaker[self.zmbvoxid].prefix;
    alias_suffix = level.vox.speaker[self.zmbvoxid].alias[category][type];

    if ( self is_player() )
    {
        if ( self.sessionstate != "playing" )
            return;

        if ( self maps\mp\zombies\_zm_laststand::player_is_in_laststand() && ( type != "revive_down" || type != "revive_up" ) )
            return;

        index = maps\mp\zombies\_zm_weapons::get_player_index( self );
        prefix = prefix + index + "_";
    }

    if ( isdefined( response ) )
    {
        if ( isdefined( level.vox.speaker[self.zmbvoxid].response[category][type] ) )
            alias_suffix = response + level.vox.speaker[self.zmbvoxid].response[category][type];

        isresponse = 1;
    }

    sound_to_play = self zmbvoxgetlinevariant( prefix, alias_suffix, force_variant, override );

    if ( isdefined( sound_to_play ) )
    {
        if ( isdefined( level._audio_custom_player_playvox ) )
            self thread [[ level._audio_custom_player_playvox ]]( prefix, index, sound_to_play, waittime, category, type, override );
        else
            self thread maps\mp\zombies\_zm_audio::do_player_or_npc_playvox( prefix, index, sound_to_play, waittime, category, type, override, isresponse );
    }
}

// Saves debris piece entities at init time BEFORE the engine can delete them
save_debris_siblings_and_pieces()
{
    self._saved_pieces = [];
    self._sibling_trigs = [];

    // Always include self in the siblings list so it gets processed
    self._sibling_trigs[0] = self;

    if ( isdefined( self.target ) )
    {
        pieces = getentarray( self.target, "targetname" );
        if ( isdefined( pieces ) )
        {
            for ( i = 0; i < pieces.size; i++ )
            {
                pieces[i].og_origin = pieces[i].origin;
                pieces[i].og_angles = pieces[i].angles;
                self._saved_pieces[self._saved_pieces.size] = pieces[i];
            }
        }

        trigs = getentarray( self.target, "target" );
        if ( isdefined( trigs ) )
        {
            for ( i = 0; i < trigs.size; i++ )
            {
                if ( trigs[i] != self )
                    self._sibling_trigs[self._sibling_trigs.size] = trigs[i];
            }
        }
    }

    if ( isdefined( self.script_flag ) )
    {
        doors = getentarray( "zombie_door", "targetname" );
        debris = getentarray( "zombie_debris", "targetname" );
        
        for ( i = 0; i < doors.size; i++ )
        {
            if ( doors[i] != self && isdefined( doors[i].script_flag ) && doors[i].script_flag == self.script_flag )
            {
                is_dup = false;
                for ( j = 0; j < self._sibling_trigs.size; j++ ) { if ( self._sibling_trigs[j] == doors[i] ) { is_dup = true; break; } }
                if ( !is_dup ) self._sibling_trigs[self._sibling_trigs.size] = doors[i];
            }
        }
        for ( i = 0; i < debris.size; i++ )
        {
            if ( debris[i] != self && isdefined( debris[i].script_flag ) && debris[i].script_flag == self.script_flag )
            {
                is_dup = false;
                for ( j = 0; j < self._sibling_trigs.size; j++ ) { if ( self._sibling_trigs[j] == debris[i] ) { is_dup = true; break; } }
                if ( !is_dup ) self._sibling_trigs[self._sibling_trigs.size] = debris[i];
            }
        }
    }
}

// Animate debris moving out of the way before hiding it
custom_debris_move( struct )
{
    self endon("death");
    
    self notsolid();

    if ( isdefined( self.script_firefx ) && isdefined( level._effect ) && isdefined( level._effect[self.script_firefx] ) )
        playfx( level._effect[self.script_firefx], self.origin );
    
    time = 0.5;
    if ( isdefined( self.script_transition_time ) )
        time = self.script_transition_time;
        
    self moveto( struct.origin, time, time * 0.5 );
    if ( isdefined( struct.angles ) )
        self rotateto( struct.angles, time * 0.75 );
        
    self waittill( "movedone" );

    if ( isdefined( self.script_fxid ) && isdefined( level._effect ) && isdefined( level._effect[self.script_fxid] ) )
    {
        playfx( level._effect[self.script_fxid], self.origin );
        playsoundatposition( "zmb_zombie_spawn", self.origin );
    }

    self hide();
}

// Animate debris moving back to its original position when closing
custom_debris_move_close()
{
    self endon("death");
    
    // Unhide but keep notsolid while moving
    self show();
    self notsolid();
    
    time = 0.5;
    if ( isdefined( self.script_transition_time ) )
        time = self.script_transition_time;
        
    if ( isdefined( self.og_origin ) )
        self moveto( self.og_origin, time, time * 0.5 );
    if ( isdefined( self.og_angles ) )
        self rotateto( self.og_angles, time * 0.75 );
        
    self waittill( "movedone" );
    
    self solid();
    if ( isdefined( self.script_noteworthy ) && self.script_noteworthy == "clip" )
        self disconnectpaths();
}

// Custom debris purchase handler: bypasses engine to prevent trigger deletion, hides models instead
custom_open_debris( player )
{
    self endon("death");

    play_sound_at_pos( "purchase", self.origin );
    level notify( "junk purchased" );
    if ( isdefined( player ) )
        player playlocalsound( "zmb_points_spent" );
    playsoundatposition( "zmb_lightning_l", self.origin );

    if ( isdefined( self.script_flag ) )
    {
        tokens = strtok( self.script_flag, "," );
        for ( i = 0; i < tokens.size; i++ )
            flag_set( tokens[i] );
    }

    if ( isdefined( self._saved_pieces ) )
    {
        for ( i = 0; i < self._saved_pieces.size; i++ )
        {
            piece = self._saved_pieces[i];
            if ( isdefined( piece ) )
            {
                if ( isdefined( piece.script_noteworthy ) && piece.script_noteworthy == "clip" )
                    piece connectpaths();
                    
                if ( isdefined( piece.script_linkto ) )
                {
                    struct = getstruct( piece.script_linkto, "script_linkname" );
                    if ( isdefined( struct ) )
                    {
                        piece thread custom_debris_move( struct );
                        continue;
                    }
                }
                
                if ( isdefined( piece.script_fxid ) && isdefined( level._effect ) && isdefined( level._effect[piece.script_fxid] ) )
                {
                    playfx( level._effect[piece.script_fxid], piece.origin );
                    playsoundatposition( "zmb_zombie_spawn", piece.origin );
                }

                piece notsolid();
                piece hide();
            }
        }
    }

    // Force trigger state and update sibling triggers
    self._door_open = true;
    self notify("door_opened");

    if ( isdefined( self._sibling_trigs ) )
    {
        foreach ( other in self._sibling_trigs )
        {
            if ( isdefined( other ) )
            {
                other._door_open = true;
                other trigger_off();
                other notify("door_opened");
            }
        }
    }

    wait 1.0;
    if ( isdefined( self._sibling_trigs ) )
    {
        foreach ( other in self._sibling_trigs )
        {
            if ( isdefined( other ) && isdefined( other._door_open ) && other._door_open )
            {
                other trigger_on();
                other sethintstring("^7Press ^3[Sprint + Melee] ^7to Close Debris");
            }
        }
    }
}

// Closes debris by unhiding saved models and resetting the trigger for re-purchase
custom_close_debris()
{
    self._door_open = false;

    // Show and animate saved debris pieces
    if ( isdefined( self._saved_pieces ) )
    {
        for ( i = 0; i < self._saved_pieces.size; i++ )
        {
            piece = self._saved_pieces[i];
            if ( isdefined( piece ) )
            {
                if ( isdefined( piece.script_linkto ) )
                {
                    piece thread custom_debris_move_close();
                    continue;
                }

                if ( isdefined( piece.og_origin ) )
                    piece.origin = piece.og_origin;
                if ( isdefined( piece.og_angles ) )
                    piece.angles = piece.og_angles;
                    
                piece show();
                piece solid();
                if ( isdefined( piece.script_noteworthy ) && piece.script_noteworthy == "clip" )
                    piece disconnectpaths();
            }
        }
    }

    // Play closing sound and lightning FX (matches the opening FX)
    play_sound_at_pos( "door_slide_open", self.origin );
    playsoundatposition( "zmb_lightning_l", self.origin );

    // Reset trigger and sibling triggers for re-purchase
    all_trigs = self._sibling_trigs;
    if ( !isdefined( all_trigs ) || all_trigs.size == 0 )
        all_trigs[0] = self;

    for ( i = 0; i < all_trigs.size; i++ )
    {
        trig = all_trigs[i];
        if ( isdefined( trig ) )
        {
            trig._door_open = false;
            if ( isdefined( trig.original_cost ) )
            {
                trig.real_cost = trig.original_cost;
                trig.zombie_cost = 999999;
                trig.is_half_bought = false;
                trig sethintstring("^7Press ^3[{+activate}] ^7for ^7" + trig.real_cost + "\n^7Press ^3[{+melee}] ^7to Pay Half: ^7" + int(trig.real_cost/2));
            }
            trig trigger_on();
            trig notify("trigger_activated"); // Kill old watchers
            trig thread watch_debris_reopen();
        }
    }
}

// Handles re-purchasing closed debris: charges points, deletes respawned models, plays sounds
watch_debris_reopen()
{
    self endon("death");
    self endon("trigger_activated");

    while ( isdefined( self ) )
    {
        self waittill( "trigger", player );

        if ( isdefined( self.real_cost ) && player.score >= self.real_cost )
        {
            player.score -= self.real_cost;
            self.real_cost = 0;

            // Sync with sibling triggers
            doors = getentarray( "zombie_door", "targetname" );
            debris = getentarray( "zombie_debris", "targetname" );
            foreach ( other in doors )
            {
                if ( (isDefined( self.target ) && isDefined( other.target ) && other.target == self.target) || (isDefined( self.script_flag ) && isDefined( other.script_flag ) && other.script_flag == self.script_flag) )
                    other.real_cost = 0;
            }
            foreach ( other in debris )
            {
                if ( (isDefined( self.target ) && isDefined( other.target ) && other.target == self.target) || (isDefined( self.script_flag ) && isDefined( other.script_flag ) && other.script_flag == self.script_flag) )
                    other.real_cost = 0;
            }

            self thread custom_open_debris( player );
            return;
        }
        else
        {
            player playlocalsound( "no_purchase" );
        }
    }
}

// ============================================================
//  Afterlife Shock Box (Mob of the Dead)
// ============================================================

// Waits for the afterlife shock box to take damage from afterlife hands to reopen the door
monitor_shockbox_reopen( door, m_shockbox, t_bump )
{
    door endon( "door_opened" );
    door endon( "door_closed" );

    while ( true )
    {
        m_shockbox waittill( "damage", amount, attacker );

        if ( isplayer( attacker ) && attacker getcurrentweapon() == "lightning_hands_zm" )
        {
            if ( isdefined( level.afterlife_interact_dist ) )
            {
                if ( distance2d( attacker.origin, m_shockbox.origin ) < level.afterlife_interact_dist )
                {
                    if ( isdefined( t_bump ) )
                    {
                        t_bump delete();
                    }

                    m_shockbox playsound( "zmb_powerpanel_activate" );
                    playfxontag( level._effect["box_activated"], m_shockbox, "tag_origin" );
                    m_shockbox setmodel( "p6_zm_al_shock_box_on" );
                    if ( isdefined( level.shockbox_anim ) )
                    {
                        m_shockbox setanim( level.shockbox_anim["on"] );
                    }

                    // Open the door
                    door custom_set_door_state( true );
                    door thread delayed_door_opened_notify();

                    attacker notify( "player_opened_afterlife_door" );
                    break;
                }
            }
        }
    }
}

delayed_door_opened_notify()
{
    wait 0.1;
    self notify( "door_opened" );
}

// Cleans up the spawned afterlife trigger if the door is forced open by the player using ADS + Melee
watch_t_bump_cleanup( door, t_bump )
{
    door endon( "door_closed" );
    door waittill_any( "door_opened", "death" );
    if ( isdefined( t_bump ) )
    {
        t_bump delete();
    }
}

// ============================================================
//  Door Physics & Sounds
// ============================================================

// Sets the door open or closed state using custom movement and physics logic
// Now plays appropriate door movement sounds for each brush
custom_set_door_state( open )
{
    self._door_open = open;

    // Move brushes first while self.doors is guaranteed to be defined
    if ( isdefined( self.doors ) )
    {
        // Play purchase sound when re-opening a door
        if ( open )
            play_sound_at_pos( "purchase", self.doors[0].origin );

        for ( i = 0; i < self.doors.size; i++ )
        {
            brush = self.doors[i];
            if ( !isdefined( brush ) )
                continue;
            brush.door_moving = undefined;

            time = 1.0;
            if ( isdefined( brush.script_transition_time ) )
                time = brush.script_transition_time;

            if ( isdefined( brush.script_noteworthy ) && brush.script_noteworthy == "clip" || isdefined( brush.script_string ) && brush.script_string == "clip" )
            {
                // Clip handling (no sound for clips)
                if ( open )
                {
                    brush connectpaths();
                    brush notsolid();
                }
                else
                {
                    brush disconnectpaths();
                    brush solid();
                }
            }
            else
            {
                // Moving brush/model handling
                brush notsolid();

                // Play door movement sound on each brush
                // Use the same sound for both open and close ("_close" variants often don't exist)
                if ( isdefined( brush.script_sound ) )
                {
                    playsoundatposition( brush.script_sound, brush.origin );
                }
                else
                {
                    play_sound_at_pos( "door_slide_open", brush.origin );
                }

                if ( open )
                {
                    brush connectpaths();

                    if ( isdefined( brush.script_string ) && brush.script_string == "rotate" )
                    {
                        if ( isdefined( brush.script_angles ) )
                            brush rotateto( brush.script_angles, time, 0, 0 );
                    }
                    else if ( isdefined( brush.script_string ) && brush.script_string == "anim" )
                    {
                        if ( isdefined( level.blocker_anim_func ) && isdefined( brush.script_animname ) )
                            brush thread [[ level.blocker_anim_func ]]( brush.script_animname );
                    }
                    else // "move" or "slide_apart"
                    {
                        if ( isdefined( brush.script_vector ) )
                            brush moveto( brush.og_origin + brush.script_vector, time, time * 0.25, time * 0.25 );
                    }

                    brush thread make_solid_after_move( time, true );
                }
                else // close
                {
                    // Ensure brush is visible (engine may have hide()'d it when opening)
                    brush show();

                    if ( isdefined( brush.script_string ) && brush.script_string == "rotate" )
                    {
                        if ( isdefined( brush.og_angles ) )
                            brush rotateto( brush.og_angles, time, 0, 0 );
                    }
                    else if ( isdefined( brush.script_string ) && brush.script_string == "anim" )
                    {
                        if ( isdefined( level.blocker_anim_func ) && isdefined( brush.script_animname ) )
                            brush thread [[ level.blocker_anim_func ]]( brush.script_animname );
                    }
                    else // "move" or "slide_apart"
                    {
                        if ( isdefined( brush.og_origin ) )
                            brush moveto( brush.og_origin, time, time * 0.25, time * 0.25 );
                    }

                    brush thread make_solid_after_move( time, false );
                }
            }
        }
    }
    else if ( !open && isdefined( self.target ) )
    {
        // Fallback: self.doors was never populated (e.g. Origins), look up brushes directly
        brushes = getentarray( self.target, "targetname" );
        if ( isdefined( brushes ) )
        {
            play_sound_at_pos( "door_slide_open", self.origin );

            for ( i = 0; i < brushes.size; i++ )
            {
                brush = brushes[i];
                if ( !isdefined( brush ) )
                    continue;

                time = 1.0;
                if ( isdefined( brush.script_transition_time ) )
                    time = brush.script_transition_time;

                if ( isdefined( brush.script_noteworthy ) && brush.script_noteworthy == "clip" || isdefined( brush.script_string ) && brush.script_string == "clip" )
                {
                    brush disconnectpaths();
                    brush solid();
                }
                else
                {
                    brush show();
                    brush notsolid();

                    if ( isdefined( brush.script_sound ) )
                        playsoundatposition( brush.script_sound, brush.origin );

                    if ( isdefined( brush.script_string ) && brush.script_string == "rotate" )
                    {
                        if ( isdefined( brush.og_angles ) )
                            brush rotateto( brush.og_angles, time, 0, 0 );
                    }
                    else if ( isdefined( brush.script_string ) && brush.script_string == "anim" )
                    {
                        if ( isdefined( level.blocker_anim_func ) && isdefined( brush.script_animname ) )
                            brush thread [[ level.blocker_anim_func ]]( brush.script_animname );
                    }
                    else
                    {
                        if ( isdefined( brush.og_origin ) )
                            brush moveto( brush.og_origin, time, time * 0.25, time * 0.25 );
                    }

                    brush thread make_solid_after_move( time, false );
                }
            }
        }
    }

    // Notify all triggers about the state change after brushes have started moving
    all_trigs = getentarray( self.target, "target" );
    foreach ( trig in all_trigs )
    {
        trig._door_open = open;
        if ( open )
        {
            trig notify( "door_opened" );
            trig.door_is_moving = undefined;
            trig trigger_off();
        }
        else
        {
            trig.door_is_moving = undefined;
            trig.trigger_off = undefined;
            trig trigger_on();
        }
    }
}

// Threaded logic to make door models solid again after moving, avoiding physics gaps or overlaps
make_solid_after_move( time, open )
{
    self endon( "death" );
    self notify( "start_solid_watch" );
    self endon( "start_solid_watch" );

    self waittill_either( "rotatedone", "movedone" );

    if ( !open )
    {
        self disconnectpaths();
    }

    while ( true )
    {
        players = get_players();
        player_touching = 0;
        for ( i = 0; i < players.size; i++ )
        {
            if ( players[i] istouching( self ) )
            {
                player_touching = 1;
                break;
            }
        }
        if ( !player_touching )
        {
            self solid();
            break;
        }
        wait 0.2;
    }
}

// ============================================================
//  Utilities
// ============================================================

get_origins_zone_name(trig)
{
    zone = trig.script_noteworthy;

    if(!isDefined(zone) && isDefined(trig.target))
        zone = trig.target;

    if(!isDefined(zone)) return "a door";

    switch(zone)
    {
        case "zone_village_0":
        case "zone_village_1":
        case "village_door_1": return "Spawn Room";

        case "zone_village_2":
        case "gen2_door":      return "Gen 2 Path";

        case "zone_village_3":
        case "gen3_door":      return "Gen 3 Path";

        case "zone_nml_0":     return "the Workshop";
        case "zone_nml_1":     return "No Man's Land";
        case "zone_nml_4":     return "Gen 4 (Juggernog)";
        case "zone_nml_5":     return "Gen 5 (Stamin-Up)";
        case "zone_nml_8":     return "the Excavation Site";

        case "zone_church_0":  return "the Church Entrance";
        case "zone_church_1":  return "the Church Upstairs";

        default:
            if(zone == "zombie_door" || zone == "default") return "a door";
            return "the " + zone;
    }
}

get_touching_trigger()
{
    // Search both doors and debris
    all_trigs = getentarray("zombie_door", "targetname");
    debris = getentarray("zombie_debris", "targetname");

    foreach(trig in all_trigs)
        if(self istouching(trig)) return trig;

    foreach(trig in debris)
        if(self istouching(trig)) return trig;

    return undefined;
}

get_touching_or_closest_trigger()
{
    trig = self get_touching_trigger();
    if ( isdefined( trig ) )
        return trig;

    all_trigs = getentarray("zombie_door", "targetname");
    debris = getentarray("zombie_debris", "targetname");

    closest = undefined;
    min_dist_sq = 65536; // 256 units squared (256 * 256)

    foreach(trig in all_trigs)
    {
        dist_sq = distancesquared(self.origin, trig.origin);
        if ( dist_sq < min_dist_sq )
        {
            min_dist_sq = dist_sq;
            closest = trig;
        }
    }

    foreach(trig in debris)
    {
        dist_sq = distancesquared(self.origin, trig.origin);
        if ( dist_sq < min_dist_sq )
        {
            min_dist_sq = dist_sq;
            closest = trig;
        }
    }

    return closest;
}


// ============================================================================
// MULE KICK - COMBINED MONITOR (was 3 threads, now 1!)
// ============================================================================

mule_kick_monitor_combined()
{
    self endon( "disconnect" );
    
    if(self.mule_monitor_running)
        return;
    self.mule_monitor_running = true;
    
    was_has_perk = self hasperk( "specialty_additionalprimaryweapon" ); 

    for(;;)
    {
        wait 0.5;
        
        now_has_perk = self hasperk( "specialty_additionalprimaryweapon" );

        // RESTORE: We didn't have it, now we do
        if( !was_has_perk && now_has_perk )
        {
            if( IsDefined( self.retain_mule_weapon ) && self.retain_mule_weapon != "knife_zm" )
            {
                self weapon_give( self.retain_mule_weapon ); 
                self.retain_mule_weapon = undefined;
            }
        }
        
        // SAVE: Track the 3rd weapon while we have the perk
        if ( now_has_perk )
        {
            primaries = self getweaponslistprimaries();
            if ( primaries.size >= 3 )
            {
                self.last_known_mule_weapon = primaries[2];
            }
            
            // Auto-reload non-current weapons (mule kick ammo fix)
            foreach( weapon in primaries )
            {
                if( weapon != self getcurrentweapon() )
                {
                    if( weaponclipsize( weapon ) > self getweaponammoclip( weapon ) && self getammocount( weapon ) > self getweaponammoclip( weapon ) )
                    {
                        self setweaponammostock( weapon, self getweaponammostock( weapon ) - 1 );
                        self setweaponammoclip( weapon, self getweaponammoclip( weapon ) + 1 );
                    }
                }
            }
        }
        else
        {
            self.last_known_mule_weapon = undefined;
        }
        
        was_has_perk = now_has_perk;
    }
}

mule_on_player_downed()
{
    self endon( "disconnect" );
    
    if(IsDefined(self.mule_down_running) && self.mule_down_running)
        return;
    self.mule_down_running = true;

    for (;;)
    {
        self waittill_any( "player_downed", "fake_death", "bled_out" );
        
        if ( IsDefined( self.last_known_mule_weapon ) && self.last_known_mule_weapon != "knife_zm" ) 
        {
            if ( !IsDefined( self.keep_perks ) || !self.keep_perks )
            {
                self.retain_mule_weapon = self.last_known_mule_weapon;
            }
        }
        
        self waittill_any( "spawned_player", "player_revived" );
    }
}

// ============================================================================
// DAMAGE & SCORE OVERRIDES (from perks.gsc)
// ============================================================================

custom_player_add_points_kill_bonus( mod, hit_location )
{
    if ( mod == "MOD_MELEE" )
    {
        self score_cf_increment_info( "death_melee" );
        return level.zombie_vars[ "zombie_score_bonus_melee" ];
    }
    
    if ( mod == "MOD_BURNED" )
    {
        self score_cf_increment_info( "death_torso" );
        return level.zombie_vars[ "zombie_score_bonus_burn" ];
    }
    
    score = 0;
    if ( IsDefined( hit_location ) )
    {
        switch( hit_location )
        {
            case "head":
            case "helmet":
                self score_cf_increment_info( "death_head" );
                score = level.zombie_vars[ "zombie_score_bonus_head" ];
                if ( self HasPerk("specialty_deadshot") ) score += 50;
                break;
            case "neck":
                self score_cf_increment_info( "death_neck" );
                score = level.zombie_vars[ "zombie_score_bonus_neck" ];
                break;
            case "torso_lower":
            case "torso_upper":
                self score_cf_increment_info( "death_torso" );
                score = level.zombie_vars[ "zombie_score_bonus_torso" ];
                break;
            default:
                self score_cf_increment_info( "death_normal" );
                break;
        }
    }
    return score;
}

custom_actor_damage_override_wrapper( inflictor, attacker, damage, flags, meansofdeath, weapon, vpoint, vdir, shitloc, psoffsettime, boneindex )
{
    damage_override = self custom_actor_damage_override( inflictor, attacker, damage, flags, meansofdeath, weapon, vpoint, vdir, shitloc, psoffsettime );
    
    if ( damage < self.health || IsDefined( self.dont_die_on_me ) && !self.dont_die_on_me )
    {
        self finishactordamage( inflictor, attacker, damage_override, flags, meansofdeath, weapon, vpoint, vdir, shitloc, psoffsettime, boneindex );
    }
    else if (damage_override >= self.health)
    {
        self finishactordamage( inflictor, attacker, damage_override, flags, meansofdeath, weapon, vpoint, vdir, shitloc, psoffsettime, boneindex );
    }
}

custom_actor_damage_override( inflictor, attacker, damage, flags, meansofdeath, weapon, vpoint, vdir, shitloc, psoffsettime )
{
    if ( !IsDefined( self ) || !IsDefined( attacker ) ) return damage;
    
    if ( weapon == "tazer_knuckles_zm" || weapon == "jetgun_zm" ) self.knuckles_extinguish_flames = 1;
    else if ( weapon != "none" ) self.knuckles_extinguish_flames = undefined;
    
    if ( IsDefined( attacker.animname ) && attacker.animname == "quad_zombie" )
    {
        if ( IsDefined( self.animname ) && self.animname == "quad_zombie" ) return 0;
    }
    
    if ( !isplayer( attacker ) && IsDefined( self.non_attacker_func ) )
        return self [[ self.non_attacker_func ]]( damage, weapon );
    
    if ( !isplayer( attacker ) && !isplayer( self ) ) return damage;
    if ( !IsDefined( damage ) || !IsDefined( meansofdeath ) ) return damage;
    if ( meansofdeath == "" ) return damage;
    
    final_damage = damage;

    if ( IsDefined( self.actor_damage_func ) )
    {
        final_damage = [[ self.actor_damage_func ]]( inflictor, attacker, final_damage, flags, meansofdeath, weapon, vpoint, vdir, shitloc, psoffsettime );
    }

    if ( isplayer(attacker) && attacker HasPerk("specialty_deadshot") )
    {
        if ( shitloc == "head" || shitloc == "helmet" ) final_damage = final_damage * 2;
    }
    
    if ( attacker.classname == "script_vehicle" && IsDefined( attacker.owner ) ) attacker = attacker.owner;
    
    if ( IsDefined( self.in_water ) && self.in_water )
    {
        if ( int( final_damage ) >= self.health ) self.water_damage = 1;
    }
    
    attacker thread maps\mp\gametypes_zm\_weapons::checkhit( weapon );
    
    if ( IsDefined( attacker.pers_upgrades_awarded[ "multikill_headshots" ] ) && attacker.pers_upgrades_awarded[ "multikill_headshots" ] && (shitloc == "head" || shitloc == "helmet") )
    {
        final_damage *= 2;
    }
    
    if ( IsDefined( level.headshots_only ) && level.headshots_only && IsDefined( attacker ) && isplayer( attacker ) )
    {
        if ( meansofdeath == "MOD_MELEE" || shitloc == "head" || shitloc == "helmet" ) return int( final_damage );
        if ( is_explosive_damage( meansofdeath ) ) return int( final_damage );
        else if ( !(shitloc == "head" || shitloc == "helmet") ) return 0;
    }
    
    return int( final_damage );
}

// ============================================================================
// LEVEL THREADS (from HRpatch)
// ============================================================================

zombie_health_cap()
{
    for(;;)
    {
        level waittill("start_of_round");
        if(level.zombie_health > 100000) level.zombie_health = 100000;
    }
}

// ============================================================================
// SHARED BOX SYSTEM
// ============================================================================

CheckForCurrentBox()
{
    flag_wait( "initial_blackscreen_passed" );
    if( getdvar( "mapname" ) == "zm_nuked" )
    {
        wait 10;
    }

    if ( getdvar( "mapname" ) == "zm_buried" )
    {
        wait 5;
        if ( isdefined( level.maze_chests ) && level.maze_chests.size > 0 )
        {
            for ( i = 0; i < level.maze_chests.size; i++ )
            {
                found = false;
                for ( j = 0; j < level.chests.size; j++ )
                {
                    if ( level.chests[j] == level.maze_chests[i] )
                    {
                        found = true;
                        break;
                    }
                }
                if ( !found )
                {
                    level.chests[level.chests.size] = level.maze_chests[i];
                }
            }
        }

        trig = getent( "maze_box_trigger", "targetname" );
        if ( isdefined( trig ) )
        {
            trig delete();
        }
    }

    // --- MERGED FROM "ALL MYSTERY BOX" SCRIPT ---
    level.chest_min_move_usage = 999999;
    level.chest_joker_probability = 0;
    arrayremovevalue(level.zombie_powerup_array, "fire_sale");
    // --------------------------------------------

    for(i = 0; i < level.chests.size; i++)
    {
        // Force all chests to be unhidden
        level.chests[ i ].hidden = false;
        
        // Grab components and apply your custom box logic
        level.chests[ i ] get_chest_pieces();
        level.chests[ i ] thread reset_box();
        level.chests[ i ].unitrigger_stub.prompt_and_visibility_func = ::boxtrigger_update_prompt;

        // Activate the blue pandora lights on all boxes
        if(isdefined(level.pandora_show_func))
        {
            level.chests[ i ] thread [[ level.pandora_show_func ]]();
        }
    }
}

monitor_boxes()
{
    flag_wait( "initial_blackscreen_passed" );
    wait 10;

    // --- MERGED FROM "ALL MYSTERY BOX" SCRIPT ---
    level.chest_min_move_usage = 999999;
    level.chest_joker_probability = 0;
    arrayremovevalue(level.zombie_powerup_array, "fire_sale");
    // --------------------------------------------

    for(i = 0; i < level.chests.size; i++)
    {
        // Force all chests to be unhidden
        level.chests[ i ].hidden = false;
        
        // Grab components and apply your custom box logic
        level.chests[ i ] get_chest_pieces();
        level.chests[ i ] thread reset_box();

        // Activate the blue pandora lights on all boxes
        if(isdefined(level.pandora_show_func))
        {
            level.chests[ i ] thread [[ level.pandora_show_func ]]();
        }
    }

    for(;;)
    {
        for(i = 0; i < level.chests.size; i++)
        {
            if(!level.chests[ i ].hidden && isdefined(level.chests[ i ].zbarrier))
            {
                level.chests[ i ].unitrigger_stub.prompt_and_visibility_func = ::boxtrigger_update_prompt;
                level.chests[ i ].zbarrier waittill( "left" );
            }
        }
        wait 15;
    }
}

reset_box()
{
    self notify("kill_chest_think");
    wait .1;
    if(!self.hidden)
    {
        self.grab_weapon_hint = 0;
        if ( isDefined( self.zbarrier ) )
        {
            self.zbarrier set_magic_box_zbarrier_state( "initial" );
        }
        self thread maps\mp\zombies\_zm_unitrigger::register_static_unitrigger( self.unitrigger_stub, ::magicbox_unitrigger_think );
        self.unitrigger_stub run_visibility_function_for_all_triggers();
    }
    self thread custom_treasure_chest_think();
}

get_chest_pieces()
{
    self.chest_box = getent( self.script_noteworthy + "_zbarrier", "script_noteworthy" );
    self.chest_rubble = [];
    rubble = getentarray( self.script_noteworthy + "_rubble", "script_noteworthy" );
    i = 0;
    while ( i < rubble.size )
    {
        if ( distancesquared( self.origin, rubble[ i ].origin ) < 10000 )
        {
            self.chest_rubble[ self.chest_rubble.size ] = rubble[ i ];
        }
        i++;
    }
    self.zbarrier = getent( self.script_noteworthy + "_zbarrier", "script_noteworthy" );
    if ( isDefined( self.zbarrier ) )
    {
        self.zbarrier zbarrierpieceuseboxriselogic( 3 );
        self.zbarrier zbarrierpieceuseboxriselogic( 4 );
    }

    old_stub = self.unitrigger_stub;

    self.unitrigger_stub = spawnstruct();
    self.unitrigger_stub.origin = self.origin + ( anglesToRight( self.angles ) * -22.5 );
    self.unitrigger_stub.angles = self.angles;
    self.unitrigger_stub.script_unitrigger_type = "unitrigger_box_use";
    self.unitrigger_stub.script_width = 104;
    self.unitrigger_stub.script_height = 50;
    self.unitrigger_stub.script_length = 45;
    self.unitrigger_stub.trigger_target = self;

    // Origins generator lock sync
    if ( isdefined( old_stub ) && isdefined( old_stub.zone ) )
    {
        self.unitrigger_stub.zone = old_stub.zone;
    }
    if ( isdefined( self.zone_capture_area ) )
    {
        self.unitrigger_stub.zone = self.zone_capture_area;
    }

    unitrigger_force_per_player_triggers( self.unitrigger_stub, 1 );
    self.unitrigger_stub.prompt_and_visibility_func = ::boxtrigger_update_prompt;
    if ( isDefined( self.zbarrier ) )
    {
        self.zbarrier.owner = self;
    }
}

boxtrigger_update_prompt( player )
{
    can_use = self custom_boxstub_update_prompt( player );
    if ( isDefined( self.hint_string ) )
    {
        if ( isDefined( self.hint_parm1 ) )
        {
            self sethintstring( self.hint_string, self.hint_parm1 );
        }
        else
        {
            self sethintstring( self.hint_string );
        }
    }
    return can_use;
}

custom_boxstub_update_prompt( player )
{
    self setcursorhint( "HINT_NOICON" );
    if(!self trigger_visible_to_player( player ))
    {
        if(level.shared_box)
        {
            self setvisibletoplayer( player );
            self.hint_string = get_hint_string( self, "default_shared_box" );
            return 1;
        }
        return 0;
    }
    self.hint_parm1 = undefined;
    if(level.shared_box)
    {
        self.hint_string = "Press ^3F^7 to take weapon"; 
        return 1;
    }

    if ( isDefined( self.stub.trigger_target.grab_weapon_hint ) && self.stub.trigger_target.grab_weapon_hint && !level.shared_box )
    {
        if (isDefined( level.magic_box_check_equipment ) && [[ level.magic_box_check_equipment ]]( self.stub.trigger_target.grab_weapon_name ) )
        {
            self.hint_string = "Press ^3F^7 Equip, ^3Melee^7 Share, ^3ADS+F^7 Close";
        }
        else 
        {
            self.hint_string = "Press ^3F^7 Weapon, ^3Melee^7 Share, ^3ADS+F^7 Close";
        }
    }
    else if(getdvar("mapname") == "zm_tomb" && isDefined(level.zone_capture.zones) && isDefined(self.stub.zone) && isDefined(level.zone_capture.zones[self.stub.zone]) && !level.zone_capture.zones[self.stub.zone] ent_flag( "player_controlled" )) 
    {
        self.stub.hint_string = &"ZM_TOMB_ZC";
        return 0;
    }
    else
    {
        if ( isDefined( level.using_locked_magicbox ) && level.using_locked_magicbox && isDefined( self.stub.trigger_target.is_locked ) && self.stub.trigger_target.is_locked )
        {
            self.hint_string = get_hint_string( self, "locked_magic_box_cost" );
        }
        else
        {
            self.hint_parm1 = self.stub.trigger_target.zombie_cost;
            self.hint_string = get_hint_string( self, "default_treasure_chest" );
        }
    }
    return 1;
}

custom_treasure_chest_think()
{
    if ( !isdefined( self.zbarrier ) )
    {
        return;
    }
    self endon( "kill_chest_think" );
    
    while(1)
    {
        user = undefined;
        user_cost = undefined;
        self.box_rerespun = undefined;
        self.weapon_out = undefined;
        self thread unregister_unitrigger_on_kill_think();
        
        while ( 1 )
        {
            if ( !isdefined( self.forced_user ) )
            {
                self waittill( "trigger", user );
                if ( user == level )
                {
                    wait 0.1;
                    continue;
                }
            }
            else
            {
                user = self.forced_user;
            }
            if ( user in_revive_trigger() )
            {
                wait 0.1;
                continue;
            }
            if ( user.is_drinking > 0 )
            {
                wait 0.1;
                continue;
            }
            if ( isdefined( self.disabled ) && self.disabled )
            {
                wait 0.1;
                continue;
            }
            if ( user getcurrentweapon() == "none" )
            {
                wait 0.1;
                continue;
            }
            reduced_cost = undefined;
            if ( is_player_valid( user ) && user maps\mp\zombies\_zm_pers_upgrades_functions::is_pers_double_points_active() )
            {
                reduced_cost = int( self.zombie_cost / 2 );
            }
            if ( isdefined( level.using_locked_magicbox ) && level.using_locked_magicbox && isdefined( self.is_locked ) && self.is_locked ) 
            {
                if ( user.score >= level.locked_magic_box_cost )
                {
                    user maps\mp\zombies\_zm_score::minus_to_player_score( level.locked_magic_box_cost );
                    self.zbarrier set_magic_box_zbarrier_state( "unlocking" );
                    self.unitrigger_stub run_visibility_function_for_all_triggers();
                }
                else
                {
                    user maps\mp\zombies\_zm_audio::create_and_play_dialog( "general", "no_money_box" );
                }
                wait 0.1 ;
                continue;
            }
            else if ( isdefined( self.auto_open ) && is_player_valid( user ) )
            {
                if ( !isdefined( self.no_charge ) )
                {
                    user maps\mp\zombies\_zm_score::minus_to_player_score( self.zombie_cost );
                    user_cost = self.zombie_cost;
                }
                else
                {
                    user_cost = 0;
                }
                self.chest_user = user;
                break;
            }
            else if ( is_player_valid( user ) && user.score >= self.zombie_cost )
            {
                user maps\mp\zombies\_zm_score::minus_to_player_score( self.zombie_cost );
                user_cost = self.zombie_cost;
                self.chest_user = user;
                break;
            }
            else if ( isdefined( reduced_cost ) && user.score >= reduced_cost )
            {
                user maps\mp\zombies\_zm_score::minus_to_player_score( reduced_cost );
                user_cost = reduced_cost;
                self.chest_user = user;
                break;
            }
            else if ( user.score < self.zombie_cost )
            {
                play_sound_at_pos( "no_purchase", self.origin );
                user maps\mp\zombies\_zm_audio::create_and_play_dialog( "general", "no_money_box" );
                wait 0.1;
                continue;
            }
            wait 0.05;
        }
        
        flag_set( "chest_has_been_used" );
        maps\mp\_demo::bookmark( "zm_player_use_magicbox", getTime(), user );
        user maps\mp\zombies\_zm_stats::increment_client_stat( "use_magicbox" );
        user maps\mp\zombies\_zm_stats::increment_player_stat( "use_magicbox" );
        if ( isDefined( level._magic_box_used_vo ) )
        {
            user thread [[ level._magic_box_used_vo ]]();
        }
        self thread watch_for_emp_close();
        if ( isDefined( level.using_locked_magicbox ) && level.using_locked_magicbox )
        {
            self thread custom_watch_for_lock();
        }
        self._box_open = 1;
        level.box_open = 1;
        self._box_opened_by_fire_sale = 0;
        if ( isDefined( level.zombie_vars[ "zombie_powerup_fire_sale_on" ] ) && level.zombie_vars[ "zombie_powerup_fire_sale_on" ] && !isDefined( self.auto_open ) && self [[ level._zombiemode_check_firesale_loc_valid_func ]]() )
        {
            self._box_opened_by_fire_sale = 1;
        }
        if ( isDefined( self.chest_lid ) )
        {
            self.chest_lid thread treasure_chest_lid_open();
        }
        if ( isDefined( self.zbarrier ) )
        {
            play_sound_at_pos( "open_chest", self.origin );
            play_sound_at_pos( "music_chest", self.origin );
            self.zbarrier set_magic_box_zbarrier_state( "open" );
        }
        self.timedout = 0;
        self.weapon_out = 1;
        self.zbarrier thread treasure_chest_weapon_spawn( self, user );
        self.zbarrier thread treasure_chest_glowfx();
        thread maps\mp\zombies\_zm_unitrigger::unregister_unitrigger( self.unitrigger_stub );
        self.zbarrier waittill_any( "randomization_done", "box_hacked_respin" );
        if ( flag( "moving_chest_now" ) && !self._box_opened_by_fire_sale && isDefined( user_cost ) )
        {
            user maps\mp\zombies\_zm_score::add_to_player_score( user_cost, 0 );
        }
        if ( flag( "moving_chest_now" ) && !level.zombie_vars[ "zombie_powerup_fire_sale_on" ] && !self._box_opened_by_fire_sale )
        {
            self thread treasure_chest_move( self.chest_user );
        }
        else
        {
            self.grab_weapon_hint = 1;
            self.grab_weapon_name = self.zbarrier.weapon_string;
            self.chest_user = user;
            thread maps\mp\zombies\_zm_unitrigger::register_static_unitrigger( self.unitrigger_stub, ::magicbox_unitrigger_think );
            if ( isDefined( self.zbarrier ) && !is_true( self.zbarrier.closed_by_emp ) )
            {
                self thread treasure_chest_timeout();
            }
            
            grabber = user;
            weapon_taken = false;
            
            for( i=0; i<105 && !weapon_taken; i++ )
            {
                if( isplayer( user ) && user adsbuttonpressed() && user usebuttonpressed() && distance(self.origin, user.origin) <= 100)
                {
                    self.timedout = 1;
                    if(isDefined(self.zbarrier.weapon_model))
                    {
                        self.zbarrier.weapon_model delete();
                    }
                    self.zbarrier notify( "weapon_grabbed" );
                    weapon_taken = true;
                    break;
                }

                if( isplayer( user ) && user meleebuttonpressed() && distance(self.origin, user.origin) <= 100)
                {
                    level.magic_box_grab_by_anyone = 1;
                    level.shared_box = 1;
                    self.unitrigger_stub run_visibility_function_for_all_triggers();
                    
                    share_timeout = 105 - i;
                    for( a = 0; a < share_timeout && !weapon_taken; a++ )
                    {
                        foreach(player in level.players)
                        {
                            if( distance(self.origin, player.origin) <= 100 )
                            {
                                if( player usebuttonpressed() && isDefined( player.is_drinking ) && !player.is_drinking)
                                {
                                    player thread treasure_chest_give_weapon( self.zbarrier.weapon_string );
                                    weapon_taken = true;
                                    break;
                                }
                            }
                        }
                        wait 0.1;
                    }
                    break;
                }

                if( isplayer( grabber ) && grabber usebuttonpressed() && user == grabber && distance(self.origin, grabber.origin) <= 100 && isDefined( grabber.is_drinking ) && !grabber.is_drinking)
                {
                    grabber thread treasure_chest_give_weapon( self.zbarrier.weapon_string );
                    weapon_taken = true;
                    break;
                }
                wait 0.1;
            }
            
            self.weapon_out = undefined;
            self notify( "user_grabbed_weapon" );
            user notify( "user_grabbed_weapon" );
            self.grab_weapon_hint = 0;
            self.zbarrier notify( "weapon_grabbed" );
            if ( isDefined( self._box_opened_by_fire_sale ) && !self._box_opened_by_fire_sale )
            {
                level.chest_accessed += 1;
            }
            if ( level.chest_moves > 0 && isDefined( level.pulls_since_last_ray_gun ) )
            {
                level.pulls_since_last_ray_gun += 1;
            }
            thread maps\mp\zombies\_zm_unitrigger::unregister_unitrigger( self.unitrigger_stub );
            if ( isDefined( self.chest_lid ) )
            {
                self.chest_lid thread treasure_chest_lid_close( self.timedout );
            }
            if ( isDefined( self.zbarrier ) )
            {
                self.zbarrier set_magic_box_zbarrier_state( "close" );
                play_sound_at_pos( "close_chest", self.origin );
                self.zbarrier waittill( "closed" );
                wait 1;
            }
            else
            {
                wait 3;
            }
            if ( isDefined( level.zombie_vars[ "zombie_powerup_fire_sale_on" ] ) && level.zombie_vars[ "zombie_powerup_fire_sale_on" ] || self [[ level._zombiemode_check_firesale_loc_valid_func ]]() || self == level.chests[ level.chest_index ] )
            {
                thread maps\mp\zombies\_zm_unitrigger::register_static_unitrigger( self.unitrigger_stub, ::magicbox_unitrigger_think );
            }
        }
        
        self._box_open = 0;
        level.box_open = 0;
        level.shared_box = 0;
        level.magic_box_grab_by_anyone = 0;
        self._box_opened_by_fire_sale = 0;
        self.chest_user = undefined;
        self notify( "chest_accessed" );
        
        wait 0.1;
    }
}

custom_watch_for_lock()
{
    self endon( "user_grabbed_weapon" );
    self endon( "chest_accessed" );
    self endon( "kill_chest_think" );
    
    self waittill( "box_locked" );
    self notify( "kill_chest_think" );
    self.grab_weapon_hint = 0;
    wait 0.1;
    self thread maps\mp\zombies\_zm_unitrigger::register_static_unitrigger( self.unitrigger_stub, ::magicbox_unitrigger_think );
    self.unitrigger_stub run_visibility_function_for_all_triggers();
    self thread custom_treasure_chest_think();
}

// ============================================================================
// UTILITY
// ============================================================================

create_dvar( dvar, set )
{
    if( getDvar( dvar ) == "" )
        setDvar( dvar, set );
}

watch_quick_revive_down_preservation()
{
    self endon( "disconnect" );
    
    // Safety guard to avoid duplicate threads running
    if ( isDefined( self.qr_preservation_running ) && self.qr_preservation_running )
        return;
    self.qr_preservation_running = true;

    for ( ;; )
    {
        self waittill( "entering_last_stand" );

        // Conditions: Player has Quick Revive, and either lives (afterlife) are undefined or 0.
        // Note: On non-prison maps, self.lives is undefined, so this evaluates to true automatically!
        if ( self hasperk( "specialty_quickrevive" ) && ( !isDefined( self.lives ) || self.lives <= 0 ) )
        {
            // Save all active perks except Quick Revive
            saved_perks = [];
            perk_array = maps\mp\zombies\_zm_perks::get_perk_array( 1 );
            foreach ( perk in perk_array )
            {
                if ( perk != "specialty_quickrevive" )
                    saved_perks[ saved_perks.size ] = perk;
            }

            // Wait until they are revived OR die (bleed out)
            self waittill_any( "player_revived", "death" );

            // If they were revived successfully, restore the saved perks
            if ( isAlive( self ) && !maps\mp\zombies\_zm_laststand::player_is_in_laststand() )
            {
                wait 0.1;
                foreach ( perk in saved_perks )
                {
                    if ( !self hasperk( perk ) )
                        maps\mp\zombies\_zm_perks::give_perk( perk );
                }
            }
        }
    }
}

secondsToTime( seconds )
{
    minutes = int(seconds / 60);
    remainder_seconds = seconds % 60;
    if(remainder_seconds < 10) //
    {
        return minutes + ":0" + remainder_seconds; //
    }
    return minutes + ":" + remainder_seconds;
}

command_thread()
{
    level endon( "end_game" );
    while ( true ) //
    {
        level waittill( "say", message, player );
        
        if ( tolower(message) == ".afk" ) //
        {
            // Only allow AFK if player is alive and not in last stand
            if(!isAlive(player) || (isDefined(player.laststand) && player.laststand))
                continue;

            if(player.isafk == 0)
            {
                player thread attempt_afk_activation();
            }
            else
            {
                player afk_disable();
            }
        }
    }
}

attempt_afk_activation()
{
    self endon("disconnect");
    self endon("death");
    
    if( self.canafk == 0 ) //
    {
         formattedTime = secondsToTime(self.afkcooldown);
         self iprintln("^1ERROR: ^7You cannot AFK yet! [" + formattedTime + " left]"); //
         return;
    }
    
    if( self.afk_casting )
        return;

    self.afk_casting = true;
    startPos = self.origin;
    
    countdownHud = newclienthudelem( self );
    countdownHud.alignx = "center";
    countdownHud.aligny = "middle";
    countdownHud.horzalign = "center";
    countdownHud.vertalign = "middle";
    countdownHud.y -= 50; 
    countdownHud.foreground = 1;
    countdownHud.fontscale = 1.5;
    countdownHud.alpha = 1;
    countdownHud.hidewheninmenu = 0;
    countdownHud.font = "default";
    
    // Updated to 3 seconds as requested
    for( i = 3; i > 0; i-- )
    {
        countdownHud setText("AFK Initiating in: ^3" + i);
        for( j = 0; j < 10; j++ )
        {
            wait 0.1;
            // Movement check
            if (distance(self.origin, startPos) > 0.5) 
            {
                self iprintln("^1AFK CANCELED: Movement detected!");
                self.afk_casting = false;
                if(isDefined(countdownHud)) countdownHud destroy();
                return;
            }
        }
    }
    
    if(isDefined(countdownHud)) countdownHud destroy();
    self.afk_casting = false;
    self afk_enable();
}

afk_enable()
{
    self.isafk = 1;
    self.afk_pos = self.origin; // Anchor the player position
    self.afk_angles = self.angles;
    
    self.ignoreme = 1;
    self EnableInvulnerability(); //
    
    self disableWeapons();
    self setMoveSpeedScale(0);
    self freezeControls(true);
    self hide();
    
    self setPlayerCollision(0);
    
    self thread afkmonitor();
    self thread afkHUD();
    
    if(getDvarInt("afk_announce_status") == 1) //
    {
        iprintln(self.name + " is now AFK."); //
    }
}

afk_disable()
{
    self.isafk = 0;
    self notify ("afk_over");
    
    self.ignoreme = 0;
    self DisableInvulnerability();
    
    self enableWeapons();
    self setMoveSpeedScale(1); //
    self freezeControls(false);
    self show();
    
    self setPlayerCollision(1);

    self thread afkCoolDown();
    
    if(getDvarInt("afk_announce_status") == 1)
    {
        iprintln(self.name + " has returned."); //
    }
}

afkmonitor()
{
    self endon ("disconnect");
    self endon ("afk_over");
    self endon ("death");

    for(;;)
    {
        wait 0.5;
        // Keep them at their spot and invisible/invulnerable
        if(self.isafk == 1)
        {
            self setOrigin(self.afk_pos);
            self setPlayerAngles(self.afk_angles);
            if(!self.ignoreme) self.ignoreme = 1;
            self EnableInvulnerability();
        }
    }
}

afkHUD()
{   
    self endon("disconnect");
    
    if(isDefined(self.afkHUD))
        self.afkHUD destroy();

    self.afkHUD = newclienthudelem( self ); //
    self.afkHUD.alignx = "center";
    self.afkHUD.aligny = "bottom";
    self.afkHUD.horzalign = "center";
    self.afkHUD.vertalign = "bottom";
    self.afkHUD.y -= 20;
    
    self.afkHUD.foreground = 1;
    self.afkHUD.fontscale = 1.2;
    self.afkHUD.alpha = 1;
    self.afkHUD.color = (1, 1, 0); // Yellow text
    self.afkHUD.hidewheninmenu = 0;
    self.afkHUD.font = "default";
    self.afkHUD setText("You are currently AFK. Type .afk to return!"); //
    
    self waittill ("afk_over");
    
    if(isDefined(self.afkHUD)) //
        self.afkHUD destroy();
}

afkCoolDown()
{
    self.canafk = 0;
    self thread afkCooldownCountdown();
}

afkCooldownCountdown()
{
    self endon("disconnect");
    
    self.afkcooldown = getDvarInt("afk_cooldown_duration");
    
    while(self.afkcooldown > 0) //
    {
        wait 1; //
        self.afkcooldown -= 1;
    }
    
    self.canafk = 1;
    self iprintln("^2You can now use .afk again!");
}

watch_round_count()
{
	level endon("end_game");
	
	while(true)
	{
		// Wait for round 5 to start
		if(level.round_number >= 5)
		{
			level thread start_round_five_chaos();
			break; // Exit loop once activated
		}
		wait 1;
	}
}

start_round_five_chaos()
{
	level.ragestarted = 1;
	
	// Visual and audio cue for the players
	level thread show_big_message("ROUND 5: RAMPAGE ACTIVATED", "zmb_laugh_child");
	
	// Apply the speed and spawn modifiers
	level.zombie_vars[ "zombie_spawn_delay" ] = 0.05; 
	level.zombie_round_start_delay = 0;
	
	level thread force_zombie_sprint();
}

is_special_zombie(zombie)
{
	if (isDefined(zombie.is_mechz) && zombie.is_mechz)
	{
		return true;
	}
	if (isDefined(zombie.is_brutus) && zombie.is_brutus)
	{
		return true;
	}
	if (isDefined(zombie.is_ghost) && zombie.is_ghost)
	{
		return true;
	}
	if (isDefined(zombie.isscreecher) && zombie.isscreecher)
	{
		return true;
	}
	if (isDefined(zombie.is_avogadro) && zombie.is_avogadro)
	{
		return true;
	}
	if (isDefined(zombie.animname) && (zombie.animname == "zombie_dog" || zombie.animname == "leaper_zombie"))
	{
		return true;
	}
	return false;
}

force_zombie_sprint()
{
	level endon("end_game");
	while(true)
    {
    	if(level.ragestarted == 1)
    	{
    		zombies = getAiArray(level.zombie_team);
            foreach(zombie in zombies)
            {
                if(isDefined(zombie) && isAlive(zombie))
                {
                    if (!is_special_zombie(zombie))
                    {
                        if(zombie.zombie_move_speed != "sprint")
                        {
                            zombie maps\mp\zombies\_zm_utility::set_zombie_run_cycle("sprint");
                        }
                    }
                }
            }
    	}
    	wait 0.2;
    }
}

new_round_over()
{
    if ( isdefined( level.noroundnumber ) && level.noroundnumber == 1 )
        return;

    players = getplayers();
    for ( i = 0; i < players.size; i++ )
    {
        if ( !isdefined( players[i].pers["previous_distance_traveled"] ) )
            players[i].pers["previous_distance_traveled"] = 0;
        dist = int( players[i].pers["distance_traveled"] - players[i].pers["previous_distance_traveled"] );
        players[i].pers["previous_distance_traveled"] = players[i].pers["distance_traveled"];
        players[i] incrementplayerstat( "distance_traveled", dist );
    }

    recordzombieroundend();

    // If rampage is active, skip the wait timer entirely
    if (isDefined(level.ragestarted) && level.ragestarted == 1)
    {
        // No wait
    }
    else
    {
        // Normal game behavior: wait for the standard inter-round delay
        wait( level.zombie_vars["zombie_between_round_time"] );
    }
}

show_big_message(setmsg, sound)
{
    players = get_players();
    foreach ( player in players )
    {
        player thread show_hud_msg( setmsg );
    }
    if(isDefined(players[0]))
        players[0] playsound(sound);
}

show_hud_msg( msg )
{
    self endon( "disconnect" );
    hud = newclienthudelem( self );
    hud.alignx = "center";
    hud.aligny = "middle";
    hud.horzalign = "center";
    hud.vertalign = "middle";
    hud.y -= 100;
    hud.foreground = 1;
    hud.fontscale = 2;
    hud.alpha = 0;
    hud.color = ( 1, 0, 0 ); 
    hud.hidewheninmenu = 1;
    hud settext( msg );

    hud fadeovertime( 0.5 );
    hud.alpha = 1;
    wait 4;
    hud fadeovertime( 1 );
    hud.alpha = 0;
    wait 1;
    hud destroy();
}

// ============================================================================
// ZONE NOTIFIER
// ============================================================================
zoneCheck()
{
    self endon("disconnect");
    level endon("end_game");
    
    // Wait for the game intro to pass
    flag_wait("initial_blackscreen_passed");
    
    // Set initial zone on spawn
    self.currentzone = self get_zone_name();
    
    for(;;)
    {
        wait 0.5;
        
        new_zone = self get_zone_name();
        
        // Trigger notification on transition to a valid new zone
        if (self.currentzone != new_zone && new_zone != "" && !IsSubStr(new_zone, "_"))
        {
            self.currentzone = new_zone;
            self thread notify_zone_transition(new_zone);
        }
    }
}
notify_zone_transition(zone_display_name)
{
    self endon("disconnect");
    self notify("zone_change");
    self endon("zone_change");
    
    // Cleanup previous HUD element if it exists
    if (IsDefined(self.zone_notifier_hud))
    {
        self.zone_notifier_hud destroy();
        self.zone_notifier_hud = undefined;
    }
    
    // Position offsets based on map
    x = 5;
    y = -119;
    if (level.script == "zm_buried")
    {
        y -= 25;
    }
    else if (level.script == "zm_tomb")
    {
        y -= 28;
    }
    
    // Create new HUD element
    hud = newClientHudElem(self);
    hud.alignx = "left";
    hud.aligny = "middle";
    hud.horzalign = "user_left";
    hud.vertalign = "user_bottom";
    hud.x += x;
    hud.y += y;
    
    if (self issplitscreen())
        hud.y += 60;
        
    hud.foreground = 1;
    hud.alpha = 0;
    hud.color = (1.0, 0.8, 0.2); // Sleek gold color
    hud.glowcolor = (0.2, 0.1, 0.0); // Dark amber glow
    hud.glowalpha = 0.8;
    hud.hidewheninmenu = 1;
    hud.font = "bigdev";
    
    hud settext(zone_display_name);
    
    // Store reference for cleanups
    self.zone_notifier_hud = hud;
    
    // Play transition sound
    self playlocalsound("zmb_hq_reveal");
    
    // Animation: Scale down and fade in
    hud fadeovertime(0.5);
    hud changefontscaleovertime(0.5);
    hud.alpha = 1;
    hud.fontscale = 1.35; // Settles on a clean scale
    
    wait 2.5;
    
    // Animation: Fade out
    hud fadeovertime(0.8);
    hud.alpha = 0;
    
    wait 0.8;
    
    if (IsDefined(hud))
    {
        hud destroy();
        if (IsDefined(self.zone_notifier_hud) && self.zone_notifier_hud == hud)
            self.zone_notifier_hud = undefined;
    }
}
get_zone_name()
{
    // Check if player is standing in a valid zone
    if (!IsDefined(self.zone_name))
    {
        // Try getting zone from stock checker
        zone_key = self maps\mp\zombies\_zm_zonemgr::get_player_zone();
        if (!IsDefined(zone_key))
            return "";
    }
    else
    {
        zone_key = self.zone_name;
    }
    
    if (zone_key == "")
        return "";
    // Read dynamically loaded custom map strings
    if ( isDefined(level.custom_zone_names) && isDefined(level.custom_zone_names[zone_key]) )
    {
        return level.custom_zone_names[zone_key];
    }
    
    return "";
}

monitor_base_health()
{
    self endon("disconnect");
    level endon("end_game");
    
    for(;;)
    {
        if (self maps\mp\zombies\_zm_laststand::player_is_in_laststand() || !isAlive(self))
        {
            wait 0.5;
            continue;
        }

        if (!self HasPerk("specialty_armorvest"))
        {
            if (self.maxhealth != 150)
            {
                self.maxhealth = 150;
                if (self.health > 150)
                {
                    self.health = 150;
                }
            }
        }
        else
        {
            if (self.maxhealth != 250)
            {
                self.maxhealth = 250;
                if (self.health > 250)
                {
                    self.health = 250;
                }
            }
        }
        wait 0.5;
    }
}

custom_survival_bank_setup()
{
    level.bank_teller_positions = [];
    level.custom_bank_origins = [];

    map = getdvar("mapname");
    location = getdvar("ui_zm_mapstartlocation");
    
    is_survival_map = false;
    spawn_origin = undefined;
    spawn_angles = (0, 0, 0);
    
    if (map == "zm_nuked")
    {
        is_survival_map = true;
        spawn_origin = (666, 737, -57);
        spawn_angles = (0, -48, 0);
    }
    else if (map == "zm_transit")
    {
        if (location == "farm")
        {
            is_survival_map = true;
            spawn_origin = (7099, -5769, -48);
            spawn_angles = (0, -144, 0);
        }
        else if (location == "transit" && getdvar("g_gametype") == "zstandard")
        {
            is_survival_map = true;
            spawn_origin = (-5932, 4627, -54);
            spawn_angles = (0, 154, 0);
        }
        else if (location == "town")
        {
            level thread custom_bank_deposit_box();
        }
    }
    
    if (is_survival_map && isdefined(spawn_origin))
    {
        level thread spawn_custom_deposit_teller(spawn_origin, spawn_angles);
    }
    
    level thread cache_native_bank_teller_positions();
}

spawn_custom_deposit_teller(origin, angles)
{
    flag_wait( "initial_blackscreen_passed" );
    setup_bank_level_vars();

    trigger_origin = origin + anglestoforward( angles ) * 25 + ( 0, 0, 20 );

    level.custom_bank_origins[ level.custom_bank_origins.size ] = origin;
    level.bank_teller_positions[ level.bank_teller_positions.size ] = trigger_origin;

    // Only spawn z_money model if we are NOT on Town survival
    location = getdvar("ui_zm_mapstartlocation");
    if ( location != "town" )
    {
        // Spawn the z_money model
        orb_ent = spawn( "script_model", origin + ( 0, 0, 45 ) );
        orb_ent.angles = angles;
        orb_ent setmodel( "zombie_z_money_icon" );
        orb_ent notsolid();
        
        // Play powerup glow FX directly on the model entity
        playfxontag( level._effect["powerup_on"], orb_ent, "tag_origin" );

        // Start rotation loop
        orb_ent thread bank_money_rotate_loop();
    }

    // Spawn the deposit unitrigger stub
    unitrigger_stub = spawnstruct();
    unitrigger_stub.origin = trigger_origin;
    unitrigger_stub.angles = angles;
    unitrigger_stub.script_angles = unitrigger_stub.angles;
    unitrigger_stub.radius = 80;
    unitrigger_stub.script_height = 96;
    unitrigger_stub.script_unitrigger_type = "unitrigger_radius_use";
    unitrigger_stub.cursor_hint = "HINT_NOICON";
    unitrigger_stub.targetname = "bank_deposit";
    
    maps\mp\zombies\_zm_unitrigger::unitrigger_force_per_player_triggers( unitrigger_stub, 1 );
    unitrigger_stub.prompt_and_visibility_func = ::custom_deposit_prompt;
    maps\mp\zombies\_zm_unitrigger::register_unitrigger( unitrigger_stub, ::custom_deposit_think );
}

cache_native_bank_teller_positions()
{
    flag_wait( "initial_blackscreen_passed" );
    
    // Add native bank deposit structs if not already added
    native_deposits = getstructarray( "bank_deposit", "targetname" );
    foreach ( struct in native_deposits )
    {
        if ( isdefined( struct.origin ) )
        {
            already_added = false;
            foreach ( pos in level.bank_teller_positions )
            {
                if ( distance( pos, struct.origin ) < 5 )
                {
                    already_added = true;
                    break;
                }
            }
            if ( !already_added )
                level.bank_teller_positions[ level.bank_teller_positions.size ] = struct.origin;
        }
    }
    
    // Add native bank withdraw structs if not already added
    native_withdraws = getstructarray( "bank_withdraw", "targetname" );
    foreach ( struct in native_withdraws )
    {
        if ( isdefined( struct.origin ) )
        {
            already_added = false;
            foreach ( pos in level.bank_teller_positions )
            {
                if ( distance( pos, struct.origin ) < 5 )
                {
                    already_added = true;
                    break;
                }
            }
            if ( !already_added )
                level.bank_teller_positions[ level.bank_teller_positions.size ] = struct.origin;
        }
    }
}

bank_money_rotate_loop()
{
    self endon( "death" );
    while ( isdefined( self ) )
    {
        self rotateyaw( 360, 4.0 );
        wait 4.0;
    }
}

custom_deposit_prompt( player )
{
    if ( !isdefined( player.account_value ) )
    {
        player.account_value = player maps\mp\zombies\_zm_stats::get_map_stat( "depositBox", "zm_transit" );
        if ( !isdefined( player.account_value ) )
            player.account_value = 0;
    }

    if ( player.account_value >= level.bank_account_max )
    {
        self sethintstring( "Bank Account Full" );
        return true;
    }

    self sethintstring( "Hold ^3[{+activate}]^7 to deposit $1000" );
    return true;
}

custom_deposit_think()
{
    self endon( "kill_trigger" );

    while ( true )
    {
        self waittill( "trigger", player );

        if ( !is_player_valid( player ) )
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

setup_bank_level_vars()
{
    if (!isdefined(level.bank_deposit_max_amount))
        level.bank_deposit_max_amount = 250000;
    if (!isdefined(level.bank_deposit_ddl_increment_amount))
        level.bank_deposit_ddl_increment_amount = 1000;
    if (!isdefined(level.bank_account_max))
        level.bank_account_max = level.bank_deposit_max_amount / 100;
    if (!isdefined(level.bank_account_increment))
        level.bank_account_increment = int( level.bank_deposit_ddl_increment_amount / 100 );
    if (!isdefined(level.banking_map))
        level.banking_map = "zm_transit";
    if (!isdefined(level.ta_vaultfee))
        level.ta_vaultfee = 100;
    if (!isdefined(level.ta_tellerfee))
        level.ta_tellerfee = 100;
}

player_bank_hud_think()
{
    self endon( "disconnect" );
    
    map = getdvar( "mapname" );
    if ( map != "zm_nuked" && map != "zm_transit" && map != "zm_highrise" && map != "zm_buried" )
        return;

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
        near_teller = false;
        player_origin = self.origin;
        
        if ( isdefined( level.bank_teller_positions ) )
        {
            foreach ( pos in level.bank_teller_positions )
            {
                if ( distance( player_origin, pos ) < 80 )
                {
                    near_teller = true;
                    break;
                }
            }
        }
        
        if ( isalive( self ) && self.sessionstate == "playing" && near_teller )
        {
            hud.alpha = 1;
            val = 0;
            if ( isdefined( self.account_value ) )
                val = self.account_value * 100;
            hud setValue( val );
        }
        else
        {
            hud.alpha = 0;
        }
        
        wait 0.1;
    }
}
