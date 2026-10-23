#!/usr/bin/perl -w -I .

# Tool to add tags to photos
use inc_all;

$gl_verbose = 0;
$gl_done_anything = 0;

put_init();

my $arg = shift;
while (defined($arg)) {
  if ($arg eq "-h") {
    show_help();
  } elsif ($arg eq "-v" || $arg eq "--verbose") {
    $gl_verbose++;
  } elsif ($arg eq "-a" || $arg eq "--all") {
    # do the whole archive
    do_all();
    $gl_done_anything++;
  } elsif ($arg eq "-c" || $arg eq "--check") {
    check_all();
    $gl_done_anything++;
  } elsif ($arg =~ /^\d\d\d\d\d\d\d\d-\d\d\d\d\d\d\w?$/) {
    do_image($arg);
    $gl_done_anything++;
  } elsif ($arg =~ /^\w\d\d\d\d\w?$/) {
    do_image($arg);
    $gl_done_anything++;
  } elsif ($arg =~ /^\d\d\d\d\d\d\d\d$/) {
    do_set($arg);
    $gl_done_anything++;
  } elsif ($arg =~ /^\w\d\d$/) {
    do_set($arg);
    $gl_done_anything++;
  } elsif ($arg =~ /^\d\d\d\d$/) {
    do_year($arg);
    $gl_done_anything++;
  } else {
    die "Unknown argument '$arg'\n";
  }

  $arg = shift;
}

if (!$gl_done_anything) {
  print "Didn't do anything...\n";
}

sub format_timestamp {
  my $time = $_[0];

  my ($sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst) = localtime($time);
  $year += 1900;
  $mon++;
  $mon = "0$mon" if ($mon < 10);
  $mday = "0$mday" if ($mday < 10);
  $hour = "0$hour" if ($hour < 10);
  $min = "0$min" if ($min < 10);
  $sec = "0$sec" if ($sec < 10);

  return "$year-$mon-$mday $hour:$min:$sec";
}

sub show_help {
  print "Initialize the database v4 field:\n";
  print "origWidth, origHeight, editWidth, editHeight, addedDateTime\n";
  print "\n";
  print "Can give an image ID, a set ID, or a year.\n";
}

sub do_image {
  my $imageId = $_[0];

  if (!pcom_is_valid($imageId)) {
    # invalid image ID
    print "$imageId: invalid image ID.\n";
    return;
  }

  pdb_open_image($imageId);

  if (!pdb_image_info($imageId)) {
    # I don't think this can happen after opening the image, but keeping this
    # just in case
    print "$imageId: does not exist in the database.\n";
    return;
  }

  my $category = pdb_get_category($imageId);
  my $status = $PCOM_STAT_AVAILABLE;
  if ($category eq $PCOM_PRIVATE) {
    $status = $PCOM_STAT_RESTRICTED;
  } elsif ($category eq $PCOM_NEW) {
    $status = $PCOM_STAT_NEW;
  }

  pdb_set_status($status);

  pdb_close_image();
}

sub do_set {
  my $setId = $_[0];

  if (!pcom_is_set_valid($setId)) {
    print "$setId: invalid set ID.\n";
    return;
  }

  my $img_iter = pdb_iter_new($setId, 50);
  pdb_iter_filter_setid($img_iter, $setId);
  my $imageId = pdb_iter_next($img_iter);
  while (defined($imageId)
    && ($imageId ne "")
    && (pcom_get_set($imageId) le $setId)) {
    if (pcom_get_set($imageId) eq $setId) {
      do_image($imageId);
    }
    $imageId = pdb_iter_next($img_iter);
    last if (!defined($imageId));
    last if ($imageId eq "");
  }
  pdb_iter_done($img_iter);

  pdb_open_set($setId);

  if (!pdb_set_info($setId)) {
    print "$setId: does not exist in the database.\n";
    return;
  }

  my $category = pdb_get_setcategory($setId);
  my $status = $PCOM_STAT_AVAILABLE;
  if ($category eq $PCOM_PRIVATE) {
    $status = $PCOM_STAT_RESTRICTED;
  } elsif ($category eq $PCOM_NEW) {
    $status = $PCOM_STAT_NEW;
  }

  my $groupid = put_get_groupid($setId);

  pdb_set_setstatus($status);
  pdb_set_setgroupid($groupId);

  pdb_close_set();

  if ($setId =~ /^\d/) {
    # All sets starting with a year belong to year group; make sure the group
    # exists
    pdb_write_group($PCOM_GRP_YEAR, $year, $year);
  }
}

