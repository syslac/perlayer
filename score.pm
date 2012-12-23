#!/usr/bin/env perl

package Score;
use config qw(get_weight);

my %score_functs = (
	played => sub{
		my $played = shift;
		return Config::get_weight('played') unless $played;
		return int(Config::get_weight('played')*(1-(0.75**$played)));		
	},
	last_played => sub {
		my $last = shift;
		return Config::get_weight('last_played') unless($last);
		$diff = time() - $last; 	
		return int($diff/(24*3600));
	},
	user_score => sub {
		my $uscore = shift;
		return Config::get_weight('user_score') unless $uscore;
		return int($uscore*Config::get_weight('user_score'));	
	},
	time_score => sub {
		my $tscore = shift;
		return Config::get_weight('time_score') unless $tscore;
		return int($tscore*Config::get_weight('time_score'));	
	},
	liked_after => sub {
		return 0;	
	},
	disliked_after => sub {
		return 0;
	},	
);

sub score {
	return \%score_functs;
}

1;
