#
# Photo Archive System - Session Functions
# This source is copyright (c) 2006 by Eric Grivel. All Rights Reserved.
#

use Crypt::URandom qw(urandom);
use MIME::Base64 qw(encode_base64);

use photos_common;
use photos_sql;

my @session_fields = ("sessionid",
                      "timestamp",
                      "type",
                      "data",
                      );

my $cur_session = "";
my %session_data = ();
my %name_value_pairs = ();

sub pses_init {
    psql_init();
}

sub pses_create_tables {
    psql_create_table("session", \@session_fields);
}

sub pses_drop_tables {
    psql_drop_table("session");
}

sub pses_new {
  my $now = time();
  %session_data = ();
  %name_value_pairs = ();
  while ($now) {
    # urandom() returns the requested number or random bytes. 16 bytes is 128
    # random bit, which is not a lot, but it will do until we can update the
    # size of the database field
    my $random_value = urandom(16);
    # This encodes the random value in a base64 string. A 16 byte random value
    # results in a 25-character string, which fits in the current session
    # database field of 31 characters. The empty string as the last character
    # avoids adding a line break.
    $cur_session = encode_base64($random_value, "");
    $session_data{"sessionid"} = $cur_session;
    $session_data{"timestamp"} = $now;
    my $query = "INSERT INTO session SET ";
    my $i;
    for ($i = 0; defined($session_fields[$i]); $i++) {
      if (defined($session_data{$session_fields[$i]})) {
        $query .= "," if ($i);
        my $value = psql_encode($session_data{$session_fields[$i]});
        $query .= " $session_fields[$i]='$value' ";
      }
    }
    if (psql_command($query)) {
      last;
    }
    $now++;
  }
  return $cur_session;
}

# Encode ':' characters that may be in the session value
sub pses_encode_value {
    my $value = $_[0];

    $value =~ s/:/%3A/g;

    return $value;
}

sub pses_decode_value {
    my $value = $_[0];

    $value =~ s/%3A/:/g;

    return $value;
}

sub pses_restore {
  my $sessionid = $_[0];

  $cur_session = "";
  %session_data = ();
  %name_value_pairs = ();
  my $query = "SELECT * FROM session WHERE sessionid='$sessionid';";
  my $i;
  if (psql_command($query)) {
    my $record = psql_next_record(psql_iterator());
    for ($i = 0; defined($session_fields[$i]); $i++) {
      my $field = $session_fields[$i];
      my $value = psql_get_field($i, $field, $record);
      $session_data{$field} = $value;
      if (!defined($value)) {
        $value = "(undefined)";
      }
      pcom_log(1, "Retrieve field '" . $field . "' as '" . $value . "'");
    }
    pcom_log(1, "Set cur_session to $sessionid");
    $cur_session = $sessionid;

    # Do some maintenance on the session table
    if (defined($session_data{"timestamp"})) {
      my $timestamp = $session_data{"timestamp"};
      if ($timestamp < (time() - 60 * 60)) {
        # Timestamp is more than an hour old, refresh its timestamp
        # This way we can use the timestamp to clean up old sessions
        $query = ""
          . "UPDATE session "
          . "SET timestamp=" . time() . " "
          . "WHERE sessionid='$sessionid'";
        psql_command($query);

        # At this point, let's also delete old sessions (more than a year
        # old for now). This will regularly do cleanup of the session table,
        # but not on every call, since the current session's timestamp is
        # only refreshed once an hour. Ideally, this would be done as an
        # hourly or daily batch job, but that would require having and
        # maintaining a batch job. This way, cleanup is automatic...
        #
        # This means that a user gets logged out after a year of not accessing
        # the archive. Eventually, we probably want a better time frame, maybe
        # a month, or three months; some balance between cleaning up (smaller
        # time frame) and usability (longer time frame).
        #
        # Note: this functionality is still commented out; let's first run a
        # while with the timestamp refresh above, so that regular users will
        # have an updated timestamp.
        #
        # $query = ""
        #   . "DELETE FROM session "
        #   . "WHERE CAST(timestamp as signed) < " . (time() - 365 * 24 * 60 * 60);
        # psql_command($query);
      }
    }
  } else {
    # Could not restore the session; explicitly create one
  }

  if (defined($session_data{"data"})) {
    my @data = split(/:/, $session_data{"data"});
    for ($i = 0; defined($data[$i]); $i++) {
      if ($data[$i] =~ /^(.+?)=(.*)$/) {
        $name_value_pairs{$1} = pses_decode_value($2);
      }
    }
  }
}

sub pses_set {
    my $name = $_[0];
    my $value = $_[1];

    $session_data{"timestamp"} = time();
    pcom_log(3, "pses_set($name, $value)");

    my $do_save = 0;
    if (($value eq "") && defined($name_value_pairs{$name}) && ($name_value_pairs{$name} ne "")) {
        $name_value_pairs{$name} = "";
        $do_save = 1;
    } elsif (!defined($name_value_pairs{$name}) || ($name_value_pairs{$name} ne $value)) {
        $name_value_pairs{$name} = $value;
        $do_save = 1;
    }

    if ($do_save) {
        my $data = "";
        my $key;
        foreach $key (keys %name_value_pairs) {
            if ($name_value_pairs{$key} ne "") {
                $data .= ":" if ($data ne "");
                $data .= "$key=" . pses_encode_value($name_value_pairs{$key});
            }
        }
        $session_data{"data"} = $data;
        my $query = "UPDATE session SET ";
        my $i;
	my $fieldcount = 0;
        for ($i = 0; defined($session_fields[$i]); $i++) {
            if (defined($session_data{$session_fields[$i]})) {
                $query .= "," if ($fieldcount);
                my $value = psql_encode($session_data{$session_fields[$i]});
                $query .= " $session_fields[$i]='$value' ";
		$fieldcount++;
            }
        }
        $query .= " WHERE sessionid = '$cur_session'";
        psql_command($query);
    }
}

sub pses_get_id {
    return $cur_session;
}

sub pses_get {
    my $name = $_[0];
    my $value = "";

    if (defined($name_value_pairs{$name})) {
        $value = $name_value_pairs{$name};
    }

    return $value;
}

sub pses_type {
    my $type = $_[0];

    if ($cur_session ne "") {
        my $now = time();
        my $query = "UPDATE session SET type='" . psql_encode($type) . "', ";
        $query .= "timestamp = '$now' ";
        $query .= "WHERE sessionid = '$cur_session'";
        psql_command($query);
    }
}

sub pses_dump_table {
    psql_dump_table("session", 0, \@session_fields);

    return "OK";
}

return 1;
