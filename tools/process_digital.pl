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

my $dir = "";
my $fname = "";

put_init();

# For the new tools, it is necessary to log in. Log in as the "process"
# user, who can add photos but not much more
pusr_login("tester", "tester");

my $gl_sourcedir = ".";
my $gl_verbose = 1;
my $gl_testmode = 0;
my $gl_silent = 0;    # silent + testmode doesn't write out commands
my $gl_recursive = 0;
my $gl_phone = 0;

# time offset: correction for the clock in the camera being off: the offset
# adjust the time reported by the camera to the actual clock time
my $gl_timeoffset = 0;

# time zone offset: correction for the time zone reported by the camera
my $gl_timezoneoffset = 0;

# video time zone: hard-coded time zone for Pixel 8 video files, if not EST/EDT
my $gl_video_time_zone = "";

while (defined($arg = shift)) {
  if ($arg eq "-test" || $arg eq "--test") {
    $gl_testmode = 1;
    print "Turning on test mode\n" if (!$gl_silent);
  } elsif ($arg eq "-silent" || $arg eq "--silent") {
    $gl_silent = 1;
    $gl_verbose = 0;
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
  } elsif ($arg eq "-video-time-zone") {
    my $value = shift;
    if (!defined($value)) {
      die "Must provide video time zone\n";
    } elsif ($value =~ /^([+\-])(\d\d?):(\d\d)$/) {
      $gl_video_time_zone = $value;
      print "Video time zone becomes $gl_video_time_zone\n";
    } else {
      die "Video time zone must be in [+-]hh:mm format\n";
    }
  } elsif ($arg eq "-phone") {
    $gl_phone = 1;
  } elsif ($arg eq "-verbose" || $arg eq "--verbose") {
    $gl_verbose = 1;
  } elsif (-d $arg) {
    $gl_sourcedir = $arg;
    $gl_sourcedir =~ s/\/$//;
    print "Set source directory to $arg\n";
  } else {
    die "Unrecognized argument $arg\n";
  }
}

process($gl_sourcedir);
exit(0);

# --------------------------------------------------------------------------
# Only subroutines below
# --------------------------------------------------------------------------

sub get_last_day {
  my $month = $_[0];

  my $last_day = 31;
  if ($month eq "02") {
    $last_day = 28;
  } elsif ($month eq "04"
    || $month eq "06"
    || $month eq "09"
    || $month eq "11") {
    $last_day = 30;
  }

  return $last_day;
}

