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

  my $orig = pfs_get_orig_location($imageId);
  my $raw = pfs_get_raw_location($imageId);
  if ($orig eq "") {
    $orig = $raw;
  }
  my $edited = pfs_get_edited_location($imageId);

  if (($orig eq "") && ($edited ne "")) {
    # It looks like some variations (..a, ..b etc. suffixes) have been saved
    # as edited files without corresponding original. Warn on that; at some
    # point, the archive should be cleaned up to move these edited to become
    # the original.
    $orig = $edited;
    print "$imageId: using edited as original.\n" if ($gl_verbose);
  }

  if ($orig eq "") {
    print "$imageId: cannot find orig; every image should have an original.\n";
    return;
  }

  ($origWidth, $origHeight) = pfs_get_file_dimensions($orig);
  print "Got file dimensions $origWidth x $origHeight for $orig\n" if ($gl_verbose);
  if (!$origWidth || !$origHeight) {
    print "$imageId: orig dimensions are $origWidth x $origHeight\n";
  }

  my $rotation = pdb_get_rotation($imageId);
  # Orientation values:
  # $PCOM_LANDSCAPE = "landscape";
  # $PCOM_PORTRAIT = "portrait";
  # $PCOM_FREEFORM = "freeform";
  # $PCOM_FREEFORM_P = "freeform-p";
  # $PCOM_FREEFORM_L = "freeform-l";
  my $orientation = pdb_get_orientation($imageId);

  my $editedWidth;
  my $editedHeight;
  if ($edited eq "") {
    # No edited file to get dimensions from, so default to copying the orig
    # values
    if ($origWidth && $origHeight) {
      # Try using the original's dimensions to determine what the edited
      # dimensions would be.

      if ($origHeight > $origWidth) {
        # Original is already portrait, so use directly. Rotation should be
        # ignored for portrait originals. However, check with the recorded
        # orientation
        if (($orientation eq $PCOM_PORTRAIT)
          # Freeform can be either landscape or portrait, so is valid for a
          # portrait image
          || ($orientation eq $PCOM_FREEFORM)
          || ($orientation eq $PCOM_FREEFORM_P)) {
          $editedWidth = $origWidth;
          $editedHeight = $origHeight;
        } else {
          print "$imageId: portrait original, no edited, recorded as landscape.\n";
        }
      } else {
        # Original is landscape, potentially the rotation applies. Only rotation
        # values of 90 or 270 indicate changing of orientation, all others leave
        # the orientation in place
        if (($rotation eq "90") || ($rotation eq "270")) {
          # The rotation says to rotate the original before rendering. Checking
          # to see that the orientation matches
          if (($orientation eq $PCOM_PORTRAIT)
            # Freeform can be either landscape or portrait, so is valid for a
            # portrait image
            || ($orientation eq $PCOM_FREEFORM)
            || ($orientation eq $PCOM_FREEFORM_P)) {
            $editedWidth = $origHeight;
            $editedHeight = $origWidth;
          } else {
            print "$imageId: has rotation set but orientation is landscape.\n";
          }
        } else {
          # No rotation, so should stay landscape. Checking to see that the
          # orientation matches
          if (($orientation eq $PCOM_LANDSCAPE)
            # Freeform can be either landscape or portrait, so is valid for a
            # landscape image
            || ($orientation eq $PCOM_FREEFORM)
            || ($orientation eq $PCOM_FREEFORM_L)) {
            $editedWidth = $origWidth;
            $editedHeight = $origHeight;
          } else {
            print "$imageId: has rotation set but orientation is landscape.\n";
          }
        }
      }
    } else {
      print "$imageId: no edited file, and no valid orig dimensions.\n";
    }
  } else {
    ($editedWidth, $editedHeight) = pfs_get_file_dimensions($edited);
    if ($editedWidth && $editedHeight) {
      # Check if the orientation matches
      if ($editedHeight > $editedWidth) {
        if (($orientation ne $PCOM_PORTRAIT)
          # Freeform can be either landscape or portrait, so is valid for a
          # portrait image
          && ($orientation ne $PCOM_FREEFORM)
          && ($orientation ne $PCOM_FREEFORM_P)) {
          print "$imageId: edited is portrait but recorded as landscape.\n";
        }
      } elsif ($editedWidth > $editedHeight) {
        if (($orientation ne $PCOM_LANDSCAPE)
          # Freeform can be either landscape or portrait, so is valid for a
          # landscape image
          && ($orientation ne $PCOM_FREEFORM)
          && ($orientation ne $PCOM_FREEFORM_L)) {
          print "$imageId: edited is landscape but recorded as portrait.\n";
        }
      }
    } else {
      print "$imageId: edited dimensions are $editedWidth x $editedHeight\n";
    }
  }
  print "Got file dimensions $editedWidth x $editedHeight for $edited\n" if ($gl_verbose);

  my $origTime = pfs_get_time($orig);
  my $rawTime = $origTime;
  if ($raw ne "") {
    $rawTime = pfs_get_time($raw);
  }
  my $time = $origTime;
  if ($rawTime < $time) {
    $time = $rawTime;
  }
  if ($edited ne "") {
    my $editedTime = pfs_get_time($edited);
    if ($editedTime < $time) {
      $time = $edited;
    }
  }
  if (!$time) {
    print "$imageId: no time found\n";
  }

  my $addedDateTime = format_timestamp($time);
  print "$addedDateTime for this file\n" if ($gl_verbose);

  pdb_set_orig_width($origWidth);
  pdb_set_orig_height($origHeight);
  pdb_set_edited_width($editedWidth);
  pdb_set_edited_height($editedHeight);
  pdb_set_added_date_time($addedDateTime);

  pdb_close_image();
}

sub do_set {
  my $setId = $_[0];

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
}

sub do_year {
  print "Doing a year is not yet implemented.\n";
}

sub do_all {
  my $start = time();
  print "Starting " . format_timestamp($start) . "\n";
  print "-------------------------------------------------------------------\n";

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

  my $origWidth = pdb_get_orig_width($imageId);
  my $origHeight = pdb_get_orig_height($imageId);
  my $editedWidth = pdb_get_edited_width($imageId);
  my $editedHeight = pdb_get_edited_height($imageId);
  my $addedDateTime = pdb_get_added_date_time($imageId);

  if (!defined($origWidth) || $origWidth eq "") {
    print "$imageId: missing orig width\n";
  }
  if (!defined($origHeight) || $origHeight eq "") {
    print "$imageId: missing orig height\n";
  }
  if (!defined($editedWidth) || $editedWidth eq "") {
    print "$imageId: missing edited width\n";
  }
  if (!defined($editedHeight) || $editedHeight eq "") {
    print "$imageId: missing edited height\n";
  }
  if (!defined($addedDateTime) || $addedDateTime eq "") {
    print "$imageId: missing added date time\n";
  }

  pdb_close_image();
}

sub check_all {
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
}
