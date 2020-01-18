use photos_common;
use photos_sql;

my @image_fields = (
  "imageid",
  "sortid",
  "setid",    # used to get images of a set
  "title",
  "datetime",
  "year",
  "description",
  "comment",
  "orientation",
  "location",
  "category",
  "quality",
  "rotation",
  "copyright",
  "latlong",
  "persons",
  "type",
);
my @set_fields = (
  "setid",       "sortid",  "datetime", "title",
  "description", "comment", "category", "year",
  "copyright",
);

my $cur_image  = "";
my $cur_set    = "";
my %image_data = ();
my %set_data   = ();

my $cur_save_image    = "";
my $cur_save_set      = "";
my %save_image_data   = ();
my %save_set_data     = ();
my $cur_image_changed = 0;
my $cur_set_changed   = 0;

sub pdb_init {
  return psql_init();
}

sub pdb_create_tables {
  return "no init" if (!pdb_init());

  psql_create_table("images", \@image_fields);
  psql_create_table("sets",   \@set_fields);

  my $query =
    "CREATE INDEX setcat ON images (setid(8), category(3), imageid(16));";
  psql_command($query);

  return "OK";
}

sub pdb_tables_exist {
  return "no init" if (!pdb_init());

  my $query = "SELECT count(*) FROM information_schema.tables ";
  $query .= "WHERE table_schema='" . setting_get('dbname') . "' ";
  $query .= "AND table_name='images';";
  psql_command($query) || return 0;
  my $record = psql_next_record(psql_iterator());
  if (!defined($record)) {
    return 0;
  }
  my $value = psql_get_field(0, 'count(*)', $record);
  print "Got value '$value'\n";
  return $value;
}

sub pdb_drop_tables {
  return "no init" if (!pdb_init());

  psql_drop_table("images");
  psql_drop_table("sets");

  return "OK";
}

sub pdb_image_exists {
  my $imageid = $_[0];

  return 0 if (!pcom_is_valid($imageid));
  return 0 if (!pdb_init());

  my $image_exists = 1;
  my $query        = "SELECT imageid FROM images WHERE imageid='$imageid';";
  psql_command($query) || return 0;
  my $record = psql_next_record(psql_iterator());
  if (!defined($record)) {
    # No data retrieved; image does not exist.
    $image_exists = 0;
  }
  return $image_exists;
}

sub pdb_set_exists {
  my $setid = $_[0];

  return 0 if (!pcom_is_set_valid($setid));
  return 0 if (!pdb_init());

  my $set_exists = 1;
  my $query      = "SELECT setid FROM sets WHERE setid='$setid';";
  psql_command($query) || return 0;

  my $record = psql_next_record(psql_iterator());
  if (!defined($record)) {
    # No data retrieved; set does not exist.
    $set_exists = 0;
  }
  return $set_exists;
}

# Retrieve the information from an image record and store the retrieved
# information. Return true on success, false on failure.
# Note: if the image does not exist, 'false' is returned.
sub pdb_image_info {
  my $imageid = $_[0];

  return 0 if (!pcom_is_valid($imageid));
  return 1 if ($imageid eq $cur_image);
  return 0 if (!pdb_init());

  my $image_exists = 1;
  my $query        = "SELECT * FROM images WHERE imageid='$imageid';";
  psql_command($query) || return 0;
  my $record = psql_next_record(psql_iterator());
  my $i;

  %image_data = ();
  if (!defined($record)) {
    # No data retrieved; image does not exist. Set the return
    # value, but still go through the code below to make sure
    # the %image_data hash is properly initialized.
    $image_exists = 0;
  }

  for ($i = 0 ; defined($image_fields[$i]) ; $i++) {
    my $field = $image_fields[$i];
    my $value = psql_get_field($i, $field, $record);
    $image_data{$field} = $value;
  }
  $cur_image = $imageid;
  return $image_exists;
}

# Retrieve the information from a set record and store the retrieved
# information. Return true on success, false on failure.
sub pdb_set_info {
  my $setid = $_[0];

  print "get set info $setid\n";
  return 0 if (!pcom_is_set_valid($setid));
  print "  is valid\n";
  return 1 if ($setid eq $cur_set);
  print "  already there\n";
  return 0 if (!pdb_init());
  print "  database initialized\n";

  my $query = "SELECT * FROM sets WHERE setid='$setid';";
  print "pdb_set_info $setid: $qyery\n";

  psql_command($query) || return 0;
  my $record = psql_next_record(psql_iterator());
  my $i;
  %set_data = ();
  my $set_exists = 1;
  if (!defined($record)) {
    print "  set does not exist\n";
    $set_exists = 0;
  }
  for ($i = 0 ; defined($set_fields[$i]) ; $i++) {
    my $field = $set_fields[$i];
    my $value = psql_get_field($i, $field, $record);
    $set_data{$field} = $value;
    print "   set field $i $field is $value\n";
  }

  $cur_set = $setid;
  return $set_exists;
}

sub pdb_get_sortid {
  return "" if (!pdb_image_info($_[0]));
  return $image_data{"sortid"};
}

sub pdb_get_setid {
  return "" if (!pdb_image_info($_[0]));
  return $image_data{"setid"};
}

sub pdb_get_title {
  return "" if (!pdb_image_info($_[0]));
  return $image_data{"title"};
}

sub pdb_get_datetime {
  return "" if (!pdb_image_info($_[0]));
  return $image_data{"datetime"};
}

sub pdb_get_year {
  return "" if (!pdb_image_info($_[0]));
  return $image_data{"year"};
}

sub pdb_get_description {
  return "" if (!pdb_image_info($_[0]));
  return $image_data{"description"};
}

sub pdb_get_comment {
  return "" if (!pdb_image_info($_[0]));
  return $image_data{"comment"};
}

sub pdb_get_orientation {
  return "" if (!pdb_image_info($_[0]));
  return $image_data{"orientation"};
}

sub pdb_get_location {
  return "" if (!pdb_image_info($_[0]));
  return $image_data{"location"};
}

