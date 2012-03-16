#!/usr/bin/perl

package List::Lazy;

###
# Lazy list utilities
###

sub node {
	my ($data, $promise) = @_;
	return [$data, $promise];
}

sub data {
	my $node = shift or die "No data in playlist";
	return $node->[0];
}

sub tail {
	my $node = shift;
	my @args = @_;
	return unless ref($node->[1]);
	return $node->[1]->(@_);
}	

sub l_grep {
	my $funct = shift;
	my $list = shift;
	my @args = @_;
	return unless ref $funct;
	while ($list && (!$funct->(data($list)))){
		warn "Skipping : not interesting \n";
		$list = tail($list, @args);
	}
	return node(data($list), sub {l_grep($funct, tail($list, @args), @args)} );
}

1;
