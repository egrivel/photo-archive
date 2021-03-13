#!/usr/bin/perl

my $script = __FILE__;
my $localdir = ".";
if ($script =~ s/\/[^\/]*$//) {
  $localdir = $script;
}
push @INC, "$localdir/../inc";
push @INC, $localdir;

require photos_util;
require film_process;
# require localsettings;
require process_tools;

put_init();

# For the new tools, it is necessary to log in. Log in as the "process"
# user, who can add photos but not much more
pusr_login("tester", "tester");

my $gl_sourcedir = ".";
my $gl_verbose = 1;
my $gl_testmode = 0;
my $gl_recursive = 0;

# time offset: correction for the clock in the camera being off: the offset
# adjust the time reported by the camera to the actual clock time
my $gl_timeoffset = 0;

# time zone offset: correction for the time zone reported by the camera
my $gl_timezoneoffset = 0;

while (defined($arg = shift)) {
  if ($arg eq "-test") {
    $gl_testmode = 1;
    print "Turning on test mode\n";
  } elsif ($arg eq "-r") {
    $gl_recursive = 1;
  } elsif ($arg eq "-h" || $arg eq "-help" || $arg eq "--help" || $arg eq "-?")
  {
    help();
    exit(0);
  } elsif ($arg eq "-offset") {
    my $value = shift;
    if (!defined($value)) {
      die "Must provide offset\n";
    } elsif ($value =~ /^([+\-])(\d\d?):(\d\d):(\d\d)$/) {
      my $sign = $1;
      $gl_timeoffset = 3600 * $2 + 60 * $3 + $4;
      if ($sign eq "-") {
        $gl_timeoffset = 0 - $gl_timeoffset;
      }
      print "Offset becomes $gl_timeoffset seconds\n";
    } else {
      die "Offset must be in [+-]hh:mm:ss format\n";
    }
  } elsif ($arg eq "-tz-offset") {
    my $value = shift;
    if (!defined($value)) {
      die "Must provide tz-offset\n";
    } elsif ($value =~ /^([+\-])(\d\d?):(\d\d)$/) {
      my $sign = $1;
      $gl_timezoneoffset = 60 * $2 + $3;
      if ($sign eq "-") {
        $gl_timezoneoffset = 0 - $gl_timezoneoffset;
      }
      print "Time zone offset becomes $gl_timezoneoffset minutes\n";
    } else {
      die "Time zone offset must be in [+-]hh:mm format\n";
    }
  } elsif (-d $arg) {
    $gl_sourcedir = $arg;
    $gl_sourcedir =~ s/\/$//;
    print "Set source directory to $arg\n";
  } else {
    die "Unrecognized argument $arg\n";
  }
}

process($gl_sourcedir);

sub process {
  my $dir = $_[0];

  opendir(DIR, $dir)
    || die "Cannot scan source directory '$dir'\n";
  my %dirlist = ();
  my %neflist = ();
  my %editedlist = ();
  my @subdirs = ();
  my $subdir_count = 0;

  my $fname;
  while (defined($fname = readdir(DIR))) {
    next if ($fname =~ /^\./);
    if (-d "$dir/$fname") {
      if ($gl_recursive) {
        $subdirs[$subdir_count++] = "$dir/$fname";
      }
      next;
    }
    if ($fname =~ /^(.+?)[_-]edited\.(jpe?g)$/) {
      # Edited file; if the corresponding non-edited exists, only use that
      my $basename = $1;
      my $suffix = $2;
      if (-f "$dir/$basename.$suffix") {
        $editedlist{lc($fname)} = $fname;
        # do not process the edited file separately
      } else {
        # Only edited file, no original, so process the edited file
        $dirlist{$fname}++;
      }
    } elsif ($fname =~ /^(.+?)\.jpe?g$/i) {
      $dirlist{$fname}++;
    } elsif ($fname =~ /^(.+?)\.png$/i) {
      $dirlist{$fname}++;
    } elsif ($fname =~ /^(.+?)\.gif$/i) {
      $dirlist{$fname}++;
    } elsif ($fname =~ /^(.+?)\.nef$/i) {
      my $basename = $1;
      if ( (-f "$dir/$basename.jpg")
        || (-f "$dir/$basename.JPG")) {
        # Corresponding JPEG file also exists; add NEF to the %neflist
        $neflist{lc($fname)} = $fname;
      } else {
        # No corresponding JPEG file, so add NEF to the files to be
        # processed
        $dirlist{$fname}++;
      }
    } elsif ($fname =~ /^(.+?)\.cr2$/i) {
      my $basename = $1;
      if ( (-f "$dir/$basename.jpg")
        || (-f "$dir/$basename.JPG")) {
        # Corresponding JPEG file also exists; add CR2 to the %neflist
        $neflist{lc($fname)} = $fname;
      } else {
        # No corresponding JPEG file, so add CR2 to the files to be
        # processed
        $dirlist{$fname}++;
      }
    } elsif (($fname =~ /^(.+?)\.mov$/i) || ($fname =~ /^(.+?)\.mp4$/i)) {
      # copy over movies (from D750 or android device)
      $dirlist{$fname}++;
    } else {
      # ignore remaining files
    }
  }
  closedir(DIR);
  foreach $key (sort (keys %dirlist)) {
    process_photo($dir, $key);
  }

  my $i;
  for ($i = 0; $i < $subdir_count; $i++) {
    process($subdirs[$i]);
  }
}