sub pdb_get_category {
  return "" if (!pdb_image_info($_[0]));
  return $image_data{"category"};
}

sub pdb_get_quality {
  return "" if (!pdb_image_info($_[0]));
  return $image_data{"quality"};
}

sub pdb_get_rotation {
  return "" if (!pdb_image_info($_[0]));
  return $image_data{"rotation"};
}

sub pdb_get_copyright {
  return "" if (!pdb_image_info($_[0]));
  return $image_data{"copyright"};
}

sub pdb_get_latlong {
  return "" if (!pdb_image_info($_[0]));
  return $image_data{"latlong"};
}

sub pdb_get_persons {
  return "" if (!pdb_image_info($_[0]));
  return $image_data{"persons"};
}

sub pdb_get_type {
  return "" if (!pdb_image_info($_[0]));
  return $image_data{"type"};
}

sub pdb_get_setsortid {
  return "" if (!pdb_set_info($_[0]));
  return $set_data{"sortid"};
}

sub pdb_get_setdatetime {
  return "" if (!pdb_set_info($_[0]));
  return $set_data{"datetime"};
}

sub pdb_get_settitle {
  return "" if (!pdb_set_info($_[0]));
  return $set_data{"title"};
}

sub pdb_get_setdescription {
  return "" if (!pdb_set_info($_[0]));
  return $set_data{"description"};
}

sub pdb_get_setcomment {
  return "" if (!pdb_set_info($_[0]));
  return $set_data{"comment"};
}

sub pdb_get_setcategory {
  return "" if (!pdb_set_info($_[0]));
  return $set_data{"category"};
}

sub pdb_get_setyear {
  return "" if (!pdb_set_info($_[0]));
  return $set_data{"year"};
}

sub pdb_get_setcopyright {
  return "" if (!pdb_set_info($_[0]));
  return $set_data{"copyright"};
}

sub pdb_set_contains_category {
  my $setid    = $_[0];
  my $category = $_[1];

  # Disabled this function; it makes the photos too slow
  # Actually, added an index to the images and now it is fast enough
  return 0 if (!pcom_is_set_valid($setid));
  return 0 if ($category eq "");

  my $query =
"SELECT imageid FROM images WHERE setid='$setid' AND category='$category' LIMIT 1;";
  psql_command($query) || return 0;
  my $record = psql_next_record(psql_iterator());
  return defined($record);
}

sub pdb_open_image {
  my $imageID = $_[0];
  return if (!pcom_is_valid($imageID));

  pdb_image_info($imageID);
  my $i;
  for ($i = 0 ; defined($image_fields[$i]) ; $i++) {
    if (defined($image_data{ $image_fields[$i] })) {
      $save_image_data{ $image_fields[$i] } = $image_data{ $image_fields[$i] };
    } else {
      $save_image_data{ $image_fields[$i] } = "";
    }
  }
  $cur_save_image                      = $imageID;
  $save_image_data{ $image_fields[0] } = $imageID;
  $cur_image_changed                   = 0;
}

sub pdb_set_sortid {
  if ($save_image_data{"sortid"} ne $_[0]) {
    $save_image_data{"sortid"} = $_[0];
    $cur_image_changed = 1;
  }
}

sub pdb_set_setid {
  if ($save_image_data{"setid"} ne $_[0]) {
    $save_image_data{"setid"} = $_[0];
    $cur_image_changed = 1;
  }
}

sub pdb_set_title {
  if ($save_image_data{"title"} ne $_[0]) {
    $save_image_data{"title"} = $_[0];
    $cur_image_changed = 1;
  }
}

sub pdb_set_datetime {
  if ($save_image_data{"datetime"} ne $_[0]) {
    $save_image_data{"datetime"} = $_[0];
    $cur_image_changed = 1;
  }
}

sub pdb_set_year {
  if ($save_image_data{"year"} ne $_[0]) {
    $save_image_data{"year"} = $_[0];
    $cur_image_changed = 1;
  }
}

sub pdb_set_description {
  if ($save_image_data{"description"} ne $_[0]) {
    $save_image_data{"description"} = $_[0];
    $cur_image_changed = 1;
  }
}

sub pdb_set_comment {
  if ($save_image_data{"comment"} ne $_[0]) {
    $save_image_data{"comment"} = $_[0];
    $cur_image_changed = 1;
  }
}

sub pdb_set_orientation {
  if ($save_image_data{"orientation"} ne $_[0]) {
    $save_image_data{"orientation"} = $_[0];
    $cur_image_changed = 1;
  }
}

sub pdb_set_location {
  if ($save_image_data{"location"} ne $_[0]) {
    $save_image_data{"location"} = $_[0];
    $cur_image_changed = 1;
  }
}

sub pdb_set_category {
  if (defined($_[0])
    && ($_[0] ne ""))
  {
    if ($save_image_data{"category"} ne $_[0]) {
      $save_image_data{"category"} = $_[0];
      $cur_image_changed = 1;
    }
  }
}

sub pdb_set_quality {
  if ($save_image_data{"quality"} ne $_[0]) {
    $save_image_data{"quality"} = $_[0];
    $cur_image_changed = 1;
  }
}

sub pdb_set_rotation {
  if ($save_image_data{"rotation"} ne $_[0]) {
    $save_image_data{"rotation"} = $_[0];
    $cur_image_changed = 1;
  }
}

sub pdb_set_copyright {
  if ($save_image_data{"copyright"} ne $_[0]) {
    $save_image_data{"copyright"} = $_[0];
    $cur_image_changed = 1;
  }
}

sub pdb_set_latlong {
  if ($save_image_data{"latlong"} ne $_[0]) {
    $save_image_data{"latlong"} = $_[0];
    $cur_image_changed = 1;
  }
}

sub pdb_set_persons {
  if ($save_image_data{"persons"} ne $_[0]) {
    $save_image_data{"persons"} = $_[0];
    $cur_image_changed = 1;
  }
}

sub pdb_set_type {
  if ($save_image_data{"type"} ne $_[0]) {
    $save_image_data{"type"} = $_[0];
    $cur_image_changed = 1;
  }
}

