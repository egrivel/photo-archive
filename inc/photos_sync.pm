use LWP::UserAgent;
use Time::HiRes qw(usleep);

my $gl_ua;

# Delays are in miliseconds
my $gl_file_delay = 500;
my $gl_api_delay = 100;

my $gl_nr_retries = 15;

sub psync_get_content {
  my $url = $_[0];
  my $retry = 0;

  if (!defined($gl_ua)) {
    $gl_ua = new LWP::UserAgent;
  }

  # usleep takes microseconds, so multiply miliseconds by 1000
  usleep($gl_api_delay * 1000);

  my $response;
  while (1) {
    $response = $gl_ua->get($url);
    if ($response->is_success) {
      last;
    }

    if (!($response->status_line =~ /no route to host/)) {
      # Seems to be getting this error a lot; just sleep for a second
      # and retry
      if ($retry < $gl_nr_retries) {
        print "Connection error, retry...\n";
        $retry++;
        usleep(2 * 1000 * 1000);
        next;
      }
      die "Still getting a connection error after $gl_nr_retries tries\n";
    }

    # Some other error, so die anyway
    if (!$response->is_success) {
      die "Error fetching url $url:\n  " . $response->status_line . "\n";
    }
  }

  return $response->decoded_content();
}

sub psync_post_content {
  my $url = $_[0];
  my $dataref = $_[1];
  # my $type = $_[1];
  # my $data = $_[2];
  # my $key = $_[3];

  if (!defined($gl_ua)) {
    $gl_ua = new LWP::UserAgent;
  }

  # usleep takes microseconds, so multiply miliseconds by 1000
  usleep($gl_api_delay * 1000);

  my $response;
  while (1) {
    $response = $gl_ua->post($url, $dataref);
    if ($response->is_success) {
      last;
    }

    if (!($response->status_line =~ /no route to host/)) {
      # Seems to be getting this error a lot; just sleep for a second
      # and retry
      if ($retry < $gl_nr_retries) {
        print "Connection error, retry...\n";
        $retry++;
        usleep(2 * 1000 * 1000);
        next;
      }
      die "Still getting a connection error after $gl_nr_retries tries\n";
    }

    # Some other error, so die anyway
    if (!$response->is_success) {
      die "Error fetching url $url:\n  " . $response->status_line . "\n";
    }
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
    if (!-d $root) {
      die("Root $root does not exist\n");
    }
    if (!-d "$root/$set") {
      mkdir("$root/$set");
      system("chmod a+w \"$root/$set\"");
    }
    if (!-d "$root/$set/$sub") {
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

  my $response = $gl_ua->get($url, ":content_file" => $fname);
  if (!$response->is_success) {
    unlink($fname);
    die "Failed to get file $fname from $url\n";
  }
}

sub psync_get_root_info {
  my $master = get_master();
  my $url = "$master";
  return psync_get_content($url);
}

sub psync_get_all_info {
  my $master = get_master();
  my $url = "$master?type=all";
  return psync_get_content($url);
}

sub psync_get_users_info {
  my $master = get_master();
  my $url = "$master?type=users";
  return psync_get_content($url);
}

sub psync_get_all_persons_info {
  my $master = get_master();
  my $url = "$master?type=persons";
  return psync_get_content($url);
}

sub psync_get_person_info {
  my $personid = $_[0];
  my $master = get_master();
  my $url = "$master?type=person&value=$personid";
  return psync_get_content($url);
}

sub psync_get_all_years_info {
  my $master = get_master();
  my $url = "$master?type=years";
  return psync_get_content($url);
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

sub psync_put_data {
  my $type = $_[0];
  my $data = $_[1];
  my $key = $_[2];

  my $master = get_master();
  my $url = "$master";
  my $payloadref = {'put' => $type, 'data' => $data, 'key' => $key};
  my $response = psync_post_content($url, $payloadref);
  $response =~ s/^\s*(.*?)\s*$/$1/s;
  if ($response ne "OK") {
    die "Putting data $url for $type resulted in '$response'\n";
  }
}

sub psync_del_data {
  my $type = $_[0];
  my $id = $_[1];
  my $key = $_[2];

  my $master = get_master();
  my $url = "$master";
  my $payloadref = {'del' => $type, 'id' => $id, 'key' => $key};
  # Note: use a 'put' to keep they key encrypted
  my $response = psync_post_content($url, $payloadref);
  $response =~ s/^\s*(.*?)\s*$/$1/s;
  if ($response ne "OK") {
    die "Delete $type, $id resulted in '$response'\n";
  }
}

sub psync_hash_data {
  my $type = $_[0];
  my $data = $_[1];
  my $key = $_[2];

  my $master = get_master();
  my $url = "$master";
  my $payloadref = {'hash' => $type, 'data' => $data, 'key' => $key};
  my $response = psync_post_content($url, $payloadref);
  $response =~ s/^\s*(.*?)\s*$/$1/s;
  if ($response ne "OK") {
    die "Hash update $url for $type resulted in '$response'\n";
  }
}

return 1;
