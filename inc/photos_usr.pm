#
# Photo Archive System - User Maintenance Functions
# This source is copyright (c) 2006 by Eric Grivel. All Rights Reserved.
#

use photos_common;
use photos_sql;

$PUSR_SEE = "S";
$PUSR_EDIT = "E";

$PUSR_SEE_REGULAR       = $PUSR_SEE . $PCOM_REGULAR;        # "Sr"
$PUSR_SEE_PRIVATE       = $PUSR_SEE . $PCOM_PRIVATE;        # "Sp"
$PUSR_SEE_EXPERIMENTAL  = $PUSR_SEE . $PCOM_EXPERIMENTAL;   # "Se"
$PUSR_SEE_NICOLINE      = $PUSR_SEE . $PCOM_NICOLINE;       # "Sn"
$PUSR_SEE_KIDS          = $PUSR_SEE . $PCOM_KIDS;           # "Sk"
$PUSR_SEE_OTHERS        = $PUSR_SEE . $PCOM_OTHERS;         # "So"
$PUSR_SEE_THEO          = $PUSR_SEE . $PCOM_THEO;           # "St"
$PUSR_SEE_PARENTS       = $PUSR_SEE . $PCOM_PARENTS;        # "Sd"
$PUSR_SEE_NEW           = $PUSR_SEE . $PCOM_NEW;            # "Sw"

$PUSR_EDIT_REGULAR      = $PUSR_EDIT . $PCOM_REGULAR;       # "Er"
$PUSR_EDIT_PRIVATE      = $PUSR_EDIT . $PCOM_PRIVATE;       # "Ep"
$PUSR_EDIT_EXPERIMENTAL = $PUSR_EDIT . $PCOM_EXPERIMENTAL;  # "Ee"
$PUSR_EDIT_NICOLINE     = $PUSR_EDIT . $PCOM_NICOLINE;      # "En"
$PUSR_EDIT_KIDS         = $PUSR_EDIT . $PCOM_KIDS;          # "Ek"
$PUSR_EDIT_OTHERS       = $PUSR_EDIT . $PCOM_OTHERS;        # "Eo"
$PUSR_EDIT_THEO         = $PUSR_EDIT . $PCOM_THEO;          # "Et"
$PUSR_EDIT_PARENTS      = $PUSR_EDIT . $PCOM_PARENTS;       # "Ed"
$PUSR_EDIT_NEW          = $PUSR_EDIT . $PCOM_NEW;           # "Ew"

$PUSR_GET_ORIG          = "Go";
$PUSR_GET_RAW           = "Gr";

$PUSR_COMMENT           = "Co";
$PUSR_JOOMLA_LINK       = "Cj";
$PUSR_QUICKTAGS         = "Cq";

$PUSR_MAINTAIN_SELF     = "Ms";
$PUSR_MAINTAIN_USERS    = "Mu";
$PUSR_MAINTAIN_PERSONS  = "Mp";
$PUSR_MAINTAIN_ALL      = "Ma";   # administrator

$PUSR_GUEST_ACCOUNT     = "guest";

# Pre-defined settings values
$PUSR_VIEW_TYPES = "type_mask";
$PUSR_VIEW_QUALITY = "quality";
$PUSR_VIEW_MAX_QUALITY = "maxquality";
$PUSR_VIEW_TAGS = "tags";
$PUSR_IMAGE_SIZE = "imgsize";
$PUSR_EDIT_SIZE = "editsize";
$PUSR_DISPLAY_QUAL = "dispqual";   # display quality in browse

my @user_fields = ("userid",
                   "fullname",
                   "password",
                   "rights",
                   "settings",
                   );

my $cur_user = "";
my %user_data = ();

my $cur_edit_user = "";
my %cur_edit_data = ();

sub pusr_init {
    psql_init();
}

