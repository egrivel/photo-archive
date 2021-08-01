#
# Photo Archive System - Person Reference Functions
# This source is copyright (c) 2012 by Eric Grivel. All Rights Reserved.
#

use photos_common;
use photos_sql;

my @person_fields = ("personid",
                     "fullname",
                     "description",
  );

my @personref_fields = ("imageid",
                         "personid");

my $cur_edit_pers = "";
my %cur_edit_data = ();

sub ppers_init {
    psql_init();
}

sub ppers_create_tables {
    # Create the tables with a 36-character person ID field, rather
    # than the default 31 character field
    my $query = "CREATE TABLE person (";
    $query .= "   personid CHAR(36),";
    $query .= "   fullname TEXT,";
    $query .= "   description TEXT,";
    $query .= "   PRIMARY KEY(personid))";
    psql_command($query);

    $query = "CREATE TABLE personref (";
    $query .= "   imageid CHAR(31),";
    $query .= "   personid CHAR(36),";
    $query .= "   PRIMARY KEY(imageid, personid),";
    $query .= "   KEY(personid, imageid))";
    psql_command($query);

    return "OK";
}

sub ppers_drop_tables {
    psql_drop_table("person");
    psql_drop_table("personref");
    return "OK";
}

sub ppers_get_id {
    my $name = $_[0];
    my $add_if_not_exist = $_[1];
    if (!defined($add_if_not_exist)) {
        $add_if_not_exist = 1;
    }

    pcom_log($PCOM_DEBUG, "ppers_get_id($name, $add_if_not_exist);");
    my $person_id = "";

    my $value = psql_encode($name);
    my $query = "SELECT * FROM person WHERE fullname='$value';";
    if (psql_command($query)) {
        my $record = psql_next_record(psql_iterator());
        if (defined($record)) {
            $person_id = psql_get_field(0, $person_fields[0], $record);
        }
    }

    if (($person_id eq "")
        && $add_if_not_exist) {
        my $query = "INSERT INTO person (personid, fullname, description) VALUES(UUID(), '$value', '');";
        psql_command($query);
        $query = "SELECT * FROM person WHERE fullname='$value';";
        if (psql_command($query)) {
            my $record = psql_next_record(psql_iterator());
            if (defined($record)) {
                $person_id = psql_get_field(0, $person_fields[0], $record);
            }
        }
    }

    return $person_id;
}

sub ppers_get_name {
    my $person_id = $_[0];
    my $person_name = "";

    pcom_log($PCOM_DEBUG, "ppers_get_name($person_id);");

    my $value = psql_encode($person_id);
    my $query = "SELECT * FROM person WHERE personid='$value';";
    if (psql_command($query)) {
        my $record = psql_next_record(psql_iterator());
        if (defined($record)) {
            $person_name = psql_get_field(1, $person_fields[1], $record);
        }
    }

    return $person_name;
}

sub ppers_get_descr {
    my $person_id = $_[0];
    my $person_descr = "";

    pcom_log($PCOM_DEBUG, "ppers_get_descr($person_id);");

    my $value = psql_encode($person_id);
    my $query = "SELECT * FROM person WHERE personid='$value';";
    if (psql_command($query)) {
        my $record = psql_next_record(psql_iterator());
        if (defined($record)) {
            $person_descr = psql_get_field(2, $person_fields[2], $record);
        }
    }

    return $person_descr;
}

sub ppers_get_count {
    my $person_id = $_[0];
    my $count = 0;

    my $value = psql_encode($person_id);
    my $query = "SELECT COUNT(imageid) FROM personref WHERE personid='$value';";
    if (psql_command($query)) {
        my $record = psql_next_record(psql_iterator());
        $count = psql_get_field(0, "COUNT(imageid)", $record);
    }
    return $count;
}

