#!/usr/bin/perl

use strict;
use warnings;

package Config;

{
	my $db_cfg = ".tables";
	my $cfg = ".config";

sub parse_file {
	my $what = shift;
	open(my $cfg, "<", $what);
	my @file = <$cfg>;
	my $file = join("", @file);
	my @tables = split("\n\n", $file);
	my $output = {};
	foreach my $table (@tables) {
		my @lines = split("\n", $table);
		my $name = shift @lines;
		$output->{$name} = {};
		foreach my $field (@lines) {
			$field =~ s/(.*)\#.*/$1/;
			my ($k,$v) = split(/\s*=\s*/, $field);
			$output->{$name}->{$k} = $v;
		}
	}
	return $output;
}


sub generate_sql {
	my $parsed = parse_file($db_cfg);
	my %output = ();
	foreach my $table (keys %{$parsed}) {
		$output{$table} .= "CREATE TABLE IF NOT EXISTS `".$table."` (\n";
		while (my($f,$p) = each %{$parsed->{$table}}) {
			$output{$table} .= "`".$f."` ".$p." ,\n";
		}
		($output{$table}) =~ s/\,\n$/\n/;
		$output{$table} .= ")";
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

sub startup_commands {
	my $cmd = (parse_file($cfg))->{"startup"};
	open(my $srv, ">", ".server.txt");
	while(my($k,$v) = each($cmd)) {
		print $srv $k."\n" if $v;
	}
	close $srv;
}

}
		
1;
