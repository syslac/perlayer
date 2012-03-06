#!/usr/bin/perl

use strict;
use warnings;

package Config;

{
	my $db_cfg = ".tables";
	my $cfg = ".config";

sub generate_sql {
	open(my $cfg, "<", $db_cfg);
	my @file = <$cfg>;
	my $file = join("", @file);
	my @tables = split("\n\n", $file);
	my %output;
	foreach my $table (@tables) {
		my @lines = split("\n", $table);
		my $name = shift @lines;
		$output{$name} .= "CREATE TABLE IF NOT EXISTS `".$name."` (\n";
		foreach my $field (@lines) {
			$output{$name} .= "`".join("` ", split("=", $field))." ,\n";
		}
		($output{$name}) =~ s/\,\n$/\n/;
		$output{$name} .= ")";
	}
	return \%output;
}

sub init_db {
	my $dbi = shift;
	my $queries = generate_sql();
	foreach (keys %{$queries}) {
		$dbi->do($queries->{$_});
	}
}

}
		
1;
