#!/usr/bin/env perl

use strict;
use warnings;
use autodie;

package Config;
use List::Util qw(sum);

{
	my $db_cfg = ".tables";
	my $cfg = ".config";
	my %weights = ();

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
	open(my $srv, ">>", ".server.txt") or die "Cannot write server file";
	while(my($k,$v) = each($cmd)) {
		print $srv $k."\n" if $v;
	}
	close $srv;
}

sub startup_mode {
	my $cmd = (parse_file($cfg))->{"config"};
	while (my($k,$v) = each($cmd)){
		next unless ($k and $k eq 'mode');
		return ['-p','a'] if ($v =~ /^a/);
		return ['-p'] if ($v =~ /^t/);
		return ['-m',''] if ($v =~ /^m/);
	}
	return [];
}

sub verbose {
	my $cmd = (parse_file($cfg))->{"config"};
	while (my($k,$v) = each($cmd)){
	return $v if ($k and $k eq 'verbose');
	}
	return 0;
}

sub read_weights {
	my $w = (parse_file($cfg))->{"score"};
	%weights = %$w;
	$weights{"played"} //= 10;
	$weights{"last_played"} //= 50;
	$weights{"user_score"} //= 30;
	$weights{"time_score"} //= 20;
}

sub get_weight {
	my $field = shift;
	return int($weights{$field}*100/sum(values(%weights)));
}

}
		
1;
