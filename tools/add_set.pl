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
    if ($fname =~ /^(($setId).+?)\.(jpg|jpeg|tif|nef|mov|mp4|gif|cr2)$/) {
      # This is a potential file
      my $imageId = $1;
      if ($fname =~ /\.(tif|nef|cr2)$/) {
        my $jpegname = $fname;
        $jpegname =~ s/\.(tif|nef|cr2)$/.jpg/;
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

  open(FILE, "exiftool \"$dir/$fname\"|")
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

  set_database_info(
    $imageId, $do_portrait, $newer_rotate, $latlong, $timezone,
    $dst, $is_mov, $is_kids, $is_freeform, $gl_force
  );
}
