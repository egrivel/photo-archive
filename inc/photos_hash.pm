#
# Photo Archive System - Hash Functions for Synchronizing
# This source is copyright (c) 2019 by Eric Grivel. All Rights Reserved.
#

my @hash_fields = (
  "resourceid",
  "type",
  "hash",
  "timestamp"
);
my $keysize = 64;

sub phash_init {
  psql_init();
}

sub phash_create_tables {
  psql_create_table("hash", \@hash_fields);
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

return 1;
