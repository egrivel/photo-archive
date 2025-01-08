#
# Photo Archive System - File System Functions
# This source is copyright (c) 2006 by Eric Grivel. All Rights Reserved.
#

use photos_common;

sub pfs_get_time {
  my $fname = $_[0];
  my @times = stat($_[0]);
  return $times[9];
}

#
# Determine the "standard" directory for the set.
sub pfs_get_set_basedir {
  my $setID = $_[0];

  my $basedir = pcom_photo_root() . "/$setID";

  if ($setID =~ /^(20\d\d)\d\d\d\d$/) {
    # Digital set starting with a year; use second base
    # directory if the year is 2009 or later
    my $year = $1;
    if ($year >= 2009) {
      $basedir = pcom_photo_root2() . "/$setID";
    }
  }
  return $basedir;
}

sub pfs_get_setdir {
  my $imageID = $_[0];

  if (!pcom_is_valid($imageID)) {
    # invalid image ID
    return "";
  }

  my $setID = pcom_get_set($imageID);
  my $basedir = pfs_get_set_basedir($setID);

  # The default should work just about always
  pcom_log($PCOM_DEBUG, "Try $basedir/tif");
  if ( (-f "$basedir/tif/$imageID.nef")
    || (-f "$basedir/tif/$imageID.dng")
    || (-f "$basedir/tif/$imageID.jpg")
    || (-f "$basedir/tif/$imageID.tif")
    || (-f "$basedir/tif/$imageID.mp4")
    || (-f "$basedir/tif/$imageID.mov")
    || (-f "$basedir/tif/$imageID.JPG")
    || (-f "$basedir/edited/$imageID.jpg")) {
    return "$basedir";
  }

  # Only if we need the alternative...
  my $pfs_alt_basedir = pcom_photo_root() . "_kids";
  $basedir = "$pfs_alt_basedir/$setID";
  pcom_log($PCOM_DEBUG, "Try $basedir/tif");
  if ( (-f "$basedir/tif/$imageID.nef")
    || (-f "$basedir/tif/$imageID.dng")
    || (-f "$basedir/tif/$imageID.jpg")
    || (-f "$basedir/tif/$imageID.tif")
    || (-f "$basedir/tif/$imageID.mp4")
    || (-f "$basedir/tif/$imageID.mov")
    || (-f "$basedir/tif/$imageID.JPG")
    || (-f "$basedir/edited/$imageID.jpg")) {
    return "$basedir";
  }

  pcom_log($PCOM_DEBUG, "None found");
  return "";
}

sub pfs_get_size {
  my $imageID = $_[0];

  # Note: invalid image ID gives empty $setdir
  # if (!pcom_is_valid($imageID)) {
  #     # invalid image ID
  #     return "";
  # }

  my $setdir = pfs_get_setdir($imageID);
  if ($setdir ne "") {
    # If the setdir is non-empty, the image must exist. The default
    # size of the image is large, except when there is a normal-size
    # version but no large version available...
    if (
      (-f "$setdir/jpeg/$imageID.jpg")
      && !(
        (-f "$setdir/edited/$imageID.jpg") || (-f "$setdir/jpeg2/$imageID.jpg"))
    ) {
      return $PCOM_NORMAL;
    }
    return $PCOM_LARGE;
  }

  return "";
}

sub pfs_get_image_location {
  my $imageID = $_[0];

  # Note: invalid image ID gives empty large and normal location
  # if (!pcom_is_valid($imageID)) {
  #     # invalid image ID
  #     return "";
  # }

  my $fname = pfs_get_large_location($imageID);
  if ($fname eq "") {
    $fname = pfs_get_normal_location($imageID);
  }
  return $fname;
}

sub pfs_get_orig_location {
  my $imageID = $_[0];

  # Note: invalid image ID gives empty $setdir
  # if (!pcom_is_valid($imageID)) {
  #     # invalid image ID
  #     return "";
  # }

  my $setdir = pfs_get_setdir($imageID);
  if ($setdir ne "") {
    if (-f "$setdir/tif/$imageID.jpg") {
      return "$setdir/tif/$imageID.jpg";
    }
  }

  return "";
}

