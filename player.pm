#!/usr/bin/perl

package Player;
use POSIX ':sys_wait_h';	#for WNOHANG in waitpid
use Data::Dumper;

my (@mplayer_args, $command_fh, $child, $path, $vol);

sub play {
	my $self = shift;
	my $args = shift;
	$path = $args->[0];
	$vol = $args->[1];
#	my $file = $args->[0];
	@mplayer_args = (qw/mplayer -nocache -slave -nolirc -really-quiet/);
	push @mplayer_args, qw/-softvol -volume/, $vol;
	push @mplayer_args, '--', $path;
	pipe my($rfh), $command_fh;
	$child = fork;
	warn "fork failed $!\n" unless defined $child;
	if($child == 0){
		close $command_fh; 
		open my($err), '>&', \*STDERR;
		open \*STDIN, '<&='.fileno $rfh;
		exec @mplayer_args or print $err "mplayer failed $!\n";

		POSIX::_exit(1);
	}
	close $rfh;
	$command_fh->autoflush(1);
	print "playing $path (process $child)\n";	
}

sub finished {
	return (waitpid($child, WNOHANG) == -1);
}

sub pause {
	print $command_fh "pause\n";
}

sub resume {
	print $command_fh "pause\n";
}

sub volume {
	my ($self,$sign) = @_;
	$vol = ($sign) ? $vol+5 : $vol-5;
	$vol = 0 if $vol < 0;
	$vol = 100 if $vol > 100;
	print $command_fh "volume $vol 1\n";
	print "Set volume to $vol\n";
}


sub stop {
	if (defined($child)){
		kill INT=>$child;
		undef $child;
	}
}

sub skip {
	if (defined($child)){
		print $command_fh "quit\n";
		undef $child;
	}
}

{
my $quit = 0;
my $playing = 0;
my $paused = 0;
my $time = 0;
my $current = undef;
my $last = 0;
my %fields = (
	quit => \$quit,
	playing => \$playing,
	paused => \$paused,
	'time' => \$time,
	current => \$current,
	'last' => \$last,
	);

my %keys = (
	n => sub {my $self = shift;
			$self->skip();
			$self->('playing', 0);
			$self->('paused', 0);
		},
	e => sub {my $self = shift;
			$self->stop();
			$self->('playing', 0);
			$self->('paused', 0);
		},
	p => sub {my $self = shift;
			$self->('paused') ? $self->resume() : $self->pause();
			$self->('paused', 1 - $self->('paused'));
		},
	q => sub {my $self = shift;
			$self->stop();
			$self->('playing', 0);
			$self->('quit', 1);
		},
	',' => sub {my $self = shift;
			$self->volume(0);
		},
	'.' => sub {my $self = shift;
			$self->volume(1);
		},
	'+' => sub {my $self = shift;
			if ($self->('current')->user_score >= 1){
				print "Already at max score\n";
				return;
			}
			$self->('current')->set(user_score => ($self->('current')->user_score+0.1));
			$self->('current')->update;
			print "Liked song; now rated : ". $self->('current')->user_score ."\n";
		},
	'-' => sub {my $self = shift;
			if ($self->('current')->user_score <= 0){
				print "Already at min score\n";
				return;
			}
			$self->('current')->set(user_score => ($self->('current')->user_score-0.1));
			$self->('current')->update;
			print "Disliked song; now rated : ". $self->('current')->user_score ."\n";
		},
	);

sub new {
	my $class = shift;
	my $player = sub {
		return unless @_;
		return unless exists($fields{$_[0]});
		return ${$fields{$_[0]}} if (@_ == 1);
		return ${$fields{$_[0]}} = $_[1] if (@_ == 2);
	};
	bless ($player, $class);
	return $player;
}

sub control {
	my $self = shift;
	return sub{} unless (my $key = shift);	
	return sub{} unless (exists $keys{$key});
	return $keys{$key}->($self);	
}
}
