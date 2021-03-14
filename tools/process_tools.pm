sub set_database_info {
  my $imageid = $_[0];
  my $do_portrait = $_[1];
  my $do_rotate = $_[2];
  my $latlong = $_[3];
  my $timezone = $_[4];
  my $dst = $_[5];
  my $is_mov = $_[6];
  my $is_kids = $_[7];
  my $is_freeform = $_[8];
  my $do_force = $_[9];
  my @monthnames = (
    "", "January", "February", "March", "April", "May",
    "June", "July", "August", "September", "October", "November",
    "December"
  );

  if (!defined($do_force)) {
    $do_force = 0;
  }

  my $setid = pcom_get_set($imageid);
  my $do_create = !pdb_set_info($setid);
  if ($do_force && !$do_create) {
    if (!defined($gl_created_set[$setid])) {
      $do_create = 1;
      $gl_created_set[$setid] = 1;
    }
  }
  if ($do_create || !pdb_set_info($setid)) {
    # Set does not yet exist; add it
    print "Create set $setid\n";
    pdb_open_set($setid);
    # default some fields
    pdb_set_settitle("");
    pdb_set_setcopyright("");
    pdb_set_setdescription("");
    pdb_set_setcomment("");

    pdb_set_setsortid(pdb_create_setsortid($setid));
    if ($imageid =~ /^(\d\d\d\d)(\d\d)(\d\d)\-(\d\d)(\d\d)(\d\d)/) {
      my $year = int($1);
      my $month = int($2);
      my $day = int($3);
      my $monthname = $monthnames[$month];
      pdb_set_setdatetime("$monthname $day, $year");
      pdb_set_setyear($year);
    } elsif ($imageid =~ /^(\w\d\d)(\d\d\w?)$/) {
      pdb_set_setdatetime("");
      pdb_set_setyear(pcom_get_year($setid));
    }
    if ($is_kids) {
      pdb_set_setcategory($PCOM_KIDS);
    } else {
      pdb_set_setcategory($PCOM_NEW);
    }
    pdb_close_set();
  }

  if ($do_force || !pdb_image_info($imageid)) {
    if ($imageid =~ /^(\d\d\d\d)(\d\d)(\d\d)\-(\d\d)(\d\d)(\d\d)/) {
      pdb_open_image($imageid);
      my $year = int($1);
      my $month = int($2);
      my $day = int($3);
      my $hour = int($4);
      my $minute = $5;
      my $second = $6;

      pdb_set_sortid(pdb_create_sortid($imageid, $timezone, $dst));
      pdb_set_setid($setid);
      my $monthname = $monthnames[$month];
      pdb_set_datetime("$monthname $day, $year $hour:$minute:$second");
      pdb_set_year($year);
      if ($is_freeform) {
        pdb_set_orientation($do_portrait ? $PCOM_FREEFORM_P : $PCOM_FREEFORM_L);
      } else {
        pdb_set_orientation($do_portrait ? $PCOM_PORTRAIT : $PCOM_LANDSCAPE);
      }
      if ($is_kids) {
        pdb_set_category($PCOM_KIDS);
      } else {
        pdb_set_category($PCOM_NEW);
      }
      pdb_set_quality($PCOM_QUAL_DEFAULT);
      pdb_set_latlong($latlong);
      if ($is_mov) {
        pdb_set_type("MOV");
      }
      my $rotation = 0;
      if ($do_rotate == 90) {
        $rotation = 90;
      } elsif ($do_rotate == -90) {
        $rotation = 270;
      }
      pdb_set_rotation($rotation);
      pdb_close_image();
    } elsif ($imageid =~ /^(\w\d\d)(\d\d\w?)$/) {
      pdb_open_image($imageid);

      pdb_set_sortid(pdb_create_sortid($imageid, $timezone, $dst));
      pdb_set_setid($setid);
      pdb_set_datetime("");
      pdb_set_year(pcom_get_year($setid));
      if ($is_freeform) {
        pdb_set_orientation($do_portrait ? $PCOM_FREEFORM_P : $PCOM_FREEFORM_L);
      } else {
        pdb_set_orientation($do_portrait ? $PCOM_PORTRAIT : $PCOM_LANDSCAPE);
      }
      if ($is_kids) {
        pdb_set_category($PCOM_KIDS);
      } else {
        pdb_set_category($PCOM_NEW);
      }
      pdb_set_quality($PCOM_QUAL_DEFAULT);
      pdb_set_latlong($latlong);
      if ($is_mov) {
        pdb_set_type("MOV");
      }
      my $rotation = 0;
      if ($do_rotate == 90) {
        $rotation = 90;
      } elsif ($do_rotate == -90) {
        $rotation = 270;
      }
      pdb_set_rotation($rotation);
      pdb_close_image();
    } else {
      warn "Cannot recognize image format '$imageid' to add to database\n";
    }
  } else {
    warn "Image '$imageid' already in database (not added)\n";
  }
}

return 1;
