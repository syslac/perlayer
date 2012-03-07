#!/usr/bin/perl

package Player::ORM;
use base Class::DBI::Sweet;

Player::ORM->connection('dbi:SQLite:dbname=player_stats');

1;

package Player::Song;
use base Player::ORM;

Player::Song->table('collection');
Player::Song->columns(All => qw/id path title album artist tracknumber genre length played last_played user_score time_score liked_after disliked_after replaygain_track_gain timestamp/ );
Player::Song->has_a(album => Player::Album);
Player::Song->has_a(artist => Player::Artist);

1;

package Player::Folder;
use base Player::ORM;
Player::Folder->table('folder');
Player::Folder->columns(All => qw/id path timestamp/ );


1;

package Player::Album;
use base Player::ORM;
Player::Album->table('album');
Player::Album->columns(All => qw/id title artist/ );
Player::Album->has_many(songs => Player::Song, { order_by => 'tracknumber' });
Player::Album->has_a(artist => Player::Artist);
Player::Album->has_many(tags => Player::Album_Tags);

1;

package Player::Artist;
use base Player::ORM;
Player::Artist->table('artist');
Player::Artist->columns(All => qw/id name/ );
Player::Artist->has_many(songs => Player::Song);
Player::Artist->has_many(albums => Player::Album);

1;

package Player::Tag;
use base Player::ORM;
Player::Tag->table('tag');
Player::Tag->columns(All => qw/id name/ );
Player::Tag->has_many(albums => Player::Album_Tags);

1;

package Player::Album_Tags;
use base Player::ORM;
Player::Album_Tags->table('album_tags');
Player::Album_Tags->columns(All => qw/id tag album/ );
Player::Album_Tags->has_a(album => Player::Album);
Player::Album_Tags->has_a(tag => Player::Tag);

1;

package Player::Song::User;

use Ogg::Vorbis::Header;
use Audio::FLAC::Header;
use MP3::Info;

our @ISA = (qw/Player::Song/);

sub create {
	my ($self, $fields) = @_;
	$fields = get_info($fields);
	$self->SUPER::create($fields);	
}

sub get_info {
	my ($fields) = @_;
	return unless $fields->{'path'};
	my ($file, $ext) = $fields->{'path'} =~ /(.*)?\.(.*)/;
	my @comments = ("artist", "title", "album", "genre", "tracknumber", "replaygain_track_gain");
	if (lc($ext) eq "ogg"){
	my $ogg_info = Ogg::Vorbis::Header->new($fields->{'path'}) or die "Problems with ". $fields->{'path'} . "\n";
	foreach my $tag ($ogg_info->comment_tags() ){
		if (grep {$_ =~ /$tag/i} @comments){
			$fields->{lc($tag)} .= ucfirst(lc($_)) foreach ($ogg_info->comment($tag));
		}
	}
	$fields->{"length"} = int($ogg_info->info('length'));
	}
	if (lc($ext) eq "flac"){
	my $flac_info = Audio::FLAC::Header->new($fields->{'path'}) or die "Problems with ". $fields->{'path'} . "\n";
	foreach my $tag (keys $flac_info->tags() ){
		if (grep {$_ =~ /$tag/i} @comments){
			$fields->{lc($tag)} .= ucfirst(lc($flac_info->tags($tag)));
		}
	}
	$fields->{"length"} = int($flac_info->{"trackTotalLengthSeconds"});
	}
	if (lc($ext) eq "mp3"){
	my $mp3_info = MP3::Info->new($fields->{'path'});
	foreach my $tag (keys %{get_mp3tag($fields->{"path"})}){
		if (grep {$_ =~ /$tag/i} @comments){
			$fields->{lc($tag)} .= ucfirst(lc(get_mp3tag($fields->{"path"})->{$tag}));
		}
	}
	$fields->{"length"} = int(get_mp3info($fields->{"path"})->{'SECS'});
	$fields->{"tracknumber"} = $fields->{"tracknum"};
	delete $fields->{"tracknum"};
	}
	my $artist = Player::Artist->retrieve( name => $fields->{"artist"});
	$artist = Player::Artist->create({name => $fields->{"artist"}}) unless $artist;
	$fields->{"artist"} = $artist;	
	my $album = Player::Album->retrieve( title => $fields->{"album"});
	$album = Player::Album->create( {title => $fields->{"album"}, artist => $artist} ) unless $album;
	$fields->{"album"} = $album;	
	warn "Adding ". $fields->{"title"} . " by ". $fields->{"artist"} .";length : ". $fields->{"length"} . "\n";
	$fields->{"timestamp"} = time();

	return $fields;
}

sub update_db {
	my $it = Player::Song::User->retrieve_all;
	while ($res = $it->next) {
		next if ($res->timestamp >= (stat($res->path))[9]);
		print "Updating info for".$res->path."\n";
		$fields = get_info({ path => $res->path });
		$res->set(%{$fields});
		$res->update;
	}
	print "Done\n";
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

1;

package Player::Folder::User;

our @ISA = (qw/Player::Folder/);

sub create {
	my ($self,$path) = @_;
	return unless (-d $path);
	my @dirs = ($path);
	my @candidates = ();
	while (@dirs){
		my $dir_path = shift @dirs;
		warn "Adding directory ". $dir_path ."\n";
		my $folder = $self->SUPER::find_or_create({ path => $dir_path });
		$folder->set( timestamp => time() );
		$folder->update;
		opendir (DIR, $dir_path);
		foreach my $file (readdir DIR){
			$file = $dir_path ."/".$file;
			next if ($file =~ /\.{1,2}$/); 
			push @dirs, $file if (-d $file);
			push @candidates, $file if ($file =~ /(.*)?\.(mp3|ogg|flac)$/i);
		}	
		close DIR;
	}
	foreach (@candidates){
		my $song = Player::Song::User->search({path => $_});
		print "Skipping $_ : already in collection\n" if $song;
		Player::Song::User->create({path => $_}) unless $song;
	}
}

sub refresh {
	my $it = Player::Folder::User->retrieve_all;
	while ($res = $it->next) {
		next if ($res->timestamp >= (stat($res->path))[9]);
		print "Updating info for folder ".$res->path."\n";
		Player::Folder::User->create($res->path);
		$res->set( timestamp => time() );
		$res->update;
	}
	print "Done\n";
}

1;
