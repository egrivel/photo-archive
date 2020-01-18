#!/usr/bin/perl

my $script = __FILE__;
my $localdir = ".";
if ($script =~ s/\/[^\/]*$//) {
  $localdir = $script;
}
push @INC, "$localdir/../inc";

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

if ($all_info =~ /users: (\w+)/) {
  my $server_users = $1;
  my $users_hash = phash_get_value("users");
  if ($users_hash ne $server_users) {
    print "Users need updating\n   $users_hash\n   => $server_users\n";
    pusr_sync_users();
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
    pdb_sync_all_years();
  }
}

# pdb_sync_all_years();
# pdb_sync_year("1957");
# pdb_sync_year("1958");
# pdb_sync_year("1959");
# pdb_sync_year("1960");
# pdb_sync_year("1961");
# pdb_sync_year("1962");
# pdb_sync_year("1963");
# pdb_sync_year("1964");
# pdb_sync_year("1965");
# pdb_sync_year("1966");
# pdb_sync_year("1967");
# pdb_sync_year("1968");
# pdb_sync_year("1969");
# pdb_sync_year("1970");
# pdb_sync_year("1971");
# pdb_sync_year("1972");
# pdb_sync_year("1973");
# pdb_sync_year("1974");
# pdb_sync_year("1975");
# pdb_sync_year("1976");
# pdb_sync_year("1977");
# pdb_sync_year("1978");
# pdb_sync_year("1979");
# pdb_sync_year("1980");
# pdb_sync_year("1981");
# pdb_sync_year("1982");
# pdb_sync_year("1983");
# pdb_sync_year("1984");
# pdb_sync_year("1985");
# pdb_sync_year("1986");
# pdb_sync_year("1987");
# pdb_sync_year("1988");
# pdb_sync_year("1989");
# pdb_sync_year("1990");
# pdb_sync_year("1991");
# pdb_sync_year("1992");
# pdb_sync_year("1993");
# pdb_sync_year("1994");
# pdb_sync_year("1995");
# pdb_sync_year("1996");
# pdb_sync_year("1997");
# pdb_sync_year("1998");
# pdb_sync_year("1999");
# pdb_sync_year("2000");
# pdb_sync_year("2001");
# pdb_sync_year("2002");
# pdb_sync_year("2003");
# pdb_sync_year("2004");
# pdb_sync_year("2005");
# pdb_sync_year("2006");
# pdb_sync_year("2007");
# pdb_sync_year("2008");
# pdb_sync_year("2009");
# pdb_sync_year("2010");
# pdb_sync_year("2011");
# pdb_sync_year("2012");
# pdb_sync_year("2013");
# pdb_sync_year("2014");
# pdb_sync_year("2015");
# pdb_sync_year("2016");
# pdb_sync_year("2017");
# pdb_sync_year("2019");
# pdb_sync_year("2018");
# pdb_sync_year("2020");
