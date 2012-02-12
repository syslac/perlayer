#!/usr/bin/perl

package Score;

my %score_functs = (
	played => sub{
		my $played = shift;
		return 10 unless $played;
		return int(10*(1-(0.75**$played)));		
	},
	last_played => sub {
		my $last = shift;
		return 50 unless($last);
		$diff = time() - $last; 	
		return int($diff/(24*3600));
	},
	user_score => sub {
		my $uscore = shift;
		return 30 unless $uscore;
		return int($uscore*30);	
	},
	time_score => sub {
		my $tscore = shift;
		return 20 unless $tscore;
		return int($tscore*20);	
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