sub pdb_close_image {
  if (($cur_save_image ne "") && $cur_image_changed) {
    my $query = "SELECT imageid FROM images WHERE imageid='$cur_save_image';";
    my $end   = "";
    psql_command($query);
    my $record = psql_next_record(psql_iterator());
    if (defined($record)) {
      $query = "UPDATE images SET ";
      $end   = " WHERE imageid = '$cur_save_image'";
    } else {
      $query = "INSERT INTO images SET ";
    }
    for ($i = 0 ; defined($image_fields[$i]) ; $i++) {
      $query .= "," if ($i);
      my $value = psql_encode($save_image_data{ $image_fields[$i] });
      $query .= " $image_fields[$i]='$value' ";
    }
    $query .= "$end;";
    psql_command($query);
    if ($cur_image eq $cur_save_image) {
      $cur_image = "";
    }
  }
  $cur_save_image    = "";
  $cur_image_changed = 0;
}

sub pdb_rename_image {
  my $old_imageid = $_[0];
  my $new_imageid = $_[1];

  my $query = "UPDATE images SET ";
  my $value = psql_encode($new_imageid);
  $query .= "imageid='$value' WHERE ";
  $value = psql_encode($old_imageid);
  $query .= "imageid='$value';";

  psql_command($query);
  print "$query\n";
}

sub pdb_open_set {
  my $setid = $_[0];

  pdb_set_info($setid);
  my $i;
  for ($i = 0 ; defined($set_fields[$i]) ; $i++) {
    $save_set_data{ $set_fields[$i] } = $set_data{ $set_fields[$i] };
  }
  $cur_save_set = $setid;
  $save_set_data{ $set_fields[0] } = $setid;
}

sub pdb_set_setsortid {
  $save_set_data{"sortid"} = $_[0];
}

sub pdb_set_setdatetime {
  $save_set_data{"datetime"} = $_[0];
}

sub pdb_set_settitle {
  $save_set_data{"title"} = $_[0];
}

sub pdb_set_setdescription {
  $save_set_data{"description"} = $_[0];
}

sub pdb_set_setcomment {
  $save_set_data{"comment"} = $_[0];
}

sub pdb_set_setcategory {
  if (defined($_[0])
    && ($_[0] ne ""))
  {
    $save_set_data{"category"} = $_[0];
  }
}

sub pdb_set_setcopyright {
  $save_set_data{"copyright"} = $_[0];
}

sub pdb_set_setyear {
  $save_set_data{"year"} = $_[0];
}

sub pdb_close_set {
  if ($cur_save_set ne "") {
    my $query = "SELECT setid FROM sets WHERE setid='$cur_save_set'";
    my $end   = "";
    psql_command($query);
    my $record = psql_next_record(psql_iterator());
    if (!defined($record)) {
      $query = "INSERT INTO sets SET ";
    } else {
      $query = "UPDATE sets SET ";
      $end   = " WHERE setid = '$cur_save_set'";
    }
    for ($i = 0 ; defined($set_fields[$i]) ; $i++) {
      $query .= "," if ($i);
      my $value = psql_encode($save_set_data{ $set_fields[$i] });
      $query .= " $set_fields[$i]='$value' ";
    }
    $query .= "$end;";
    psql_command($query);
  }
  $cur_save_set = "";
}

sub pdb_create_basesortid {
  my $setid  = $_[0];
  my $sortid = "";
  my $year   = pcom_get_year($setid);

  # Start of the sort ID is the year
  $sortid = $year;

  # Second part is the type
  # use 'a' for regular, 'b' for digital, 'c' for Frank and Mark,
  # 'd' for dad's, 'e' for Theo's and 'f' for 'special'
  if ($setid =~ /^\d\d\d$/) {
    $sortid .= "a";
  } elsif ($setid =~ /^\d\d\d\d\d\d\d\d$/) {
    $sortid .= "b";
  } elsif ($setid =~ /^[fm]\d\d$/) {
    $sortid .= "c";
  } elsif ($setid =~ /^[adp]\d\d$/) {
    $sortid .= "d";
  } elsif ($setid =~ /^t\d\d$/) {
    $sortid .= "e";
  } elsif ($setid =~ /^x\d\d$/) {
    $sortid .= "g";
  } else {
    $sortid .= "z";
  }

  return $sortid;
}

sub pdb_create_setsortid {
  my $setid  = $_[0];
  my $sortid = pdb_create_basesortid($setid);
  $sortid .= $setid;

  return $sortid;
}

#
# Fix the image ID to represent the REAL time rather than the
# local time, based on the timezone and "daylight savings time"
# information. This is used in the sort ID calculation only
#
sub pdb_fix_imageid {
  my $imageid  = $_[0];
  my $timezone = $_[1];
  my $dst      = $_[2];

  if ($imageid =~ /^(\d\d\d\d)(\d\d)(\d\d)-(\d\d)(\d\d)(\d\d)(\w?)$/) {
    my $year   = $1;
    my $month  = $2;
    my $day    = $3;
    my $hour   = $4;
    my $minute = $5;
    my $second = $6;
    my $suffix = $7;

    if ($timezone =~ /^\+(\d\d):(\d\d)$/) {
      $hour   -= $1;
      $minute -= $2;
    } elsif ($timezone =~ /^\-(\d\d):(\d\d)$/) {
      $hour   += $1;
      $minute += $2;
    }
    if ($dst eq "Yes") {
      $hour -= 1;
    }
    while ($minute > 59) {
      $hour++;
      $minute -= 60;
    }
    while ($minute < 0) {
      $hour--;
      $minute += 60;
    }
    while ($hour > 23) {
      $day++;
      $hour -= 24;
    }
    while ($hour < 0) {
      $day--;
      $hour += 24;
    }
    if ($day < 1) {
      $month--;
      $day += 31;
      if ($month == 2) {
        if ((4 * int($year / 4)) == $year) {
          # leap year; February has 29 days
          $day -= 2;
        } else {
          # non-leap year: February has 28 days
          $day -= 3;
        }
      } elsif (($month == 4)
        || ($month == 6)
        || ($month == 9)
        || ($month == 11))
      {
        # 30-day month
        $day -= 1;
      } elsif ($month == 0) {
        # back one year
        $year--;
        $month += 12;
      }
    }

    # Got the corrected timestamp; now re-build the image ID
    $imageid = $year;
    $imageid .= "0" if ($month < 10);
    $imageid .= int($month);
    $imageid .= "0" if ($day < 10);
    $imageid .= int($day);
    $imageid .= "-";
    $imageid .= "0" if ($hour < 10);
    $imageid .= int($hour);
    $imageid .= "0" if ($minute < 10);
    $imageid .= int($minute);
    $imageid .= $second;
    $imageid .= $suffix;
  }
  return $imageid;
}

