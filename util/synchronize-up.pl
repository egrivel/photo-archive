#!/usr/bin/perl

my $script = __FILE__;
my $localdir = ".";
if ($script =~ s/\/[^\/]*$//) {
  $localdir = $script;
}
push @INC, "$localdir/../inc";

my $gl_debug = 0;

my $arg = shift;
while (defined($arg)) {
  if ($arg eq "--debug") {
    $gl_debug = 1;
  }
  $arg = shift;
}

require "photos_util.pm";

put_init();

my $gl_key = get_master_key();
if (!defined($gl_key) || $gl_key eq "") {
  die "No master key specified, abort!\n";
}

print "============================================================\n";
print "Synchronizing to the database copy\n";
print "============================================================\n";
print "\n";

sync_all();
exit(0);

sub sync_all {
  my $local_hash = phash_get_value("all");
  my $server_hash = "";

  my $root_info = psync_get_root_info();
  if ($root_info =~ /^all: (\w+)\n/) {
    $server_hash = $1;
  } else {
    print "ERROR: Cannot get root info from server, got:\n$root_info\n";
    exit(0);
  }

  if ($local_hash eq $server_hash) {
    print "Server copy is up-to-date\n";
    return;
  }

  my $all_info = psync_get_all_info();

  print "All info:\n$all_info\n" if ($gl_debug);

  if ($all_info =~ /users: (\w+)/) {
    sync_users($1);
  }

  if ($all_info =~ /persons: (\w+)/) {
    sync_persons($1);
  }

  if ($all_info =~ /years: (\w+)/) {
    sync_years($1);
  }
}

sub sync_users {
  my $remote_hash = $_[0];
  my $local_hash = phash_get_value("users");

  print "Users:\nlocal : $local_hash\nremote: $remote_hash\n" if ($gl_debug);
  if ($local_hash eq $remote_hash) {
    print "Users are up-to-date\n\n" if ($gl_debug);
    return;
  }

  my $local_text = pusr_get_hash_text();
  my %local_users = ();
  while ($local_text =~ s/^(\w+):\s+([^\n]+)\n//) {
    my $name = $1;
    my $value = $2;
    if (defined($local_users{$name})) {
      print "ERROR: user $name listed multiple times in local list\n";
      return;
    }
    $local_users{$name} = $value;
  }

  my $remote_text = psync_get_users_info();
  my %remote_users = ();
  while ($remote_text =~ s/^(\w+):\s+([^\n]+)\n//) {
    my $name = $1;
    my $value = $2;
    if (defined($remote_users{$name})) {
      print "ERROR: user $name listed multiple times in remote list\n";
      return;
    }
    $remote_users{$name} = $value;
  }

  my $user;
  foreach $user (keys %local_users) {
    if (!defined($remote_users{$user})) {
      print "User $user does not exist remotely, must be added.\n";
      print $local_users{$user} . "\n";
      psync_put_data("user", $local_users{$user}, $gl_key);
    } elsif ($local_users{$user} ne $remote_users{$user}) {
      print "User $user is different remotely, must be updated.\n";
      psync_put_data("user", $local_users{$user}, $gl_key);
    }
  }
  foreach $user (keys %remote_users) {
    if (!defined($local_users{$user})) {
      print "User $user does not exist locally, must be removed.\n";
      psync_del_data("user", $user, $gl_key);
    }
  }
}

