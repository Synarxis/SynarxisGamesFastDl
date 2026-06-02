main()
{
	mapname = getDvar( "mapname" );
	if ( mapname != "zm_transit" && mapname != "zm_highrise" && mapname != "zm_buried" )
	{
		level thread on_player_connect();
	}
	level thread command_thread();
	level thread auto_deposit_on_end_game();
}

command_thread()
{
	level endon( "end_game" );
	while ( true )
	{
		level waittill( "say", message, player, isHidden );
		args = strTok( message, " " );
		command = args[ 0 ];
		switch ( command )
		{
			case ".w":
			case ".with":
			case ".withdraw":
			 	player withdraw_logic( args[ 1 ] );
				break;
			case ".d":
			case ".dep":
			case ".deposit":
				player deposit_logic( args[ 1 ] );
				break;
			case ".b":
			case ".bal":
			case ".balance":
				player balance_logic();
				break;
			default:
				break;
		}
	}
}

auto_deposit_on_end_game()
{
	level waittill( "end_game" );
	wait 1;
	foreach ( player in level.players )
	{
		player deposit_logic( "all" );
	}
}

on_player_connect()
{
	level endon( "end_game" );
	while ( true )
	{
		level waittill( "connected", player );
		player.account_value = player maps\mp\zombies\_zm_stats::get_map_stat( "depositBox", "zm_transit" );
	}
}

withdraw_logic( amount )
{
	if ( !isDefined( self.account_value ) )
	{
		self thread bank_print( "Map is not bank compatible" );
		return;
	}
	if ( self.account_value <= 0 )
	{
		self thread bank_print( "Withdraw failed: empty bank" );
		return;
	}
	if ( self.score >= 1000000 )
	{
		self thread bank_print( "Withdraw failed: Max score is 1000000" );
		return;
	}
	if ( !isDefined( amount ) )
	{
		self thread bank_print( "Usage .w <number|all>" );
		return;
	}

	// Scale changed to 100
	num_score = int( floor( self.score / 100 ) ); 
	
	if ( is_str_int( amount ) )
	{
		num_amount = int( amount );
		if ( num_amount < 100 )
		{
			self thread bank_print( "Withdraw failed: Value must be 100 or greater" );
			return;
		}
		divided_value = num_amount / 100;
		num_amount = int( floor( divided_value ) );
	}
	else if ( amount == "all" )
	{
		num_amount = self.account_value;
	}
	else 
	{
		self thread bank_print( "Usage .w <number|all>" );
		return;
	}

	if ( num_amount > self.account_value )
	{
		num_amount = self.account_value;
	}

	new_balance = self.account_value - num_amount;
	
	// Max score unit is now 10,000 (10,000 * 100 = 1,000,000)
	over_balance = num_score + num_amount - 10000;
	max_score_available = abs( num_score - 10000 );

	if ( over_balance > 0 ) 
	{
		num_amount = max_score_available;
		new_balance = self.account_value - num_amount;
	}

	self.account_value = new_balance;
	final_amount = num_amount * 100;
	self.score += final_amount;
	self maps\mp\zombies\_zm_stats::set_map_stat( "depositBox", new_balance, "zm_transit" );
	self thread bank_print( "Successfully withdrew " + final_amount );
}

deposit_logic( amount )
{
	if ( !isDefined( self.account_value ) )
	{
		self thread bank_print( "Map is not bank compatible" );
		return;
	}
	if ( self.score <= 0 )
	{
		self thread bank_print( "Deposit failed: Not enough points" );
		return;
	}
	
	// Max bank unit is now 2,500 (2,500 * 100 = 250,000)
	if ( self.account_value >= 2500 ) 
	{
		self thread bank_print( "Deposit failed: Max bank is 250000" );
		return;
	}
	if ( !isDefined( amount ) )
	{
		self thread bank_print( "Usage .d <number|all>" );
		return;
	}

	num_score = int( floor( self.score / 100 ) );

	if ( is_str_int( amount ) )
	{
		num_amount = int( amount );
		if ( num_amount < 100 )
		{
			self thread bank_print( "Deposit failed: Value must be 100 or greater" );
			return;
		}
		divided_value = num_amount / 100;
		num_amount = int( floor( divided_value ) );
	}
	else if ( amount == "all" )
	{
		num_amount = num_score;
	}
	else 
	{
		self thread bank_print( "Usage .d <number|all>" );
		return;
	}

	if ( num_amount > num_score )
	{
		num_amount = num_score;
	}
	
	// Max allowed in bank is 2500 units
	if ( num_amount > 2500 ) 
	{
		num_amount = 2500;
	}
	
	new_balance = self.account_value + num_amount;
	over_balance = new_balance - 2500;
	
	if ( over_balance > 0 )
	{
		num_amount -= over_balance;
		new_balance -= over_balance;
	}
	self.account_value = new_balance;
	final_amount = num_amount * 100;
	self.score -= final_amount;
	self maps\mp\zombies\_zm_stats::set_map_stat( "depositBox", new_balance, "zm_transit" );
	self thread bank_print( "Successfully deposited " + final_amount );
}

balance_logic()
{
	self thread bank_print( "Current balance: " + (self.account_value * 100) + " Max: 250000" );
}

is_str_int( str )
{
	val = 0;
	list_num = [];
	list_num[ "0" ] = val; val++;
	list_num[ "1" ] = val; val++;
	list_num[ "2" ] = val; val++;
	list_num[ "3" ] = val; val++;
	list_num[ "4" ] = val; val++;
	list_num[ "5" ] = val; val++;
	list_num[ "6" ] = val; val++;
	list_num[ "7" ] = val; val++;
	list_num[ "8" ] = val; val++;
	list_num[ "9" ] = val;

	for ( i = 0; i < str.size; i++ )
	{
		if ( !isDefined( list_num[ str[ i ] ] ) )
		{
			return false;
		}
	}
	return true;
}

bank_print( text )
{
	self endon( "disconnect" );
	self notify( "bank_hud_update" );
	self endon( "bank_hud_update" );

	if ( !isDefined( self.bank_hud ) )
	{
		self.bank_hud = newClientHudElem( self );
		self.bank_hud.alignx = "left";
		self.bank_hud.aligny = "middle";
		self.bank_hud.horzalign = "user_left";
		self.bank_hud.vertalign = "user_bottom";
		self.bank_hud.foreground = 1;
		self.bank_hud.hidewheninmenu = 1;
		self.bank_hud.font = "default";
		self.bank_hud.fontscale = 1.3;
		self.bank_hud.color = ( 1, 1, 1 );
	}

	// Positions: shifted up on Origins to clear custom elements
	if ( getDvar( "mapname" ) == "zm_tomb" )
	{
		self.bank_hud.x = 10;
		self.bank_hud.y = -205; // Shifted up past health bar/zone notifier
	}
	else
	{
		self.bank_hud.x = 10;
		self.bank_hud.y = -140; // Default position above normal iPrintLn range
	}

	self.bank_hud setText( text );
	self.bank_hud.alpha = 1;

	wait 4;

	self.bank_hud fadeOverTime( 1.0 );
	self.bank_hud.alpha = 0;

	wait 1;
	if ( isDefined( self.bank_hud ) )
	{
		self.bank_hud destroy();
		self.bank_hud = undefined;
	}
}