sub pusr_create_tables {
  my $user = $_[0];
  my $name = $_[1];
  my $password = $_[2];
  my $encrypted_password = crypt($password, "abcde");
  psql_create_table("users", \@user_fields);

  # Cause the first user to be created
  $cur_edit_user = $user;
  $cur_edit_data{"userid"} = $cur_edit_user;
  $cur_edit_data{"fullname"} = $name;
  $cur_edit_data{"password"} = $encrypted_password;
  $cur_edit_data{"rights"} = "SrSpSeSnStSdErEpEeEnEtEdMsMuMaSkSwEwGoGrCoEkMpSoEoCq";
  $cur_edit_data{"settings"} = "dispqual=1:type_mask=rpenkotdw:quality=0:maxquality=5:imgsize=large:editsize=large";
  pusr_edit_close();

  # Cause the guest user to be created
  $cur_edit_user = $PUSR_GUEST_ACCOUNT;
  $cur_edit_data{"userid"} = $cur_edit_user;
  $cur_edit_data{"fullname"} = "Guest Account";
  $cur_edit_data{"password"} = "";
  $cur_edit_data{"rights"} = "SrStSd";
  $cur_edit_data{"settings"} = "type_mask=rtd:quality=2:imgsize=default";
  pusr_edit_close();

  # Cause the "test" process user to be created
  $cur_edit_user = "tester";
  $cur_edit_data{"userid"} = $cur_edit_user;
  $cur_edit_data{"fullname"} = "Guest Account";
  $cur_edit_data{"password"} = "abFXMoa4CDRlc";
  $cur_edit_data{"rights"} = "SwEw";
  $cur_edit_data{"settings"} = "type_mask=rtd:quality=3:imgsize=default";
  pusr_edit_close();
}

sub pusr_drop_tables {
    psql_drop_table("users");
}

sub pusr_login {
    my $userid = $_[0];
    my $password = $_[1];
    my $success = 0;

    # if invalid user ID, log out
    if (!pcom_is_user_valid($userid)) {
        pusr_logout();
        return 0;
    }

    # if the current user, no need to re-login
    if ($userid eq $cur_user) {
        return 1;
    }

    $cur_user = "";
    %cur_data = ();

    if (($userid eq $PUSR_GUEST_ACCOUNT) || ($password ne "")) {
        my $query = "SELECT * FROM users WHERE userid='$userid';";
        if (psql_command($query)) {
            my $record = psql_next_record(psql_iterator());
            my $i;
            for ($i = 0; defined($user_fields[$i]); $i++) {
                my $field = $user_fields[$i];
                my $value = psql_get_field($i, $field, $record);
                $user_data{$field} = $value;
            }
            $cur_user = $userid;
            $success = 1;
        }
    }

    # If the data was successfully loaded, check the password. If the
    # password doesn't match, reset $success to indicate failure. Note:
    # no password check necessary for guests.
    if ($success && ($userid ne $PUSR_GUEST_ACCOUNT)) {
        if (!defined($user_data{"password"})
            || (crypt($password, "abcde") ne $user_data{"password"})) {
            $success = 0;
        }
    }

    if (!$success) {
        if ($userid eq $PUSR_GUEST_ACCOUNT) {
            # Failure loading guest data??? don't do anything to prevent
            # infinite recursion.
        } else {
            pusr_login($PUSR_GUEST_ACCOUNT);
        }
    }

    return $success;
}

sub pusr_load {
    my $userid = $_[0];
    my $success = 0;

    # if invalid user ID, log out
    if (!pcom_is_user_valid($userid)) {
        return 0;
    }

    # if the current user, no need to re-login
    if ($userid eq $cur_user) {
        return 1;
    }

    $cur_user = "";
    %cur_data = ();

    my $query = "SELECT * FROM users WHERE userid='$userid';";
    if (psql_command($query)) {
        my $record = psql_next_record(psql_iterator());
        my $i;
        for ($i = 0; defined($user_fields[$i]); $i++) {
            my $field = $user_fields[$i];
            my $value = psql_get_field($i, $field, $record);
            $user_data{$field} = $value;
        }
        $cur_user = $userid;
        $success = 1;
    }

    return $success;
}

