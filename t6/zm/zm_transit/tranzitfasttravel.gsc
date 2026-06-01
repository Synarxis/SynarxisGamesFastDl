#include maps\mp\_utility;
#include common_scripts\utility;
#include maps\mp\zombies\_zm;
#include maps\mp\gametypes_zm\_hud_util;
#include maps\mp\gametypes_zm\_hud_message;

init()
{
	level thread onplayerconnect();
	create_dvar( "fasttravel_price", 1500 );
	create_dvar( "fasttravel_activateonpower", 0 );
	level thread checktransit(); // <-- FIX 1: Threaded to prevent init() from stalling
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
	level endon( "game_ended" );
	for(;;)
	{
		self waittill( "spawned_player" );
		if( level.scr_zm_map_start_location == "transit" && getdvar( "g_gametype" ) == "zclassic" )
		{
			self iprintln( "^4Tranzit Fast Travel ^7created by ^1techboy04gaming" );
		}
	}
}

checktransit()
{
	if( level.scr_zm_map_start_location == "transit" && getdvar( "g_gametype" ) == "zclassic" )
	{
		createtriggers();
		level.activatefasttravel = 0;
	}
}

createtravel( location, destination, angle, whereto )
{
	// REVERTED FIX: Back to trigger_radius. This is the correct, non-looping way.
	traveltrigger = spawn( "trigger_radius", location, 1, 50, 50 ); 
	traveltrigger sethintstring( "^7Something needs to be activated..." );
	traveltrigger setcursorhint( "HINT_NOICON" );
	travelmodel = spawn( "script_model", location );
	travelmodel setmodel( "p6_zm_screecher_hole" );
	travelmodel rotateto( angle, 0.1 );
	
	level waittill( "fasttravel_on" );
	
	playfx( level._effect[ "screecher_vortex"], location, anglestoforward( 0 ), 45, 55 );
	traveltrigger sethintstring( "^7Press ^3&&1 ^7to travel to ^3" + ( whereto + ( "^7 [Cost: " + ( getdvar( "fasttravel_price" ) + "]" ) ) ) );
	
	while( 1 )
	{
		traveltrigger waittill( "trigger", i ); // This will fire rapidly (laggy)
		
		if( i.score >= getdvarint( "fasttravel_price" ) )
		{
			if( level.activatefasttravel == 1 )
			{
				// REVERTED FIX: This check prevents the loop.
				if( i usebuttonpressed() ) 
				{
					i.score = i.score - getdvarint( "fasttravel_price" );
					i playsound( "zmb_weap_wall" );
					
					fadetowhite = newhudelem();
					fadetowhite.x = 0;
					fadetowhite.y = 0;
					fadetowhite.alpha = 0;
					fadetowhite.horzalign = "fullscreen";
					fadetowhite.vertalign = "fullscreen";
					fadetowhite.foreground = 1;
					fadetowhite setshader( "black", 640, 480 );
					fadetowhite fadeovertime( 0.2 );
					fadetowhite.alpha = 1;
					
					i.ignoreme = 1;
					i enableinvulnerability();
					
					wait 2;
					
					i setorigin( destination );
					
					fadetowhite fadeovertime( 1 );
					fadetowhite.alpha = 0;
					
					wait 1.1;
					
					fadetowhite destroy();
					i.ignoreme = 0;
					i disableinvulnerability();
				}
			}
		}
	}
}

createtriggers()
{
	level thread createtravel( ( -7424.21, 4201.22, -63.5 ), ( -5143.78, -7402.17, -69 ), ( 0, 77, 0 ), "Diner" );
	level thread createtravel( ( -6073.19, 4519.49, -54.216 ), ( 1992.76, -437.126, -61.875 ), ( 0, 160, 0 ), "Town" );
	level thread createtravel( ( -4145.74, -7440.28, -63.875 ), ( 6929.9, -5716.29, -59 ), ( 0, 133, 0 ), "Farm" );
	level thread createtravel( ( -6235.26, -7147.53, -62.744 ), ( -6764.35, 5460.54, -55.875 ), ( 0, 53, 0 ), "Bus Depot" );
	level thread createtravel( ( 6821.2, -5470.26, -67 ), ( 10889.5, 7554.89, -588 ), ( 0, 164, 0 ), "Power Station" );
	level thread createtravel( ( 6770.84, -5973.64, -64 ), ( -5143.78, -7402.17, -69 ), ( 0, 141, 0 ), "Diner" );
	level thread createtravel( ( 10745.1, 7790.9, -585.129 ), ( 1992.76, -437.126, -61.875 ), ( 0, -90, 0 ), "Town" );
	level thread createtravel( ( 11310.6, 7792.6, -545 ), ( 6929.9, -5716.29, -59 ), ( 0, -164, 0 ), "Farm" );
	level thread createtravel( ( 686.931, -732.29, -55.875 ), ( -6764.35, 5460.54, -55.875 ), ( 0, 90, 0 ), "Bus Depot" );
	level thread createtravel( ( 1897.9, 846.475, -55.2886 ), ( 10889.5, 7554.89, -588 ), ( 0, 177, 0 ), "Power" );
	
	if( getdvarint( "fasttravel_activateonpower" ) == 1 )
	{
		level waittill( "power_on" );
		level notify( "fasttravel_on" );
		level.activatefasttravel = 1;
	}
	else
	{
		level thread spawntravelactivator( 993.641, 258.615, -39.875 );
	}
}

spawntravelactivator( x, y, z )
{
	travelactivatortrigger = spawn( "trigger_radius", ( x, y, z ), 1, 50, 50 );
	travelactivatortrigger sethintstring( "^7The power must be activated first!" );
	travelactivatortrigger setcursorhint( "HINT_NOICON" );
	
	level waittill( "power_on" );
	
	travelactivatortrigger sethintstring( "^7Press ^3&&1 ^7to activate Fast Travel phones" );
	
	while( 1 ) // <-- FIX 2: Changed from "if( 1 )"
	{
		travelactivatortrigger waittill( "trigger", i );
		
		if( i usebuttonpressed() )
		{
			i playsound( "zmb_weap_wall" );
			level notify( "fasttravel_on" );
			level.activatefasttravel = 1;
			travelactivatortrigger delete();
			break; // <-- FIX 2: Exit the loop once activated
		}
	}
}

create_dvar( dvar, set )
{
	if( getdvar( dvar ) == "" )
	{
		setdvar( dvar, set );
	}
}