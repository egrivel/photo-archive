use photos_common;

my $pht_sessionid = "";
my $pht_title = "";
my $pht_banner = "";
my $pht_copyright = "";
my $pht_refresh = "";
my $pht_pagetype = "default";
my $pht_extra_header = "";
my $pht_css_file = "photos.css";
my $pht_systemmessage = "";

sub pht_init {
}

sub pht_set_sessionid {
    $pht_sessionid = $_[0];
}

#
# Retrieve a previously set session ID. If no session ID was previously
# set, retrieve the session ID from the request. Note: the typical use
# will be to retrieve the session ID from the request.
# Note 2: once the session ID has been retrieved from the request, there
# is no need to set it again. Of course, it is always possible to set it
# to something else.
#
sub pht_get_sessionid {
    # First check for an explicit session ID in the request
    my $arg = parg_get("_session");
    if ($arg ne "") {
        $pht_sessionid = $arg;
    } else {
        my $cookies = $ENV{"HTTP_COOKIE"};
        if (!defined($cookies)) {
            return "";
        }

        my @cookies = split(/;\s*/, $cookies);
        my $nr = 0;
        for ($nr = 0; defined($cookies[$nr]); $nr++) {
            if ($cookies[$nr] =~ /^(\w+)=(.*)$/) {
                my $name = $1;
                my $value = $2;
                if ($name eq "sessionid") {
                    $pht_sessionid = $value;
                }
            }
        }
    }
    return $pht_sessionid;
}

sub pht_set_title {
    $pht_title = $_[0];
}

sub pht_set_systemmessage {
    $pht_systemmessage = $_[0];
}

sub pht_set_css {
    $pht_css_file = $_[0];
}

sub pht_set_banner {
    $pht_banner = $_[0];
}

sub pht_set_copyright {
    $pht_copyright = $_[0];
}

sub pht_set_pagetype {
    $pht_pagetype = $_[0];
}

#
# Add to the HTML header.
#
sub pht_add_header {
    $pht_extra_header .= $_[0];
}

sub pht_set_refresh {
    $pht_refresh = $_[0];
}

#
# Output the start of the page, up to and including the title (unless the
# do_title argument is false).
# This starts the output, including handling of cookies.
#
sub pht_page_start {
    my $do_title = $_[0];
    my $do_body = $_[1];

    my $staticroot = get_static_root();

    if (!defined($do_title)) {
        $do_title = 1;
    }
    if (!defined($do_body)) {
        $do_body = 1;
    }
    my $title = $pht_title;
    if ($title eq "") {
        $title = "Photos System";
    }
    print "content-type: text/html; charset=utf-8\n";
    if ($pht_sessionid ne "") {
        print "set-cookie: sessionid=$pht_sessionid\n";
    }
    if ($pht_refresh ne "") {
        print "refresh: $pht_refresh\n";
    }
    print "\n";
    print "<!DOCTYPE html PUBLIC \"-//W3C//DTD XHTML 1.0 Strict//EN\"\n";
    print "        \"http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd\">\n";
    print "<html xmlns='http://www.w3.org/1999/xhtml'>\n";
    print "<head>\n";
    print "   <meta http-equiv='X-UA-Compatible' content='IE=edge' />\n";
    print "   <meta name='viewport' content='width=device-width, initial-scale=1' />\n";
    print "   <meta http-equiv='content-type' content='text/html; charset=utf-8' />\n";
    print "   <title>$title</title>\n";
    print "   <link rel='stylesheet' type='text/css' href='$staticroot/css/$pht_css_file' ";
    print "title='FotoStyles' />\n";
    print "   <link rel='shortcut icon' href='$staticroot/images/photo_favicon.ico'/>\n";
    print "   <script type='text/javascript' \n";
    print "           src='$staticroot/js/photos.js'></script>\n";
    print $pht_extra_header;
    print "</head>\n";
    print "\n";
    if ($do_body) {
        print "<body class='$pht_pagetype'>\n";
        print "<div class='banner'>$pht_banner</div>\n" if ($pht_banner ne "");
        print "<h1>$title</h1>\n" if ($do_title);
    }
}

#
# Output content on the page
#
sub pht_output {
    print $_[0];
}

sub pht_error_message {
    my $msg = $_[0];

    if ($msg ne "") {
        print "<p style='color: red; font-weight: bold;'>$msg</p>\n";
    }
}


#
# Output the copyright (unless the do_copyright argument is false) and
# the end of the page
#
sub pht_page_end {
    my $do_copyright = $_[0];
    if (!defined($do_copyright)) {
        $do_copyright = 1;
    }

    if ($do_copyright) {
        my $copyright = $pht_copyright;
        if ($copyright eq "") {
            my $year = pcom_current_year();
            my $default = setting_get("default-copyright");
            $copyright = "Copyright &copy;$year by $default. All Rights Reserved.";
        }
#        print "<hr />\n";
        print "<div class='footer'><hr />$copyright</div>\n";
    }
    print "</body>\n";
    print "</html>\n";
}

# Redirect the browser somewhere else
sub pht_redirect {
    my $target = $_[0];

    print "location: $target\n";
    if ($pht_sessionid ne "") {
        print "set-cookie: sessionid=$pht_sessionid\n";
    }
    print "\n";
}

sub pht_tabs_start {
    pht_output "<div class='tabs'>\n";
}

sub pht_tabs_end {
    pht_output "</div>\n";
    if ($pht_systemmessage ne "") {
        pht_output "<div class='systemmessage'><h2>";
        pht_output "$pht_systemmessage";
        pht_output "</h2></div>\n";
    }
}

sub pht_tab {
    my $label = $_[0];
    my $link = $_[1];
    my $id = $_[2];

    if (defined($id)) {
        pht_output "<span class='tab' id='$id'>";
    } else {
        pht_output "<span class='tab'>";
    }
    if ($link ne "") {
        $link =~ s/[^<>]*<\/a>$//;
        pht_output "$link$label</a>";
    } else {
        pht_output $label;
    }
    pht_output "</span>\n";
}

sub pht_prev_tab {
    pht_tab("&#8249;&#8249; prev", $_[0], "prevlink");
}

sub pht_next_tab {
    pht_tab("next &#8250;&#8250;", $_[0], "nextlink");
}

#
# Escape a value parameter. This provides the proper HTML escape for
# value='...' attributes. Note: for value attributes, the ampersand
# indicating the start of an HTML entity is changed to an &amp; entity.
#
sub pht_value_escape {
    my $value = $_[0];
    $value =~ s/&/&amp;/sg;
    $value =~ s/\'/&apos;/sg;
    return $value;
}

sub pht_url_escape {
    my $value = $_[0];
    $value =~ s/([^A-Za-z0-9])/sprintf("%%%2.2X", ord($1))/ge;
    return $value;
}

#
# Escape a title parameter. This provides the proper HTML escape for
# title='...' attributes. Note: for title attibutes, only the single-quote
# is change to an apostrophe sequence. All other special characters remain
# the way they are.
#
sub pht_title_escape {
    my $title = $_[0];
    $title =~ s/'/&apos;/sg;
    return $title;
}

return 1;
