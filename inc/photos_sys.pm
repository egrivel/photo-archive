#
# Photo Archive System - System Table Functions
# This source is copyright (c) 2019 by Eric Grivel. All Rights Reserved.
#

# use photos_common;
# use photos_sql;

# Note: 'key' and 'value' may be reserved words in SQL, so avoid those.
my @sys_fields = (
  "syskey",
  "sysvalue"
);

# System version. Has to be updated manually for now, have to remember to
# update this every time a new version is pushed
my $VERSION = "2.0.2";

sub psys_init {
  psql_init();
}

sub psys_create_tables {
  my $version = $_[0];
  psql_create_table("system", \@sys_fields);
  psys_set_value("version", $version);
}

sub psys_drop_tables {
  psql_drop_table("system");
}

sub psys_dump_table {
  psql_dump_table("system", 1, \@sys_fields);
}

sub psys_get_value {
  my $key = $_[0];
  my $value = "";

  my $query = "SELECT sysvalue FROM system WHERE syskey='";
  $query .= psql_encode($key) . "'";
  if (psql_command($query)) {
    my $record = psql_next_record(psql_iterator());
    $value = psql_get_field(0, "sysvalue", $record);
  }
  return $value;
}

sub psys_set_value {
  my $key = $_[0];
  my $value = $_[1];

  my $query = "SELECT sysvalue FROM system WHERE syskey='";
  $query .= psql_encode($key) . "'";
  psql_command($query);
  my $record = psql_next_record(psql_iterator());
  if (defined($record)) {
    $query = "UPDATE system SET sysvalue='";
    $query .= psql_encode($value);
    $query .= "' WHERE syskey='";
    $query .= psql_encode($key) . "'";
  } else {
    $query = "INSERT INTO system SET syskey='";
    $query .= psql_encode($key);
    $query .= "', sysvalue='";
    $query .= psql_encode($value);
    $query .= "'";
  }
  psql_command($query);
}

sub psys_version {
  return $VERSION;
}

sub psys_db_version {
  if (!psql_table_exists("users")) {
    # No tables have been created yet
    return "0.0";
  }
  if (psql_table_exists("system")) {
    return psys_get_value("version");
  }

  return "0.9";
}

sub psys_get_data {
  my $key = $_[0];
  my $value = psys_get_value($key);
  my $result = "";

  if ($key ne "" && $value ne "") {
    $result .= "syskey='" . psql_encode($key);;
    $result .= "', sysvalue='" . psql_encode($value);
    $result .= "'";
  }

  return $result;
}

return 1;
