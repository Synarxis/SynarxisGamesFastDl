// ============================================================
// prisonpatch.gsc  —  Mob of the Dead custom patch
//
// Features:
//   1. Afterlife auto-revive  — when mana expires the player is
//      revived instead of killed (works on both the initial
//      spawn afterlife and mid-game downs).
//   2. Golden Spork OHK       — one-shots all zombies on any round.
//   3. Golden Spork OHK Brutus — one-shots Brutus, bypassing all
//      his damage-reduction logic.
//   4. Loadout save/restore   — weapons, ammo, score and equipment
//      are preserved across the afterlife, matching stock behaviour.
// ============================================================

#include common_scripts\utility;
#include maps\mp\_utility;
#include maps\mp\zombies\_zm_utility;
#include maps\mp\zombies\_zm_perks;
#include maps\mp\zm_alcatraz_utility;
#include maps\mp\zombies\_zm;
#include maps\mp\gametypes_zm\_weapons;
#include maps\mp\zombies\_zm_ai_brutus;
#include maps\mp\zombies\_zm_score;
#include maps\mp\zombies\_zm_weapons;
#include maps\mp\zombies\_zm_equipment;

init()
{
    if (!isDefined(level.custom_zone_names))
        level.custom_zone_names = [];

    level.custom_zone_names["zone_start"] = "D-Block";
    level.custom_zone_names["zone_library"] = "Library";
    level.custom_zone_names["zone_cellblock_west"] = "Cell Block 2nd Floor & C-D Street";
    level.custom_zone_names["zone_cellblock_west_gondola"] = "Cell Block 3rd Floor";
    level.custom_zone_names["zone_cellblock_west_gondola_dock"] = "Upper Gondola Platform";
    level.custom_zone_names["zone_cellblock_west_barber"] = "Michigan Avenue";
    level.custom_zone_names["zone_cellblock_east"] = "Times Square";
    level.custom_zone_names["zone_cafeteria"] = "Cafeteria";
    level.custom_zone_names["zone_cafeteria_end"] = "Cafeteria End";
    level.custom_zone_names["zone_infirmary"] = "Infirmary 1";
    level.custom_zone_names["zone_infirmary_roof"] = "Infirmary 2";
    level.custom_zone_names["zone_roof_infirmary"] = "Roof 1";
    level.custom_zone_names["zone_roof"] = "Roof 2";
    level.custom_zone_names["zone_cellblock_west_warden"] = "Sally Port";
    level.custom_zone_names["zone_warden_office"] = "Warden's Office";
    level.custom_zone_names["cellblock_shower"] = "Showers";
    level.custom_zone_names["zone_citadel_shower"] = "Citadel To Showers";
    level.custom_zone_names["zone_citadel"] = "Citadel";
    level.custom_zone_names["zone_citadel_warden"] = "Citadel To Warden's Office";
    level.custom_zone_names["zone_citadel_stairs"] = "Citadel Tunnels";
    level.custom_zone_names["zone_citadel_basement"] = "Citadel Basement";
    level.custom_zone_names["zone_citadel_basement_building"] = "China Alley";
    level.custom_zone_names["zone_studio"] = "Building 64";
    level.custom_zone_names["zone_dock"] = "Docks";
    level.custom_zone_names["zone_dock_puzzle"] = "Docks Gates";
    level.custom_zone_names["zone_dock_gondola"] = "Docks Bridge";
    level.custom_zone_names["zone_golden_gate_bridge"] = "Golden Gate Bridge";
    level.custom_zone_names["zone_gondola_ride"] = "Gondola";

    // --- Afterlife hooks ---
    // These are function-pointer overrides (the stock code already
    // calls them through level.afterlife_save_loadout /
    // level.afterlife_give_loadout), so replaceFunc is used to keep
    // parity with how the stock _zm_afterlife.gsc registers them.
    replaceFunc( maps\mp\zombies\_zm_afterlife::afterlife_mana_watch, ::custom_afterlife_mana_watch );
    replaceFunc( maps\mp\zombies\_zm_afterlife::afterlife_save_loadout, ::custom_afterlife_save_loadout );
    replaceFunc( maps\mp\zombies\_zm_afterlife::afterlife_give_loadout, ::custom_afterlife_give_loadout );

    // --- Damage overrides ---
    replaceFunc( maps\mp\zombies\_zm::actor_damage_override_wrapper, ::custom_actor_damage_override_wrapper );
    replaceFunc( maps\mp\zombies\_zm_ai_brutus::brutus_damage_override, ::custom_brutus_damage_override );
    replaceFunc( maps\mp\zombies\_zm_afterlife::afterlife_player_damage_callback, ::custom_afterlife_player_damage_callback );


    // --- Blundersplat spread override --- 
    replaceFunc( maps\mp\zombies\_zm_weap_blundersplat::wait_for_blundersplat_fired, ::wait_for_blundersplat_fired_override );
    replaceFunc( maps\mp\zombies\_zm_weap_blundersplat::wait_for_blundersplat_upgraded_fired, ::wait_for_blundersplat_upgraded_fired_override );

    
    level thread bank_setup();
    level thread plane_set_pieces_shared();
    //level.is_forever_solo_game = true;
    level thread on_player_connect();
    level thread remove_weapon_limits();
}


// ============================================================
// === AFTERLIFE AUTO-REVIVE                                 ===
// ============================================================