sub ppers_names_to_ids {
    my $person_list = ";" . $_[0];
    my $id_result = "";
    my $error_result = "";
    while ($person_list =~ s/^([;\|])([^;\|]*)//) {
        my $separator = $1;
        my $name = $2;
        my $not = "";
        $name =~ s/^\s+//;
        $name =~ s/\s+$//;
        if ($name =~ s/^!\s*//) {
            $not = "!";
        } elsif ($name =~ s/^not\s+//i) {
            $not = "!";
        }
        if ($name ne "") {
            my $person_id = ppers_get_id($name, 0);
            if ($person_id eq "") {
                $error_result .= "$separator " if ($error_result ne "");
                $error_result .= "Person not found: $name";
            } else {
                $id_result .= $separator if ($id_result ne "");
                $id_result .= $not . $person_id;
            }
        }
    }
    if ($error_result eq "") {
        return $id_result;
    } else {
        return "ERROR: " . $error_result;
    }
}

sub ppers_ids_to_names {
    my $id_list = $_[0] . ";";
    my $result = "";
    while ($id_list =~ s/^\s*([\w\-!]+)\s*;?//) {
        my $id = $1;
        my $not = "";
        if ($id =~ s/^!//) {
            $not = "NOT ";
        }
        my $name = ppers_get_name($id);
        if ($name ne "") {
            $result .= ", " if ($result ne "");
            $result .= $not.$name;
        }
    }
    return $result;
}

sub ppers_get_filter {
    my $id_list = $_[0];
    my @imagelist = ppers_get_multiple_people($id_list, 0);

    my $result = "";
    my $i;
    for ($i = 0; defined($imagelist[$i]); $i++) {
        $result .= "," if ($result ne "");
        $result .= "'" . $imagelist[$i] . "'";
    }
    return "($result)";
}

sub ppers_get_filter_exclude {
    my $id_list = $_[0];
    my @imagelist = ppers_get_multiple_people($id_list, 1);
    my $result = "";
    my $i;
    for ($i = 0; defined($imagelist[$i]); $i++) {
        $result .= "," if ($result ne "");
        $result .= "'" . $imagelist[$i] . "'";
    }
    return "($result)";
}

sub ppers_update {
    my $image_id = psql_encode($_[0]);
    my $person_list = $_[1] . ";";

    pcom_log($PCOM_DEBUG, "ppers_update($image_id, $person_list)");
    my $query = "DELETE FROM personref WHERE imageid='$image_id';";
    psql_command($query);
    while ($person_list =~ s/^(.*?);//) {
        my $name = $1;
        $name =~ s/^\s+//;
        $name =~ s/\s+$//;
        if ($name ne "") {
            my $person_id = ppers_get_id($name, 1);
            if ($person_id ne "") {
                $query = "INSERT INTO personref (imageid, personid) VALUES ('$image_id', '$person_id');";
                psql_command($query);
            }
        }
    }
}

sub ppers_update_ids {
    my $image_id = psql_encode($_[0]);
    my $person_id_list = $_[1] . ";";

    pcom_log($PCOM_DEBUG, "ppers_update_ids($image_id, $person_id_list)");
    my $query = "DELETE FROM personref WHERE imageid='$image_id';";
    psql_command($query);
    while ($person_id_list =~ s/^(.*?);//) {
        my $person_id = $1;
        $person_id =~ s/^\s+//;
        $person_id =~ s/\s+$//;
        if ($person_id ne "") {
            $query = "INSERT INTO personref (imageid, personid) VALUES ('$image_id', '$person_id');";
            psql_command($query);
        }
    }
}

sub ppers_get_persons_in_image {
    my $image_id = psql_encode($_[0]);
    my $result = "";

    pcom_log($PCOM_DEBUG, "ppers_get_persons_in_image($image_id)");
    my $query = "SELECT * FROM personref WHERE imageid='$image_id';";
    if (psql_command($query)) {
      my $record;
      while (defined($record = psql_next_record(psql_iterator()))) {
          my $person_id = psql_get_field(0, $person_fields[0], $record);
          $result .= ";" if ($result ne "");
          $result .= $person_id;
      }
    }
    pcom_log($PCOM_DEBUG, "got result: $result");
    return $result;
}

