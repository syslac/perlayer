#!/usr/bin/perl
#

use SDL;
use SDL::Audio;
use SDL::Mixer;
use SDL::Mixer::Music;
require list;
require cmd_arg;
use orm;
use strict;
use warnings;

###
# SDL audio init
###

die "No audio" if (SDL::init(SDL_INIT_AUDIO) == -1);

die "No ogg" unless (SDL::Mixer::init(MIX_INIT_OGG));
#die "No ogg" unless (SDL::Mixer::init(MIX_INIT_MP3));
die "No audio 2" if (SDL::Mixer::open_audio( 44100, AUDIO_S16, 2, 1024 ) == -1);

my $volume_before = SDL::Mixer::Music::volume_music(100);

my $callback = CMD::Decision::get_callback(@ARGV);
$callback->[0]->($callback->[1]);

###
# Couple of callbacks
###

#my $next = sub {
#	$playing = 0;	
#	return undef unless @playlist;
#	my $index = int(rand($#playlist+1));
#	my $n = splice(@playlist, $index, 1);
#	print scalar(@playlist)."\n";
#	my $name = $n;
#   	$name =~ s/(.*)?\/(.*)?.ogg/$2/;
#	open (my $f, ">", "/tmp/cmus-status");
#   	print $f "$name";	
#	close $f;
#	print "Playing ". $n . "\n";
#	return SDL::Mixer::Music::load_MUS($n);
#};
#
#my $plist = node(undef, $next);
#
#my $skip = sub {
#	my $alist = shift;
#	$alist = tail($alist);
#	$playing = 0;
#	return $alist;
#};
#sub skip_song { 
#	$plist = $skip->($plist);
#	SDL::Mixer::Music::play_music(data($plist), 0);
#};
#
####
## Playing ;)
####
#
#$plist = $skip->($plist);
#while (data($plist)){
#	SDL::Mixer::Music::hook_music_finished('main::skip_song');
#	SDL::Mixer::Music::play_music(data($plist), 0);
#	while ($playing == 1) {
#		if (<STDIN> =~ /n/){
#			$plist = $skip->($plist);
#			last;
#		}
#		SDL::delay(100);
#	}
#}
#