// Replaces stock afterlife_mana_watch.
// Stock behaviour: when mana hits 0 the corpse is notified
//   "stop_revive_trigger", a fade plays, then "out_of_mana" is
//   sent which triggers afterlife_leave(0) → dodamage(1000) → death.
//
// Our change: instead of letting the mana-expired path kill the
//   player, we notify "player_revived" on the corpse so the stock
//   afterlife_laststand() waittill fires and the player comes back
//   alive through the normal revive path.
//
// Drain formula is kept identical to stock:
//   per-tick drain = 0.05 * afterlifedeaths * 3
//   tick interval  = 0.05 s
//   (your previous version doubled the interval to 0.1 s which
//    silently halved the drain rate — corrected here.)
//
// NOTE: We delegate to stock afterlife_reduce_mana() rather than
//   doing the subtract ourselves so that host-migration pausing,
//   infinite_mana, the "beingrevived" pause, and cheat dvars are
//   all handled automatically.

custom_afterlife_mana_watch( corpse )
{
    self endon( "disconnect" );
    corpse endon( "player_revived" );

    while ( self.manacur > 0 )
    {
        wait 0.05;
        self afterlife_reduce_mana( 0.05 * self.afterlifedeaths * 3 );

        if ( self.manacur < 0 )
            self.manacur = 0;

        n_mapped_mana = linear_map( self.manacur, 0, 200, 0, 1 );
        self setclientfieldtoplayer( "player_afterlife_mana", n_mapped_mana );
    }

    // Wait if a teammate is already mid-revive on the corpse.
    if ( isdefined( corpse.revivetrigger ) )
    {
        while ( corpse.revivetrigger.beingrevived )
            wait 0.05;
    }

    // Auto-revive: notify "player_revived" on the corpse exactly as
    // a player pressing the revive trigger would.  The waittill in
    // afterlife_laststand() catches this and runs the normal
    // afterlife_leave() → afterlife_laststand_cleanup() path so the
    // player is restored alive, not killed.
    corpse notify( "player_revived", self );
}


// ============================================================
// === LOADOUT SAVE                                          ===
// ============================================================

// Aligned to stock afterlife_save_loadout() in _zm_afterlife.gsc.
// Key corrections vs. your original:
//   • Uses loadout.stockcount / clipcount / clipcount2 /
//     stockcountalt / clipcountalt to match stock field names
//     (you had stockammo / currentclip / dualmags / altammo).
//   • current_weapon stored as the ARRAY INDEX of the active weapon
//     (stock stores the index; you stored the weapon string, which
//     broke the switchtoweapon call in give_loadout).
//   • Perk stripping delegated to stock afterlife_save_perks() which
//     calls get_perk_array(1) then unsetperk — matching stock exactly.
//   • Equipment taken via equipment_take() (stock) rather than just
//     saving the reference.
//   • lethal_grenade cleared on self after saving (stock sets it to
//     undefined; your version left it set).

custom_afterlife_save_loadout()
{
    primaries      = self getweaponslistprimaries();
    currentweapon  = self getcurrentweapon();
    self.loadout   = spawnstruct();
    self.loadout.player        = self;
    self.loadout.weapons       = [];
    self.loadout.score         = self.score;
    self.loadout.current_weapon = 0;

    foreach ( index, weapon in primaries )
    {
        self.loadout.weapons[ index ]    = weapon;
        self.loadout.stockcount[ index ] = self getweaponammostock( weapon );
        self.loadout.clipcount[ index ]  = self getweaponammoclip( weapon );

        if ( weaponisdualwield( weapon ) )
        {
            weapon_dw = weapondualwieldweaponname( weapon );
            self.loadout.clipcount2[ index ] = self getweaponammoclip( weapon_dw );
        }

        weapon_alt = weaponaltweaponname( weapon );
        if ( weapon_alt != "none" )
        {
            self.loadout.stockcountalt[ index ] = self getweaponammostock( weapon_alt );
            self.loadout.clipcountalt[ index ]  = self getweaponammoclip( weapon_alt );
        }

        if ( weapon == currentweapon )
            self.loadout.current_weapon = index;
    }

    self.loadout.equipment = self get_player_equipment();
    if ( isdefined( self.loadout.equipment ) )
        self equipment_take( self.loadout.equipment );

    self.loadout.hasclaymore  = 0;
    self.loadout.claymoreclip = 0;
    if ( self hasweapon( "claymore_zm" ) )
    {
        self.loadout.hasclaymore  = 1;
        self.loadout.claymoreclip = self getweaponammoclip( "claymore_zm" );
    }

    self.loadout.hasemp  = 0;
    self.loadout.empclip = 0;
    if ( self hasweapon( "emp_grenade_zm" ) )
    {
        self.loadout.hasemp  = 1;
        self.loadout.empclip = self getweaponammoclip( "emp_grenade_zm" );
    }

    self.loadout.hastomahawk = 0;
    if ( self hasweapon( "bouncing_tomahawk_zm" ) || self hasweapon( "upgraded_tomahawk_zm" ) )
    {
        self.loadout.hastomahawk = 1;
        self setclientfieldtoplayer( "tomahawk_in_use", 0 );
    }

    // afterlife_save_perks() calls get_perk_array(1) then unsetperk
    // on each perk — same as stock.
    self.loadout.perks = afterlife_save_perks( self );

    // Track whether the player had Quick Revive.  Always keep QR in
    // the saved array — we decide whether to restore it at give-loadout
    // time so the keep_perks flag is checked at the right moment.
    self.loadout.had_quickrevive = false;
    if ( isdefined( self.loadout.perks ) )
    {
        for ( i = 0; i < self.loadout.perks.size; i++ )
        {
            if ( self.loadout.perks[i] == "specialty_quickrevive" )
            {
                self.loadout.had_quickrevive = true;
                break;
            }
        }
    }

    lethal_grenade = self get_player_lethal_grenade();
    if ( self hasweapon( lethal_grenade ) )
        self.loadout.grenade = self getweaponammoclip( lethal_grenade );
    else
        self.loadout.grenade = 0;

    self.loadout.lethal_grenade = lethal_grenade;
    self set_player_lethal_grenade( undefined );
}