sub ppers_delete {
    my $persid = psql_encode($_[0]);
    my $query = "DELETE FROM person WHERE personid='$persid';";
    psql_command($query);
}

sub ppers_delete_image {
    my $image_id = psql_encode($_[0]);
    my $person_list = $_[1] . ";";

    pcom_log($PCOM_DEBUG, "ppers_delete_image($image_id)");
    my $query = "DELETE FROM personref WHERE imageid='$image_id';";
    psql_command($query);
}

sub ppers_get_person_list {
    my $do_count = $_[0];
    if (!defined($do_count)) {
        $do_count = 1;
    }
    my %persons = ();

    my $query = "SELECT personid, fullname, description FROM person";
    if ($do_count) {
        $query = "SELECT personid, fullname, description, (SELECT COUNT(imageid) FROM personref WHERE personref.personid = person.personid) as 'count' FROM person";
    }
    if (psql_command($query)) {
        my $iterator = psql_iterator();
        my $record = psql_next_record($iterator);
        while (defined($record)) {
            my $id = psql_get_field(0, "personid", $record);
            my $name = psql_get_field(1, "fullname", $record);
            my $descr = psql_get_field(2, "description", $record);
            my $count = 1;
            if ($do_count) {
                $count = psql_get_field(3, "count", $record);
            }
            if (($id ne "") && ($name ne "")) {
                $persons{$id} = "$name|$descr|$count";
            }
            $record = psql_next_record($iterator);
        }
    }
    return %persons;
}

sub ppers_dump_tables {
    psql_dump_table("person", 1, \@person_fields);
    psql_dump_table("personref", 1, \@personref_fields);
    return "OK";
}

sub ppers_edit_open {
    my $persid = $_[0];

    return 1 if ($persid eq $cur_edit_pers);
    $cur_edit_pers = "";
    %cur_edit_data = ();

    # Reject if user cannot maintain person database
    return 0 if (!pusr_allowed($PUSR_MAINTAIN_PERSONS));

    my $query = "SELECT * FROM person WHERE personid='$persid';";
    psql_command($query) || return 0;
    my $record = psql_next_record(psql_iterator());
    my $i;
    for ($i = 0; defined($person_fields[$i]); $i++) {
        my $field = $person_fields[$i];
        my $value = psql_get_field($i, $field, $record);
        $cur_edit_data{$field} = $value;
    }
    $cur_edit_data{"persid"} = $persid;
    $cur_edit_pers = $persid;
    return 1;

}

sub ppers_edit_name {
    $cur_edit_data{"fullname"} = $_[0];
}

sub ppers_edit_descr {
    $cur_edit_data{"description"} = $_[0];
}

sub ppers_edit_close {
    if ($cur_edit_pers ne "") {
        my $query = "SELECT personid FROM person WHERE personid='$cur_edit_pers';";
        my $end = "";
        psql_command($query);
        my $record = psql_next_record(psql_iterator());
        if (defined($record)) {
            $query = "UPDATE person SET ";
            $end = " WHERE personid = '$cur_edit_pers'";
        } else {
            $query = "INSERT INTO person SET ";
        }
        my $i;
        for ($i = 0; defined($person_fields[$i]); $i++) {
            $query .= "," if ($i);
            my $value = psql_encode($cur_edit_data{$person_fields[$i]});
            $query .= " $person_fields[$i]='$value' ";
        }
        $query .= "$end;";
        psql_command($query);
    }
    $cur_edit_user = "";
    %cur_edit_data = ();
}

sub ppers_get_photos {
    my $persid = $_[0];

    my $query = "SELECT personref.imageid FROM personref INNER JOIN images ON images.imageid = personref.imageid  WHERE personref.personid='"
        . psql_encode($persid) . "' ORDER BY images.year, images.sortid;";
    my @result = ();
    my $count = 0;

    if (psql_command($query)) {
        my $iterator = psql_iterator();
        my $record = psql_next_record($iterator);
        while (defined($record)) {
            my $imageid = psql_get_field(0, "imageid", $record);
            $result[$count++] = $imageid;
            $record = psql_next_record($iterator);
        }
    }

    return @result;
}