sub pfs_get_edited_location {
  my $imageID = $_[0];

  # Note: invalid image ID gives empty $setdir
  # if (!pcom_is_valid($imageID)) {
  #     # invalid image ID
  #     return "";
  # }

  my $setdir = pfs_get_setdir($imageID);

  if ($setdir ne "") {
    my $ext = ".jpg";
    if (pdb_get_type($imageID) eq "MOV") {
      if (-f "$setdir/edited/$imageID.mov") {
        $ext = ".mov";
      } elsif (-f "$setdir/edited/$imageID.mp4") {
        $ext = ".mp4";
      }
    }

    if (-f "$setdir/edited/$imageID$ext") {
      my $fname = "$setdir/edited/$imageID$ext";
      # Check to see if there is a RawShooter updated file
      my $ftime = pfs_get_time($fname);
      my $nr = "02";
      while (-f "$setdir/edited/$imageID-$nr$ext") {
        if (pfs_get_time("$setdir/edited/$imageID-$nr$ext") > $ftime) {
          $fname = "$setdir/edited/$imageID-$nr$ext";
          $ftime = pfs_get_time($fname);
        }
        $nr++;
        $nr = "0" . int($nr) if ($nr < 10);
      }
      return $fname;
    }
  }

  return "";
}

sub pfs_get_size_location {
  my $imageID = $_[0];
  my $size = $_[1];
  my $altsize = $_[2];

  # Note: invalid image ID gives empty $setdir
  # if (!pcom_is_valid($imageID)) {
  #     # invalid image ID
  #     return "";
  # }

  my $setdir = pfs_get_setdir($imageID);
  if ($setdir ne "") {
    my $edittime = 0;
    if (pfs_get_edited_location($imageID) ne "") {
      $edittime = pfs_get_time(pfs_get_edited_location($imageID));
    } elsif (pfs_get_orig_location($imageID) ne "") {
      $edittime = pfs_get_time(pfs_get_orig_location($imageID));
    }
    if (-f "$setdir/$size/$imageID.jpg") {
      if (pfs_get_time("$setdir/$size/$imageID.jpg") >= $edittime) {
        return "$setdir/$size/$imageID.jpg";
      }
    }

    if (defined($altsize) && ($altsize ne "")) {
      if (-f "$setdir/$altsize/$imageID.jpg") {
        if (pfs_get_time("$setdir/$altsize/$imageID.jpg") >= $edittime) {
          return "$setdir/$altsize/$imageID.jpg";
        }
      }
    }
  }

  return "";
}

sub pfs_get_large_location {
  return pfs_get_size_location($_[0], "large", "jpeg2");
}

sub pfs_get_google_location {
  return pfs_get_size_location($_[0], "google");
}

sub pfs_get_normal_location {
  return pfs_get_size_location($_[0], "normal", "jpeg");
}

sub pfs_get_small_location {
  return pfs_get_size_location($_[0], "small");
}

sub pfs_get_thumbnail_location {
  return pfs_get_size_location($_[0], "thumbnails");
}

sub pfs_get_thumbnail_square_location {
  return pfs_get_size_location($_[0], "thsqu");
}

sub pfs_get_freeform_location {
  return pfs_get_size_location($_[0], "custom");
}

sub pfs_get_raw_location {
  my $imageID = $_[0];

  # Note: invalid image ID gives empty $setdir
  # if (!pcom_is_valid($imageID)) {
  #     # invalid image ID
  #     return "";
  # }

  my $setdir = pfs_get_setdir($imageID);
  if ($setdir ne "") {
    if (-f "$setdir/tif/$imageID.tif") {
      return "$setdir/tif/$imageID.tif";
    }
    if (-f "$setdir/tif/$imageID.nef") {
      return "$setdir/tif/$imageID.nef";
    }
    if (-f "$setdir/tif/$imageID.dng") {
      return "$setdir/tif/$imageID.dng";
    }
    if (-f "$setdir/tif/$imageID.mov") {
      return "$setdir/tif/$imageID.mov";
    }
    if (-f "$setdir/tif/$imageID.mp4") {
      return "$setdir/tif/$imageID.mp4";
    }
    if (-f "$setdir/tif/$imageID.png") {
      return "$setdir/tif/$imageID.png";
    }
    if (-f "$setdir/tif/$imageID.gif") {
      return "$setdir/tif/$imageID.gif";
    }
  }

  return "";
}

