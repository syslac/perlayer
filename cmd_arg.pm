#!/usr/bin/env perl

use strict;
use warnings;
use autodie;
use orm;
use score;
use player;
use server;
use config;
use AnyEvent;
use POSIX qw/floor ceil/;
use Carp qw/confess/;
use utf8;
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
	my $played = $stats->played;
	my $tscore = $stats->time_score;
	my $l_after = $stats->liked_after;
	my $d_after = $stats->disliked_after;
	$played //= 1;
	$tscore //= 0;
	$l_after //= "";
	$d_after //= "";
	$stats->set(played => $played, last_played => time);
	my $new_score = ($tscore*($played-1)+$gained)/$played;
	$stats->set(time_score => $new_score);
	$stats->set(liked_after => ($l_after." ".$player->('last'))) if ($gained >= 0.5);
	$stats->set(disliked_after => ($d_after." ".$player->('last'))) if ($gained < 0.5);
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
	open (my $output, ">", ".current_status");
	print $output $song->title . "::". $song->artist->name ."::". $song->album->title."::". int($song->length/60) .":". sprintf("%02d", $song->length%60). "::00::". $player->('paused');
	close $output;
	print "\nPlaying ". $song->title . " by ". $song->artist->name ." (". $song->album->title.") (". int($song->length/60) .":". sprintf("%02d", $song->length%60) .")\n";
	$song->user_score(0) unless defined($song->user_score);
	my ($volume_gain, $rest) = split(" ", $song->replaygain_track_gain);
	my $volume = defined($volume_gain) ? int(100*(10**($volume_gain/20))) : undef;
	print "Replaygain : adjusted volume to ".$volume." \n" if $player->('verbose');
	print "Song score : ".$song->score(Score::score())." \n" if $player->('verbose');
	my $loaded = [$song->path, $volume];
	return List::Lazy::node([$loaded, $song], $next);
};

sub add_timer {
	my ($player,$server) = @_;
	my $len = 0;
	open (my $percent, "+>", ".current_status");
	return AnyEvent->timer(
		after => 0,
		interval => 0.1,
		cb => sub {
			ReadMode 'cbreak';
			while (my $key = $server->()){
				print "$key\n";
				$player->control($key);
			}
			$player->('time', $len*0.1);
			$len++ unless $player->('paused');
			my $perc = int(100*$player->('time')/$player->('current')->length);
			seek($percent,-5,2);
			print $percent sprintf("%02d", $perc)."::". $player->('paused');
			print "\b"x70;
			print "|"."#"x(POSIX::ceil($perc/2))."-"x(POSIX::floor((100-$perc)/2))."|";
			print '('.($player->('paused') ? '||' : ' ▸').')';
			print "    ".'★'x(10*$player->('current')->user_score);
			print '☆'x(10-10*$player->('current')->user_score);
			}
	);
}

sub handle_input {
	my ($player) = @_;
	return AnyEvent->io(
		fh => \*STDIN,
		poll => 'r',
		cb => sub {
			if (defined (my $key = ReadKey(-1))){
				$player->control($key);
			}
		}
	);
}

sub server_input {
	my ($player,$fh) = @_;
	return AnyEvent->io(
		fh => $fh,
		poll => 'r',
		cb => sub {
			my $key = <$fh>;
			return unless $key;
			chomp $key;
			$player->control($key);
		}
	);
}

my $play = sub {
	my $mode = shift;
	$mode //= 't';
	my $mood = shift;
	my $player = new Player;
	$player->('mode', $mode);
	$player->('mood', $mood);
	$player->('verbose', Config::verbose());
	my $plist = ($mode eq 'a') ? List::Lazy::node(undef,$next) : 
		List::Lazy::l_grep( sub {
		return unless($_[0]);
		return 1 if ($_[0]->[1]->score(Score::score()) > rand(100));
		return;
		}, List::Lazy::node(undef,$next), $player);
	my $server = new Server;
	my $in = handle_input($player);
	open (my $percent, "+>", ".current_status");
	while (!$player->('quit') && ($plist = $skip->($plist, $player))){
		my $song_timer = add_timer($player,$server);
		$player->play(List::Lazy::data($plist)->[0]);
		$player->('current', List::Lazy::data($plist)->[1]);
		$player->('chld')->recv;
		undef $song_timer;
	}
	close $percent;
	ReadMode 'normal';
};

my $mood = sub {
	my $mood = shift;
	$play->('a',$mood);
};

my $stats = sub {
	my $top = shift;
	$top //= 'a';
	if ($top eq 'a'){
		Player::Album->top5();
	}
	elsif ($top eq 't'){
		Player::Song->top5();
	}
	elsif ($top eq 'p'){
		Player::Artist->top5();
	}
	else {
		Player::Album->top5();
	}
};

my $default = sub {
	my $und = shift;
	warn "Undefined command line option $und, defaulting to play\n";
	$play->();
};

sub clean_up {
	unlink ".server.txt" or die "Cannot delete temp server file in cmd_arg: possible permission problem? $!\n";
	unlink ".current_status";
	ReadMode 'normal';	
}

{
	my %args_table = (
		"a" => [$add_tracks,1],
		"p" => [$play,1],
		"m" => [$mood,1],
		"s" => [$stats,1],
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
