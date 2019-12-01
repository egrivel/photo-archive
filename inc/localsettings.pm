# ============================================================
# Generic Perl include file. This file will be the single
# place to put code which is system-dependent.
#
# This include file must be accessible by Perl in order
# for the other system files to be found.
# ============================================================

my $script = __FILE__;
my $localdir = ".";
if ($script =~ s/\/[^\/]*$//) {
  $localdir = $script;
}

my %settings = ();

if (-f "$localdir/../private/photos.ini") {
  open(FILE, "<$localdir/../private/photos.ini");
  while (<FILE>) {
    chomp;
    s/\r//;

    # Remove comments
    s/\s*\#.*$//;

    if (/^\s*([\w\-]+)\s*=\s*(.*?)\s*$/) {
      $settings{$1} = $2;
    }
  }
  close FILE;
}

sub setting_get {
  my $name = $_[0];

  if (defined($settings{$name})) {
    return $settings{$name};
  }

  return "";
}

sub is_dos {
  return 0;
  return (-d "c:/eric");
}

sub local_directory {
  my $dirtype = $_[0];

  if ($dirtype eq "photos") {
    return local_photos_directory();
  } elsif ($dirtype eq "photos2") {
    return local_photos2_directory();
  } else {
    die "Unknown directory type $dirtype in local_directory()";
  }
}

sub local_photos_directory {
  return setting_get("photosdir");
}

sub local_photos2_directory {
  return setting_get("photos2dir");
}

sub get_static_root {
  return setting_get("staticroot");
}

sub get_admin_email {
  return setting_get("admin-email");
}

sub get_map_key {
  return setting_get("google-map-key");
}

sub get_title {
  $title = setting_get("title");
  if ($title eq "") {
    return "Photo Archive";
  }
  return $title;
}

sub get_nr_cols {
  $nr = setting_get("nr-cols");
  if ($nr eq "") {
    return 12;
  }
  return $nr;
}

sub get_master {
  return setting_get("master");
}

return 1;