// ============================================================
// === LOADOUT RESTORE                                       ===
// ============================================================

// Replaces stock afterlife_give_loadout().
// Stock calls this directly inside afterlife_laststand_cleanup()
// which runs synchronously during afterlife_leave() — BEFORE the
// player's afterlife flag is cleared.  There is NO need for the
// delayed thread your original used; doing it synchronously matches
// stock and avoids the race condition where self.afterlife is never
// cleared if the player disconnects mid-wait.
//
// Correction: the endon( "player_fake_corpse_created" ) your version
// had would abort the entire restore whenever the initial spawn
// afterlife fires (the corpse is created BEFORE give_loadout is
// called in that path), silently leaving the player weaponless.
// Removed here.
//
// Perk restore uses the exact same logic as stock:
//   strip all current perks, then re-grant loadout.perks only if
//   keep_perks is truthy (Shock Box path).

custom_afterlife_give_loadout()
{
    if ( !isdefined( self.loadout ) )
        return;

    loadout = self.loadout;

    // Strip and re-give weapons — same logic as stock.
    self takeallweapons();
    primaries = self getweaponslistprimaries();

    if ( loadout.weapons.size > 1 || primaries.size > 1 )
    {
        foreach ( weapon in primaries )
            self takeweapon( weapon );
    }

    for ( i = 0; i < loadout.weapons.size; i++ )
    {
        if ( !isdefined( loadout.weapons[ i ] ) )
            continue;
        if ( loadout.weapons[ i ] == "none" )
            continue;

        weapon = loadout.weapons[ i ];

        if ( !self hasweapon( weapon ) )
        {
            self giveweapon( weapon, 0, self maps\mp\zombies\_zm_weapons::get_pack_a_punch_weapon_options( weapon ) );
            self setweaponammostock( weapon, loadout.stockcount[ i ] );
            self setweaponammoclip( weapon, loadout.clipcount[ i ] );

            if ( weaponisdualwield( weapon ) )
            {
                weapon_dw = weapondualwieldweaponname( weapon );
                self setweaponammoclip( weapon_dw, loadout.clipcount2[ i ] );
            }

            weapon_alt = weaponaltweaponname( weapon );
            if ( weapon_alt != "none" )
            {
                self setweaponammostock( weapon_alt, loadout.stockcountalt[ i ] );
                self setweaponammoclip( weapon_alt, loadout.clipcountalt[ i ] );
            }
        }
    }

    // Switch to the weapon the player was holding when they went down.
    self setspawnweapon( loadout.weapons[ loadout.current_weapon ] );
    self switchtoweaponimmediate( loadout.weapons[ loadout.current_weapon ] );

    // Melee weapon (knife / spork).
    if ( isdefined( self get_player_melee_weapon() ) )
        self giveweapon( self get_player_melee_weapon() );

    // Equipment.
    self maps\mp\zombies\_zm_equipment::equipment_give( self.loadout.equipment );

    // Claymore.
    if ( isdefined( loadout.hasclaymore ) && loadout.hasclaymore && !self hasweapon( "claymore_zm" ) )
    {
        self giveweapon( "claymore_zm" );
        self set_player_placeable_mine( "claymore_zm" );
        self setactionslot( 4, "weapon", "claymore_zm" );
        self setweaponammoclip( "claymore_zm", loadout.claymoreclip );
    }

    // EMP grenade.
    if ( isdefined( loadout.hasemp ) && loadout.hasemp )
    {
        self giveweapon( "emp_grenade_zm" );
        self setweaponammoclip( "emp_grenade_zm", loadout.empclip );
    }

    // Tomahawk.
    if ( isdefined( loadout.hastomahawk ) && loadout.hastomahawk )
    {
        self giveweapon( self.current_tomahawk_weapon );
        self set_player_tactical_grenade( self.current_tomahawk_weapon );
        self setclientfieldtoplayer( "tomahawk_in_use", 1 );
    }

    self.score = loadout.score;

    // Perks — strip all current, then restore saved perks
    perk_array = maps\mp\zombies\_zm_perks::get_perk_array( 1 );
    for ( i = 0; i < perk_array.size; i++ )
    {
        perk = perk_array[ i ];
        self unsetperk( perk );
        self set_perk_clientfield( perk, 0 );
    }
    self.num_perks = 0;

    // Restore perks if player used a kill switch (keep_perks) or had QR (auto-revive)
    b_restore_perks = is_true( self.keep_perks ) || is_true( loadout.had_quickrevive );
    if ( b_restore_perks && isdefined( loadout.perks ) && loadout.perks.size > 0 )
    {
        for ( i = 0; i < loadout.perks.size; i++ )
        {
            if ( self hasperk( loadout.perks[ i ] ) )
                continue;

            // Skip QR if this was NOT a kill switch — QR is consumed for auto-revive
            if ( loadout.perks[ i ] == "specialty_quickrevive" && !is_true( self.keep_perks ) )
                continue;

            if ( loadout.perks[ i ] == "specialty_finalstand" )
                continue;

            if ( loadout.perks[ i ] == "specialty_quickrevive" && flag( "solo_game" ) )
                level.solo_game_free_player_quickrevive = 1;

            maps\mp\zombies\_zm_perks::give_perk( loadout.perks[ i ] );
        }
    }

    self.keep_perks = undefined;

    // Restore custom max health after afterlife exit
    if ( !self hasperk( "specialty_armorvest" ) )
        self.maxhealth = 150;

    self.health = self.maxhealth;

    // Lethal grenade.
    self set_player_lethal_grenade( self.loadout.lethal_grenade );
    if ( loadout.grenade > 0 )
    {
        curgrenadecount = 0;
        if ( self hasweapon( self get_player_lethal_grenade() ) )
            curgrenadecount = self getweaponammoclip( self get_player_lethal_grenade() );
        else
            self giveweapon( self get_player_lethal_grenade() );

        self setweaponammoclip( self get_player_lethal_grenade(), loadout.grenade + curgrenadecount );
    }
}


