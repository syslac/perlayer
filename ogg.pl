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

$SIG{__DIE__} =  sub { &CMD::Decision::clean_up(); };

my $callback = CMD::Decision::get_callback(@ARGV);
$callback->[0]->($callback->[1]);

CMD::Decision::clean_up();
