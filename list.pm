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
	my $node = shift;
	return $node->[0];
}

sub tail {
	my $node = shift;
	return unless ref($node->[1]);
	return $node->[1]->();
}	

sub l_grep(&$) {
	my ($funct, $list) = @_;
	return unless ref $funct;
	while ($list && (!$funct->(data($list)))){
		warn "Skipping : not interesting \n";
		$list = tail($list);
	}
	return node(data($list), sub {l_grep($funct, tail($list))} );
}

1;