// ============================================================
// === GOLDEN SPORK — ZOMBIE DAMAGE OVERRIDE                 ===
// ============================================================

// Replaces stock actor_damage_override_wrapper() in _zm.gsc.
//
// Stock logic (line 4475):
//   if ( damage_override < self.health ||
//        !( isdefined(self.dont_die_on_me) && self.dont_die_on_me ) )
//       self finishactordamage( ... );
//
// Translation: call finishactordamage UNLESS the zombie has
//   dont_die_on_me == true AND the hit is lethal.
// i.e. "skip the kill blow only when dont_die_on_me is explicitly
//   blocking it."
//
// Your original had the condition backwards (damage < self.health
// instead of damage_override < self.health) and added a spurious
// second finishactordamage call, meaning damage was always applied
// twice on lethal hits — corrected below.

custom_actor_damage_override_wrapper( inflictor, attacker, damage, flags, meansofdeath, weapon, vpoint, vdir, shitloc, psoffsettime, boneindex )
{
    // Golden Spork: set damage to lethal before the damage pipeline
    // runs so all per-actor multipliers still fire correctly.
    if ( isplayer( attacker ) && meansofdeath == "MOD_MELEE" )
    {
        melee_weapon = attacker get_player_melee_weapon();
        if ( isdefined( melee_weapon ) && melee_weapon == "spork_zm_alcatraz" )
            damage = self.health + 1000;
    }

    damage_override = self actor_damage_override( inflictor, attacker, damage, flags, meansofdeath, weapon, vpoint, vdir, shitloc, psoffsettime, boneindex );

    // Exact stock condition — single finishactordamage call.
    if ( damage_override < self.health || !( isdefined( self.dont_die_on_me ) && self.dont_die_on_me ) )
        self finishactordamage( inflictor, attacker, damage_override, flags, meansofdeath, weapon, vpoint, vdir, shitloc, psoffsettime, boneindex );
}


// ============================================================
// === GOLDEN SPORK — BRUTUS DAMAGE OVERRIDE                 ===
// ============================================================

// Replaces stock brutus_damage_override() in _zm_ai_brutus.gsc.
// The spork check is placed at the very top so it returns before
// any of Brutus's damage-reduction multipliers fire.
//
// All other logic is a faithful copy of stock so vanilla Brutus
// behaviour (helmet tracking, shield fling, afterlife teleport,
// explosive accumulation, etc.) is preserved.
//
// Corrections vs. your original:
//   • instakill condition aligned to stock: the stock function
//     checks zombie_insta_kill OR personal_instakill in a single
//     compound condition; your version split them with || which
//     accidentally evaluated personal_instakill unconditionally.
//   • is_weapon_shotgun() used (stock helper) instead of checking
//     weaponclass() == "spread" yourself.
//   • round_up_score() used for point calculations (stock helper).
//   • add_to_player_score() called directly on attacker (stock
//     style) instead of through the score namespace path.
//   • Explosive scaler fix: stock uses n_brutus_headshot_modifier
//     when helmet is absent, level.brutus_damage_percent when helmet
//     is present — your version had these swapped.

