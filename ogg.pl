#!/usr/bin/perl
#

require list;
require cmd_arg;
use orm;
use strict;
use warnings;
use DBI;

###
# DB Init
###
my $dbh = DBI->connect("dbi:SQLite:dbname=player_stats","","");
$dbh->do( "CREATE  TABLE IF NOT EXISTS `collection` (
  `id` INTEGER PRIMARY KEY UNIQUE ,
  `path` TEXT UNIQUE NOT NULL,
  `artist` TEXT ,
  `title` TEXT ,
  `album` TEXT ,
  `genre` TEXT ,
  `length` INTEGER ,
  `played` INTEGER ,
  `last_played` INTEGER ,
  `user_score` INTEGER ,
  `time_score` INTEGER ,
  `liked_after` TEXT ,
  `disliked_after` TEXT ,
  `replaygain_track_gain` TEXT 
   )" ) ;

my $callback = CMD::Decision::get_callback(@ARGV);
$callback->[0]->($callback->[1]);

