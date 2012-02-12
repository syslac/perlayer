#!/usr/bin/perl

package Player;
use SDL::Mixer::Music;

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
			$self->('playing', 0);
			$self->('paused', 0);
		},
	p => sub {my $self = shift;
			$self->('paused') ? SDL::Mixer::Music::resume_music() : SDL::Mixer::Music::pause_music();
			$self->('paused', 1 - $self->('paused'));
		},
	q => sub {my $self = shift;
			$self->('playing', 0);
			$self->('quit', 1);
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