sub pfs_get_buffer_location {
  my $imageID = $_[0];
  my $size = $_[1];

  if ( ($size ne "thumbnail")
    && ($size ne $PCOM_THUMBNAIL_SQUARE)
    && ($size ne "small")
    && ($size ne "normal")
    && ($size ne "google")
    && ($size ne "large")
    && ($size ne "super")
    && ($size ne "freeform")
    && ($size ne "2k")
    && ($size ne "4k")) {
    # Invalid size, can't buffer
    return "";
  }

  # Directory to use: default to same name as size
  my $subdir = $size;
  if ($size eq "thumbnail") {
    # Use directory name 'thumbnails' instead of 'thumbnail'
    $subdir = "thumbnails";
  } elsif ($size eq "freeform") {
    # Use custom directory for freeform (ends up as "default" custom
    # image, without any size parameters)
    $subdir = "custom";
  }

  # Note: invalid image ID gives empty $setdir
  # if (!pcom_is_valid($imageID)) {
  #     # invalid image ID
  #     return "";
  # }

  my $setdir = pfs_get_setdir($imageID);
  if ($setdir ne "") {
    if (!(-d "$setdir/$subdir")) {
      mkdir("$setdir/$subdir");
      system("chmod 777 $setdir/$subdir");
    }
    if ($size eq $PCOM_THUMBNAIL_SQUARE) {
      return "$setdir/$subdir/$imageID-thsqu.jpg";
    } else {
      return "$setdir/$subdir/$imageID.jpg";
    }
  }
  return "";
}

sub pfs_get_custom_realsize_location {
  my $imageID = $_[0];
  my $width = $_[1];
  my $height = $_[2];
  my $realwidth = $_[3];
  my $realheight = $_[4];
  my $x_offset = $_[5];
  my $y_offset = $_[6];

  if (!defined($x_offset)) {
    $x_offset = 0;
  }
  if (!defined($y_offset)) {
    $y_offset = 0;
  }

  # Note: invalid image ID gives empty $setdir
  # if (!pcom_is_valid($imageID)) {
  #     # invalid image ID
  #     return "";
  # }

  my $setdir = pfs_get_setdir($imageID);
  if ($setdir ne "") {
    if (!(-d "$setdir/custom")) {
      mkdir("$setdir/custom");
      system("chmod 777 $setdir/custom");
    }
    my $fname =
      "$setdir/custom/$imageID-${width}-${height}-${realwidth}-${realheight}";
    if (($x_offset != 0) || ($y_offset != 0)) {
      $fname .= "-o-$x_offset-$y_offset";
    }
    $fname .= ".jpg";
    return $fname;
  }
  return "";
}

sub pfs_get_mobile_location {
  my $imageID = $_[0];
  my $size = $_[1];

  # Note: invalid image ID gives empty $setdir
  # if (!pcom_is_valid($imageID)) {
  #     # invalid image ID
  #     return "";
  # }

  my $setdir = pfs_get_setdir($imageID);
  if ($setdir ne "") {
    if (!(-d "$setdir/custom")) {
      mkdir("$setdir/custom");
      system("chmod 777 $setdir/custom");
    }
    return "$setdir/custom/$imageID-${size}.jpg";
  }
  return "";
}

sub pfs_get_custom_location {
  my $imageID = $_[0];
  my $width = $_[1];
  my $height = $_[2];
  my $x_offset = $_[3];
  my $y_offset = $_[4];

  if (!defined($x_offset)) {
    $x_offset = 0;
  }
  if (!defined($y_offset)) {
    $y_offset = 0;
  }

  # Note: invalid image ID gives empty $setdir
  # if (!pcom_is_valid($imageID)) {
  #     # invalid image ID
  #     return "";
  # }

  my $setdir = pfs_get_setdir($imageID);
  if ($setdir ne "") {
    if (!(-d "$setdir/custom")) {
      mkdir("$setdir/custom");
      system("chmod 777 $setdir/custom");
    }
    my $fname = "$setdir/custom/$imageID-${width}-${height}";
    if (($x_offset != 0) || ($y_offset != 0)) {
      $fname .= "-o-$x_offset-$y_offset";
    }
    $fname .= ".jpg";
    return $fname;
  }
  return "";
}

#
# Get only the folder back, not the entire image path; this is used
# to find all the 'custom' versions of an image for deletion.
sub pfs_get_custom_folder_location {
  my $imageID = $_[0];

  my $setdir = pfs_get_setdir($imageID);
  if ($setdir ne "") {
    return "$setdir/custom";
  }
  return "";
}

