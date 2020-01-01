use LWP::UserAgent;
use Time::HiRes qw(usleep);

my $gl_ua;

# Delays are in miliseconds
my $gl_file_delay = 500;
my $gl_api_delay = 100;

sub psync_get_content {
  my $url = $_[0];

  if (!defined($gl_ua)) {
    $gl_ua = new LWP::UserAgent;
  }

  # usleep takes microseconds, so multiply miliseconds by 1000
  usleep($gl_api_delay * 1000);

  my $response = $gl_ua->get($url);
  if (! $response->is_success) {
    die "Error fetching url $url:\n  "
      . $response->status_line . "\n";
  }
  return $response->decoded_content();
}

sub psync_get_file {
  my $url = $_[0];
  my $fname = $_[1];

  if ($fname =~ /^(.*?)\/([\w\-]+)\/(\w+)\/([\w\-\.]+)$/) {
    my $root = $1;
    my $set = $2;
    my $sub = $3;
    my $img = $4;
    if (! -d $root) {
      die ("Root $root does not exist\n");
    }
    if (! -d "$root/$set") {
      mkdir("$root/$set");
      system("chmod a+w \"$root/$set\"");
    }
    if (! -d "$root/$set/$sub") {
      mkdir("$root/$set/$sub");
      system("chmod a+w \"$root/$set/$sub\"");
    }
  }

  print "sync $url $fname\n";
  if (!defined($gl_ua)) {
    $gl_ua = new LWP::UserAgent;
  }

  # usleep takes microseconds, so multiply miliseconds by 1000
  usleep($gl_file_delay * 1000);

  my $response = $gl_ua->get($url, ":content_file"=>$fname);
  if (! $response->is_success) {
    unlink($fname);
    die "Failed to get file $fname from $url\n";
  }
}

sub psync_get_year_info {
  my $id = $_[0];

  my $master = get_master();
  my $url = "$master?type=year&value=$id";
  return psync_get_content($url);
}

sub psync_get_set_info {
  my $id = $_[0];

  my $master = get_master();
  my $url = "$master?type=set&value=$id";
  return psync_get_content($url);
}

sub psync_get_image_info {
  my $id = $_[0];

  my $master = get_master();
  my $url = "$master?type=image&value=$id";
  $content = psync_get_content($url);
  return $content;
}

sub psync_retrieve_file {
  my $set = $_[0];
  my $fileid = $_[1];

  my $master = get_master();
  my $root = local_photos_directory();
  my $url = "$master?set=$set&file=$fileid";
  psync_get_file($url, "$root/$set/$fileid");
}

return 1;
