#!/usr/bin/perl
#

require list;
require cmd_arg;
use orm;
use strict;
use warnings;

my $callback = CMD::Decision::get_callback(@ARGV);
$callback->[0]->($callback->[1]);