#
# Get the list of images in which one or more people all appear
#
# Input: string with semicolon-separated list of person IDs
# Output: array with image IDs of images in which ALL of the people
#         in the input appear
#
sub ppers_get_multiple_people {
    my $id_list = $_[0];
    my $do_exclude = $_[1];

    # We can either to a global AND (default) or a global OR among the
    # people listed. A global OR is triggered by at least one '|' sepatator
    # (instead of the default ';' sepatator).
    #
    # It is not yet possible to do a combination of AND and OR...
    my $do_any = 0;

    $id_list =~ s/\s+//sg;
    $id_list =~ s/;;/;/g;
    $id_list =~ s/^;//;
    $id_list =~ s/;$//;

    my @result = ();
    my $result_count = 0;

    my $include_count = 0;
    my $include = "";
    my $exclude_count = 0;
    my $exclude = "";
    while ($id_list =~ s/^\s*([^;\|]+)\s*([;\|]?)//) {
        my $id = $1;
        my $separator = $2;
        if ($id =~ s/^!//) {
            $exclude .= "," if ($exclude ne "");
            $exclude .= "'$id'";
            $exclude_count++;
        } else {
            $include .= "," if ($include ne "");
            $include .= "'$id'";
            $include_count++;
        }
        if ($separator eq "|") {
            $do_any = 1;
        }
    }
    # while ($id_list =~ s/\s*;\s*/\',\'/) {
    #     $id_count++;
    # }
    my $count = 0;
    my $query = "SELECT imageid FROM personref WHERE ";
    if ($do_exclude) {
        if ($exclude ne "") {
            $query .= "personid IN ($exclude) ";
            $count = $exclude_count;
        } else {
            # nothing to exclude
            return @result;
        }
    } else {
        if ($include ne "") {
            $query .= "personid IN ($include) ";
            $count = $include_count;
        } else {
            # nothing to include
            return @result;
        }
    }

    # if ($exclude ne "") {
    #     $query .= "AND " if ($include ne "");
    #     $query .= "personid NOT IN ($exclude) ";
    # }
    $query .= "GROUP BY imageid ";
    if (!$do_any) {
        $query .= "HAVING COUNT(DISTINCT personid) = $count ";
    }
    $query .= "ORDER BY imageid";

    if (psql_command($query)) {
        my $iterator = psql_iterator();
        my $record = psql_next_record($iterator);
        while (defined($record)) {
            my $imageid = psql_get_field(0, "imageid", $record);
            $result[$result_count++] = $imageid;
            $record = psql_next_record($iterator);
        }
    }

    return @result;
}

sub ppers_get_list {
  my @persons = ();
  my $count = 0;

  my $query = "SELECT personid FROM person ORDER BY personid";
  if (psql_command($query)) {
    my $iterator = psql_iterator();
    my $record = psql_next_record($iterator);
    while (defined($record)) {
      my $id = psql_get_field(0, "personid", $record);
      if ($id ne "") {
        $persons[$count++] = $id;
      }
      $record = psql_next_record($iterator);
    }
  }
  return @persons;
}

sub ppers_get_data {
  my $personid = $_[0];
  my $data = "";

  my $query = "SELECT * FROM person WHERE personid='";
  $query .= psql_encode($personid) . "'";
  psql_command($query);
  my $record = psql_next_record(psql_iterator());
  my $fullname = psql_get_field(1, "fullname", $record);
  my $description = psql_get_field(2, "description", $record);

  $data .= "database: ";
  $data .= "personid='" . psql_encode($personid) . "'";
  $data .= ",fullname='" . psql_encode($fullname) . "'";
  $data .= ",description='" . psql_encode($description) . "'";

  $query = "SELECT imageid FROM personref WHERE personid='";
  $query .= psql_encode($personid) . "' ORDER BY imageid";
  psql_command($query);
  my $iterator = psql_iterator();
  $record = psql_next_record($iterator);
  my $count = 0;
  while (defined($record)) {
    $data .= "\n";
    $data .= psql_encode(psql_get_field(0, "imageid", $record));
    $count++;
    $record = psql_next_record($iterator);
  }

  return $data;
}