sub pdb_create_sortid {
  my $imageid  = $_[0];
  my $timezone = $_[1];
  my $dst      = $_[2];
  if (!defined($timezone)) {
    $timezone = "+00:00";
  }
  if (!defined($dst) || !($dst eq "Yes")) {
    $dst = "No";
  }
  my $setid = pcom_get_set($imageid);
  if ($setid eq "") {
    $setid = $imageid;
  }
  my $sortid = pdb_create_basesortid($setid);

  $sortid .= pdb_fix_imageid($imageid, $timezone, $dst);

  return $sortid;
}

# ------------------------------------------------------------
# Implement the iterator functionality
# ------------------------------------------------------------

my @iter           = ();
my @iter_type      = ();
my @iter_filter    = ();
my @iter_subfilter = ();
my @iter_limit     = ();
my @iter_count     = ();
my @iter_result    = ();

sub pdb_iter_new {
  my $imageID = $_[0];
  my $limit   = $_[1];
  if (!defined($limit)) {
    $limit = 1;
  }
  my $i = 0;

  while (defined($iter_type[$i]) && ($iter_type[$i] ne "free")) {
    $i++;
  }

  $iter_type[$i] = "image";
  if (defined($imageID)) {
    my $sortid = pdb_get_sortid($imageID);
    if ($sortid eq "") {
      $sortid = pdb_create_sortid($imageID);
      if ($sortid =~ /^(\d\d\d\d\w)(\d\d\d\d)(\d\d)(\d\d)(.*)$/) {
        my $part1 = $1;
        my $year  = $2;
        my $month = $3;
        my $day   = $4;
        my $rest  = $5;
        $day--;
        if ($day < 1) {
          $month--;
          if ($month == 2) {
            $day = 28;
          } elsif (($month == 4)
            || ($month == 6)
            || ($month == 9)
            || ($month == 11))
          {
            $day = 30;
          } else {
            $day = 31;
          }
          if ($day < 10) {
            $day = '0' . int($day);
          }
          if ($month < 1) {
            $year--;
            $month = 12;
          } elsif ($month < 10) {
            $month = '0' . int($month);
          }
        } elsif ($day < 10) {
          $day = '0' . int($day);
        }
        $sortid = $part1 . $year . $month . $day . $rest;
      }
      pcom_log($PCOM_DEBUG, "Created sortid $sortid for imageid $imageID");
    }
    $iter[$i] = $sortid;
  }
  $iter_filter[$i]    = "";
  $iter_subfilter[$i] = "";
  $iter_limit[$i]     = $limit;
  $iter_count[$i]     = 0;
  my @result = ();
  $iter_result[$i] = [@result];

  return $i;
}

sub pdb_iter_done {
  my $iter = $_[0];
  if (defined($iter_type[$iter]) && ($iter_type[$iter] eq "image")) {
    $iter_type[$iter] = "free";
    my @result = ();
    $iter_result[$iter] = [@result];
  }
}

sub pdb_iter_set_new {
  my $setid = $_[0];
  my $limit = $_[1];
  if (!defined($limit)) {
    $limit = 1;
  }
  my $i = 0;

  while (defined($iter_type[$i]) && ($iter_type[$i] ne "free")) {
    $i++;
  }

  $iter_type[$i] = "set";
  if (defined($setid)) {
    my $sortid = pdb_get_setsortid($setid);
    if ($sortid eq "") {
      $sortid = pdb_create_setsortid($setid);
      pcom_log($PCOM_DEBUG, "Created sortid $sortid for setid $setid");
    }
    $iter[$i] = $sortid;
    pcom_log($PCOM_DEBUG, "Set iter[$i] to $sortid");
  }
  $iter_filter[$i]    = "";
  $iter_subfilter[$i] = "";
  $iter_limit[$i]     = $limit;
  $iter_count[$i]     = 0;
  my @result = ();
  $iter_result[$i] = [@result];

  return $i;
}

sub pdb_iter_set_done {
  my $iter = $_[0];

  if (defined($iter_type[$iter]) && ($iter_type[$iter] eq "set")) {
    $iter_type[$iter] = "free";
    my @result = ();
    $iter_result[$iter] = [@result];
  }
}

# add a filter to only allow the selected categories. The categories
# are given as a string, and any category matches
sub pdb_iter_filter_category {
  my $iter       = $_[0];
  my $categories = $_[1];

  # If no categories given, we're done
  return if ($categories eq "");

  # Add logical "and" with previous filters
  if ($iter_filter[$iter] ne "") {
    $iter_filter[$iter] .= " AND ";
  }

  if ($categories =~ /^\w$/) {
    $iter_filter[$iter] .= "category='$categories' ";
  } else {

    # Must be multiple categories
    $iter_filter[$iter] .= "(";
    while ($categories =~ s/(\w)//) {
      $iter_filter[$iter] .= " category='$1'";
      $iter_filter[$iter] .= " OR " if ($categories ne "");
    }
    $iter_filter[$iter] .= ")";
  }
}

sub pdb_iter_filter_min_quality {
  my $iter    = $_[0];
  my $quality = $_[1];

  if ($iter_type[$iter] eq "set") {
    # Add logical "and" with previous subfilters
    if ($iter_subfilter[$iter] ne "") {
      $iter_subfilter[$iter] .= " AND ";
    }
    $iter_subfilter[$iter] .= "quality >= '$quality' ";
  } else {
    # Add logical "and" with previous filters
    if ($iter_filter[$iter] ne "") {
      $iter_filter[$iter] .= " AND ";
    }
    $iter_filter[$iter] .= "quality >= '$quality' ";
  }
}

