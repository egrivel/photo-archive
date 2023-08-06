#
# Photo Archive System - Common Functions
# This source is copyright (c) 2006 by Eric Grivel. All Rights Reserved.
#

use localsettings;

# Logging levels
$PCOM_DEBUG = 1;
$PCOM_NORMAL = 2;
$PCOM_ERROR = 3;

# Quality
$PCOM_QUAL_DUD = 0;
$PCOM_QUAL_BAD = 1;
$PCOM_QUAL_DEFAULT = 2;
$PCOM_QUAL_OK = 3;
$PCOM_QUAL_GOOD = 4;
$PCOM_QUAL_GREAT = 5;

# Photo types
$PCOM_REGULAR = "r";
$PCOM_PRIVATE = "p";
$PCOM_EXPERIMENTAL = "e";
$PCOM_NICOLINE = "n";
$PCOM_KIDS = "k";
$PCOM_THEO = "t";
$PCOM_PARENTS = "d";
$PCOM_OTHERS = "o";
$PCOM_NEW = "w";

# Photo sizes
$PCOM_DEFAULT = "default";
$PCOM_THUMBNAIL = "thumbnail";
$PCOM_THUMBNAIL_SQUARE = "thsqu";
$PCOM_SMALL = "small";
$PCOM_NORMAL = "normal";
$PCOM_GOOGLE = "google";
$PCOM_LARGE = "large";
$PCOM_SUPER = "super";
$PCOM_2K = "2k";
$PCOM_4K = "4k";
$PCOM_ORIG = "orig";
$PCOM_RAW = "raw";
$PCOM_CUSTOM = "custom";

# Raw file types
$PCOM_TIF = "tif";
$PCOM_NEF = "nef";
$PCOM_DNG = "dng";

# Orientation
$PCOM_LANDSCAPE = "landscape";
$PCOM_PORTRAIT = "portrait";
$PCOM_FREEFORM = "freeform";
$PCOM_FREEFORM_P = "freeform-p";
$PCOM_FREEFORM_L = "freeform-l";

# Mobile Sizes
$PCOM_M1_WIDTH = 480;
$PCOM_M1_HEIGHT = 320;
$PCOM_M2_WIDTH = 640;
$PCOM_M2_HEIGHT = 480;
$PCOM_M3_WIDTH = 900;
$PCOM_M3_HEIGHT = 600;
$PCOM_M4_WIDTH = 1366;
$PCOM_M4_HEIGHT = 720;
$PCOM_M5_WIDTH = 1920;
$PCOM_M5_HEIGHT = 1080;

@quicktags = ();
my $quicktags_txt = get_quicktags();
while ($quicktags_txt =~ s/^\s*([^, ]+)[, ]*//) {
  push(@quicktags, $1);
}

my $log_level = $PCOM_DEBUG;
my $log_file = pcom_photo_root() . "/photos_log.txt";

sub pcom_log {
  my $level = $_[0];
  my $message = $_[1];

  if ($level >= $log_level) {
    if (open(LOGFILE, ">>$log_file")) {
      print LOGFILE "$message\n";
      close LOGFILE;
    }
  }
}

sub pcom_photo_root {
  return local_directory("photos");
}

sub pcom_photo_root2 {
  return local_directory("photos2");
}

sub pcom_slideshow_filename {
  my $slideshow_id = $_[0];
  return local_directory("photos") . "/slideshows/$slideshow_id.txt";
}

sub pcom_error {
  my $message = $_[0];

  pcom_log($PCOM_ERROR, $message);
  print "content-type: text/plain\n\nError: $message\n";
  exit(0);
}

sub pcom_assert {
  my $test = $_[0];
  my $explanation = $_[1];

  if (!$test) {
    pcom_error($explanation);
  }
}

sub pcom_is_valid {
  my $imageID = $_[0];

  return 1 if ($imageID =~ /^[\dafmdptx]\d\d\d\d[a-z]?$/);
  return 1 if ($imageID =~ /^\d\d\d\d\d\d\d\d\-\d\d\d\d\d\d[a-z]?$/);
  return 0;
}

sub pcom_get_set {
  my $imageID = $_[0];

  if ($imageID =~ /^([\dafmdptx]\d\d)\d\d[a-z]?$/) {
    return $1;
  }
  if ($imageID =~ /^(\d\d\d\d\d\d\d\d)\-\d\d\d\d\d\d\w?$/) {
    return $1;
  }

  return "";
}

sub pcom_is_set_valid {
  my $setID = $_[0];

  return 1 if ($setID =~ /^[\dafmdptx]\d\d$/);
  return 1 if ($setID =~ /^\d\d\d\d\d\d\d\d$/);
  return 0;
}

sub pcom_is_user_valid {
  my $userid = $_[0];

  return ($userid =~ /^\w+$/);
}

sub pcom_is_digital {
  my $imageid = $_[0];
  return ($imageid =~ /^\d\d\d\d\d\d\d\d\-\d\d\d\d\d\d\w?$/);
}

