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

print "============================================================\n";
print "Synchronizing with the master database\n";
print "============================================================\n";
print "\n";

my $root_info = psync_get_root_info();
if ($root_info =~ /^all: (\w+)\n/) {
  my $server_root = $1;
  my $root_hash = phash_get_value("all");
  if ($root_hash eq $server_root) {
    print "Everything is current, done!\n";
    exit(0);
  }
}

my $all_info = psync_get_all_info();

print "All info:\n$all_info\n" if ($gl_debug);

if ($all_info =~ /users: (\w+)/) {
  my $server_users = $1;
  my $users_hash = phash_get_value("users");
  if ($users_hash ne $server_users) {
    print "Users need updating\n   $users_hash\n   => $server_users\n";
    pusr_sync_users($gl_debug);
  }
}

if ($all_info =~ /persons: (\w+)/) {
  my $server_persons = $1;
  my $persons_hash = phash_get_value("persons");
  if ($persons_hash ne $server_persons) {
    print "Persons need updating\n   $persons_hash\n   => $server_persons\n";
    ppers_sync_all_persons();
  }
}

if ($all_info =~ /years: (\w+)/) {
  my $server_years = $1;
  my $years_hash = phash_get_value("years");
  if ($years_hash ne $server_years) {
    print "Years need updating\n   $years_hash\n   => $server_years\n";
    pdb_sync_all_years($gl_debug);
  }
}
