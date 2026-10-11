#!/usr/bin/perl

my $script = __FILE__;
my $localdir = ".";
if ($script =~ s/\/[^\/]*$//) {
  $localdir = $script;
}
push @INC, "$localdir/../inc";
push @INC, $localdir;

require photos_util;
require process_tools;

put_init();

my $gl_force = 0;

my $arg = shift;
my $count = 0;
while (defined($arg)) {
  if ($arg eq "-help") {
    help();
    exit(0);
  } elsif ($arg eq "-force") {
    $gl_force = 1;
  } else {
    # Not a known argument, so it should be the desired set ID
    my $setdir = pfs_get_set_basedir($arg);
    if (-d $setdir) {
      # This looks like a set; need at least the 'tif' directory
      if (-d "$setdir/tif") {
        $count += process($arg);
      } else {
        warn "$arg: no 'tif' directory found for $arg, skip\n";
      }
    } else {
      warn "$arg: no directory '$setdir' exists, skip\n";
    }
    $count++;
  }
  $arg = shift;
}

if (!$count) {
  warn "Must specify the set ID to add.\n";
  help();
}
exit(0);

sub help {
  print "Add a set to the photo archive. Assume the set’s photos have\n";
  print "already be placed in the appopriate 'tif' directory.\n";
  print "\n";
  print "Usage:\n";
  print "  add_set.pl <setId>\n";
}

sub process {
  my $setId = $_[0];

  my $setdir = pfs_get_set_basedir($setId);
  opendir(DIR, "$setdir/tif") || die "Cannot open '$setdir/tif'\n";
  my $count = 0;
  my $fname;
  while (defined($fname = readdir(DIR))) {
    next if ($fname =~ /^\./);
    if ($fname =~ /^(($setId).+?)\.(jpg|jpeg|tif|nef|dng|mov|mp4|gif|cr2)$/) {
      # This is a potential file
      my $imageId = $1;
      if ($fname =~ /\.(tif|nef|dng|cr2)$/) {
        my $jpegname = $fname;
        $jpegname =~ s/\.(tif|nef|dng|cr2)$/.jpg/;
        if (-f "$setdir/tif/$jpegname") {
          # There is also a .jpg version of the file. Use the .jpg version
          # to add the photo (the .jpg version should have the correct
          # aspect ratio, the .tif etc. may not)
          next;
        }
      }
      if (pdb_image_exists($imageId)) {
        warn("Image $imageId already exists, skipping\n");
      } else {
        if (-f "$setdir/edited/$fname") {
          # A version of the image already pre-processed
          add_image($setId, $imageId, "$setdir/edited/$fname");
        } else {
          add_image($setId, $imageId, "$setdir/tif/$fname");
        }
        $count++;
      }
    } else {
      warn("Unrecognized file '$fname' was skipped\n");
    }
  }
  closedir(DIR);
  if (!$count) {
    warn("No files processed....?\n");
  }
  return $count;
}

sub compute_values {
  my $imageId = $_[0];

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

  my $editedWidth = "";
  my $editedHeight = "";
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
  if ($edited ne "") {
    print "Got edited dimensions $editedWidth x $editedHeight for $edited\n" if ($gl_verbose);
  } else {
    print "No edited file\n";
  }

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
  print "Got added date-time $addedDateTime for this file\n" if ($gl_verbose);

  return ($origWidth, $origHeight, $editedWidth, $editedHeight, $addedDateTime);
}

sub add_image {
  my $setId = $_[0];
  my $imageId = $_[1];
  my $fname = $_[2];

  my $do_portrait = 0;
  my $newer_rotate = "0";
  my $latlong = "";
  my $timezone = "+00:00";
  my $dst = "No";
  my $is_mov = 0;
  my $is_kids = 0;
  my $is_freeform = 0;

  if ($fname =~ /\.mov$/i || $fname =~ /\.mp4$/i || $fname =~ /\.gif$/i) {
    $is_mov = 1;
  }
  if ($fname =~ /\.cr2$/i) {
    $is_kids = 1;
  }

  open(FILE, "exiftool -api largefilesupport=1 \"$dir/$fname\"|")
    || die "Cannot process '$dir/$fname'\n";
  while (<FILE>) {
    chomp();
    if (/^(.*?)\s*:\s*(.*?)\s*$/s) {
      my $label = $1;
      my $value = $2;
      $attrib{$label} = $value;
      if ($label eq "Orientation") {
        if ( ($value eq "rotate 90")
          || ($value eq "Rotate 90 CW")) {
          $newer_rotate = "90";
          print "$label: $value\n";
        } elsif (($value eq "rotate 270")
          || ($value eq "Rotate 270 CW")) {
          $newer_rotate = "-90";
          print "$label: $value\n";
        } elsif ($value eq "Horizontal (normal)"
          || $value eq "Unknown (0)") {
          # don't rotate
        } elsif ($value eq "Rotate 180") {
          # rotate 180, doesn't change width or height
        } else {
          print "Unknown rotation value '$value'\n";
          die "Stopping for now\n";
        }
      } elsif ($label eq "GPS Position") {
        $latlong = $value;
      } elsif ($label eq "Daylight Savings") {
        $dst = $value;
        if ($dst eq "Off") {
          $dst = "No";
        } elsif ($dst eq "On") {
          $dst = "Yes";
        }
      } elsif (($label eq "Timezone") || ($label eq "Time Zone")) {
        $timezone = $value;
      } elsif ($label eq "Image Size") {
        if ($value =~ /(\d+)x(\d+)/) {
          my $width = $1;
          my $height = $2;
          if ($height > $width) {
            # Phone images can be taller than wide
            $do_portrait = 1;
          }
          if (($width > 1.8 * $height) || ($height > 1.8 * $width)) {
            # extra skinny
            $is_freeform = true;
          } elsif (($width < 1.3 * $height) && ($height < 1.3 * $width)) {
            # more squarish
            $is_freeform = true;
          }
        }
      }
    } elsif (/./) {
      print "$dir/$fname: unknown line '$_'\n";
    }
  }
  close FILE;

  my ($origWidth, $origHeight, $editedWidth, $editedHeight, $addedDateTime)
    = compute_values($imageid);

  set_database_info(
    $imageId, $do_portrait, $newer_rotate, $latlong, $timezone,
    $dst, $is_mov, $is_kids, $is_freeform, $gl_force,
    $origWidth, $origHeight, $editedWidth, $editedHeight,
    $addedDateTime
  );
}
