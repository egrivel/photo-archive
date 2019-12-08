#
# Photo Archive System - SQL Access Module
# This source is copyright (c) 2006 by Eric Grivel. All Rights Reserved.
#

use DBI;

use photos_common;

my $mysql;
my $was_init = 0;
my $use_dbi  = 0;

sub psql_init {
  $dbname   = setting_get("dbname");
  $dbuser   = setting_get("dbuser");
  $dbpasswd = setting_get("dbpasswd");
  if (!$was_init) {
    # Database is UTF8. Set the database connection to UTF8.
    $mysql = DBI->connect("DBI:mysql:$dbname;localhost", $dbuser, $dbpasswd,
      { mysql_enable_utf8 => 1 });

    # Also, set the output mode to UTF8 to match
    binmode STDOUT, ":utf8";

    $use_dbi = 1;
    if (defined($mysql)) {
      $was_init++;
    }
  }
  pcom_assert($was_init, "psql_init() didn't initialize");
  return $was_init;
}

# execute an SQL command, return true on success, false on failure
sub psql_command {
  my $query = $_[0];

  # print "query: '$query'<br/>";
  $is_error = 0;
  pcom_assert($was_init, "psql_command but not initialized");
  if ($use_dbi) {
    if (($query =~ /^\s*select/i) || ($query =~ /^\s*show/i)) {
      pcom_log($PCOM_DEBUG, "Prepare query '$query'");
      $resulthandle = $mysql->prepare($query);
      $resulthandle->execute();
      if ($resulthandle->err) {
        pcom_log($PCOM_DEBUG, "Query returned " . $resulthandle->errstr);
      }
    } else {
      pcom_log($PCOM_DEBUG, "Execute query '$query'");

      # Use a local result variable so as not to clobber the global
      # $resulthandle variable used to iterate through the result
      # of a SELECT statement
      my $rv = $mysql->do($query);
      if (!defined($rv)) {
        pcom_log($PCOM_DEBUG, "Query returned " . $mysql->errstr);
      }
    }

  } else {
    pcom_log($PCOM_DEBUG, "Execute query '$query'");
    $mysql->query($query);
    $is_error = $mysql->is_error();
    pcom_log($PCOM_DEBUG, "Query returned " . $mysql->is_error());
  }
  return !$is_error;
}

sub psql_iterator {
  if ($use_dbi) {
    return $resulthandle;
  } else {
    return $mysql->create_record_iterator();
  }
}

$gl_counter = 0;

sub psql_next_record {
  my $iterator = $_[0];
  if (defined($iterator)) {
    if ($use_dbi) {
      if ($ref = $iterator->fetchrow_hashref()) {
        return $ref;
      } else {
        return undef;
      }
    } else {
      # NOTE: THIS GIVES AN ERROR!!!
      return $iterator->each;
    }
  }
  return undef;
}

sub psql_encode {
  my $value = $_[0];

  if (defined($value)) {
    $value =~ s/\&/&amp;/sg;
    $value =~ s/\"/&quot;/sg;
    $value =~ s/\'/&apos;/sg;
  }

  return $value;
}

sub psql_decode {
  my $value = $_[0];

  if (defined($value)) {
    $value =~ s/&apos;/\'/sg;
    $value =~ s/&quot;/\"/sg;
    $value =~ s/&amp;/\&/sg;
  }

  return $value;
}

sub psql_create_table {
  my $table  = $_[0];
  my @fields = @{ $_[1] };
  my $keysize = $_[2];
  if (!defined($keysize)) {
    $keysize = 31;
  }

  psql_init();

  my $i;
  my $query = "CREATE TABLE $table (";
  for ($i = 0 ; defined($fields[$i]) ; $i++) {
    $query .= "   $fields[$i] ";
    if ($i) {
      $query .= "TEXT,";
    } else {
      $query .= "CHAR($keysize),";
    }
  }
  $query .= "   PRIMARY KEY($fields[0])";
  $query .= ");";
  # ignore error if table already exists
  psql_command($query);
}

sub psql_get_field {
  my $field_nr   = $_[0];
  my $field_name = $_[1];
  my $record     = $_[2];

  my $value;

  if ($use_dbi) {
    if (defined($record) && defined($record->{$field_name})) {
      $value = psql_decode($record->{$field_name});
    }
  } else {
    if (defined($record) && defined($record->[$field_nr])) {
      $value = psql_decode($record->[$field_nr]);
    }
  }
  return $value;
}

