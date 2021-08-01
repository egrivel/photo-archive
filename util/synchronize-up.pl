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
    my $instead = $1;
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
      sync_single_person($person, 0);
    } elsif ($local_persons{$person} ne $remote_persons{$person}) {
      print "Person $person is different remotely, must be updated.\n";
      sync_single_person($person, 0);
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
}

sub sync_years {
  my $server_hash = $_[0];
  my $local_hash = phash_get_value("years");

  print "Years:\nlocal : $local_hash\nserver: $server_hash\n" if ($gl_debug);
  if ($local_hash eq $server_hash) {
    print "Years are up-to-date\n\n" if ($gl_debug);
    return;
  }

  print "Sync years not yet inplemented\n\n";
}