sub pdb_iter_filter_max_quality {
  my $iter    = $_[0];
  my $quality = $_[1];

  if ($iter_type[$iter] eq "set") {
    # Add logical "and" with previous sub filters
    if ($iter_subfilter[$iter] ne "") {
      $iter_subfilter[$iter] .= " AND ";
    }
    $iter_subfilter[$iter] .= "quality <= '$quality' ";
  } else {
    # Add logical "and" with previous filters
    if ($iter_filter[$iter] ne "") {
      $iter_filter[$iter] .= " AND ";
    }
    $iter_filter[$iter] .= "quality <= '$quality' ";
  }
}

sub pdb_iter_filter_persons {
  my $iter          = $_[0];
  my $person_filter = $_[1];
  if ($person_filter =~ /^\(.*\)$/) {
    # proper SQL list format
    if ($iter_filter[$iter] ne "") {
      $iter_filter[$iter] .= " AND ";
    }
    $iter_filter[$iter] .= "imageid in $person_filter ";
  } else {
    print "<br/>Invalid filter: $person_filter\n";
  }
}

sub pdb_iter_filter_year {
  my $iter = $_[0];
  my $year = $_[1];

  # Add logical "and" with previous filters
  if ($iter_filter[$iter] ne "") {
    $iter_filter[$iter] .= " AND ";
  }
  $iter_filter[$iter] .= "year = '$year' ";
}

sub pdb_iter_filter_setid {
  my $iter  = $_[0];
  my $setid = $_[1];

  # Add logical "and" with previous filters
  if ($iter_filter[$iter] ne "") {
    $iter_filter[$iter] .= " AND ";
  }
  $iter_filter[$iter] .= "setid = '$setid' ";
}

sub pdb_iter_filter_year_range {
  my $iter  = $_[0];
  my $year1 = $_[1];
  my $year2 = $_[2];

  # Add logical "and" with previous filters
  if ($iter_filter[$iter] ne "") {
    $iter_filter[$iter] .= " AND ";
  }
  $iter_filter[$iter] .= "year >= '$year1' AND year <= '$year2'";
}

sub pdb_iter_filter_title {
  my $iter = $_[0];
  my $text = $_[1];

  if ($iter_filter[$iter] ne "") {
    $iter_filter[$iter] .= " AND ";
  }
  $iter_filter[$iter] .= "title like '\%$text\%' ";
}

sub pdb_iter_filter_descr {
  my $iter = $_[0];
  my $text = $_[1];

  if ($iter_filter[$iter] ne "") {
    $iter_filter[$iter] .= " AND ";
  }
  $iter_filter[$iter] .= "description like '\%$text\%' ";
}

sub pdb_iter_filter_comment {
  my $iter = $_[0];
  my $text = $_[1];

  if ($iter_filter[$iter] ne "") {
    $iter_filter[$iter] .= " AND ";
  }
  $iter_filter[$iter] .= "comment like '\%$text\%' ";
}

sub pdb_do_iter {
  my $iter  = $_[0];
  my $query = $_[1];

  my $result = "";

  if (!defined($iter_type[$iter]) || ($iter_type[$iter] eq "free")) {
    return "";
  }

  my $field = "";
  if ($iter_type[$iter] eq "image") {
    $field = "imageid";
  } else {
    $field = "setid";
  }

  # Check if we already have some results. Reuse those results if
  # possible
  my $resultref = $iter_result[$iter];
  $result = $$resultref[$iter_count[$iter]++];
  if (defined($result)) {
    return $result;
  }

  # We don't have any results. Do the query and remember the results
  # that we get back.
  psql_command($query);
  my $pit    = psql_iterator();
  my $record = psql_next_record($pit);
  my $count  = 0;
  @result = ();
  $result[0] = "";

  while (defined($record)) {
    my $value = psql_get_field(0, $field, $record);
    last if (!defined($value));
    $result[$count++] = $value;
    $iter[$iter] = psql_get_field(1, "sortid", $record);
    $record = psql_next_record($pit);
  }
  $iter_result[$iter] = [@result];
  $iter_count[$iter]  = 1;

  # Return the first result we got;
  return $result[0];
}

sub pdb_iter_debug {
  my $i = 0;

  while (defined($iter_type[$i]) && ($iter_type[$i] ne "free")) {
    print "iter_type[$i] is $iter_type[$i]\n";
    print "iter_result[$i] is $iter_result[$i]\n";
    my $resultref = $iter_result[$i];
    my $j         = 0;
    while (defined($$resultref[$j])) {
      print "  result[$j] is $$resultref[$j]\n";
      $j++;
    }
    print "iter_count[$i] is $iter_count[$i]\n";
    $i++;
  }
}

sub pdb_iter_next {
  my $iter  = $_[0];
  my $query = "";

  if ($iter_type[$iter] eq "image") {
    $query = "SELECT imageid, sortid FROM images ";
  } else {
    $query = "SELECT setid, sortid FROM sets ";
  }

  if (defined($iter[$iter])) {
    if ($iter_count[$iter] > 0) {
      # We already have results; next result should be
      # AFTER current one
      $query .= "WHERE sortid > '$iter[$iter]' ";
    } else {
      # We don't have results yet; next result should
      # include the starting position
      $query .= "WHERE sortid >= '$iter[$iter]' ";
    }
    if ($iter_filter[$iter] ne "") {
      $query .= "AND $iter_filter[$iter] ";
    }
  } elsif ($iter_filter[$iter] ne "") {
    pcom_log($PCOM_DEBUG, "iter[$iter] is not defined");
    $query .= "WHERE $iter_filter[$iter] ";
  }

  $query .= "ORDER BY sortid LIMIT $iter_limit[$iter]";

  return pdb_do_iter($iter, $query);
}