sub pfs_get_raw_type {
  my $imageID = $_[0];

  # Note: invalid image ID gives empty $setdir
  # if (!pcom_is_valid($imageID)) {
  #     # invalid image ID
  #     return "";
  # }

  my $setdir = pfs_get_setdir($imageID);
  if ($setdir ne "") {
    if (-f "$setdir/tif/$imageID.tif") {
      return $PCOM_TIF;
    }
    if (-f "$setdir/tif/$imageID.nef") {
      return $PCOM_NEF;
    }
    if (-f "$setdir/tif/$imageID.dng") {
      return $PCOM_DNG;
    }
  }

  return "";
}

sub pfs_get_file_dimensions {
  my $fname = $_[0];

  my $width = 0;
  my $height = 0;

  # Note: use the "identify" command for JPEG files, since it seems to
  # be significantly faster.
  if (-f $fname) {
    if (
         ($fname =~ /\.nef$/i)
      || ($fname =~ /\.dng$/i)
      #	    || ($fname =~ /\.jpe?g$/i)
      || ($fname =~ /\.tiff?$/i)
    ) {
      if (open(SIZE, "exiftool $fname|")) {
        while (<SIZE>) {
          if (/Image Width\s+:\s+(\d+)/i) {
            $width = $1;
          }
          if (/Image Height\s+:\s+(\d+)/i) {
            $height = $1;
          }
          last if (($width > 0) && ($height > 0));
        }
        close SIZE;
      }
    } elsif ($fname =~ /\.mov$/ || $fname =~ /\.mp4$/i) {
      if (open(SIZE, "exiftool $fname|")) {
        while (<SIZE>) {
          if (/Image Size\s+:\s+(\d+)x(\d+)\s*$/) {
            $width = $1;
            $height = $2;
            last;
          }
        }
      }
    } else {
      if (open(SIZE, "identify $fname|")) {
        while (<SIZE>) {
          if (/(\d+)x(\d+)/) {
            $width = $1;
            $height = $2;
            last;
          }
        }
        close SIZE;
      }
    }
  }
  return ($width, $height);
}

sub pfs_get_orig_dimensions {
  my $imageID = $_[0];

  my $width = 0;
  my $height = 0;

  if (pcom_is_valid($imageID)) {
    my $fname = pfs_get_orig_location($imageID);
    if ($fname eq "") {
      $fname = pfs_get_raw_location($imageID);
    }
    if ($fname eq "") {
      $fname = pfs_get_edited_location($imageID);
    }

    pcom_log($PCOM_DEBUG, "Get file dimensions for $fname");
    ($width, $height) = pfs_get_file_dimensions($fname);
    pcom_log($PCOM_DEBUG, "Got file dimensions ($width,$height) for $fname");
  }

  return ($width, $height);
}

sub pfs_get_orig_orientation {
  my $imageID = $_[0];
  my $orientation = "";

  if (pcom_is_valid($imageID)) {
    my ($width, $height) = pfs_get_orig_dimensions($imageID);
    if ($width >= $height) {
      $orientation = $PCOM_LANDSCAPE;
    } else {
      $orientation = $PCOM_PORTRAIT;
    }
  }

  return $orientation;
}

sub pfs_get_orientation {
  my $imageID = $_[0];
  my $orientation = "";

  my $fname = pfs_get_edited_location($imageID);
  if ($fname eq "") {
    # Not an edited file; use orientation of original
    #        pcom_log($PCOM_DEBUG, "Get orig orientation for $imageID");
    $orientation = pfs_get_orig_orientation($imageID);
  } else {
    #        pcom_log($PCOM_DEBUG, "Get file dimensions for $imageID at $fname");
    my ($width, $height) = pfs_get_file_dimensions($fname);
    #        pcom_log($PCOM_DEBUG, "Got file dimensions ($width,$height) for $imageID at $fname");
    if ($width >= $height) {
      $orientation = $PCOM_LANDSCAPE;
    } else {
      $orientation = $PCOM_PORTRAIT;
    }
  }
  pcom_log($PCOM_DEBUG, "Found orientation $orientation for $imageID");
  return $orientation;
}

