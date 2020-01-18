#
# Photo Archive System - Hash Functions for Synchronizing
# This source is copyright (c) 2019 by Eric Grivel. All Rights Reserved.
#

use Digest::SHA qw(sha256_hex sha256_base64);

my @hash_fields = (
  "resourceid",
  "type",
  "hash",
  "timestamp"
);
my $keysize = 42;

sub phash_init {
  psql_init();
}

sub phash_create_tables {
  # Person ID is 36 characters, so the resource ID, which has to allow for
  # the "p-" prefix, has to be at least 38 characters. Make it 42 to have some
  # wiggle room.
  # Note: file elements are at most 29 characters; the longest would look like:
  #   f-edited/20200101-120000a.jpg
  # Other resource IDs like user IDs have an at most 31 characters key plus
  # a two-letter prefix, so they should fit as well.
  my $query = "CREATE TABLE hash(";
  $query .= "   resourceid CHAR(42),";
  $query .= "   type TEXT,";
  $query .= "   hash TEXT,";
  $query .= "   timestamp TEXT,";
  $query .= "   PRIMARY KEY(resourceid))";
  psql_command($query);
}

sub phash_increase_keysize {
  # Increase the keysize from the old 31 to the new 42
  my $query = "ALTER TABLE hash MODIFY resourceid CHAR(42)";
  psql_command($query);
}

sub phash_drop_tables {
  psql_drop_table("hash");
}

sub phash_dump_table {
  psql_dump_table("hash", 1, \@hash_fields, undef);
}

sub phash_get_resource {
  my $resourceid = $_[0];

  my %resource = ();

  my $query = "SELECT * FROM hash WHERE resourceid='";
  $query .= psql_encode($resourceid) . "'";
  psql_command($query);
  my $record = psql_next_record(psql_iterator());
  if (defined($record)) {
    for ($i = 0; defined($hash_fields[$i]); $i++) {
      my $field = $hash_fields[$i];
      $resource{$field} = psql_get_field($i, $field, $record);
    }
  }

  return %resource;
}

sub phash_get_value {
  my $name = $_[0];
  my %hash = phash_get_resource($name);
  if (defined($hash{"hash"})) {
    return $hash{"hash"};
  }
  return "";
}

sub phash_set_resource {
  my $resourceid = $_[0];
  my $resourceref = $_[1];

  my $type = $$resourceref{"type"};
  my $hash = $$resourceref{"hash"};
  my $timestamp = $$resourceref{"timestamp"};
  if (!defined($timestamp)) {
    $timestamp = "";
  }

  my $query = "";
  my %hash = phash_get_resource($resourceid);
  if (defined($hash) && defined($hash{"resourceid"})) {
    $query = "UPDATE hash SET type='";
    $query .= psql_encode($type) . "', hash='";
    $query .= psql_encode($hash) . "', timestamp='";
    $query .= psql_encode($timestamp) . "' WHERE resourceid='";
    $query .= psql_encode($resourceid) . "'";
  } else {
    $query = "INSERT INTO hash SET resourceid='";
    $query .= psql_encode($resourceid) . "', type='";
    $query .= psql_encode($type) . "', hash='";
    $query .= psql_encode($hash) . "', timestamp='";
    $query .= psql_encode($timestamp) . "'";
  }
  psql_command($query)
}

sub phash_set_value {
  my $resourceid = $_[0];
  my $resourcetype = $_[1];
  my $texthash = $_[2];

  my %hash = ();
  $hash{"hash"} = $texthash;
  $hash{"type"} = $resourcetype;
  phash_set_resource($resourceid, \%hash);
}

sub phash_do_hash {
  my $text = $_[0];
  utf8::encode($text);
  $hash = sha256_hex($text);
  return $hash;
}

return 1;
