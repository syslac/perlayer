#!/usr/bin/perl

use strict;
use warnings;
use orm;
use score;
use player;
use server;
require list;

package CMD::Decision;
use SDL;
use Term::ReadKey;
use Data::Dumper;

my $add_tracks = sub {
	my $path = shift;
	$path =~ s/(.*)?\/$/$1/;
	return unless (-d $path);
	my @dirs = ($path);
	my @candidates = ();
	while (@dirs){
		my $dir_path = shift @dirs;
		warn "Adding directory ". $dir_path ."\n";
		opendir (DIR, $dir_path);
		foreach my $file (readdir DIR){
			$file = $dir_path ."/".$file;
			next if ($file =~ /\.{1,2}$/); 
			push @dirs, $file if (-d $file);
			push @candidates, $file if ($file =~ /(.*)?\.(mp3|ogg)$/i);
		}	
		close DIR;
	}
	foreach (@candidates){
		my $song = Player::Song::User->search({path => $_});
		print "Skipping $_ : already in collection\n" if $song;
		Player::Song::User->create({path => $_}) unless $song;
	}
};

my $total;

my $skip = sub {
	my $alist = shift;
	my $player = shift;
	unless (List::Lazy::data($alist)) {
		$alist = List::Lazy::tail($alist);
		return $alist;
	}
	my $stats = List::Lazy::data($alist)->[1];
	my $gained = $player->('time')/($stats->length);
	$stats->set(played => $stats->played()+1, last_played => time);
	my $new_score = ($stats->time_score*($stats->played()-1)+$gained)/$stats->played;
	$stats->set(time_score => $new_score);
	$stats->set(liked_after => ($stats->liked_after." ".$player->('last'))) if ($gained >= 0.5);
	$stats->set(disliked_after => ($stats->disliked_after." ".$player->('last'))) if ($gained < 0.5);
	$stats->update();
	$player->('last', $stats->id);
	$alist = List::Lazy::tail($alist);
	return $alist;
};

my $prova :shared = 0;

sub end_song { 
	return set_playing(0);
};

my $next;
$next = sub {
	my $total = Player::Song->count() unless $total;
	return undef unless $total;
	my $index = int(rand($total))+1;
	my $song = Player::Song::User->retrieve($index);
	open (my $output, ">", "/tmp/cmus-status");
	print $output $song->title . "- ". $song->artist ." (". int($song->length/60) .":". sprintf("%02d", $song->length%60) .")\n";
	close $output;
	print "Playing ". $song->title . " by ". $song->artist ." (". int($song->length/60) .":". sprintf("%02d", $song->length%60) .")\n";
	my ($volume_gain, $rest) = split(" ", $song->replaygain_track_gain);
	SDL::Mixer::Music::volume_music(100*(10**($volume_gain/20)));
	print "Replaygain : adjusted volume to ".SDL::Mixer::Music::volume_music(-1)." \n";
	print "Song score : ".$song->score(Score::score())." \n";
	my $loaded = SDL::Mixer::Music::load_MUS($song->path);
	return List::Lazy::node([$loaded, $song], $next);
};

my $play = sub {
	my $ilist = List::Lazy::node(undef, $next);
	my $plist = List::Lazy::l_grep {
		return unless($_[0]);
		return 1 if ($_[0]->[1]->score(Score::score()) > rand(100));
		return;
		} $ilist;
	my $player = new Player;
	my $server = new Server;
	while (!$player->('quit') && ($plist = $skip->($plist, $player))){
		SDL::Mixer::Music::play_music(List::Lazy::data($plist)->[0], 0);
		$player->('current', List::Lazy::data($plist)->[1]);
		$player->('playing', 1);
		$player->('time', 0);
		my $len = 0;
		while ($player->('playing')) {
			if (defined (my $key = ReadKey(-1))){
				$player->control($key);
			}
			while (my $key = $server->()){
				print "$key\n";
				$player->control($key);
			}
			$len++ unless $player->('paused');
			$player->('time', $len/10);
			open (my $percent, ">", "/home/syslac/.fluxbox/cmus-percent");
			print $percent int(100*$player->('time')/$player->('current')->length);
			close $percent;
			$player->('playing', 0) if(int($len/10) > List::Lazy::data($plist)->[1]->length);
			SDL::delay(100);
		}
	}
};


my $default = sub {
	my $und = shift;
	warn "Undefined command line option $und, defaulting to play\n";
	$play->();
};

{
	my %args_table = (
		"a" => [$add_tracks,1],
		"p" => [$play,0],
		"default" => [$default,0],
	);

	sub get_callback {
		my @arg = @_;
		$arg[0] = "-p" unless @arg;
		$arg[0] =~ s/-*//;
		$arg[0] = (exists $args_table{$arg[0]}) ? $arg[0] : "default";
		return [$args_table{$arg[0]}->[0], $_[$args_table{$arg[0]}->[1]]];
	}
}