sub pfs_cmd_copy_exif {
  my $imageID = $_[0];
  my $targetfile = $_[1];
  my $origfile = pfs_get_raw_location($imageID);

  my $cmd = "";
  if ($origfile =~ /\.nef$/) {
    # Only can get the exif if we have the original .NEF file
    # Note: blank out the serial number (nobody's business) and the
    # orientation (when we process the photo, it is already rotated,
    # so the orientation will only confuse programs that recognize it).
    $cmd = "exiftool -TagsFromFile $origfile -q -q -SerialNumber=0 "
      . "-Orientation= -overwrite_original $targetfile > /dev/null";
  } else {
    # For other files, just remove the orientation from the EXIF, since the
    # orientation is already applied
    $cmd = "exiftool -Orientation= -overwrite_original $targetfile > /dev/null";
    pcom_log($PCOM_DEBUG, "EXIF: $cmd");
  }
  return $cmd;
}

sub pfs_cmd_orig {
  my $imageID = $_[0];
  my $rotation = $_[1];
  my $outfile = $_[2];

  # To get the original file, the only issue is to get a conversion from
  # the raw format to JPEG
  my $fname = pfs_get_raw_location($imageID);
  $cmd = "convert $fname jpg:- > $outfile; ";
  if ($fname =~ /\.nef$/i) {
    $cmd = "exiftool -b -JpgFromRaw $fname > $outfile; ";
  }
  $cmd .= pfs_cmd_copy_exif($imageID, $outfile);
  return $cmd;
}

