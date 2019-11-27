#
# Photo Archive System - Session Functions
# This source is copyright (c) 2006 by Eric Grivel. All Rights Reserved.
#

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
    $cur_session = "s$now";
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