sub help {
  print "Usage:\n";
  print "  process_digital [options] [directory]\n";
  print "Processes all the photos for inclusion into the photo archive.\n";
  print "If no directory is given, the current directory is processed.\n";
  print "Options:\n";
  print " -r: recursive (also process all subdirectorys of [directory]\n";
  print " -offset <time offset>: offset the calculated time\n";
  print "    Time offset must be in [+-]hh:mm:ss format\n";
  print " -tz-offset <offset>: time zone offset\n";
  print "    Time zone offset must be in [+-]hh:mm format\n";
  print "";
}

sub get_shuttercount {
  my $imageid = $_[0];
  my $fname = pfs_get_raw_location($imageid);
  if ($fname eq "") {
    $fname = pfs_get_orig_location($imageid);
  }

  if ($fname eq "") {
    return 0;
  }
  open(FILE, "exiftool \"$fname\"|") || die "Cannot look at '$fname'\n";
  while (<FILE>) {
    chomp();
    if (/^(.*?)\s*:\s*(.*?)\s*$/s) {
      my $label = $1;
      my $value = $2;
      if ($label eq "Shutter Count") {
        close FILE;
        return $value;
      }
    }
  }
  close FILE;
  return 0;
}

sub last_day_of_month {
  my $year = $_[0];
  my $month = $_[1];
  if ($month == 2) {
    if (4 * int($year / 4) == $year) {
      return 29;
    } else {
      return 28;
    }
  } elsif (($month == 4) || ($month == 6) || ($month == 9) || ($month == 11)) {
    return 30;
  } else {
    return 31;
  }
}

sub get_id_from_file_name {
  my $fname = $_[0];

  # remove suffix
  $fname =~ /\.\w+$/;
  if ($fname =~
    /^(.*?)(20\d\d[_-]?\d\d[_-]?\d\d[_-]?\d\d[_-]?\d\d[_-]?\d\d)(.*)$/) {
    # there is something that looks like a date-time in the middle; make sure
    # it's not preceded or followed by digits;
    my $part1 = $1;
    my $part2 = $2;
    my $part3 = $3;
    if (!($part1 =~ /\d$/) && !($part3 =~ /^\d/)) {
      # Seems to be valid
      $part2 =~ s/\D//g;
      if ($part2 =~ /^(\d\d\d\d\d\d\d\d)(\d\d\d\d\d\d)$/) {
        # found a valid ID
        return "$1-$2";
      }
    }
  }

  if ($fname =~ /^(.*?)(20\d\d[_-]?\d\d[_-]?\d\d)(.*)$/) {
    # there is something that looks like a date-time in the middle; make sure
    # it's not preceded or followed by digits;
    my $part1 = $1;
    my $part2 = $2;
    my $part3 = $3;
    if (!($part1 =~ /\d$/) && !($part3 =~ /^\d/)) {
      # Seems to be valid
      $part2 =~ s/\D//g;
      if ($part2 =~ /^(\d\d\d\d\d\d\d\d)$/) {
        # found a valid ID
        return "$1-000000";
      }
    }
  }

  return "";
}

sub get_indexed_image {
  my $targetfile = $_[0];
  my $index = $_[1];

  if ($targetfile =~ s/000000$//) {
    while (length($index) < 6) {
      $index = "0$index";
    }
    return "$targetfile$index";
  }
  return $targetfile . chr($index + 96);
}