sub pfs_cmd_resize {
  my $imageID = $_[0];
  my $rotation = $_[1];
  my $outfile = $_[2];
  my $longval = $_[3];
  my $shortval = $_[4];
  my $use_edit = $_[5];
  my $fill_portrait = $_[6];    # if true, fill portrait to make it
                                # landscape. Also, fill freeform
  my $realwidth = $_[7];
  my $realheight = $_[8];
  my $keep_aspect = $_[9];
  my $rotate_always = $_[10];    # if true, even rotate when using edited file
  my $scale = $_[11];    # pre-computed scale; ignores all other
                         # size parameters
  my $x_offset = $_[12];    # shift image horizontally
  my $y_offset = $_[13];    # shift image vertically

  if (!defined($scale) || ($scale eq "")) {
    $scale = 0;
  }

  if (!defined($rotation) || ($rotation eq "")) {
    $rotation = 0;
  }

  if (!defined($x_offset)) {
    $x_offset = 0;
  }
  if (!defined($y_offset)) {
    $y_offset = 0;
  }

  my $orientation = pdb_get_orientation($imageID);
  my $is_freeform =
    (    ($orientation eq $PCOM_FREEFORM)
      || ($orientation eq $PCOM_FREEFORM_P)
      || ($orientation eq $PCOM_FREEFORM_L));
  if (!defined($fill_portrait)) {
    $fill_portrait = 0;
  }
  if (!defined($realwidth) || ($realwidth eq "")) {
    $realwidth = 0;
  }
  if (!defined($realheight) || ($realheight eq "")) {
    $realheight = 0;
  }
  if (!defined($keep_aspect)) {
    $keep_aspect = 0;
  }

  my $fname = "";
  if ($use_edit) {
    $fname = pfs_get_edited_location($imageID);
    # don't rotate if using the edited file
    $rotation = 0 if (($fname ne "") && !$rotate_always);
    # if no edited file found, don't use edit
    $use_edit = 0 if ($fname eq "");
  }
  if ($fname eq "") {
    $fname = pfs_get_orig_location($imageID);
  }
  if ($fname eq "") {
    my $rawfname = pfs_get_raw_location($imageID);
    if ($rawfname ne "") {
      if ($rawfname =~ /\.nef$/i) {
        # Need to extract the JPG from the RAW file first...
        $fname = $rawfname;
        $fname =~ s/\.nef/\.jpg/i;
        system("exiftool -b -JpgFromRaw $rawfname > $fname");
        if (!(-f $fname)) {
          # couldn't create target file
          $fname = "";
        }
      } else {
        $fname = $rawfname;
      }
    }
  }
  # can't find original file
  return "" if ($fname eq "");

  my ($width, $height);

  if ($use_edit) {
    ($width, $height) = pfs_get_file_dimensions($fname);
  } else {
    ($width, $height) = pfs_get_orig_dimensions($imageID);
  }

  if (!$width || !$height) {
    # Can't extract width and height from original
    return "";
  }

  if (($rotation == 90) || ($rotation == 270) || ($rotation == -90)) {
    # Will be rotated; exchange width and height (but only if it
    # is a landscape or freeform original)
    if (($width > $height) || $is_freeform) {
      my $temp = $width;
      $width = $height;
      $height = $temp;
    } else {
      # Original is already portrait; don't rotate (except for a
      # possible 180 degree rotation, if appropriate
      if ($rotation == 90) {
        $rotation = 0;
      } else {
        $rotation = 180;
      }
    }
  }

  my $finalsize = "";
  my $scalesize = "";
  my $extraval = 2 * $shortval;
  my $page = "";
  my $ratio = $longval / $shortval;

  if ($scale > 0) {
    $finalsize = int($width * $scale) . "x" . int($height * $scale);
    $scalesize = $finalsize;
  } else {
    if ($is_freeform) {
      # For a free-form size image, resize with the same aspect
      # ratio as the original
      $finalsize = "";
      $scalesize = "";
      $page = "";
      if ($keep_aspect) {
        my $scale = 1;
        if ($width >= $height) {
          if ($width > $longval) {
            $scale = $longval / $width;
          }
          if ( ($height > $shortval)
            && ($scale > ($shortval / $height))) {
            $scale = $shortval / $height;
          }
        } else {
          if ($height > $longval) {
            $scale = $longval / $height;
          }
          if ( ($width > $shortval)
            && ($scale > ($shortval / $width))) {
            $scale = $shortval / $width;
          }
        }
        $finalsize = int($width * $scale) . "x" . int($height * $scale);
        $scalesize = $finalsize;
      } else {
        if ($width >= $height) {
          # Original is landscape
          my $ratio1 = $longval / $width;
          my $ratio2 = $shortval / $height;
          if ($ratio2 > $ratio1) {
            $ratio = $ratio1;
          } else {
            $ratio = $ratio2;
          }
          $finalsize = "${longval}x${shortval}";
          if (int($width * $ratio) < $longval) {
            my $offset = int(($longval - int($width * $ratio)) / 2);
            $page = "-bordercolor \"#CCCCCC\" -border ${offset}x0";
          } else {
            my $offset = int(($shortval - int($height * $ratio)) / 2);
            $page = "-bordercolor \"#CCCCCC\" -border 0x${offset}";
          }
        } else {
          # Original is portrait
          if ($fill_portrait) {
            pcom_log($PCOM_DEBUG,
              "freeform, don't keep aspect, portrait, fillportrait=$fill_portrait"
            );
            $finalsize = "${longval}x${shortval}";
            $ratio = $shortval / $height;
            my $scaleheight = $shortval;
            my $scalewidth = int($width * $ratio);
            $scalesize = "${scalewidth}x${scaleheight}";
            my $offset = int(($longval - $scalewidth) / 2);
            $page = "-bordercolor \"#000000\" -border ${offset}x0";
          } else {
            my $ratio1 = $shortval / $width;
            my $ratio2 = $longval / $height;
            if ($ratio2 > $ratio1) {
              $ratio = $ratio1;
            } else {
              $ratio = $ratio2;
            }
            $finalsize = "${shortval}x${longval}";
            if (int($height * $ratio) < $longval) {
              my $offset = int(($longval - int($height * $ratio)) / 2);
              $page = "-bordercolor \"#CCCCCC\" -border 0x${offset}";
            } else {
              my $offset = int(($shortval - int($width * $ratio)) / 2);
              $page = "-bordercolor \"#CCCCCC\" -border ${offset}x0";
            }
          }
        }
        $scalesize = int($width * $ratio) . "x" . int($height * $ratio);
      }
    } else {
      # This is a regular portrait or landscape picture
      if ($width > $height) {
        # landscape picture
        $finalsize = "${longval}x${shortval}";
        if (($ratio * $height) > $width) {
          # resize based on width, crop height
          $scalesize = "${longval}x${longval}";
          my $scalefactor = $longval / $width;
          my $scaleheight = int($height * $scalefactor);
          if (($scaleheight - $shortval) > 10) {
            $offset = int(($scaleheight - $shortval) / 2);
            $y_offset += $offset;
            # $finalsize .= "+0+${offset}";
          }
        } else {
          # resize based on height, crop width
          $scalesize = "${extraval}x${shortval}";
          my $scalefactor = $shortval / $height;
          my $scalewidth = int($width * $scalefactor);
          if (($scalewidth - $longval) > 10) {
            $offset = int(($scalewidth - $longval) / 2);
            $x_offset += $offset;
            #$finalsize .= "+${offset}+0";
          }
        }
      } else {
        # portrait picture
        if ($fill_portrait) {
          $finalsize = "${longval}x${shortval}";
          my $scaleheight = $shortval;
          my $scalewidth = int($width * $shortval / $height);
          $scalesize = "${scalewidth}x${scaleheight}";
          my $offset = int(($longval - $scalewidth) / 2);
          $page = "-bordercolor \"#000000\" -border ${offset}x0";
          # If filling portrait (make portrait photos show in landscape),
          # also strip the EXIF info so the information that the photo
          # was portrait is erased
          # OOPS, the -strip is not supported by the convert on Washington...
          #                $page .= " -strip";
        } else {
          # Produce true portrait output
          $finalsize = "${shortval}x${longval}";
          if (($ratio * $width) > $height) {
            # resize based on height, crop width
            $scalesize = "${longval}x${longval}";
            my $scalefactor = $longval / $height;
            my $scalewidth = int($width * $scalefactor);
            if (($scalewidth - $shortval) > 10) {
              $offset = int(($scalewidth - $shortval) / 2);
              $x_offset += $offset;
              #$finalsize .= "+${offset}+0";
            }
          } else {
            # resize based on width, crop height
            $scalesize = "${shortval}x${extraval}";
            my $scalefactor = $shortval / $width;
            my $scaleheight = int($height * $scalefactor);
            if (($scaleheight - $longval) > 10) {
              $offset = int(($scaleheight - $longval) / 2);
              $y_offset += $offset;
              #$finalsize .= "+0+${offset}";
            }
          }
        }
      }
    }
  }

  if (($x_offset != 0) || ($y_offset != 0)) {
    if ($x_offset < 0) {
      $finalsize .= $x_offset;
    } else {
      $finalsize .= "+$x_offset";
    }
    if ($y_offset < 0) {
      $finalsize .= $y_offset;
    } else {
      $finalsize .= "+$y_offset";
    }
  }

  $quality = "-quality 85";
  $sharpen = "-sharpen 1x1";
  my $rotate = "";
  if ($rotation) {
    $rotate = "-rotate $rotation";
  }

  # Use the 'convert' command for the conversion. Quality and sharpening
  # settings are defined hard-coded. Use the "jpg:" prefix on the output
  # filename to force a JPEG output
  $realresize = "";
  if (($realwidth > 0) && ($realheight > 0)) {
    $realresize = " jpg:- | convert jpg:- -resize ${realwidth}x${realheight}! ";
  }

  # Removing the color profile from the image. It seems the Vuescan
  # adds a color profile to the scans, which does not quite match the
  # standard RGB profile. As a result, the photos look good in a
  # browser that forces standard RGB but not in a color-profile-aware
  # browser (firefox)...
  # Note that this only started with a newer version of vuescan, so
  # actually some older scans are OK. For now, only remove the color
  # profile from my father's slides (the "d*" photos).
  my $remove_profile = "";
  if ($imageID =~ /^d\d\d\d\d/) {
    $remove_profile = "+profile \"*\"";
  }

  # If this is a video, explicitly get the first frame from the video
  my $imgInstance = "";
  if ($fname =~ /\.((mov)|(mp4))$/) {
    $imgInstance = "[1]";
  }
  
  return
    "convert -size $finalsize $fname$imgInstance $rotate -resize $scalesize $page -crop $finalsize $realresize $quality $sharpen $remove_profile jpg:- > $outfile; "
    . pfs_cmd_copy_exif($imageID, $outfile);
}

