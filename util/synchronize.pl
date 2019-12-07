#!/usr/bin/perl

use Digest::SHA qw(sha256_hex sha256_base64);
use LWP::UserAgent;

my $script = __FILE__;
my $localdir = ".";
if ($script =~ s/\/[^\/]*$//) {
  $localdir = $script;
}
push @INC, "$localdir/../cgi-bin";

require "inc_all.pm";

pdb_init();
my $ua = new LWP::UserAgent;

print "============================================================\n";
print "Synchronizing with the master database\n";
print "============================================================\n";
print "\n";

$master = get_master();
if ($master eq "") {
  print "ERROR: no master database defined. Exiting.\n\n";
  exit(0);
}

my $resp = get_content($master);
my $all_hash = "";
if ($resp =~ /^all: (\w+)/) {
  $all_hash = $1;
}
print "Got response from master server $master:\n   $all_hash\n\n";

my $current_hash = phash_get_value("all");
if ($all_hash eq $current_hash) {
  print "Hash is current, done!\n\n";
  exit(0);
}

print "Current hash: $current_hash\n\n";

pdb_sync_image("d02", "d0201");

sub get_content {
  my $url = $_[0];

  my $response = $ua->get($url);
  if (! $response->is_success) {
    die "Error fetching url $url:\n  "
      . $response->status_line . "\n";
  }
  return $response->content;
}