sub sync_persons {
  my $server_hash = $_[0];
  my $local_hash = phash_get_value("persons");

  print "Persons:\nlocal : $local_hash\nserver: $server_hash\n" if ($gl_debug);
  if ($local_hash eq $server_hash) {
    print "Persons are up-to-date\n\n" if ($gl_debug);
    return;
  }

  my $local_text = ppers_get_all_persons_text(0);
  my %local_persons = ();
  while ($local_text =~ s/^([\w-]+):\s+([^\n]+)\n//) {
    my $id = $1;
    my $value = $2;
    if (defined($local_persons{$id})) {
      print "ERROR: person $name listed multiple times in local list\n";
      return;
    }
    $local_persons{$id} = $value;
  }

  my $remote_text = psync_get_all_persons_info();
  my %remote_persons = ();
  while ($remote_text =~ s/^([\w-]+):\s+([^\n]+)\n//) {
    my $id = $1;
    my $value = $2;
    if (defined($remote_persons{$id})) {
      print "ERROR: person $id listed multiple times in remote list\n";
      return;
    }
    $remote_persons{$id} = $value;
  }

  my $person;
  foreach $person (keys %local_persons) {
    if (!defined($remote_persons{$person})) {
      print "Person $person does not exist remotely, must be added.\n";
      sync_single_person($person);
    } elsif ($local_persons{$person} ne $remote_persons{$person}) {
      print "Person $person is different remotely, must be updated.\n";
      sync_single_person($person);
    }
  }
  foreach $person (keys %remote_persons) {
    if (!defined($local_persons{$person})) {
      print "Person $person does not exist locally, must be removed.\n";
      psync_del_data("person", $person, $gl_key);
    }
  }
}

sub sync_single_person {
  my $person = $_[0];

  my $local_text = ppers_get_person_text($person, $do_update);
  print "person $person: $local_text\n";
  psync_put_data("person", $local_text, $gl_key);
  print "done putting person\n\n";
}

sub sync_years {
  my $server_hash = $_[0];
  my $local_hash = phash_get_value("years");

  print "Years:\nlocal : $local_hash\nserver: $server_hash\n" if ($gl_debug);
  if ($local_hash eq $server_hash) {
    print "Years are up-to-date\n\n" if ($gl_debug);
    return;
  }

  my $local_text = pdb_get_all_years_hash_text(0);
  my %local_years = ();
  while ($local_text =~ s/(\d\d\d\d): (\w+)\s*//s) {
    $local_years{$1} = $2;
  }

  my $remote_text = psync_get_all_years_info();
  my %remote_years = ();
  while ($remote_text =~ s/(\d\d\d\d): (\w+)\s*//s) {
    $remote_years{$1} = $2;
  }

  my $year;
  foreach $year (keys %local_years) {
    if (!defined($remote_years{$year})) {
      print "Year $year does not exist remotely, must be added.\n";
      sync_single_year($year);
    } elsif ($local_years{$year} ne $remote_years{$year}) {
      print "Year $year is different remotely, must be updated.\n";
      sync_single_year($year);
    }
  }
  foreach $year (keys %remote_years) {
    if (!defined($local_years{$year})) {
      print "Year $year does not exist locally, must be removed.\n";
      die "Removing remote year not yet implemented.\n";
    }
  }
}

sub sync_single_year {
  my $year = $_[0];

  my $local_text = pdb_get_year_hash_text($year, 0);
  print "Year $year: local text $local_text\n";
  my %local_sets = ();
  while ($local_text =~ s/^(\w+):\s+(\w+)?\n//s) {
    $local_sets{$1} = $2;
  }

  my $remote_text = psync_get_year_info($year);
  print "Year $year: remote text $remote_text\n";
  my %remote_sets = ();
  while ($remote_text =~ s/^(\w+):\s+(\w+)?\n//s) {
    $remote_sets{$1} = $2;
  }

  my $set;
  foreach $set (keys %local_sets) {
    if (!defined($remote_sets{$set})) {
      print "Set $set does not exist remotely, but be added.\n";
      sync_single_set($set);
    } elsif ($local_sets{$set} ne $remote_sets{$set}) {
      print "Set $set is different remotely, must be updated.\n";
      sync_single_set($set);
    }
  }

  foreach $set (keys %remote_sets) {
    if (!defined($local_set{$set})) {
      print "Set $set does not exist locally, must be removed.\n";
      die "Removing remote set not yet implemented.\n";
    }
  }

  psync_hash_data("year", $year, $gl_key);
}