sub pfs_cmd_large {
  return pfs_cmd_resize($_[0], $_[1], $_[2], 900, 600, 1);
}

sub pfs_cmd_large_movie {
  my $imageid = $_[0];
  my $orientation = $_[1];
  my $src = $_[2];

  if (!defined($src) || ($src eq "")) {
    $src = pfs_get_edited_location($imageid);
    if ($src eq "") {
      $src = pfs_get_raw_location($imageid);
    }
  }

  my $size = "scale=960:540";
  if ($orientation eq $PCOM_PORTRAIT || $orientation eq $PCOM_FREEFORM_P) {
    $size = "scale=540:960";
  }

  my $outfile = pfs_get_buffer_location($imageid, "large");
  if (($src ne "") && ($outfile ne "")) {
    $outfile =~ s/\.jpg$/.mp4/;
    # add -max_muxing_queue_size 400 to handle "movies with sparse video
    # or audio frames", see:
    #    https://trac.ffmpeg.org/ticket/6375
    return
      "ffmpeg -i $src -max_muxing_queue_size 400 -vcodec libx264 -acodec libvorbis -aq 5 -ac 2 -crf 30 -vf $size $outfile.mp4; qt-faststart $outfile.mp4 $outfile; rm $outfile.mp4; chmod a+w $outfile";
  }
  return "";
}