sub process {
  my $dir = $_[0];

  if ($gl_testmode && -f "$dir/index.txt") {
    # process the files listed in index.txt
    my $fname = "";
    my %ids = ();
    my %sortids = ();
    open(FILE, "<$dir/index.txt");
    while (<FILE>) {
      next if (/^\s*#/);
      next if (/^\s*\/\//);
      if (/^file\s+=\s+(.*?)\s*$/) {
        $fname = $1;
      } elsif (/^id\s+=\s+(.*?)\s*$/) {
        my $id = $1;
        if ($fname eq "") {
          die "No file for id $id in $dir/index.txt\n";
        }
        $ids{$fname} = $id;
      } elsif (/^sortid\s+=\s+(.*?)\s*$/) {
        my $sortid = $1;
        if ($fname eq "") {
          die "No file for sortid $sortid in $dir/index.txt\n";
        }
        $sortids{$fname} = $sortid;
      }
    }
    foreach $key (keys %ids) {
      process_photo($dir, $key, $ids{$key}, $sortids{$key});
    }
    return;
  }

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
    } elsif ($fname =~ /^(.+?)\.dng$/i) {
      print "Got $fname\n" if ($gl_testmode);
      my $basename = $1;
      if ( (-f "$dir/$basename.jpg")
        || (-f "$dir/$basename.JPG")) {
        # Corresponding JPEG file also exists; add NEF to the %neflist
        print "Add $fname to neflist\n" if ($gl_testmode);
        $neflist{lc($fname)} = $fname;
      } else {
        # No corresponding JPEG file, so add NEF to the files to be
        # processed
        print "Add to dirlist\n" if ($gl_testmode);
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
  my $key;
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
  print " -phone: recognize photos and videos from different phones and\n";
  print "    apply time zone offsets automatically.\n";
  print " -test: run in test mode.\n";
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

sub get_exif_data {
  my $dir = $_[0];
  my $fname = $_[1];

  my %data;
  $data{"_dir"} = $dir;
  $data{"_fname"} = $fname;

  open(FILE, "exiftool -api largefilesupport=1 \"$dir/$fname\"|")
    || die "Cannot process '$dir/$fname'\n";
  while (<FILE>) {
    chomp();
    if (/^(.*?)\s*:\s*(.*?)\s*$/s) {
      my $label = $1;
      my $value = $2;
      $data{$label} = $value;
    } elsif (/./) {
      print "$dir/$fname: unknown line '$_'\n";
    }
  }
  close FILE;

  return \%data;
}

sub get_type {
  my $data_ref = $_[0];

  if (defined(%$data_ref{"Camera Model Name"})
    && (%$data_ref{"Camera Model Name"} eq "Pixel 3")) {
    return "nicoline photo";
  }
  return "unknown";
}

sub process_photo {
  my $dir = $_[0];
  my $fname = $_[1];
  my $expect_id = $_[2];
  my $expect_sortid = $_[3];

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
  my $timezone_found = 0;
  my $dst = "No";
  my $shuttercount = 0;
  my $phoneportrait = 0;
  my $is_mov = 0;

  if ($gl_testmode) {
    print "Process photo '$fname'\n";
    if (defined($expect_sortid)) {
      # $gl_verbose = 0;
      # $gl_silent = 1;
    }
  }

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

  my $camera_model = "";

  print "Process $dir/$fname\n" if ($gl_verbose);
  open(FILE, "exiftool -api largefilesupport=1 \"$dir/$fname\"|")
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
        # Normalize on No/Yes
        if ($dst eq "Off") {
          $dst = "No";
        } elsif ($dst eq "On") {
          $dst = "Yes";
        }
      } elsif (($label eq "Timezone") || ($label eq "Time Zone")) {
        $timezone = $value;
        $timezone_found = 1;
      } elsif ($label eq "Offset Time") {
        # On Pixel, offset time includes DST adjustment
        $timezone = $value;
        $timezone_found = 1;
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
      } elsif (($label eq "Camera Model Name")
        || ($label eq "Android Model")) {
        # This is used to recognized images and videos from Eric's and
        # Nicoline's phone
        $camera_model = $value;
      }
    } elsif (/./) {
      print "$dir/$fname: unknown line '$_'\n";
    }
  }
  close FILE;

  if ($gl_testmode && $gl_verbose) {
    print "time zone = $timezone; time zone found = $timezone_found; ";
    print "dst = $dst\n";
    print "latlong = $latlong\n";
    print "camera model = $camera_model\n";
  }

  if ($setID eq "00000000") {
    # Not a valid set ID
    $setID = "";
    $targetfile = "";
  }

  print "setID=$setID, targetfile=$targetfile\n";

  # Files starting with PXL come from a Pixel phone
  # Note: Pixel phones do not store the $dst, so that is "No", but since the
  # time zone (if stored) already includes any DST offset, that's not a problem.
  if ($fname =~ /^PXL_/ && !$timezone_found) {
    print "No time zone, pixel camera, ID is $targetfile\n" if ($gl_verbose);
    if ($fname =~ /^PXL_(\d\d\d\d)(\d\d)(\d\d)_(\d\d)(\d\d)(\d\d)\d\d\d\.\w+$/)
    {
      my $year = $1;
      my $month = $2;
      my $day = $3;
      my $hour = $4;
      my $min = $5;
      my $sec = $6;

      # Pixel stores videos in a file with a UTC file name, but does not store
      # the time zone info in the EXIF. So use the `date` command to convert
      # the UTC date-time in a local one if no video time zone is provided
      print "Google Pixel video without time zone. ";
      if ($gl_video_time_zone ne "") {
        print "Use hard-coded time zone $gl_video_time_zone\n";
        $timezone = $gl_video_time_zone;
        $timezone_found = 0;
        if ($gl_video_time_zone =~ /^([+-]?)(\d\d):(\d\d)$/) {
          my $sign = $1;
          my $h = $2;
          my $m = $3;
          if ($sign eq "-") {
            $hour -= $h;
            $min -= $m;
          } else {
            $hour += $h;
            $min += $m;
          }
          if ($min >= 60) {
            $hour++;
            $min -= 60;
          } elsif ($min < 0) {
            $hour--;
            $min += 60;
          }
          if ($hour >= 24) {
            $day++;
            $hour -= 24;
          } elsif ($hour < 0) {
            $day--;
            $hour += 24;
          }
          if ($day < 1) {
            $month--;
            if ($month < 1) {
              $year--;
              $month += 12;
            }
            $day += get_last_day($month);
          } elsif ($day > get_last_day($month)) {
            $day -= get_last_day($month);
            $month++;
            if ($month > 12) {
              $year++;
              $month -= 12;
            }
          }
          if ($month < 10) {
            $month = "0" . int($month);
          }
          if ($day < 10) {
            $day = "0" . int($day);
          }
          if ($hour < 10) {
            $hour = "0" . int($hour);
          }
          if ($min < 10) {
            $min = "0" . int($min);
          }
        }
        $setid = "$year$month$day";
        $targetfile = "$year$month$day-$hour$min$sec";
        # The time zone above already takes DST offset into account
        $dst = "No";
      } else {
        $testdate = "$year-$month-${day}T$hour:$min:${sec}Z";
        open(PIPE, "date \"+\%Y\%m\%d-\%H\%M\%S \%Z\" --date=$testdate|")
          || die "Cannot determine time zone for $testdate\n";
        print "Get time zone from date #1\n" if ($gl_testmode);
        while (<PIPE>) {
          # This should just be a single line, so process here
          chomp();
          if (/^((\d\d\d\d\d\d\d\d)-\d\d\d\d\d\d) (\w\w\w)$/) {
            my $date_imageid = $1;
            my $date_setid = $2;
            my $date_timezone = $3;
            print "Got image ID $date_imageid, time zone $date_timezone\n"
              if ($gl_verbose);
            if ($date_timezone eq "EST") {
              $timezone = "-05:00";
              $timezone_found = 1;
              $setID = $date_setid;
              $targetfile = $date_imageid;
              $dst = "No";
            } elsif ($date_timezone eq "EDT") {
              $timezone = "-04:00";
              $timezone_found = 0;
              $setid = $date_setid;
              $targetfile = $date_imageid;
              # The time zone above already takes EDT offset into account
              $dst = "No";
            } else {
              print "Unknown time zone for $testdate\n";
            }
          }
        }
        close(PIPE);
      }
    }
  }

  if (!$timezone_found && $fname =~ /^WhatsApp/) {
    print "No time zone, WhatsApp photo or video\n" if ($gl_verbose);
    if ($fname =~
      /^WhatsApp \w+ (\d\d\d\d)-(\d\d)-(\d\d) at (\d\d)\.(\d\d)\.(\d\d)/) {
      # WhatsApp has virtually no EXIF info, but uses the _post_ timestamp
      # (local time) in the file name. So use the `date` command to figure out
      # the time zone for the post timestamp
      my $fname_timestamp = "$1$2$3-$4$5$6";
      my $fname_setId = "$1$2$3";
      $testdate = "$1-$2-${3}T$4:$5:$6";
      open(PIPE, "date \"+\%Y\%m\%d-\%H\%M\%S \%Z\" --date=$testdate|")
        || die "Cannot determine time zone for $testdate\n";
      print "Get time zone from date #2\n" if ($gl_testmode);
      while (<PIPE>) {
        # This should just be a single line, so process here
        chomp();
        if (/^(\d\d\d\d\d\d\d\d-\d\d\d\d\d\d) (\w\w\w)$/) {
          my $date_imageid = $1;
          my $date_timezone = $2;
          print "Got image ID $date_imageid, time zone $date_timezone\n"
            if ($gl_verbose);
          if ($date_timezone eq "EST") {
            $timezone = "-05:00";
            $timezone_found = 1;
            $targetfile = $fname_timestamp;
            $setID = $fname_setId;
            $dst = "No";
          } elsif ($date_timezone eq "EDT") {
            $timezone = "-04:00";
            $timezone_found = 0;
            $targetfile = $fname_timestamp;
            $setID = $fname_setId;
            # The timezone offset already takes EDT/EST into account
            $dst = "No";
          } else {
            print "Unknown time zone for $testdate\n";
          }
        } else {
          print "Unknown response from date command\n";
        }
      }
      close(PIPE);
    }
  }

  if ($gl_phone) {
    # At the moment, it seems that Eric's phone uses IMG for images, VID
    # for videos, and has a camera model of "Nexus 5X" for both.
    # Nicoline's phone uses PXL for both images and videos, has "Pixel 3"
    # as the camera model for images, but _no_ camera model information in
    # the video EXIF.
    # Eric's phone uses local time for the file name, Nicoline's phone uses
    # UTC for the file name.

    my $is_eric;
    if ($fname =~ /^(IMG)|(VID)_/) {
      # Eric's phone
      $is_eric = 1;
    } elsif ($fname =~ /^PXL_/) {
      $is_eric = 0;
    } else {
      die "Cannot determine phone owner: $fname\n";
    }

    my $testdate = "";
    if ($fname =~ /^\w\w\w_(\d\d\d\d)(\d\d)(\d\d)_(\d\d)(\d\d)(\d\d)/) {
      # YYYY, MM, DD, hh, mm, ss
      $testdate = "$1-$2-${3}T$4:$5:$6";
      if (!$is_eric) {
        # Nicoline's phone is in UTC, so add `Z` to the date string
        # ("Zulu time").
        $testdate .= "Z";
      }
    } else {
      die "Can't determine file date for $fname\n";
    }
    # Use the shell 'date' command to determine time zone, as well as convert
    # a filename in UTC to a proper image ID.
    print "Get time zone from date #3\n" if ($gl_testmode);
    open(PIPE, "date \"+\%Y\%m\%d-\%H\%M\%S \%Z\" --date=$testdate|")
      || die "Cannot determine DST for $testdate\n";
    while (<PIPE>) {
      chomp();
      if (/^((\d\d\d\d\d\d\d\d)-\d\d\d\d\d\d) (\w\w\w)$/) {
        my $date_imageid = $1;
        my $date_setid = $2;
        my $date_tz = $3;
        if ($date_tz eq "EDT") {
          # timezone offset is "-4:00"
          $gl_timezoneoffset = "-240";
        } elsif ($date_tz eq "EST") {
          # timezone offset is "-5:00"
          $gl_timezoneoffset = "-300";
        } else {
          die "Cannot determine timezone offset: $_\n";
        }
        print
          "Got image ID $date_imageid, time zone offset $gl_timezoneoffset\n";
        $setID = $date_setid;
        $targetfile = $date_imageid;
      } else {
        die "Unrecognized output from date: '$_'\n";
      }
    }
    close PIPE;
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

  # This is no longer needed, now handle video files in the if ($gl_phone)
  # section above...
  # if ($fname =~ /^VID_(\d\d\d\d\d\d\d\d)_(\d\d\d\d\d\d)\.mp4$/) {
  #   # Video from Android phone, use timestamp from filename
  #   $setID = $1;
  #   $targetfile = "$1-$2";
  # }

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

  # Adjust for an incorrect camera clock; the target file name (image ID)
  # needs to be adjusted
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
      $setID = "$year$month$day";
    } else {
      print "Got offset but don't recognize target file $targetfile, skip\n";
      return;
    }
  }

  # Adjust for a time zone offset
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
        && ($shuttercount == get_shuttercount($imageid))) {
        # duplicate!
        if ($fname =~ /\.nef$/i) {
          move_file("$dir/$fname", "$set_directory/tif/$imageid.nef");
        } elsif ($fname =~ /\.dng$/i) {
          move_file("$dir/$fname", "$set_directory/tif/$imageid.dng");
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
          && ($shuttercount == get_shuttercount($imageid))) {
          # duplicate!
          if ($fname =~ /\.nef$/i) {
            move_file("$dir/$fname", "$set_directory/tif/$imageid.nef");
          } elsif ($fname =~ /\.dng$/i) {
            move_file("$dir/$fname", "$set_directory/tif/$imageid.dng");
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
      print
        "Image $fname: image ID $imageid timezone=$timezone --> sort ID $sortid\n"
        if ($gl_verbose);

      if (defined($expect_id)) {
        if ($imageid ne $expect_id) {
          print "   image ID $imageid expected $expect_id\n";
        }
      }
      if (defined($expect_sortid)) {
        if ($sortid ne $expect_sortid) {
          print
            "   sort ID $sortid expected $expect_sortid\n   (time zone $timezone $dst)\n";
        }
      }
      if ( defined($expect_id)
        && defined($expect_sortid)
        && ($imageid eq $expect_id)
        && ($sortid eq $expect_sortid)) {
        print "   image ID and sort ID match expectation\n";
      }
    }

    # Create the directories
    create_directory($set_directory);
    create_directory("$set_directory/tif");
    create_directory("$set_directory/thumbnails");
    create_directory("$set_directory/normal");
    create_directory("$set_directory/large");
    create_directory("$set_directory/edited");
    create_directory("$set_directory/custom");

    if (!$gl_testmode) {
      set_database_info(
        $imageid, $do_portrait, $newer_rotate,
        $latlong, $timezone, $dst,
        $is_mov, $is_kids, $is_freeform
      );
    }

    # Move over the files we are processing

    if ($fname =~ /\.jpe?g$/i) {
      move_file("$dir/$fname", "$set_directory/tif/$imageid.jpg");
      # If we also have a NEF file, move that as well
      my $nefname = $fname;
      my $dngname = $fname;
      $nefname =~ s/\.jpg$/\.nef/;
      $dngname =~ s/\.jpg$/\.dng/;

      if (-f "$dir/$nefname") {
        # Got a ".nef" file (Nikon RAW format), copy that too
        move_file("$dir/$nefname", "$set_directory/tif/$imageid.nef");
      } elsif (-f "$dir/$dngname") {
        # Got a ".dng" file (Google phone "RAW" format), copy that too
        print "Got dng name '$dngname'\n" if ($gl_testmode);
        move_file("$dir/$dngname", "$set_directory/tif/$imageid.dng");
      } else {
        print "Not found in neflist: $nefname or $dngname\n" if ($gl_verbose);
      }
    } elsif ($fname =~ /\.png$/i) {
      # Get the JPG first
      run_cmd("convert \"$dir/$fname\" \"$set_directory/tif/$imageid.jpg\"");
      move_file("$dir/$fname", "$set_directory/tif/$imageid.png");
    } elsif ($fname =~ /\.nef$/i) {
      # Extract the JPG first
      run_cmd(
        "exiftool -b -JpgFromRaw \"$dir/$fname\" > \"$set_directory/tif/$imageid.jpg\""
      );
      # Add all the EXIF information to the JPG file
      run_cmd(
        "exiftool -TagsFromFile \"$dir/$fname\" -q -q -SerialNumber=0 -overwrite_original \"$set_directory/tif/$imageid.jpg\""
      );
      move_file("$dir/$fname", "$set_directory/tif/$imageid.nef");
    } elsif ($fname =~ /\.dng$/i) {
      # Extract the JPG first
      run_cmd(
        "exiftool -b -JpgFromRaw \"$dir/$fname\" > \"$set_directory/tif/$imageid.jpg\""
      );
      # Add all the EXIF information to the JPG file
      run_cmd(
        "exiftool -TagsFromFile \"$dir/$fname\" -q -q -SerialNumber=0 -overwrite_original \"$set_directory/tif/$imageid.jpg\""
      );
      move_file("$dir/$fname", "$set_directory/tif/$imageid.dng");
    } elsif ($fname =~ /\.cr2$/i) {
      # Extract the JPG first
      run_cmd(
        "exiftool -b -PreviewImage \"$dir/$fname\" > \"$set_directory/tif/$imageid.jpg\""
      );
      # Add all the EXIF information to the JPG file
      run_cmd(
        "exiftool -TagsFromFile \"$dir/$fname\" -q -q -SerialNumber=0 -overwrite_original \"$set_directory/tif/$imageid.jpg\""
      );
      move_file("$dir/$fname", "$set_directory/tif/$imageid.cr2");
    } elsif ($fname =~ /\.mov$/i || $fname =~ /\.mp4$/i) {
      # Extract a JPG thumbnail
      run_cmd(
        "ffmpeg -i \"$dir/$fname\" -vframes 1 -ss 1 \"$set_directory/tif/$imageid.jpg\""
      );
      # Add all the EXIF information to the JPG file
      #run_cmd("exiftool -TagsFromFile $dir/$fname -q -q -SerialNumber=0 -overwrite_original $set_directory/tif/$imageid.jpg");
      if ($fname =~ /\.mov$/i) {
        move_file("$dir/$fname", "$set_directory/tif/$imageid.mov");
      } else {
        move_file("$dir/$fname", "$set_directory/tif/$imageid.mp4");
      }
    } elsif ($fname =~ /\.gif$/i) {
      # Convert GIF to an MP4 file
      run_cmd("ffmpeg -i \"$dir/$fname\" \"$set_directory/tif/$imageid.mp4\"");
      # Extract JPG
      run_cmd(
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
  print "\n" if ($gl_verbose || $gl_testmode);
}

sub create_directory {
  my $dirname = $_[0];

  if (!-d $dirname) {
    if ($gl_testmode) {
      if (!$gl_silent) {
        print "mkdir($dirname)\n";
        print "chmod 777 \"$dirname\"\n";
      }
    } else {
      mkdir($dirname);
      system("chmod 777 \"$dirname\"");
    }
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
  if ($gl_testmode) {
    if (!$gl_silent) {
      print "mv \"$srcfile\" \"$dstfile\"\n";
      print "chmod 444 \"$dstfile\"\n";
    }
  } else {
    system("mv \"$srcfile\" \"$dstfile\"");
    system("chmod 444 \"$dstfile\"");
  }
}

sub run_cmd {
  my $cmd = $_[0];

  if ($gl_testmode) {
    if (!$gl_silent) {
      print "run command $cmd\n";
    }
  } else {
    system($cmd);
  }
}