custom_brutus_damage_override( inflictor, attacker, damage, flags, meansofdeath, weapon, vpoint, vdir, shitloc, poffsettime, boneindex )
{
    // ---- Golden Spork instant kill ----
    if ( isplayer( attacker ) && meansofdeath == "MOD_MELEE" )
    {
        melee_weapon = attacker get_player_melee_weapon();
        if ( isdefined( melee_weapon ) && melee_weapon == "spork_zm_alcatraz" )
            return self.health + 1000;
    }

    // ---- Base damage multipliers (stock) ----
    if ( isdefined( attacker ) && isalive( attacker ) && isplayer( attacker ) &&
         ( level.zombie_vars[ attacker.team ][ "zombie_insta_kill" ] ||
           ( isdefined( attacker.personal_instakill ) && attacker.personal_instakill ) ) )
    {
        n_brutus_damage_percent    = 1.0;
        n_brutus_headshot_modifier = 2.0;
    }
    else
    {
        n_brutus_damage_percent    = level.brutus_damage_percent;
        n_brutus_headshot_modifier = 1.0;
    }

    if ( isdefined( weapon ) && is_weapon_shotgun( weapon ) )
    {
        n_brutus_damage_percent    *= level.brutus_shotgun_damage_mod;
        n_brutus_headshot_modifier *= level.brutus_shotgun_damage_mod;
    }

    // ---- Tomahawk (helmet interaction) ----
    if ( isdefined( weapon ) && weapon == "bouncing_tomahawk_zm" && isdefined( inflictor ) )
    {
        self playsound( "wpn_tomahawk_imp_zombie" );

        if ( self.has_helmet )
        {
            if ( damage == 1 )
                return 0;

            if ( isdefined( inflictor.n_cookedtime ) && inflictor.n_cookedtime >= 2000 )
                self.helmet_hits = level.brutus_helmet_shots;
            else if ( isdefined( inflictor.n_grenade_charge_power ) && inflictor.n_grenade_charge_power >= 2 )
                self.helmet_hits = level.brutus_helmet_shots;
            else
                self.helmet_hits++;

            if ( self.helmet_hits >= level.brutus_helmet_shots )
            {
                self thread brutus_remove_helmet( vdir );

                if ( level.brutus_in_grief )
                    player_points = level.brutus_points_for_helmet;
                else
                {
                    multiplier    = maps\mp\zombies\_zm_score::get_points_multiplier( self );
                    player_points = multiplier * round_up_score( level.brutus_points_for_helmet, 5 );
                }

                if ( isdefined( attacker ) && isplayer( attacker ) )
                {
                    attacker add_to_player_score( player_points );
                    attacker.pers[ "score" ] = attacker.score;
                    level notify( "brutus_helmet_removed", attacker );
                }
            }

            return damage * n_brutus_damage_percent;
        }
        else
            return damage;
    }

    // ---- Shield fling ----
    if ( isdefined( meansofdeath ) && ( meansofdeath == "MOD_MELEE" || meansofdeath == "MOD_IMPACT" ) )
    {
        if ( weapon == "alcatraz_shield_zm" )
        {
            shield_damage = level.zombie_vars[ "riotshield_fling_damage_shield" ];
            inflictor maps\mp\zombies\_zm_weap_riotshield_prison::player_damage_shield( shield_damage, 0 );
            return 0;
        }
    }

    // ---- Afterlife lightning hands (teleport Brutus) ----
    if ( isdefined( level.zombiemode_using_afterlife ) && level.zombiemode_using_afterlife &&
         weapon == "lightning_hands_zm" )
    {
        self thread brutus_afterlife_teleport();
        return 0;
    }

    // ---- Explosive damage (accumulate toward helmet pop) ----
    if ( is_explosive_damage( meansofdeath ) )
    {
        self.explosive_dmg_taken += damage;

        // Stock: no-helmet → use headshot modifier; helmet → use base percent.
        if ( !self.has_helmet )
            scaler = n_brutus_headshot_modifier;
        else
            scaler = level.brutus_damage_percent;

        if ( self.explosive_dmg_taken >= self.explosive_dmg_req &&
             isdefined( self.has_helmet ) && self.has_helmet )
        {
            self thread brutus_remove_helmet( vectorscale( ( 0, 1, 0 ), 10.0 ) );

            if ( level.brutus_in_grief )
                player_points = level.brutus_points_for_helmet;
            else
            {
                multiplier    = maps\mp\zombies\_zm_score::get_points_multiplier( self );
                player_points = multiplier * round_up_score( level.brutus_points_for_helmet, 5 );
            }

            attacker add_to_player_score( player_points );
            attacker.pers[ "score" ] = attacker.score;   // fixed: was inflictor.score in your version
        }

        return damage * scaler;
    }
    else if ( shitloc != "head" && shitloc != "helmet" )
        return damage * n_brutus_damage_percent;
    else
        return int( self scale_helmet_damage( attacker, damage, n_brutus_headshot_modifier, n_brutus_damage_percent, vdir ) );
}

on_player_connect()
{
    for ( ;; )
    {
        level waittill( "connected", player );
        player.account_value = player maps\mp\zombies\_zm_stats::get_map_stat( "depositBox", "zm_transit" );
        player thread player_bank_hud_think();
    }
}

bank_setup()
{
    flag_wait( "initial_blackscreen_passed" );

    level.bank_deposit_max_amount = 250000;
    level.bank_deposit_ddl_increment_amount = 1000;
    // Scaled to 100 to match bank_mod_main.gsc (1 unit = 100 points)
    level.bank_account_max = 2500; // 2500 * 100 = 250,000
    level.bank_account_increment = 10; // 1000 / 100 = 10
    
    if ( !isdefined( level.ta_vaultfee ) )
        level.ta_vaultfee = 100;

    level.banking_map = "zm_transit";
    level.bank_power_active = false;

    // Precache shock box models
    precachemodel( "p6_zm_al_shock_box_off" );
    precachemodel( "p6_zm_al_shock_box_on" );

    // Spawn shock box at coordinates: (3496, 9504, 1336), angles: (0, -94, 0)
    shockbox = spawn( "script_model", ( 3496, 9490, 1336 ) );
    shockbox.angles = ( 0, 180, 0 );
    shockbox setmodel( "p6_zm_al_shock_box_off" );
    shockbox.script_string = "bank_power_on";
    shockbox.script_int = 0; // 0 allows infinite resets
    shockbox thread maps\mp\zombies\_zm_afterlife::afterlife_interact_object_think();

    level thread bank_power_listener( shockbox );

    deposit_spot = spawnstruct();
    deposit_spot.origin = ( 1651, 9240, 1336 );
    deposit_spot.angles = ( 0, 85, 0 );
    deposit_spot.script_length = 16;
    deposit_spot.targetname = "bank_deposit";

    withdraw_spot = spawnstruct();
    withdraw_spot.origin = ( 1651, 9768, 1336 );
    withdraw_spot.angles = ( 0, 87, 0 );
    withdraw_spot.script_length = 16;
    withdraw_spot.targetname = "bank_withdraw";

    level.bank_deposit_stub = deposit_spot bank_deposit_unitrigger();
    level.bank_withdraw_stub = withdraw_spot bank_withdraw_unitrigger();
}

