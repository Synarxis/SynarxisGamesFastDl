/*
*	 Black Ops 2 - GSC Studio by iMCSx
*
*	 Creator : Fraz
*	 Project : bank
*    Mode : Zombies
*	 Date : 2025-06-06 - 05:53:33	
*
*/	

#include maps\mp\_utility;
#include common_scripts\utility;
#include maps\mp\gametypes_zm\_hud_util;
#include maps\mp\gametypes_zm\_hud_message;

init()
{
    level thread onPlayerConnect();
}

onPlayerConnect()
{
    for(;;)
    {
        level waittill("connected", player);
        player thread onPlayerSpawned();
    }
}

onPlayerSpawned()
{
    self endon("disconnect");
    for(;;)
    {
        self waittill("spawned_player");
		{
			self thread give_bank();
		}
		
	}
}

give_bank()
{
	flag_wait("initial_blackscreen_passed");
	self.account_value = 2500;		
    
}