sub pdb_iter_previous {
  my $iter  = $_[0];
  my $query = "";

  if ($iter_type[$iter] eq "image") {
    $query = "SELECT imageid, sortid FROM images ";
  } else {
    $query = "SELECT setid, sortid FROM sets ";
  }
  if (defined($iter[$iter])) {
    $query .= "WHERE sortid < '$iter[$iter]' ";
    if ($iter_filter[$iter] ne "") {
      $query .= "AND $iter_filter[$iter] ";
    }
  } elsif ($iter_filter[$iter] ne "") {
    $query .= "WHERE $iter_filter[$iter] ";
  }
  $query .= "ORDER BY sortid DESC LIMIT 1";

  return pdb_do_iter($iter, $query);
}

my $filter = "";

sub pdb_filter_category {
  my $categories = $_[0];

  # If no categories given, we're done
  return if ($categories eq "");

  # Add logical "and" with previous filters
  if ($filter ne "") {
    $filter .= "AND ";
  }

  if ($categories =~ /^\w$/) {
    $filter .= "category='$categories' ";
  } else {

    # Must be multiple categories
    $filter .= "(";
    while ($categories =~ s/(\w)//) {
      $filter .= " category='$1'";
      $filter .= " OR " if ($categories ne "");
    }
    $filter .= ") ";
  }
}

sub pdb_filter_min_quality {
  my $quality = $_[0];

  # Add logical "and" with previous filters
  if ($filter ne "") {
    $filter .= "AND ";
  }
  $filter .= "quality >= '$quality' ";
}

sub pdb_filter_max_quality {
  my $quality = $_[0];

  # Add logical "and" with previous filters
  if ($filter ne "") {
    $filter .= "AND ";
  }
  $filter .= "quality <= '$quality' ";
}

sub pdb_filter_range_start {
  my $start = $_[0];

  # Add logical "and" with previous filters
  if ($filter ne "") {
    $filter .= "AND ";
  }
  $filter .= "imageid >= '$start' ";
}

sub pdb_filter_range_end {
  my $end = $_[0];

  # Add logical "and" with previous filters
  if ($filter ne "") {
    $filter .= "AND ";
  }
  $filter .= "imageid <= '$end' ";
}

sub pdb_filter_descr {
  my $text = $_[0];

  # Add logical "and" with previous filters
  if ($filter ne "") {
    $filter .= "AND ";
  }
  $filter .= "description like '\%$text\%' ";
}

sub pdb_filter_title {
  my $text = $_[0];

  # Add logical "and" with previous filters
  if ($filter ne "") {
    $filter .= "AND ";
  }
  $filter .= "title like '\%$text\%' ";
}

sub pdb_filter_comment {
  my $text = $_[0];

  # Add logical "and" with previous filters
  if ($filter ne "") {
    $filter .= "AND ";
  }
  $filter .= "comment like '\%$text\%' ";
}

sub pdb_filter_year {
  my $year = $_[0];

  # Add logical "and" with previous filters
  if ($filter ne "") {
    $filter .= "AND ";
  }
  $filter .= "year = '$year' ";
}

sub pdb_filter_year_range {
  my $year1 = $_[0];
  my $year2 = $_[1];

  # Add logical "and" with previous filters
  if ($filter ne "") {
    $filter .= "AND ";
  }
  $filter .= "year >= '$year1' AND year <= '$year2'";
}

# The filter passed in is the one returned from ppers_get_filter
sub pdb_filter_persons {
  my $person_filter = $_[0];
  if ($person_filter =~ /^\(.*\)$/) {

    # proper SQL list format
    if ($filter ne "") {
      $filter .= "AND ";
    }
    $filter .= "imageid in $person_filter ";
  } else {
    print "<br/>Invalid filter: $person_filter\n";
  }
}

sub pdb_year_exists {
  my $year  = $_[0];
  my $query = "SELECT setid FROM sets WHERE year = '$year' LIMIT 1";
  psql_command($query) || return 0;
  my $record = psql_next_record(psql_iterator());
  if (!defined($record)) {
    return 0;
  }
  my $field = psql_get_field(0, "setid", $record);
  return (defined($field) && ($field ne ""));
}

sub pdb_image_count {
  my $query = "SELECT COUNT(imageid) FROM images";
  if ($filter ne "") {
    $query .= " WHERE $filter";
  }
  psql_command($query) || return 0;
  my $record = psql_next_record(psql_iterator());
  return psql_get_field(0, "COUNT(imageid)", $record);
}

sub pdb_trash_image {
  my $imageid = $_[0];

  my $query = "DELETE FROM images WHERE imageid = '$imageid'";
  psql_command($query);
}

#
# Adding the delete set function, but only allowing a set to be
# deleted if there are no images...
#
sub pdb_delete_set_if_empty {
  my $setid = $_[0];

  my $query =
"DELETE FROM sets WHERE (setid='$setid') AND NOT EXISTS (SELECT * FROM images WHERE setid = '$setid') ";
  psql_command($query);
}

sub pdb_random_image {
  my $query = "SELECT imageid FROM images";
  if ($filter ne "") {
    $query .= " WHERE $filter";
  }
  $query .= " ORDER BY RAND() LIMIT 1";
  psql_command($query) || return "";
  my $record = psql_next_record(psql_iterator());
  return psql_get_field(0, "imageid", $record);
}

sub pdb_set_has_latlong {
  my $setid = $_[0];

  my $query = "SELECT imageid FROM images";
  if ($filter eq "") {
    $query .= " WHERE latlong != ''";
  } else {
    $query .= " WHERE $filter AND latlong != ''";
  }
  $query .= " LIMIT 1";
  psql_command($query) || return 0;
  my $record = psql_next_record(psql_iterator());
  return defined(psql_get_field(0, "imageid", $record));
}

# Return the latest (newest) set from the digital photos
sub pdb_latest_set {
  my $query = "SELECT setid FROM sets WHERE LENGTH(setid) = 8 ";
  $query .= "AND setid < '21000000' ORDER BY setid DESC LIMIT 1";
  if (psql_command($query)) {
    my $record = psql_next_record(psql_iterator());
    return psql_get_field(0, "setid", $record);
  }
  return "";
}

