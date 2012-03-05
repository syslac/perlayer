#!/usr/bin/perl

package Server;

sub new {
	my $class = shift;
	open(my $clean, ">", ".server.txt") or die "Cannot open file";
	print $clean "";
	close $clean;
	open (my $fh , "<", ".server.txt") or die "Cannot open file";
	my $last_mod = 0;
	my $continue = 0;
	my $server = sub {
		if (@_){
			close $fh;
			return;
		}
		return if (
				((my $new = (stat($fh))[9]) <= $last_mod) &&
	   			(!$continue)	);
		$last_mod = $new;
		my $line = <$fh>;
		$continue = 1 if($line);
		chomp($line);
		return $line;
	};
	bless $server, $class;
	return $server;
}

sub clean {
	unlink ".server.txt" or warn "Cannot delete temp server file: possible permission problem?\n";
}

1;