sub ppers_get_person_text {
  my $person_id = $_[0];
  my $do_update = $_[1];

  my $old_hash = phash_get_value("p-$person_id");

  my $text = ppers_get_data($person_id);

  if ($do_update) {
    my $hash = phash_do_hash($text);
    if ($hash ne $old_hash) {
      print "Person $person_id: $old_hash ==> $hash\n";
      phash_set_value("p-$person_id", "person", $hash);
    }
  }

  return $text;
}

sub ppers_get_all_persons_text {
  my $do_update = $_[0];

  my $old_hash = phash_get_value("persons");
  my $text = "";

  my %persons = ppers_get_person_list();
  foreach $person (sort (keys %persons)) {
    my $person_hash = phash_get_value("p-$person");
    if (($person_hash eq "") || $do_update) {
      my $person_text = ppers_get_person_text($person, $do_update);
      $person_hash = phash_do_hash($person_text);
    }
    $text .= "$person: $person_hash\n";
  }

  if ($do_update) {
    my $hash = phash_do_hash($text);
    if ($hash ne $old_hash) {
      print "Persons: $old_hash ==> $hash\n";
      phash_set_value("persons", "persons", $hash);
    }
  }

  return $text;
}

sub ppers_sync_person {
  my $personid = $_[0];
  print "Syncing person $personid\n";

  my $sync_info = psync_get_person_info($personid);
  if ($sync_info =~ s/^database: ([^\n]+)\n//) {
    psql_upsert("person", $1);
  }
  my %images_still_exist = ();

  # Loop through all the images that should be there, and insert them
  # if they don't exist yet
  while ($sync_info =~ s/^([\w\-]+)\n//) {
    my $imageid = $1;
    if ($imageid ne "") {
      $images_still_exist{$imageid}++;
      my $query = "INSERT IGNORE INTO personref(personid, imageid) "
        . "VALUES('"
        . psql_encode($personid) . "','"
        . psql_encode($imageid) . "');";
      psql_command($query);
    }
  }

  # Find any images that need to be deleted
  # (still to be done)
  $query = "SELECT imageid FROM personref WHERE personid='";
  $query .= psql_encode($personid) . "' ORDER BY imageid";
  psql_command($query);
  my $iterator = psql_iterator();
  $record = psql_next_record($iterator);
  while (defined($record)) {
    my $imageid = psql_get_field(0, "imageid", $record);
    if (!defined($images_still_exist{$imageid})) {
      print "Imageref for person $personid to $imageid willl be deleted.\n";
      my $query = "DELETE FROM personref WHERE personid='"
        . psql_encode($personid) . "' AND imageid='"
        . psql_encode($imageid) . "'";
      psql_command($query);
    }
    $record = psql_next_record($iterator);
  }

  # Update person hash
  my $text = ppers_get_person_text($personid, 0);
  my $new_hash = phash_do_hash($text);

  phash_set_value("p-$personid", "person", $new_hash);
}

sub ppers_sync_all_persons {
  print "Syncing persons\n";

  my $sync_info = psync_get_all_persons_info();

  while ($sync_info =~ s/^([\w\-]+): ([^\n]+)\n//) {
    my $personid = $1;
    my $hash = $2;

    my $current_hash = phash_get_value("p-$personid");
    if ($current_hash ne $hash) {
      print "Person $personid: $current_hash => $hash\n";
      ppers_sync_person($personid);
    }
  }

  my $text = ppers_get_all_persons_text(0);
  my $new_hash = phash_do_hash($text);

  phash_set_value("persons", "persons", $new_hash);
}

sub ppers_sync_set_person {
  my $database = $_[0];
  psql_upsert("person", $database);
  return "OK";
}

sub ppers_sync_del_person {
  my $person = $_[0];
  ppers_delete_person($person);
  return "OK";
}

return 1;
