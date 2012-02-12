#!/usr/bin/perl

package Player::ORM;
use base Class::DBI::Sweet;

Player::ORM->connection('dbi:SQLite:dbname=player_stats');

1;

package Player::Song;
use base Player::ORM;

Player::Song->table('collection');
Player::Song->columns(All => qw/id path artist title album genre length played last_played user_score time_score liked_after disliked_after replaygain_track_gain/ );

1;

package Player::Song::User;

use Ogg::Vorbis::Header;
use MP3::Info;

our @ISA = (qw/Player::Song/);

sub create {
	my ($self, $fields) = @_;
	return unless $fields->{'path'};
	my ($file, $ext) = $fields->{'path'} =~ /(.*)?\.(.*)/;
	my @comments = ("artist", "title", "album", "genre", "replaygain_track_gain");
	if (lc($ext) eq "ogg"){
	my $ogg_info = Ogg::Vorbis::Header->new($fields->{'path'}) or die "Problems with ". $fields->{'path'} . "\n";
	foreach my $tag ($ogg_info->comment_tags() ){
		if (grep {$_ =~ /$tag/i} @comments){
			$fields->{lc($tag)} .= ucfirst(lc($_)) foreach ($ogg_info->comment($tag));
		}
	}
	$fields->{"length"} = int($ogg_info->info('length'));
	warn "Adding ". $fields->{"title"} . " by ". $fields->{"artist"} .";length : ". $fields->{"length"} . "\n";
	$self->SUPER::create($fields);	
	}
	if (lc($ext) eq "mp3"){
	my $mp3_info = MP3::Info->new($fields->{'path'});
	foreach my $tag (keys %{get_mp3tag($fields->{"path"})}){
		if (grep {$_ =~ /$tag/i} @comments){
			$fields->{lc($tag)} .= ucfirst(lc(get_mp3tag($fields->{"path"})->{$tag}));
		}
	}
	$fields->{"length"} = int(get_mp3info($fields->{"path"})->{'SECS'});
	warn "Adding ". $fields->{"title"} . " by ". $fields->{"artist"} .";length : ". $fields->{"length"} . "\n";
	$self->SUPER::create($fields);	
	}
}

sub score {
	my ($self, $table) = @_;
	my $score = 0;
	foreach (keys %{$table}){
		my $incr = $table->{$_}->($self->$_);
		$score += $incr;
	}
	return $score;
}

