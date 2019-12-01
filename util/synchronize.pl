#!/usr/bin/perl

use Digest::SHA qw(sha256_hex sha256_base64);

my $script = __FILE__;
my $localdir = ".";
if ($script =~ s/\/[^\/]*$//) {
  $localdir = $script;
}
push @INC, "$localdir/../cgi-bin";

require "inc_all.pm";

pdb_init();

$master = get_master();
