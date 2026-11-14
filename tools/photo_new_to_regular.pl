#!/usr/bin/perl -w

my $script = __FILE__;
my $localdir = ".";
if ($script =~ s/\/[^\/]*$//) {
  $localdir = $script;
}
push @INC, "$localdir/../inc";
push @INC, $localdir;

require localsettings;
require photos_util;
# require photos_common;

put_init();

# Iterate over the sets

my $iter = pdb_iter_set_new("001", 50);
pdb_iter_filter_category($iter, $PCOM_NEW);
my $setId = pdb_iter_next($iter);
while (defined($setId) && ($setId ne "")) {
  print "New set: $setId\n";
  pdb_open_set($setId);
  my $category = pdb_get_setcategory($setId);
  my $status = pdb_get_setstatus($setId);
  if ($category eq $PCOM_NEW) {
    pdb_set_setcategory($PCOM_REGULAR);
  }
  if ($status eq $PCOM_STAT_NEW) {
    pdb_set_setstatus($PCOM_STAT_AVAILABLE);
  }
  pdb_close_set();
  $setId = pdb_iter_next($iter);
}
pdb_iter_set_done($iter);

$iter = pdb_iter_set_new("001", 50);
pdb_iter_filter_status($iter, $PCOM_STAT_NEW);
$setId = pdb_iter_next($iter);
while (defined($setId) && ($setId ne "")) {
  print "New set: $setId\n";
  pdb_open_set($setId);
  my $category = pdb_get_setcategory($setId);
  my $status = pdb_get_setstatus($setId);
  if ($category eq $PCOM_NEW) {
    pdb_set_setcategory($PCOM_REGULAR);
  }
  if ($status eq $PCOM_STAT_NEW) {
    pdb_set_setstatus($PCOM_STAT_AVAILABLE);
  }
  pdb_close_set();
  $setId = pdb_iter_next($iter);
}
pdb_iter_set_done($iter);

# Now do the same for images
$iter = pdb_iter_new("00101", 50);
pdb_iter_filter_category($iter, $PCOM_NEW);
my $imageId = pdb_iter_next($iter);
while (defined($imageId) && ($imageId ne "")) {
  print "New image: $imageId\n";
  pdb_open_image($imageId);
  my $category = pdb_get_category($imageId);
  my $status = pdb_get_status($imageId);
  if ($category eq $PCOM_NEW) {
    pdb_set_category($PCOM_REGULAR);
  }
  if ($status eq $PCOM_STAT_NEW) {
    pdb_set_status($PCOM_STAT_AVAILABLE);
  }
  pdb_close_image();
  $imageId = pdb_iter_next($iter);
}
pdb_iter_done($iter);

$iter = pdb_iter_new("00101", 50);
pdb_iter_filter_status($iter, $PCOM_STAT_NEW);
$imageId = pdb_iter_next($iter);
while (defined($imageId) && ($imageId ne "")) {
  print "New image: $imageId\n";
  pdb_open_set($imageId);
  my $category = pdb_get_category($imageId);
  my $status = pdb_get_status($imageId);
  if ($category eq $PCOM_NEW) {
    pdb_set_category($PCOM_REGULAR);
  }
  if ($status eq $PCOM_STAT_NEW) {
    pdb_set_status($PCOM_STAT_AVAILABLE);
  }
  pdb_close_image();
  $imageId = pdb_iter_next($iter);
}
pdb_iter_done($iter);