bank_power_listener( shockbox )
{
    while ( true )
    {
        level waittill( "bank_power_on" );
        level.bank_power_active = true;

        if ( isdefined( level.bank_deposit_stub ) )
            level.bank_deposit_stub maps\mp\zombies\_zm_unitrigger::run_visibility_function_for_all_triggers();
        if ( isdefined( level.bank_withdraw_stub ) )
            level.bank_withdraw_stub maps\mp\zombies\_zm_unitrigger::run_visibility_function_for_all_triggers();

        level waittill( "end_of_round" );
        level.bank_power_active = false;
        shockbox notify( "afterlife_interact_reset" );

        if ( isdefined( level.bank_deposit_stub ) )
            level.bank_deposit_stub maps\mp\zombies\_zm_unitrigger::run_visibility_function_for_all_triggers();
        if ( isdefined( level.bank_withdraw_stub ) )
            level.bank_withdraw_stub maps\mp\zombies\_zm_unitrigger::run_visibility_function_for_all_triggers();
    }
}

custom_afterlife_player_damage_callback( einflictor, eattacker, idamage, idflags, smeansofdeath, sweapon, vpoint, vdir, shitloc, psoffsettime )
{
    if ( isdefined( eattacker ) )
    {
        if ( isdefined( eattacker.is_zombie ) && eattacker.is_zombie )
        {
            if ( isdefined( eattacker.custom_damage_func ) )
                idamage = eattacker [[ eattacker.custom_damage_func ]]( self );
            else if ( isdefined( eattacker.meleedamage ) && smeansofdeath != "MOD_GRENADE_SPLASH" )
                idamage = eattacker.meleedamage;

            if ( isdefined( self.afterlife ) && self.afterlife )
            {
                self maps\mp\zombies\_zm_afterlife::afterlife_reduce_mana( 10 );
                self clientnotify( "al_d" );
                return 0;
            }
        }
    }

    if ( isdefined( self.afterlife ) && self.afterlife )
        return 0;

    if ( isdefined( eattacker ) && ( isdefined( eattacker.is_zombie ) && eattacker.is_zombie || isplayer( eattacker ) ) )
    {
        if ( isdefined( self.hasriotshield ) && self.hasriotshield && isdefined( vdir ) )
        {
            item_dmg = 100;

            if ( isdefined( eattacker.custom_item_dmg ) )
                item_dmg = eattacker.custom_item_dmg;

            if ( isdefined( self.hasriotshieldequipped ) && self.hasriotshieldequipped )
            {
                if ( self maps\mp\zombies\_zm::player_shield_facing_attacker( vdir, 0.2 ) && isdefined( self.player_shield_apply_damage ) )
                {
                    self [[ self.player_shield_apply_damage ]]( item_dmg, 0 );
                    return 0;
                }
            }
            else if ( !isdefined( self.riotshieldentity ) )
            {
                if ( !self maps\mp\zombies\_zm::player_shield_facing_attacker( vdir, -0.2 ) && isdefined( self.player_shield_apply_damage ) )
                {
                    self [[ self.player_shield_apply_damage ]]( item_dmg, 0 );
                    return 0;
                }
            }
        }
    }

    if ( sweapon == "tower_trap_zm" || sweapon == "tower_trap_upgraded_zm" || sweapon == "none" && shitloc == "riotshield" && !( isdefined( eattacker.is_zombie ) && eattacker.is_zombie ) )
    {
        self.use_adjusted_grenade_damage = 1;
        return 0;
    }

    if ( smeansofdeath == "MOD_PROJECTILE" || smeansofdeath == "MOD_PROJECTILE_SPLASH" || smeansofdeath == "MOD_GRENADE" || smeansofdeath == "MOD_GRENADE_SPLASH" )
    {
        if ( sweapon == "blundersplat_explosive_dart_zm" )
        {
            // Fixed logic: use 'else if' to prevent overwriting damage to 10 for Flak Jacket (PhD) players.
            if ( self hasperk( "specialty_flakjacket" ) )
            {
                self.use_adjusted_grenade_damage = 1;
                idamage = 0;
            }
            else if ( isalive( self ) && !( isdefined( self.is_zombie ) && self.is_zombie ) )
            {
                self.use_adjusted_grenade_damage = 1;
                idamage = 10;
            }
        }
        else
        {
            if ( self hasperk( "specialty_flakjacket" ) )
                return 0;

            if ( self.health > 75 && !( isdefined( self.is_zombie ) && self.is_zombie ) )
                idamage = 75;
        }
    }

    if ( idamage >= self.health && ( isdefined( level.intermission ) && !level.intermission ) )
    {
        if ( self.lives > 0 && ( isdefined( self.afterlife ) && !self.afterlife ) )
        {
            self playsoundtoplayer( "zmb_afterlife_death", self );
            self maps\mp\zombies\_zm_afterlife::afterlife_remove();
            self.afterlife = 1;
            self thread maps\mp\zombies\_zm_afterlife::afterlife_laststand();

            if ( self.health <= 1 )
                return 0;
            else
                idamage = self.health - 1;
        }
        else
            self thread maps\mp\zombies\_zm_afterlife::last_stand_conscience_vo();
    }

    return idamage;
}