#
# Dump an SQL table.
# The dump_data parameter can be:
#  -1: dump the data only, not the creation of the table
#  0: print the creation of the table only, don't dump the data
#  1: print the creation of the table and dump the data
#
sub psql_dump_table {
  my $table     = $_[0];
  my $dump_data = $_[1];
  my @fields    = @{ $_[2] };
  my $setid     = $_[3];
  my $keysize = $_[4];
  if (!defined($keysize)) {
    $keysize = 31;
  }

  psql_init();

  my $i;
  if ($dump_data >= 0) {
    my $query;
    if ($table eq "personref") {
      # Personref table is special, with a special key structure
      $query = "CREATE TABLE personref (";
      $query .= "   imageid CHAR(31),";
      $query .= "   personid CHAR(36),";
      $query .= "   PRIMARY KEY(imageid, personid),";
      $query .= "   KEY(personid, imageid))";
    } else {
      $query = "CREATE TABLE $table (";
      for ($i = 0 ; defined($fields[$i]) ; $i++) {
        $query .= "   $fields[$i] ";
        if ($fields[$i] eq "personid") {
          $query .= "CHAR(36),";
        } elsif ($i) {
          $query .= "TEXT,";
        } else {
          $query .= "CHAR($keysize),";
        }
      }
      $query .= "   PRIMARY KEY($fields[0])";
      $query .= ");";
    }

    # ignore error if table already exists
    print $query, "\n";
  }

  if ($dump_data) {
    $query = "SELECT * FROM $table";
    if (defined($setid) && ($setid =~ /^\d\d\d\d\d\d\d\d$/)) {
      $query .= " WHERE setid='$setid'";
    }
    $query .= ";";
    psql_command($query);
    my $iterator = psql_iterator();
    my $record   = psql_next_record($iterator);
    while (defined($record)) {
      print "INSERT INTO $table VALUES (";
      for (my $i = 0 ; defined($fields[$i]) ; $i++) {
        my $field = $fields[$i];
        my $value = psql_get_field($i, $field, $record);
        print ", " if ($i);
        if (defined($value)) {
          print "'" . psql_encode($value) . "'";
        } else {
          print "''";
        }
      }

      print ");\n";
      $record = psql_next_record($iterator);
    }
  }
}

sub psql_dump_records {
  my $table     = $_[0];
  my $condition = $_[1];
  my @fields    = @{ $_[2] };

  psql_init();

  my $i;
  my $query = "";

  $query = "SELECT * FROM $table WHERE $condition;";
  psql_command($query);
  my $iterator = psql_iterator();
  my $record   = psql_next_record($iterator);
  while (defined($record)) {
    print "INSERT INTO $table VALUES (";
    for (my $i = 0 ; defined($fields[$i]) ; $i++) {
      my $field = $fields[$i];
      my $value = psql_encode(psql_get_field($i, $field, $record));
      print ", " if ($i);
      print "'$value'";
    }

    print ");\n";
    $record = psql_next_record($iterator);
  }
}

sub psql_drop_table {
  my $table = $_[0];

  my $query = "DROP TABLE $table;";
  psql_command($query);
}

sub psql_table_exists {
  my $table = $_[0];

  my $query = "SHOW TABLES LIKE '";
  $query .= psql_encode($table) . "'";
  psql_command($query);
  my $record = psql_next_record(psql_iterator());
  return defined($record);
}

sub psql_upsert {
  my $table = $_[0];
  my $data = $_[1];

  my $update_data = $data;
  my $insert_names = "";
  my $insert_values = "";

  while ($data ne "") {
    if ($data =~ s/^([^=]+)=(\'[^\']*\')(, )?//) {
      $insert_names .= $1.$3;
      $insert_values .= $2.$3;
    } else {
      $data = "";
    }
  }

  my $sql = "INSERT INTO $table ($insert_names) ";
  $sql .= "VALUES ($insert_values) ";
  $sql .= "ON DUPLICATE KEY UPDATE $update_data";
  psql_command($sql);
}

return 1;
