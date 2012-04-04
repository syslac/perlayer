#!/usr/bin/perl
#

require list;
require cmd_arg;
use orm;
use config;
use strict;
use warnings;
use DBI;

###
# DB Init
###
my $dbh = DBI->connect("dbi:SQLite:dbname=player_stats","","");
Config::init_db($dbh);
Config::startup_commands();
Config::read_weights();

$SIG{__DIE__} =  sub { &CMD::Decision::clean_up(); };

@ARGV = @{Config::startup_mode()} unless @ARGV;
my $callback = CMD::Decision::get_callback(@ARGV);
$callback->[0]->($callback->[1]);

CMD::Decision::clean_up();