# dump the contents of the database to standard output
sub pdb_dump_tables {
  my $setid = $_[0];
  if (defined($setid)) {
    psql_dump_table("sets",   -1, \@set_fields,   $setid);
    psql_dump_table("images", -1, \@image_fields, $setid);
  } else {
    psql_dump_table("images", 1, \@image_fields);
    print
      "CREATE INDEX setcat ON images (setid(8), category(3), imageid(16));\n";
    psql_dump_table("sets", 1, \@set_fields);
  }
  return "OK";
}

sub pdb_dump_set {
  my $setid = $_[0];

  psql_dump_records("images", "setid='$setid'", \@image_fields);
  psql_dump_records("sets",   "setid='$setid'", \@set_fields);

  return "OK";
}

sub pdb_get_image_data {
  my $imageid = $_[0];
  my $result = "";

  if (pdb_image_info($imageid)) {
    my $i;
    for ($i = 0; defined($image_fields[$i]); $i++) {
      $result .= ", " if ($i);
      my $field = $image_fields[$i];
      $result .= "$field='" . psql_encode($image_data{$field}) . "'";
    }
  }
  return $result;
}

sub pdb_get_set_data {
  my $setid = $_[0];
  my $result = "";

  print "pdb_get_set_data($setid)\n";
  if (pdb_set_info($setid)) {
    my $i;
    for ($i = 0; defined($set_fields[$i]); $i++) {
      $result .= ", " if ($i);
      my $field = $set_fields[$i];
      $result .= "$field='" . psql_encode($set_data{$field}) . "'";
    }
  }
  return $result;
}

# Return all the years in the database
sub pdb_get_years {
  my $query = "SELECT DISTINCT year FROM sets ORDER BY year";
  my @result = ();
  my $count = 0;

  psql_command($query);
  my $iterator = psql_iterator();
  my $record = psql_next_record($iterator);
  while (defined($record)) {
    my $year = psql_get_field(0, "year", $record);
    $result[$count++] = $year;
    $record = psql_next_record($iterator);
  }

  return \@result;
}

# Return all the non-private and non-blank sets in a year
sub pdb_get_year_sets {
  my $year = $_[0];
  my $query = "SELECT DISTINCT setid FROM sets ";
  $query .= "WHERE year='" . psql_encode($year) . "' ";
  $query .= "AND category !='" . psql_encode($PCOM_PRIVATE) . "' ";
  $query .= "AND category !='" . psql_encode($PCOM_NEW) . "' ";
  $query .= "ORDER BY setid";
  my @result = ();
  my $count = 0;

  psql_command($query);
  my $iterator = psql_iterator();
  my $record = psql_next_record($iterator);
  while (defined($record)) {
    my $setid = psql_get_field(0, "setid", $record);
    $result[$count++] = $setid;
    $record = psql_next_record($iterator);
  }

  return \@result;
}

# Return all the images in a set
sub pdb_get_set_images {
  my $setid = $_[0];
  my $query = "SELECT DISTINCT imageid FROM images ";
  $query .= "WHERE setid='" . psql_encode($setid) . "' ";
  $query .= "AND category !='" . psql_encode($PCOM_PRIVATE) . "' ";
  $query .= "AND category !='" . psql_encode($PCOM_NEW) . "' ";
  $query .= "ORDER BY imageid";
  my @result = ();
  my $count = 0;

  psql_command($query);
  my $iterator = psql_iterator();
  my $record = psql_next_record($iterator);
  while (defined($record)) {
    my $imageid = psql_get_field(0, "imageid", $record);
    $result[$count++] = $imageid;
    $record = psql_next_record($iterator);
  }

  return \@result;
}

sub pdb_get_file_item_hash {
  my $item = $_[0];
  my $fname = $_[1];
  my $do_update = $_[2];
  my $resourceid = "f-$item";

  my $file_hash = phash_get_value($resourceid);

  if ($do_update || $file_hash eq "") {
    my %hash = phash_get_resource($resourceid);
    my ($dev, $ino, $mode, $nlink, $uid, $gid, $rdev, $size,
      $atime, $mtime, $ctime, $blksize, $blocks) = stat($fname);

    if (defined($hash{"timestamp"}) && $hash{"timestamp"} == $mtime) {
      return $file_hash;
    }

    my $cmd = "sha256sum \"$fname\"";
    open(PIPE, "$cmd|") || die "Cannot get hash for '$fname'\n";
    my $text = <PIPE>;
    $file_hash = "";
    close(PIPE);
    if ($text =~ /^([\w\-]+)/) {
      $file_hash = $1;
    }
    $hash{"hash"} = $file_hash;
    $hash{"type"} = "file";
    $hash{"timestamp"} = $mtime;
    phash_set_resource($resourceid, \%hash);
  }

  return $file_hash;
}

sub pdb_get_image_hash_text {
  my $image = $_[0];
  my $set = $_[1];
  my $do_update = $_[2];
  my $text = "";

  my $old_hash = phash_get_value("i-$image");

  $database = pdb_get_image_data($image);
  $text .= "database: " . $database . "\n";
  my $root = local_photos_directory();

  $item = "tif/$image.nef";
  if (-f "$root/$set/$item") {
    my $hash = pdb_get_file_item_hash($item, "$root/$set/$item", $do_update);
    $text .= "$item: $hash\n";
  }

  $item = "tif/$image.tif";
  if (-f "$root/$set/$item") {
    my $hash = pdb_get_file_item_hash($item, "$root/$set/$item", $do_update);
    $text .= "$item: $hash\n";
  }

  $item = "tif/$image.jpg";
  if (-f "$root/$set/$item") {
    my $hash = pdb_get_file_item_hash($item, "$root/$set/$item", $do_update);
    $text .= "$item: $hash\n";
  }

  $item = "edited/$image.jpg";
  if (-f "$root/$set/$item") {
    my $hash = pdb_get_file_item_hash($item, "$root/$set/$item", $do_update);
    $text .= "$item: $hash\n";
  }

  if ($do_update) {
    my $hash = phash_do_hash($text);
    if ($hash ne $old_hash) {
      print "Image $image: $old_hash ==> $hash\n";
      phash_set_value("i-$image", "image", $hash);
    }
  }

  return $text;
}