sub process_photo {
  my $dir = $_[0];
  my $fname = $_[1];

  my %attrib = ();
  my $setID = "";
  my $targetfile = "";
  my $setID2 = "";
  my $targetfile2 = "";
  my $rotate = "";
  my $thmbscale = "-width 150 -height 100";
  my $newrotate = "";
  my $newsize = "900x600";
  my $newresize = "904x600";
  my $newer_rotate = "0";
  my $do_portrait = 0;
  my $latlong = "";
  my $timezone = "+00:00";
  my $dst = "No";
  my $shuttercount = 0;
  my $phoneportrait = 0;
  my $is_mov = 0;

  if ($fname =~ /\.mov$/i || $fname =~ /\.mp4$/i || $fname =~ /\.gif$/i) {
    $is_mov = 1;
  }
  my $is_kids = 0;
  if ($fname =~ /\.cr2$/i) {
    $is_kids = 1;
  }
  my $is_freeform = 0;

  my $edited_file = "";
  if ($fname =~ /^(.*?)(\.jpe?g)$/) {
    my $part1 = $1;
    my $part2 = $2;
    if (-f "$dir/${part1}-edited$part2") {
      $edited_file = "${part1}-edited$part2";
    } elsif (-f "$dir/${part1}_edited$part2") {
      $edited_file = "${part1}_edited$part2";
    }
  }

  print "Process $dir/$fname\n" if ($gl_verbose);
  open(FILE, "exiftool \"$dir/$fname\"|")
    || die "Cannot process '$dir/$fname'\n";
  while (<FILE>) {
    chomp();
    if (/^(.*?)\s*:\s*(.*?)\s*$/s) {
      my $label = $1;
      my $value = $2;
      $attrib{$label} = $value;
      if ($label eq "Create Date") {
        if ($value =~ /(\d\d\d\d):(\d\d):(\d\d) (\d\d):(\d\d):(\d\d)/) {
          $setID = "$1$2$3";
          $targetfile = "$1$2$3-$4$5$6";
        }
      } elsif (($label eq "Date/Time")
        || ($label eq "Date/Time Original")) {
        # Use the Date/Time only if there is no Create Date. In case
        # the photo is modified in-camera, the Date/Time will be the
        # timestamp for the original photo (which would make this a
        # duplicate), but the Create Date will be the real timestamp
        # for this photo.
        if ($value =~ /(\d\d\d\d):(\d\d):(\d\d) (\d\d):(\d\d):(\d\d)/) {
          $setID2 = "$1$2$3";
          $targetfile2 = "$1$2$3-$4$5$6";
        }
      } elsif ($label eq "Orientation") {
        if ( ($value eq "rotate 90")
          || ($value eq "Rotate 90 CW")) {
          $rotate = " | pnmrotate -90 ";
          $newrotate = "-rotate 90";
          $newsize = "600x900";
          $newresize = "600x904";
          $thmbscale = "-width 100 -height 150";
          $newer_rotate = "90";
          $do_portrait = 1;
        } elsif (($value eq "rotate 270")
          || ($value eq "Rotate 270 CW")) {
          $rotate = " | pnmrotate 90 ";
          $newrotate = "-rotate -90";
          $newsize = "600x900";
          $newresize = "600x904";
          $thmbscale = "-width 100 -height 150";
          $newer_rotate = "-90";
          $do_portrait = 1;
        } elsif ($value eq "Horizontal (normal)"
          || $value eq "Unknown (0)") {
          # don't rotate
        } elsif ($value eq "Rotate 180") {
          # rotate 180, doesn't change width or height
          $rotate = " | pnmrotate 180 ";
          $newrotate = "-rotate -180";
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
      } elsif ($label eq "Shutter Count") {
        $shuttercount = $value;
      } elsif ($label eq "Image Size") {
        if ($value =~ /(\d+)x(\d+)/) {
          my $width = $1;
          my $height = $2;
          if ($height > $width) {
            # Phone images can be taller than wide
            $phoneportrait = 1;
          }
          if (($width > 2 * $height) || ($height > 2 * $width)) {
            $is_freeform = true;
          }
        }
      }
    } elsif (/./) {
      print "$dir/$fname: unknown line '$_'\n";
    }
  }
  close FILE;

  if ($setID eq "00000000") {
    # Not a valid set ID
    $setID = "";
    $targetfile = "";
  }

  if ($phoneportrait && !$do_portrait) {
    # Images from a phone, in portrait mode, are already rotated, so
    # they don't show up when looking for rotation or orientation
    # Recognize them as portrait photos after all
    $newsize = "600x900";
    $newresize = "600x904";
    $thmbscale = "-width 100 -height 150";
    $do_portrait = 1;
  }

  if ($setID eq "") {
    $setID = $setID2;
  }
  if ($targetfile eq "") {
    $targetfile = $targetfile2;
  }

  if ($fname =~ /^VID_(\d\d\d\d\d\d\d\d)_(\d\d\d\d\d\d)\.mp4$/) {
    # Video from Android phone, use timestamp from filename
    $setID = $1;
    $targetfile = "$1-$2";
  }

  if ($setID eq "") {
    # No set ID found, so try getting it from the filename
    # Think this applies to all files, not just images
    # if (($fname =~ /\.jpe?g$/i) || ($fname =~ /\.png$/i)) {
    my $id = get_id_from_file_name($fname);
    if ($id ne "") {
      if ($id =~ /^(\d\d\d\d\d\d\d\d)/) {
        $setID = $1;
        $targetfile = $id;
      }
    }
    # }
  }

  if ($setID eq "") {
    # Still no set ID found based on the filename, try the
    # directory
    my $temp = $dir;
    $temp =~ s/\/$//;
    $temp =~ s/^.*\///;
    my $id = get_id_from_file_name($temp);
    if ($id ne "") {
      if ($id =~ /^(\d\d\d\d\d\d\d\d)/) {
        $setID = $1;
        $targetfile = $id;
      }
    }
  }

  if ($gl_timeoffset) {
    if ($targetfile =~ /^(\d\d\d\d)(\d\d)(\d\d)-(\d\d)(\d\d)(\d\d)(\w?)$/) {
      my $year = $1;
      my $month = $2;
      my $day = $3;
      my $seconds = 3600 * $4 + 60 * $5 + $6;
      my $suffix = $7;
      $seconds += $gl_timeoffset;
      my $minutes = int($seconds / 60);
      $seconds -= 60 * $minutes;
      my $hours = int($minutes / 60);
      $minutes -= 60 * $hours;

      while ($hours < 0) {
        $hours += 24;
        $day--;
        if ($day < 1) {
          $month--;
          if ($month < 1) {
            $year--;
            $month = 12;
          }
          $day = last_day_of_month($year, $month);
        }
      }
      while ($hours > 23) {
        $hours -= 24;
        $day++;
        if ($day > last_day_of_month($year, $month)) {
          $day = 1;
          $month++;
          if ($month > 12) {
            $year++;
            $month = 1;
          }
        }
      }
      $month = '0' . int($month) if ($month < 10);
      $day = '0' . int($day) if ($day < 10);
      $hours = '0' . $hours if ($hours < 10);
      $minutes = '0' . $minutes if ($minutes < 10);
      $seconds = '0' . $seconds if ($seconds < 10);
      $targetfile = "$year$month$day-$hours$minutes$seconds$suffix";
    } else {
      print "Got offset but don't recognize target file $targetfile, skip\n";
      return;
    }
  }

  if ($gl_timezoneoffset) {
    if ($timezone =~ /^([+\-]?\d\d):(\d\d)$/) {
      my $minutes = 60 * $1 + $2;
      $minutes += $gl_timezoneoffset;
      my $sign = '+';
      if ($minutes < 0) {
        $sign = '-';
        $minutes = 0 - $minutes;
      }
      my $hours = int($minutes / 60);
      $minutes -= 60 * $hours;
      $hours = '0' . int($hours) if ($hours < 10);
      $minutes = '0' . int($minutes) if ($minutes < 10);
      $timezone = $sign . $hours . ':' . $minutes;
    } else {
      print
        "Got timezone offset but don't recognize time zone '$timezone', skip\n";
      return;
    }
  }

  if (($setID eq "") || ($targetfile eq "")) {
    print "No timestamp found in '$dir/$fname'\n";
  } else {
    # Determine the image ID
    my $set_directory = pfs_get_set_basedir($setID);
    $imageid = $targetfile;
    if (pdb_image_exists($imageid)) {
      if ( ($shuttercount > 0)
        && ($shuttercount == get_shuttercount($imageid))
        && !$gl_testmode) {
        # duplicate!
        if ($fname =~ /\.nef$/i) {
          move_file("$dir/$fname", "$set_directory/tif/$imageid.nef");
        } else {
          print "File $fname is duplicate but not nef - ignored!\n";
        }
        return;
      }
      # Image exists; add suffix
      $suffixnr = 1;
      $imageid = get_indexed_image($targetfile, $suffixnr);
      while (pdb_image_exists($imageid)) {
        if ( ($shuttercount > 0)
          && ($shuttercount == get_shuttercount($imageid))
          && !$gl_testmode) {
          # duplicate!
          if ($fname =~ /\.nef$/i) {
            move_file("$dir/$fname", "$set_directory/tif/$imageid.nef");
          } else {
            print "File $fname is duplicate but not nef - ignored!\n";
          }
          return;
        }
        $suffixnr++;
        $imageid = get_indexed_image($targetfile, $suffixnr);
      }
    }
    print "Determined image ID to be $imageid\n" if ($gl_verbose);

    if ($gl_testmode) {
      my $sortid = pdb_create_sortid($imageid, $timezone, $dst);
      print "Image $fname: image ID $imageid --> sort ID $sortid\n";
      return;
    }

    # Create the directories
    create_directory($set_directory);
    create_directory("$set_directory/tif");
    create_directory("$set_directory/thumbnails");
    create_directory("$set_directory/normal");
    create_directory("$set_directory/large");
    create_directory("$set_directory/edited");
    create_directory("$set_directory/custom");

    set_database_info(
      $imageid, $do_portrait, $newer_rotate, $latlong, $timezone,
      $dst, $is_mov, $is_kids, $is_freeform
    );

    # Move over the files we are processing

    if ($fname =~ /\.jpe?g$/i) {
      move_file("$dir/$fname", "$set_directory/tif/$imageid.jpg");
      # If we also have a NEF file, move that as well
      my $nefname = lc($fname);
      $nefname =~ s/\.jpg$/\.nef/;
      if (defined($neflist{$nefname})) {
        # Got a ".nef" file (Nikon RAW format), copy that too
        move_file("$dir/$neflist{$nefname}", "$set_directory/tif/$imageid.nef");
      }
    } elsif ($fname =~ /\.png$/i) {
      # Get the JPG first
      system("convert \"$dir/$fname\" \"$set_directory/tif/$imageid.jpg\"");
      move_file("$dir/$fname", "$set_directory/tif/$imageid.png");
    } elsif ($fname =~ /\.nef$/i) {
      # Extract the JPG first
      system(
        "exiftool -b -JpgFromRaw \"$dir/$fname\" > \"$set_directory/tif/$imageid.jpg\""
      );
      # Add all the EXIF information to the JPG file
      system(
        "exiftool -TagsFromFile \"$dir/$fname\" -q -q -SerialNumber=0 -overwrite_original \"$set_directory/tif/$imageid.jpg\""
      );
      move_file("$dir/$fname", "$set_directory/tif/$imageid.nef");
    } elsif ($fname =~ /\.cr2$/i) {
      # Extract the JPG first
      system(
        "exiftool -b -PreviewImage \"$dir/$fname\" > \"$set_directory/tif/$imageid.jpg\""
      );
      # Add all the EXIF information to the JPG file
      system(
        "exiftool -TagsFromFile \"$dir/$fname\" -q -q -SerialNumber=0 -overwrite_original \"$set_directory/tif/$imageid.jpg\""
      );
      move_file("$dir/$fname", "$set_directory/tif/$imageid.cr2");
    } elsif ($fname =~ /\.mov$/i || $fname =~ /\.mp4$/i) {
      # Extract a JPG thumbnail
      system(
        "ffmpeg -i \"$dir/$fname\" -vframes 1 -ss 1 \"$set_directory/tif/$imageid.jpg\""
      );
      # Add all the EXIF information to the JPG file
      #system("exiftool -TagsFromFile $dir/$fname -q -q -SerialNumber=0 -overwrite_original $set_directory/tif/$imageid.jpg");
      if ($fname =~ /\.mov$/i) {
        move_file("$dir/$fname", "$set_directory/tif/$imageid.mov");
      } else {
        move_file("$dir/$fname", "$set_directory/tif/$imageid.mp4");
      }
    } elsif ($fname =~ /\.gif$/i) {
      # Convert GIF to an MP4 file
      system("ffmpeg -i \"$dir/$fname\" \"$set_directory/tif/$imageid.mp4\"");
      # Extract JPG
      system(
        "ffmpeg -i \"$dir/$fname\" -vframes 1 -ss 1 \"$set_directory/tif/$imageid.jpg\""
      );
      # Move the GIF to the target
      move_file("$dir/$fname", "$set_directory/tif/$imageid.gif");
    } else {
      print "Don't know what to do with file $fname\n";
    }
    if ($edited_file ne "") {
      move_file("$dir/$edited_file", "$set_directory/edited/$imageid.jpg");
    }
  }
  print "\n" if ($gl_verbose);
}

sub create_directory {
  my $dirname = $_[0];

  if (!-d $dirname) {
    mkdir($dirname);
    system("chmod 777 \"$dirname\"");
  }
}

sub move_file {
  my $srcfile = $_[0];
  my $dstfile = $_[1];

  if (!-f $srcfile) {
    warn "Move file '$srcfile' to '$dstfile': source does not exist\n";
    return;
  }
  if (-f $dstfile) {
    warn "Move file '$srcfile' to '$dstfile': destination already exists\n";
    return;
  }
  system("mv \"$srcfile\" \"$dstfile\"");
  system("chmod 444 \"$dstfile\"");
}