sub pusr_reload {
    my $userid = $_[0];
    my $success = 0;

    # if invalid user ID, log out
    if (!pcom_is_user_valid($userid)) {
        pusr_logout();
        return 0;
    }

    # if the current user, no need to re-login
    if ($userid eq $cur_user) {
        return 1;
    }

    $cur_user = "";
    %cur_data = ();

    my $query = "SELECT * FROM users WHERE userid='$userid';";
    if (psql_command($query)) {
        my $record = psql_next_record(psql_iterator());
        my $i;
        for ($i = 0; defined($user_fields[$i]); $i++) {
            my $field = $user_fields[$i];
            my $value = psql_get_field($i, $field, $record);
            $user_data{$field} = $value;
        }
        $cur_user = $userid;
        $success = 1;
    }

    if (!$success) {
        if ($userid eq $PUSR_GUEST_ACCOUNT) {
            # Failure loading guest data??? don't do anything to prevent
            # infinite recursion.
        } else {
            pusr_login($PUSR_GUEST_ACCOUNT);
        }
    }

    return $success;
}

sub pusr_logout {
    pusr_login($PUSR_GUEST_ACCOUNT, "");
}

sub pusr_get_userid {
    return $cur_user;
}

sub pusr_get_fullname {
    return $user_data{"fullname"};
}

sub pusr_allowed {
    my $right = $_[0];
    my $allowed = 0;

    # Make sure the right requested is not bogus
    if ($right =~ /^\w+$/) {
        my $rights = $user_data{"rights"};
        if (defined($rights) && ($rights ne "")) {
            pcom_log($PCOM_DEBUG, "Got right '$rights'\n");
            if ($rights =~ /$right/) {
                $allowed = 1;
            }
        } else {
            pcom_log($PCOM_DEBUG, "No rights defined for '$cur_user'");
        }
    }

    return $allowed;
}

sub pusr_get_setting {
    my $setting_name = $_[0];
    my $value = "";

    my $settings = $user_data{"settings"};
    if (defined($settings) && ($settings ne "")) {
        #print "Settings is '$settings'; ";
        if ($settings =~ /^(.*?:)?$setting_name=([^:=]*)(:.*)?$/) {
            $value = $2;
        }
    }

    return $value;
}

sub pusr_can_see {
    my $type = $_[0];
    my $can_see = 0;

    my $setting = pusr_get_setting($PUSR_VIEW_TYPES);
    if ($setting ne "") {
        if ($setting =~ /$type/) {
            $can_see = 1;
        }
    }

    return $can_see;
}

sub pusr_edit_open {
    my $userid = $_[0];

    # Reject invalid user IDs
    if (!pcom_is_user_valid($userid)) {
        $cur_edit_user = "";
        %cur_edit_data = ();
        return 0;
    }

    # If we're already editing this user, don't have to do anything
    return 1 if ($userid eq $cur_edit_user);

    # Cleanup old data before continuing with the editing
    $cur_edit_user = "";
    %cur_edit_data = ();

    # Reject if the user is not allowed to maintain anyone
    return 0 if (!pusr_allowed($PUSR_MAINTAIN_SELF)
                 && !pusr_allowed($PUSR_MAINTAIN_USERS)
                 && !pusr_allowed($PUSR_MAINTAIN_ALL));

    # Reject if the user is asking for someone else and the user is not
    # allowed to maintain others
    return 0 if (($userid ne $cur_user)
                 && !pusr_allowed($PUSR_MAINTAIN_USERS)
                 && !pusr_allowed($PUSR_MAINTAIN_ALL));

    my $query = "SELECT * FROM users WHERE userid='$userid';";
    psql_command($query) || return 0;
    my $record = psql_next_record(psql_iterator());
    my $i;
    for ($i = 0; defined($user_fields[$i]); $i++) {
        my $field = $user_fields[$i];
        my $value = psql_get_field($i, $field, $record);
        $cur_edit_data{$field} = $value;
    }
    $cur_edit_data{"userid"} = $userid;
    $cur_edit_user = $userid;
    return 1;
}

sub pusr_edit_fullname {
    $cur_edit_data{"fullname"} = $_[0];
}

sub pusr_edit_get_fullname {
    return $cur_edit_data{"fullname"};
}

sub pusr_edit_password {
    $cur_edit_data{"password"} = crypt($_[0], "abcde");
}

sub pusr_edit_right_add {
    my $right = $_[0];
    if (! ($cur_edit_data{"rights"} =~ /$right/)) {
        $cur_edit_data{"rights"} .= $right;
    }
}