sub pdb_get_set_hash_text {
  my $set = $_[0];
  my $do_update = $_[1];

  print "pdb_get_set_hash_text($set)\n";
  my $old_hash = phash_get_value("s-$set");

  my $text = "";
  $text .= "database: " . pdb_get_set_data($set) . "\n";
  my $images = pdb_get_set_images($set);
  for (my $i = 0; defined(@$images[$i]); $i++) {
    my $image = @$images[$i];
    my $image_hash = phash_get_value("i-$image");
    if ($do_update) {
      my $image_text = pdb_get_image_hash_text($image, $set, $do_update);
      $image_hash = phash_do_hash($image_text);
    }
    $text .= "$image: $image_hash\n";
  }

  if ($do_update) {
    my $hash = phash_do_hash($text);
    if ($hash ne $old_hash) {
      print "Set $set: $old_hash ==> $hash\n";
      phash_set_value("s-$set", "set", $hash);
    }
  }

  return $text;
}

sub pdb_get_year_hash_text {
  my $year = $_[0];
  my $do_update = $_[1];

  my $old_hash = phash_get_value("y-$year");

  my $text = "";
  my $sets = pdb_get_year_sets($year);
  for (my $i = 0; defined(@$sets[$i]); $i++) {
    my $set = @$sets[$i];
    print "pdb_get_year_hash_text: check set $set\n";
    my $set_hash = phash_get_value("s-$set");
    if ($do_update) {
      my $set_text = pdb_get_set_hash_text($set, $do_update);
      $set_hash = phash_do_hash($set_text);
    }
    $text .= "$set: $set_hash\n";
  }

  if ($do_update) {
    my $hash = phash_do_hash($text);
    if ($hash ne $old_hash) {
      print "Year $year: $old_hash ==> $hash\n";
      phash_set_value("y-$year", "year", $hash);
    }
  }

  return $text;
}

sub pdb_get_all_years_hash_text {
  my $do_update = $_[0];
  my $text = "";

  my $old_hash = phash_get_value("years");

  my $years = pdb_get_years();

  for (my $i = 0; defined(@$years[$i]); $i++) {
    my $year = @$years[$i];
    my $year_hash = phash_get_value("y-$year");
    if ($do_update) {
      my $year_text = pdb_get_year_hash_text($year, $do_update);
      if ($year_text ne "") {
        $year_hash = phash_do_hash($year_text);
      }
    }
    if ($year_hash ne "") {
      $text .= "$year: $year_hash\n";
    }
  }

  if ($do_update) {
    my $hash = phash_do_hash($text);
    if ($hash ne $old_hash) {
      print "Alll years: $old_hash ==> $hash\n";
      phash_set_value("years", "", $hash);
    }
  }

  return $text;
}

sub pdb_sync_image {
  my $setid = $_[0];
  my $imageid = $_[1];
  print "Syncing image $imageid\n";

  my $sync_info = psync_get_image_info($imageid);

  if ($sync_info =~ s/^database: ([^\n]+)\n//) {
    psql_upsert("images", $1);
  }
  while ($sync_info =~ s/^([\w\-\.\/]+): (\w+)\n//) {
    my $fileid = $1;
    my $hash = $2;
    my $current_hash = phash_get_value("f-$fileid");
    if ($current_hash ne $hash) {
      psync_retrieve_file($setid, $fileid);
    }
    my $root = local_photos_directory();
    my $fname = "$root/$setid/$fileid";
    pdb_get_file_item_hash($fileid, $fname, 1);
  }

  my $text = pdb_get_image_hash_text($imageid, $setid, 0);
  my $new_hash = phash_do_hash($text);
  phash_set_value("i-$imageid", "image", $new_hash);
}

sub pdb_sync_set {
  my $setid = $_[0];
  print "Syncing set $setid\n";

  my $sync_info = psync_get_set_info($setid);

  if ($sync_info =~ s/^database: ([^\n]+)\n//) {
    print "Do upsert: $1\n";
    psql_upsert("sets", $1);
  }
  while ($sync_info =~ s/^([\w\-\.\/]+): (\w+)\n//) {
    my $imageid = $1;
    my $hash = $2;
    my $current_hash = phash_get_value("i-$imageid");
    if ($current_hash ne $hash) {
      print "Image $imageid: $current_hash => $hash\n";
      pdb_sync_image($setid, $imageid);
    }
  }

  my $text = pdb_get_set_hash_text($set, 0);
  my $new_hash = phash_do_hash($text);

  print "\nSet $setid:\nnew hash: $new_hash\n$text\n\n";
  phash_set_value("s-$setid", "set", $new_hash);
}

sub pdb_sync_year {
  my $year = $_[0];

  print "Syncing year $year\n";
  my $sync_info = psync_get_year_info($year);

  while ($sync_info =~ s/^(\w+): (\w+)\n//) {
    my $setid = $1;
    my $hash = $2;

    my $current_hash = phash_get_value("s-$setid");
    if ($current_hash ne $hash) {
      print "Set $setid: $current_hash => $hash\n";
      pdb_sync_set($setid);
    }
  }

  my $text = pdb_get_year_hash_text($year, 0);
  my $new_hash = phash_do_hash($text);
  phash_set_value("y-$year", "year", $new_hash);
}

sub pdb_sync_all_years {
  print "Syncing all years\n";
  my $sync_info = psync_get_all_years_info();

  while ($sync_info =~ s/^(\d\d\d\d): (\w+)\n//) {
    my $year = $1;
    my $hash = $2;

    my $current_hash = phash_get_value("y-$year");
    if ($current_hash ne $hash) {
      print "Year $year: $current_hash => $hash\n";
      pdb_sync_year($year);
    }
  }

  my $text = pdb_get_all_years_hash_text($year, 0);
  my $new_hash = phash_do_hash($text);
  phash_set_value("years", "years", $new_hash);
}

return 1;