bank_deposit_unitrigger()
{
    return bank_unitrigger( "bank_deposit", ::trigger_deposit_update_prompt, ::trigger_deposit_think, 5, 5, undefined, 5 );
}

bank_withdraw_unitrigger()
{
    return bank_unitrigger( "bank_withdraw", ::trigger_withdraw_update_prompt, ::trigger_withdraw_think, 5, 5, undefined, 5 );
}

bank_unitrigger( name, prompt_fn, think_fn, override_length, override_width, override_height, override_radius )
{
    unitrigger_stub = spawnstruct();
    unitrigger_stub.origin = self.origin;

    if ( isdefined( self.script_angles ) )
        unitrigger_stub.angles = self.script_angles;
    else
        unitrigger_stub.angles = self.angles;

    unitrigger_stub.script_angles = unitrigger_stub.angles;

    if ( isdefined( override_length ) )
        unitrigger_stub.script_length = override_length;
    else if ( isdefined( self.script_length ) )
        unitrigger_stub.script_length = self.script_length;
    else
        unitrigger_stub.script_length = 32;

    if ( isdefined( override_width ) )
        unitrigger_stub.script_width = override_width;
    else if ( isdefined( self.script_width ) )
        unitrigger_stub.script_width = self.script_width;
    else
        unitrigger_stub.script_width = 32;

    if ( isdefined( override_height ) )
        unitrigger_stub.script_height = override_height;
    else if ( isdefined( self.script_height ) )
        unitrigger_stub.script_height = self.script_height;
    else
        unitrigger_stub.script_height = 64;

    if ( isdefined( override_radius ) )
        unitrigger_stub.script_radius = override_radius;
    else if ( isdefined( self.radius ) )
        unitrigger_stub.radius = self.radius;
    else
        unitrigger_stub.radius = 32;

    if ( isdefined( self.script_unitrigger_type ) )
        unitrigger_stub.script_unitrigger_type = self.script_unitrigger_type;
    else
    {
        unitrigger_stub.script_unitrigger_type = "unitrigger_box_use";
        unitrigger_stub.origin = unitrigger_stub.origin - anglestoright( unitrigger_stub.angles ) * ( unitrigger_stub.script_length / 2 );
    }

    unitrigger_stub.cursor_hint = "HINT_NOICON";
    unitrigger_stub.targetname = name;
    maps\mp\zombies\_zm_unitrigger::unitrigger_force_per_player_triggers( unitrigger_stub, 1 );
    unitrigger_stub.prompt_and_visibility_func = prompt_fn;
    maps\mp\zombies\_zm_unitrigger::register_static_unitrigger( unitrigger_stub, think_fn );
    return unitrigger_stub;
}

trigger_deposit_update_prompt( player )
{
    if ( !is_true( level.bank_power_active ) )
    {
        self sethintstring( &"ZOMBIE_NEED_POWER" );
        return false;
    }

    if ( player.score < level.bank_deposit_ddl_increment_amount || player.account_value >= level.bank_account_max )
    {
        self sethintstring( "" );
        return false;
    }

    self sethintstring( &"ZOMBIE_BANK_DEPOSIT_PROMPT", level.bank_deposit_ddl_increment_amount );
    return true;
}

