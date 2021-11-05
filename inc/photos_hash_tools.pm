# This file provides hash tools without having to have the whole database
# setup.

sub phash_do_hash_file {
  my $fname = $_[0];

  if (! -f $fname) {
    die "File '$fname' not found\n";
  }
  
  my $cmd = "sha256sum \"$fname\"";
  open(PIPE, "$cmd|") || die "Cannot get hash for '$fname'\n";
  my $text = <PIPE>;
  close(PIPE);
  $file_hash = "";
  if ($text =~ /^([\w\-]+)/) {
    $file_hash = $1;
  }
  
  return $file_hash;
}

return 1;