sub do_year {
  print "Doing a year is not yet implemented.\n";
}

sub do_all {
  my $start = time();
  print "Starting " . format_timestamp($start) . "\n";
  print "-------------------------------------------------------------------\n";

  # Write the standard groups
  pdb_write_group($PCOM_GRP_OTHER, "g-frank", "Frank’s Photos");
  pdb_write_group($PCOM_GRP_OTHER, "g-mark", "Mark’s Photos");
  pdb_write_group($PCOM_GRP_OTHER, "g-parents", "Photos of my Parents");
  pdb_write_group($PCOM_GRP_OTHER, "g-albums", "Albums");
  pdb_write_group($PCOM_GRP_OTHER, "g-misc", "Miscellaneous");

  # The iter must be created with a potentially valid image ID. Since film
  # sets come first, "001" is the first possible set ID and "00100" is the
  # first possible image ID
  my $img_iter = pdb_iter_new("00100", 50);
  my $imageId = pdb_iter_next($img_iter);
  while (defined($imageId) && ($imageId ne "")) {
    print "Image $imageId\n" if ($gl_verbose);
    do_image($imageId);
    $imageId = pdb_iter_next($img_iter);
    last if (!defined($imageId));
    last if ($imageId eq "");
  }
  pdb_iter_done($img_iter);

  my $set_iter = pdb_iter_set_new("001", 50);
  my $setId = pdb_iter_next($set_iter);
  while (defined($setId) && $setId ne "") {
    print "Check set $setId\n" if ($gl_verbose);
    do_set($setId);
    $setId = pdb_iter_next($set_iter);
    last if (!defined($setId));
    last if ($setId eq "");
  }
  pdb_iter_set_done($set_iter);

  my $end = time();
  print "-------------------------------------------------------------------\n";
  print "Ending " . format_timestamp($end) . "\n";
  my $seconds = $end - $start;
  my $minutes = int($seconds / 60);
  $seconds -= 60 * $minutes;
  my $hours = int($minutes / 60);
  $minutes -= 60 * $hours;
  my $days = int($hours / 24);
  $hours -= 24 * $days;
  print "Time to run: $days days, $hours hours, $minutes minutes, $seconds seconds\n";
  print "-------------------------------------------------------------------\n";
}

sub check_image {
  my $imageId = $_[0];

  pdb_open_image($imageId);

  my $storedStatus = pdb_get_status($imageId);
  if (!defined($storedStatus) || $storedStatus eq "") {
    print "$imageId: missing status\n";
  }

  pdb_close_image();
}

sub check_all {
  my $start = time();
  print "Starting full check " . format_timestamp($start) . "\n";
  print "-------------------------------------------------------------------\n";

  # The iter must be created with a potentially valid image ID. Since film
  # sets come first, "001" is the first possible set ID and "00100" is the
  # first possible image ID
  my $img_iter = pdb_iter_new("00100", 50);
  my $imageId = pdb_iter_next($img_iter);
  while (defined($imageId) && ($imageId ne "")) {
    print "Check image $imageId\n" if ($gl_verbose);
    check_image($imageId);
    $imageId = pdb_iter_next($img_iter);
    last if (!defined($imageId));
    last if ($imageId eq "");
  }
  pdb_iter_done($img_iter);

  my $set_iter = pdb_iter_set_new("001", 50);
  my $setId = pdb_iter_next($set_iter);
  while (defined($setId) && $setId ne "") {
    print "Check set $setId\n" if ($gl_verbose);
    check_set($setId);
    $setId = pdb_iter_next($set_iter);
    last if (!defined($setId));
    last if ($setId eq "");
  }
  pdb_iter_set_done($set_iter);

  my $end = time();
  print "-------------------------------------------------------------------\n";
  print "Ending " . format_timestamp($end) . "\n";
  my $seconds = $end - $start;
  my $minutes = int($seconds / 60);
  $seconds -= 60 * $minutes;
  my $hours = int($minutes / 60);
  $minutes -= 60 * $hours;
  my $days = int($hours / 24);
  $hours -= 24 * $days;
  print "Time to run: $days days, $hours hours, $minutes minutes, $seconds seconds\n";
  print "-------------------------------------------------------------------\n";
}