trigger_deposit_think()
{
    self endon( "kill_trigger" );

    while ( true )
    {
        self waittill( "trigger", player );

        if ( !is_player_valid( player ) )
            continue;

        if ( !is_true( level.bank_power_active ) )
            continue;

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

trigger_withdraw_update_prompt( player )
{
    if ( !is_true( level.bank_power_active ) )
    {
        self sethintstring( &"ZOMBIE_NEED_POWER" );
        return false;
    }

    if ( player.account_value <= 0 )
    {
        self sethintstring( "" );
        return false;
    }

    self sethintstring( &"ZOMBIE_BANK_WITHDRAW_PROMPT", level.bank_deposit_ddl_increment_amount, level.ta_vaultfee );
    return true;
}

trigger_withdraw_think()
{
    self endon( "kill_trigger" );

    while ( true )
    {
        self waittill( "trigger", player );

        if ( !is_player_valid( player ) )
            continue;

        if ( !is_true( level.bank_power_active ) )
            continue;

        if ( player.account_value >= level.bank_account_increment )
        {
            player playsoundtoplayer( "zmb_vault_bank_withdraw", player );
            player.score = player.score + level.bank_deposit_ddl_increment_amount;
            level notify( "bank_withdrawal" );
            player.account_value = player.account_value - level.bank_account_increment;
            player maps\mp\zombies\_zm_stats::set_map_stat( "depositBox", player.account_value, level.banking_map );

            if ( isdefined( level.custom_bank_withdrawl_vo ) )
                player thread [[ level.custom_bank_withdrawl_vo ]]();

            player thread player_withdraw_fee();

            if ( player.account_value < level.bank_account_increment )
                self sethintstring( "" );
        }
    }
}

player_withdraw_fee()
{
    self endon( "disconnect" );
    wait_network_frame();
    self.score = self.score - level.ta_vaultfee;
}

player_bank_hud_think()
{
    self endon( "disconnect" );

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
        dist_dep = distance( self.origin, ( 1651, 9240, 1336 ) );
        dist_with = distance( self.origin, ( 1651, 9768, 1336 ) );

        if ( is_true( level.bank_power_active ) && ( dist_dep < 80 || dist_with < 80 ) )
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

plane_set_pieces_shared()
{
    foreach (stub in level.zombie_include_craftables)
    {
        if (stub.name == "plane" || stub.name == "refuelable_plane")
        {
            foreach (piece in stub.a_piecestubs)
            {
                piece.is_shared = 1;
                piece.client_field_state = undefined;
            }
        }
    }
}

wait_for_blundersplat_fired_override()
{
    self endon( "disconnect" );
    self waittill( "spawned_player" );

    for (;;)
    {
        self waittill( "weapon_fired", str_weapon );

        if ( str_weapon == "blundersplat_zm" )
        {
            self thread fire_blundersplat_projectiles( 1 ); // 1 = is_not_upgraded
        }
    }
}

wait_for_blundersplat_upgraded_fired_override()
{
    self endon( "disconnect" );
    self waittill( "spawned_player" );

    for (;;)
    {
        self waittill( "weapon_fired", str_weapon );

        if ( str_weapon == "blundersplat_upgraded_zm" )
        {
            self thread fire_blundersplat_projectiles( 0 ); // 0 = upgraded
        }
    }
}

fire_blundersplat_projectiles( is_not_upgraded )
{
    self endon( "disconnect" );
    
    // Fire 3 projectiles in a horizontal spread
    wait_network_frame();
    _titus_locate_target_override( is_not_upgraded, 0 ); // Center
    wait_network_frame();
    _titus_locate_target_override( is_not_upgraded, 1 ); // Right
    wait_network_frame();
    _titus_locate_target_override( is_not_upgraded, 2 ); // Left
}

_titus_locate_target_override( is_not_upgraded, count )
{
    fire_angles = self getplayerangles();
    fire_origin = self getplayercamerapos();

    // Set fuse detonation timers matching stock behavior
    if ( is_not_upgraded )
        n_fuse_timer = randomfloatrange( 1.0, 2.5 );
    else
        n_fuse_timer = randomfloatrange( 3.0, 4.0 );

    // Horizontal spread size tuning (5 degrees)
    n_spread = 5;
    
    if ( self isads() )
    {
        n_spread *= 0.5; // Tighter spread when aiming down sights
    }
    else if ( self hasperk( "specialty_deadshot" ) )
    {
        n_spread *= getdvarfloat( "perk_weapSpreadMultiplier" ); // Deadshot modifier scaling
    }

    // Apply horizontal spread offsets to yaw angle
    if ( count == 1 )
    {
        fire_angles += ( 0, n_spread, 0 );
    }
    else if ( count == 2 )
    {
        fire_angles -= ( 0, n_spread, 0 );
    }

    // Shoot projectile straight towards the adjusted camera view direction
    vec = anglestoforward( fire_angles );
    trace_end = fire_origin + vec * 20000;
    trace = bullettrace( fire_origin, trace_end, 1, self );
    offsetpos = trace["position"];
    
    // Shoot sticky dart bullet
    e_dart = magicbullet( "blundersplat_bullet_zm", fire_origin, offsetpos, self );
    e_dart thread _titus_reset_grenade_fuse_override( n_fuse_timer, is_not_upgraded );
}

_titus_reset_grenade_fuse_override( n_fuse_timer, is_not_upgraded )
{
    self waittill( "death" );

    a_grenades = getentarray( "grenade", "classname" );

    foreach ( e_grenade in a_grenades )
    {
        // Detect the custom blundergat sticky dart projectile entity
        if ( isdefined( e_grenade.model ) && e_grenade.model == "t6_wpn_zmb_projectile_blundergat" && !isdefined( e_grenade.fuse_reset ) )
        {
            e_grenade.fuse_reset = 1;
            e_grenade.fuse_time = n_fuse_timer;
            e_grenade resetmissiledetonationtime( n_fuse_timer );

            // Setup points of interest to attract zombies
            if ( is_not_upgraded )
                e_grenade create_zombie_point_of_interest( 250, 5, 10000 );
            else
                e_grenade create_zombie_point_of_interest( 500, 10, 10000 );

            return;
        }
    }
}

remove_weapon_limits()
{
    flag_wait( "initial_blackscreen_passed" );

    if ( isdefined( level.limited_weapons ) )
    {
        // Mob of the Dead Box Weapon Limits
        if ( isdefined( level.limited_weapons[ "blundergat_zm" ] ) )
            level.limited_weapons[ "blundergat_zm" ] = 8;
        if ( isdefined( level.limited_weapons[ "blundergat_upgraded_zm" ] ) )
            level.limited_weapons[ "blundergat_upgraded_zm" ] = 8;
        if ( isdefined( level.limited_weapons[ "minigun_alcatraz_zm" ] ) )
            level.limited_weapons[ "minigun_alcatraz_zm" ] = 8;
        if ( isdefined( level.limited_weapons[ "minigun_alcatraz_upgraded_zm" ] ) )
            level.limited_weapons[ "minigun_alcatraz_upgraded_zm" ] = 8;
        if ( isdefined( level.limited_weapons[ "raygun_mark2_zm" ] ) )
            level.limited_weapons[ "raygun_mark2_zm" ] = 8;
        if ( isdefined( level.limited_weapons[ "raygun_mark2_upgraded_zm" ] ) )
            level.limited_weapons[ "raygun_mark2_upgraded_zm" ] = 8;
    }
}