sub sync_single_set {
  my $set = $_[0];

  my $local_text = pdb_get_set_hash_text($set, 0);
  print "Set $set: local text $local_text\n";
  my $local_database = "";
  if ($local_text =~ s/^database:\s+([^\n]*)\n//s) {
    $local_database = $1;
  }
  my %local_images = ();
  while ($local_text =~ s/^([\w-]+): (\w+)\n?//s) {
    $local_images{$1} = $2;
  }

  my $remote_text = psync_get_set_info($set);
  print "Set $set: remote text $remote_text\n";
  my $remote_database = "";
  if ($remote_text =~ s/^database:\s+([^\n]*)\n//s) {
    $remote_database = $1;
  }
  my %remote_images = ();
  while ($remote_text =~ s/^([\w-]+): (\w+)\n?//s) {
    $remote_images{$1} = $2;
  }

  if ($local_database ne $remote_database) {
    if ($local_database eq "") {
      print "Set $set does not exist locally, must be removed.\n";
      die "Removing remote set not yet implemented.\n";
    } else {
      psync_put_data("set", $local_database, $gl_key);
    }
  }

  my $image;
  foreach $image (keys %local_images) {
    if (!defined($remote_images{$image})) {
      print "Image $image does not exist remotely, must be added.\n";
      psync_single_image($image, $set);
    } elsif ($local_images{$image} ne $remote_images{$image}) {
      print "Image $image is different remotely, must be updated.\n";
      psync_single_image($image, $set);
    }
  }
  foreach $image (keys %remote_images) {
    if (!defined($local_imags{$image})) {
      print "Image $image does not exist locally, must be removed.\n";
      psync_del_data("image", $image, $gl_key);
    }
  }

  psync_hash_data("set", $set, $gl_key);
}

sub psync_single_image {
  my $image = $_[0];
  my $set = $_[1];

  my $local_text = pdb_get_image_hash_text($image, $set, 0);
  print "Image $image: local text $local_text\n";
  my $local_database = "";
  if ($local_text =~ s/^database:\s+([^\n]*)\n//s) {
    $local_database = $1;
  }
  my %local_files = ();
  while ($local_text =~ s/^([\w\/\.-]+): (\w+)\n?//s) {
    $local_files{$1} = $2;
  }

  my $remote_text = psync_get_image_info($image);
  print "Image $image: remote text $remote_text\n";
  my $remote_database = "";
  if ($remote_text =~ s/^database:\s+([^\n]*)\n//s) {
    $remote_database = $1;
  }
  my %remote_files = ();
  while ($remote_text =~ s/^([\w\/\.-]+): (\w+)\n?//s) {
    $remote_files{$1} = $2;
  }

  if ($local_database ne $remote_database) {
    if ($local_database eq "") {
      print "Image $image does not exist locally, must be removed.\n";
      die "Removing remote image not yet implemented.\n";
    } else {
      psync_put_data("image", $local_database, $gl_key);
    }
  }

  my $file;
  foreach $file (keys %local_files) {
    if (!defined($remote_files{$file})) {
      print "File $file does not exist remotely, must be added.\n";
      psync_single_file($file, $set);
    } elsif ($local_files{$file} ne $remote_files{$file}) {
      print "File $file is different remotely, must be updated.\n";
      psync_single_file($file, $set);
    }
  }
  foreach $file (keys %remote_images) {
    if (!defined($local_imags{$file})) {
      print "Image $image does not exist locally, must be removed.\n";
      psync_del_data("file", $file, $gl_key);
    }
  }

  psync_hash_data("image", "$set:$image", $gl_key);
}

sub psync_single_file {
  my $fname = $_[0];
  my $set = $_[1];

  my $basedir = pfs_get_set_basedir($set);
  my $fullname = "$basedir/$fname";
  if (!-f $fullname) {
    print "Cannot read '$fname'\n";
  }
  open(FILE, "base64 \"$fullname\"|") || die "Cannot parse $fname\n";
  my $data = "";
  while (<FILE>) {
    chomp();
    s/[\r\n]//s;
    $data .= $_;
  }
  close FILE;

  # print "Got for file $fname:\n$data\n";
  psync_put_data("file", "$fname:$set:$data", $gl_key);
  print "sent data for $fname\n";
}