sub pfs_cmd_google {
  return pfs_cmd_resize($_[0], $_[1], $_[2], 800, 533, 1);
}

sub pfs_cmd_normal {
  return pfs_cmd_resize($_[0], $_[1], $_[2], 580, 390, 1);
}

sub pfs_cmd_small {
  return pfs_cmd_resize($_[0], $_[1], $_[2], 300, 200, 1);
}

sub pfs_cmd_thumbnail {
  return pfs_cmd_resize($_[0], $_[1], $_[2], 150, 100, 1);
}

sub pfs_cmd_thumbnail_square {
  return pfs_cmd_resize($_[0], $_[1], $_[2], 200, 200, 1, 0, 200, 200, 1);
}

sub pfs_cmd_freeform {
  return pfs_cmd_resize($_[0], $_[1], $_[2], 900, 600, 1, 0, 0, 0, 1);
}

sub pfs_trash_image {
  my $imageID = $_[0];

  # First clear the 'cache'; clearing the cache needs the original
  # image to find the right file system to use, so the chached
  # versions must be removed before the original is moved out
  # of the way.
  pfs_discard_cache($imageID);

  my $setID = pcom_get_set($imageID);
  my $trashdir = pfs_get_set_basedir($setID) . "/../trash";

  my $rawfile = pfs_get_raw_location($imageID);
  my $origfile = pfs_get_orig_location($imageID);
  my $editedfile = pfs_get_edited_location($imageID);

  if ($rawfile ne "") {
    pcom_mv($rawfile, $trashdir);
    # in the case of a .gif, the first "get raw location" returns
    # the .mp4, the second gets the gif
    $rawfile = pfs_get_raw_location($imageID);
    if ($rawfile ne "") {
      pcom_mv($rawfile, $trashdir);
    }
  }
  if ($origfile ne "") {
    pcom_mv($origfile, $trashdir);
  }
  if ($editedfile ne "") {
    pcom_mv($editedfile, "$trashdir/$imageID.edited.jpg");
  }
}

sub pfs_discard_cache {
  my $imageID = $_[0];

  my $largefile = pfs_get_large_location($imageID);
  my $normalfile = pfs_get_normal_location($imageID);
  my $smallfile = pfs_get_small_location($imageID);
  my $thumbnailfile = pfs_get_thumbnail_location($imageID);

  if ($largefile ne "") {
    pcom_log($PCOM_DEBUG, "Delete file '$largefile'");
    pcom_rm($largefile);
    $largefile =~ s/\.jpg$/.mp4/;
    if (-f $largefile) {
      pcom_log($PCOM_DEBUG, "Delete movie file '$largefile'");
      pcom_rm($largefile);
    }
  }

  if ($normalfile ne "") {
    pcom_log($PCOM_DEBUG, "Delete file '$normalfile'");
    pcom_rm($normalfile);
  }

  if ($smallfile ne "") {
    pcom_log($PCOM_DEBUG, "Delete file '$smallfile'");
    pcom_rm($smallfile);
  }

  if ($thumbnailfile ne "") {
    pcom_log($PCOM_DEBUG, "Delete file '$thumbnailfile'");
    pcom_rm($thumbnailfile);
  }
}

# Try to delete a set from the file system.
#  - return 1 on success (set has been deleted)
#  - return 0 on failure (set directory still exists)
# This will fail if there are any files in the "tif" or "edited"
# directory of the set
sub pfs_delete_set {
  my $setID = $_[0];

  $basedir = pfs_get_set_basedir($setID);

  # Try removing the edited directory. If this fails, the set cannot
  # be deleted
  system("rmdir \"$basedir/edited\"");
  if (-d "$basedir/edited") {
    # Could not delete the edited directory, so deleting the set failed
    return 0;
  }

  # Try removing the tif directory. If this fails, need to re-establish
  # edited directory
  system("rmdir \"$basedir/tif\"");
  if (-d "$basedir/tif") {
    # Tif directory wasn't deleted
    mkdir("$basedir/edited");
    system("chmod a+w \"$basedir/edited\"");
    return 0;
  }

  # The remainder is generated files, so anything left there can be
  # removed
  system("rm -rf \"$basedir\"");
  return 1;
}

return 1;
