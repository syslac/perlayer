#!/usr/bin/perl

use Test;
use cmd_arg;
use list;
use SDL;
use SDL::Mixer::Music;
use SDL::Mixer;
use Term::ReadKey;
use orm;
use player;
use strict;
use warnings;


plan(tests => 26);

# Player class test

my $player = new Player;
ok($player->(), undef);
ok($player->('quit'), 0);
ok($player->('playing'), 0);
ok($player->('paused'), 0);
ok($player->('quit', 1), 1);
ok($player->('playing', 1), 1);
ok($player->('paused', 1), 1);
ok($player->('quit'), 1);
ok($player->('playing'), 1);
ok($player->('paused'), 1);

$player->control('n');
ok($player->('playing'), 0);
$player->('playing', 1);
$player->control('q');
ok($player->('playing'), 0);
ok($player->('quit'), 1);
$player->control('p');
$player->control('n');
ok($player->('paused'), 0);
$player->control('p');
ok($player->('paused'), 1);
$player->control('p');
ok($player->('paused'), 0);

# Server tests

$player = Player->new();
open(my $clean, ">", ".server.txt");
print $clean "";
close $clean;
my $server = Server->new();
open(my $client, ">>", ".server.txt");
print $client "p\n";
print $client "p\n";
print $client "p\n";
close $client;
my @input = ();
while (my $key = $server->()){
	push @input, $key;
	$player->control($key);
}
ok(join("", @input), "ppp");
ok($player->('paused'), 1);
ok($server->(), undef);
ok($server->(1), undef);

# List tests

my $int = 1;
my $promise;
$promise = sub { return List::Lazy::node(++$int, $promise) if ($int <=20);
					return undef;
			};

my $list = List::Lazy::node(1, $promise);

ok(List::Lazy::data(List::Lazy::tail($list)), 2);
ok(List::Lazy::data(List::Lazy::tail($list)), 3);

# Grep tests

$int = 1;
my $list2 = List::Lazy::node(1, $promise);
my $odd = List::Lazy::l_grep { $_[0] % 2 } $list2;

ok(List::Lazy::data($odd), 1);
ok(List::Lazy::data(List::Lazy::tail($odd)), 3);
ok(List::Lazy::data(List::Lazy::tail(List::Lazy::tail(List::Lazy::tail($odd)))), 9);
ok(List::Lazy::data(List::Lazy::tail(List::Lazy::tail(List::Lazy::tail(List::Lazy::tail(List::Lazy::tail($odd)))))), 19);

# Simulated fixed-time or input break

$player = Player->new();
$player->('playing', 1);
my $index = 0;
while ($player->('playing')) {
	if (defined (my $key = ReadKey(-1))){
		$player->control('n') if ($key eq "n");
	}
	$index++;
	$player->('playing', 0) if ($index >= 50);
	SDL::delay(100);
}

ok($player->('playing'),0);

1;