sub pusr_edit_right_remove {
    my $right = $_[0];
    $cur_edit_data{"rights"} =~ s/$right//;
}

sub pusr_edit_right {
    my $right = $_[0];
    my $add = $_[1];
    if ($add) {
        pusr_edit_right_add($right);
    } else {
        pusr_edit_right_remove($right);
    }
}

sub pusr_edit_has_right {
    my $right = $_[0];
    return $cur_edit_data{"rights"} =~ /$right/;
}

sub pusr_edit_setting {
    my $setting = $_[0];
    my $value = $_[1];

    # First, remove the setting, then, if appropriate, add it with the
    # new value
    if (!defined($cur_edit_data{"settings"})) {
        $cur_edit_data{"settings"} = "";
    }
    $cur_edit_data{"settings"} =~ s/^(.*?:)?$setting=([^:=]*)(:.*)?$/$1$3/;
    $cur_edit_data{"settings"} =~ s/::/:/;

    $value =~ s/[:=]//sg;
    if ($value ne "") {
        if ($cur_edit_data{"settings"} eq "") {
            $cur_edit_data{"settings"} = "$setting=$value";
        } else {
            $cur_edit_data{"settings"} .= ":$setting=$value";
        }
    }
}

sub pusr_edit_get_setting {
    my $setting = $_[0];
    my $value = "";

    my $settings = $cur_edit_data{"settings"};
    if (defined($settings) && ($settings ne "")) {
        if ($settings =~ /^(.*?:)?$setting=([^:=]*)(:.*)?$/) {
            $value = $2;
        }
    }
    return $value;
}

sub pusr_edit_close {
    if ($cur_edit_user ne "") {
        my $query = "SELECT userid FROM users WHERE userid='$cur_edit_user';";
        my $end = "";
        psql_command($query);
        my $record = psql_next_record(psql_iterator());
        if (defined($record)) {
            $query = "UPDATE users SET ";
            $end = " WHERE userid = '$cur_edit_user'";
        } else {
            $query = "INSERT INTO users SET ";
        }
        my $i;
        for ($i = 0; defined($user_fields[$i]); $i++) {
            $query .= "," if ($i);
            my $value = psql_encode($cur_edit_data{$user_fields[$i]});
            $query .= " $user_fields[$i]='$value' ";
        }
        $query .= "$end;";
        psql_command($query);
    }
    $cur_edit_user = "";
    %cur_edit_data = ();
}

sub pusr_get_user_list {
  my %users = ();

  # Note: make sure the list is always returned in the same order
  my $query = "SELECT userid, fullname FROM users ORDER BY userid";
  if (psql_command($query)) {
    my $iterator = psql_iterator();
    my $record = psql_next_record($iterator);
    while (defined($record)) {
      my $id = psql_get_field(0, "userid", $record);
      my $name = psql_get_field(1, "fullname", $record);
      if (($id ne "") && ($name ne "")) {
        $users{$id} = $name;
      }
      $record = psql_next_record($iterator);
    }
  }
  return %users;
}

sub pusr_dump_table {
  psql_dump_table("users", 1, \@user_fields);

  return "OK";
}

sub pusr_get_data {
  my $userid = $_[0];
  my $result = "";

  if (pusr_load($userid)) {
    my $i;
    for ($i = 0; defined($user_fields[$i]); $i++) {
      $result .= ", " if ($i);
      my $field = $user_fields[$i];
      $result .= "$field='" . psql_encode($user_data{$field}) . "'";
    }
  }
  return $result;
}

sub pusr_get_hash_text {
  my %users = pusr_get_user_list();
  my $text = "";
  foreach $user (sort (keys %users)) {
    my $usertext = pusr_get_data($user);
    $text .= "$user: $usertext\n";
  }
  return $text;
}

sub pusr_sync_users {
  print "Syncing users\n";

  my $sync_info = psync_get_users_info();

  while ($sync_info =~ s/^(\w+): ([^\n]+)\n//) {
    my $user = $1;
    my $database = $2;
    psql_upsert("users", $database);
  }

  my $text = pusr_get_hash_text(0);
  my $new_hash = phash_do_hash($text);
  phash_set_value("users", "users", $new_hash);
}

return 1;