my @year_film = ();
my @year_year = ();
my %start_years = (
  "001", 1974, "007", 1975, "011", 1976, "015", 1977, "016", 1978,
  "020", 1979, "024", 1980, "030", 1981, "031", 1982, "036", 1983,
  "044", 1984, "049", 1985, "063", 1986, "078", 1987, "089", 1988,
  "096", 1989, "110", 1990, "131", 1991, "148", 1992, "173", 1993,
  "185", 1994, "193", 1995, "212", 1996, "226", 1997, "237", 1998,
  "251", 1999, "270", 2000, "288", 2001, "313", 2002, "334", 2003,
  "349", 2004,
);

# Get the year of a set, based on the set ID.
sub pcom_get_year {
  my $setid = $_[0];

  # Get the actual year from the database, and only if
  # the database doesn't have a year, figure out the year
  # by ID.

  my $year = "";    # pdb_get_setyear($setid);
  if ($year eq "") {
    if ($setid =~ /^x/) {
      $year = 9999;
    } elsif ($setid =~ /^[dpq]/) {
      $year = 9998;
    } elsif ($setid =~ /^[t]/) {
      $year = 9997;
    } elsif ($setid =~ /^[a]/) {
      $year = 9996;
    } elsif ($setid =~ /^f(\d\d)/i) {
      my $nr = $1;
      if ($nr <= 1) {
        $year = 1998;
      } elsif ($nr <= 2) {
        $year = 1999;
      } elsif ($nr <= 4) {
        $year = 2001;
      } elsif ($nr <= 5) {
        $year = 2002;
      } elsif ($nr < 14) {
        $year = 2003;
      } elsif ($nr < 16) {
        $year = 2004;
      } elsif ($nr < 50) {
        $year = 2005;
      } elsif ($nr < 53) {
        $year = 2015;
      } else {
        $year = 2016;
      }
    } elsif ($setid =~ /^m(\d\d)/i) {
      my $nr = $1;
      if ($nr <= 1) {
        $year = 1998;
      } elsif ($nr <= 3) {
        $year = 1999;
      } elsif ($nr <= 6) {
        $year = 2001;
      } elsif ($nr <= 7) {
        $year = 2002;
      } elsif ($nr < 13) {
        $year = 2003;
      } elsif ($nr < 14) {
        $year = 2004;
      } else {
        $year = 2005;
      }
    } elsif ($setid =~ /^(\d\d\d\d)\d\d(\d\d)?$/) {
      $year = $1;
    } elsif ($setid =~ /^\d+$/) {
      my $count = 0;
      if (!defined($year_film[0])) {
        my $key = "";
        foreach $key (sort (keys %start_years)) {
          $year_film[$count] = $key;
          $year_year[$count] = $start_years{$key};
          $count++;
        }
      }
      $count = 0;
      while (defined($year_film[$count])) {
        if ($setid >= $year_film[$count]) {
          $year = $year_year[$count];
        } else {
          last;
        }
        $count++;
      }
    } else {

      # Set ID is not numeric, nor any of the special ones - default
      # to year 1900
      $year = 1900;
    }
  }

  return $year;
}

# first year with photos in the database
sub pcom_first_year {
  $year = setting_get("startyear");
  if ($year eq "") {
    $year = 1957;
  }
  return $year;
}

# last year I had pictures
sub pcom_last_year {
  return pcom_current_year();
}

# current year
sub pcom_current_year {
  my @now = localtime;
  return $now[5] + 1900;
}

sub pcom_has_photos_in_year {
  my $year = $_[0];
  return pdb_year_exists($year);
}

# First set is the first _regular_ set, not including special sets
sub pcom_first_set {
  my $iter = pdb_iter_set_new();
  # was put_types()
  pdb_iter_filter_category($iter, $PUSR_SEE_REGULAR);
  $setId = pdb_iter_next($iter);
  pdb_iter_set_done($iter);

  return $setId;
}

# First set is the first _regular_ set, not including special sets
sub pcom_last_set {
  my $iter = pdb_iter_set_new();
  # was put_types()
  pdb_iter_filter_category($iter, $PUSR_SEE_REGULAR);
  pdb_iter_filter_sortid($iter, "2199");
  $setId = pdb_iter_previous($iter);
  pdb_iter_set_done($iter);

  return $setId;
}

# return a formatted version of the image ID
sub pcom_format_imageid {
  my $imageid = $_[0];

  if ($imageid =~ /^([a-z])(\d\d)(\d\d)(\w?)$/) {
    return $1 . int($2) . "." . int($3) . $4;
  } elsif ($imageid =~ /^(\d\d\d)(\d\d)(\w?)$/) {
    return int($1) . "." . int($2) . $3;
  } else {
    return $imageid;
  }
}

sub pcom_mv {
  my $src = $_[0];
  my $target = $_[1];
  my $dir = $target;
  if ($dir =~ s/\/[^\/]+$//) {
    if (!(-d $dir)) {
      mkdir($dir);
      system("chmod 777 $dir");
    }
  }
  pcom_log($PCOM_DEBUG, "mv $src $target");
  system("mv $src $target");
}

sub pcom_rm {
  pcom_log($PCOM_DEBUG, "unlink($_[0])");
  unlink($_[0]);
}

return 1;
