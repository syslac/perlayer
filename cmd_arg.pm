#!/usr/bin/perl

use strict;
use warnings;
use orm;
use score;
use player;
use server;
require list;



package CMD::Decision;
use Term::ReadKey;
use Time::HiRes qw(sleep usleep);

my $add_tracks = sub {
	my $path = shift;
	$path =~ s/(.*)?\/$/$1/;
	Player::Folder::User->create($path);
};

my $total;

my $skip = sub {
	my $alist = shift;
	my $player = shift;
	unless (List::Lazy::data($alist)) {
		$alist = List::Lazy::tail($alist, $player);
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
#	$player->stop();
	$alist = List::Lazy::tail($alist, $player);
	return $alist;
};

my $next;
$next = sub {
	my $player = shift;
	my $total = Player::Song->count() unless $total;
	return undef unless $total;
	my $index = undef;
	$index = $player->from_queue() if $player;
	my $song = undef;
	unless(defined($index)){
		if ($player && $player->('mood')){
			my $tag = Player::Tag->search({ name => $player->('mood')});
			die "You haven't used tag ".$player->('mood')." yet\n" unless $tag;
			my @albums = map {$_->album} ($tag->next->albums);
			die "You haven't tagged any album as ".$player->('mood')." yet\n" unless @albums;
			my $choice = (sort { rand > rand } @albums)[0];
			$index = ($choice->songs)[0]->id;
		}
		$index //= int(rand($total))+1;
		$song = Player::Song::User->retrieve($index);
		if ($player && $player->('mode') eq 'a') {
			my $album = $song->album;
			foreach my $track ($album->songs) {
				$player->enqueue($track->id);
			}
			$song = Player::Song::User->retrieve($player->from_queue());
		}
	}
	$song = Player::Song::User->retrieve($index) unless(defined($song));
	open (my $output, ">", "/tmp/status");
	print $output $song->title . "- ". $song->artist->name ." (". int($song->length/60) .":". sprintf("%02d", $song->length%60) .")\n";
	close $output;
	print "Playing ". $song->title . " by ". $song->artist->name ." (". int($song->length/60) .":". sprintf("%02d", $song->length%60) .")\n";
	my ($volume_gain, $rest) = split(" ", $song->replaygain_track_gain);
	my $volume = defined($volume_gain) ? int(100*(10**($volume_gain/20))) : undef;
	print "Replaygain : adjusted volume to ".$volume." \n";
	print "Song score : ".$song->score(Score::score())." \n";
	my $loaded = [$song->path, $volume];
	return List::Lazy::node([$loaded, $song], $next);
};

my $play = sub {
	my $mode = shift;
	$mode //= 't';
	my $mood = shift;
	my $player = new Player;
	$player->('mode', $mode);
	$player->('mood', $mood);
	my $ilist = List::Lazy::node(undef,$next);
	my $plist = List::Lazy::l_grep( sub {
		return unless($_[0]);
		return 1 if ($_[0]->[1]->score(Score::score()) > rand(100));
		return;
		}, $ilist, $player);
	$plist = ($mode eq 'a') ? $ilist : $plist;
	ReadMode 4;
	my $server = new Server;
	open (my $percent, ">", "/tmp/status-percent");
	while (!$player->('quit') && ($plist = $skip->($plist, $player))){
		$player->play(List::Lazy::data($plist)->[0]);
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
			$player->('time', $len*0.1);
			$len++;
			seek ($percent,0,0);
			print $percent int(100*$player->('time')/$player->('current')->length);
			$player->control('e') if($player->finished());
			sleep(0.1);
		}
	}
	close $percent;
	$server->clean();
	ReadMode 1;
};

my $mood = sub {
	my $mood = shift;
	$play->('a',$mood);
};

my $default = sub {
	my $und = shift;
	warn "Undefined command line option $und, defaulting to play\n";
	$play->();
};

sub clean_up {
	unlink ".server.txt";
	ReadMode 1;	
}

{
	my %args_table = (
		"a" => [$add_tracks,1],
		"p" => [$play,1],
		"m" => [$mood,1],
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
