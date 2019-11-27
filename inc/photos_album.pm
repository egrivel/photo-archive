# ------------------------------------------------------------
# Photo Album Database Module
#
# A photo album has the following properties:
#  - album id
#  - album title
#  - album owner (who created the album)
#  - description
#  - category (regular, private, experimental, etc.)
#  - keywords?
#  - individual pages
#
# Album pages have:
#  - a sequential page number
#  - a layout to be used for the page
#  - a page title
#
# Page items have:
#  - an item ID
#  - a photo ID
#  - formatted text (allows bold, italics, underline,
#    hyperlinks only)
#
# A page layout is implemented through a CSS file. The HTML
# generated consists of a series of <div> elements with the
# respective item IDs (the item ID is the layout ID plus the
# item sequence number). The <div> contains the photo, the
# text, or both if both exist (if both exist, the photo comes
# first, followed by a <br />, then the text).
#
# Initially, there is only a single layout, called "plain",
# which has a single item. 
# ------------------------------------------------------------

use photos_common;
use photos_sql;

my @album_fields = ("albumid",
                    "sortid",
                    "ownerid",
                    "title",
                    "description",
                    );

my @album_item_fields = ("albumid",
                         "linenr",
                         "imageid",
                         "title",
                         "description",
                         );

my @album_user_fields = ("albumid",
                         "userid",
                         );

my $alb_cur_album = "";
my %alb_data = ();
my $alb_cur_page = -1;
my %alb_page_data = ();
my @alb_page_texts = ();
my @alb_page_textsizes = ();
my @alb_page_photos = ();

my $alb_datadir = pcom_photo_root() . "/albums/data";
my $alb_datadir2 = pcom_photo_root() . "/albums/data2";

sub palb_init {
    return psql_init();
}

sub palb_create_tables {
    return "no init" if (!palb_init());

    psql_create_table("albums", \@album_fields);
    psql_create_table("albumitems", \@album_item_fields);
    psql_create_table("albumusers", \@album_user_fields);

    return "OK";
}

sub palb_drop_tables {
    return "no init" if (!pdb_init());

    psql_drop_table("albumusers");
    psql_drop_table("albumitems");
    psql_drop_table("albums");

    return "OK";
}

sub palb_list_albums {
    opendir(DIR, "$alb_datadir");
    my $fname;
    my %list;
    while (defined($fname = readdir(DIR))) {
        if ($fname =~ s/\.alb$//) {
            palb_load_album($fname);
            if (defined($alb_data{"title"})) {
                $list{$fname} = $alb_data{"title"};
            } else {
                $list{$fname} = "(untitled)";
            }
        }
    }
    return %list;
}

sub palb_load_album {
    my $albumid = $_[0];
    if ($alb_cur_album ne $albumid) {
        palb_load_page($albumid, 0);
    }
}

sub palb_load_page {
    my $albumid = $_[0];
    my $pagenr = $_[1];

    if (($alb_cur_album eq $album_id) 
        && ($alb_cur_page == $pagenr)) {
        return;
    }

    %alb_data = ();
    %alb_page_data = ();
    @alb_page_texts = ();
    @alb_page_textsizes = ();
    @alb_page_photos = ();
    $alb_cur_album = "";
    $alb_cur_page = -1;

    if (open(FILE, "<$alb_datadir/$albumid.alb")) {
        while (<FILE>) {
            chomp;
            s/\r//;
            s/^\s+//;
            s/\s+$//;
            s/^\#.*$//;
            if (/^(.*?)\s*=\s*(.*)$/) {
                $alb_data{$1} = $2;
            }
            if (/^(\d+)\.(\w+)\s*=\s*(.*)$/) {
                my $pg = $1;
                my $name = $2;
                my $value = $3;
                if ($pg == $pagenr) {
                    $alb_page_data{$name} = $value;
                }
            } elsif (/^(\d+)\.(\d+)\.(\w+)\s*=\s*(.*)$/) {
                my $pg = $1;
                my $it = $2;
                my $name = $3;
                my $value = $4;
                if ($pg == $pagenr) {
                    if ($name eq "text") {
                        $alb_page_texts[$it] = $value;
                    } elsif ($name eq "textsize") {
                        $alb_page_textsizes[$it] = $value;
                    } elsif ($name eq "photo") {
                        $alb_page_photos[$it] = $value;
                    }
                }
            }

        }
        close FILE;
        $alb_cur_album = $albumid;
        $alb_cur_page = $pagenr;
    } else {
#        print "Cannot open 'c:/eric/htdocs/private/album/$albumid.alb'\n";
    }
}

sub palb_set_value {
    my $name = $_[0];
    my $value = $_[1];
    $alb_data{$name} = $value;
}

sub palb_save_album {
    my $albumid = $_[0];
    if (open(FILE, ">$alb_datadir/$albumid.alb")) {
        foreach $key (keys %alb_data) {
            print FILE "$key=$alb_data{$key}\n";
        }
        close FILE;
        system("chmod 666 $alb_datadir/$albumid.alb");
    }
}
        
sub palb_album_get_title {
    my $albumid = $_[0];
    palb_load_album($albumid);
    if (defined($alb_data{"title"})) {
        return $alb_data{"title"};
    }
    return "";
}

sub palb_album_get_owner {
    my $albumid = $_[0];
    palb_load_album($albumid);
    if (defined($alb_data{"owner"})) {
        return $alb_data{"owner"};
    }
    return "";
}

sub palb_album_get_nr_pages {
    my $albumid = $_[0];
    palb_load_album($albumid);
    if (defined($alb_data{"nrpages"})) {
        return $alb_data{"nrpages"};
    }
    return 0;
}

sub palb_album_get_link {
    my $albumid = $_[0];
    my $size = $_[1];

    return "phalbum?albumid=$albumid&size=$size";
}

sub palb_page_get_layout {
    my $albumid = $_[0];
    my $pagenr = $_[1];
    
    palb_load_page($albumid, $pagenr);
    if (defined($alb_page_data{"layout"})) {
        return $alb_page_data{"layout"};
    }
    return "plain";
}

sub palb_page_get_title {
    my $albumid = $_[0];
    my $pagenr = $_[1];

    palb_load_page($albumid, $pagenr);
    return $alb_page_data{"title"};
}

sub palb_page_get_bgcolor {
    my $albumid = $_[0];
    my $pagenr = $_[1];

    palb_load_page($albumid, $pagenr);
    if (defined($alb_page_data{"bgcolor"})) {
        return $alb_page_data{"bgcolor"};
    }
    return "";
}

sub palb_page_get_fgcolor {
    my $albumid = $_[0];
    my $pagenr = $_[1];

    palb_load_page($albumid, $pagenr);
    if (defined($alb_page_data{"fgcolor"})) {
        return $alb_page_data{"fgcolor"};
    }
    return "";
}

sub palb_page_get_bgimage {
    my $albumid = $_[0];
    my $pagenr = $_[1];

    palb_load_page($albumid, $pagenr);
    if (defined($alb_page_data{"bgimage"})) {
        return $alb_page_data{"bgimage"};
    }
    return "";
}

sub palb_page_get_prevlink {
    my $albumid = $_[0];
    my $pagenr = $_[1];
    my $size = $_[2];

    if ($pagenr > 0) {
        $pagenr--;
        return "phalbum?albumid=$albumid&pagenr=$pagenr&size=$size";
    } else {
        return "";
    }
}

sub palb_page_get_nextlink {
    my $albumid = $_[0];
    my $pagenr = $_[1];
    my $size = $_[2];

    $pagenr++;
    if ($pagenr < palb_album_get_nr_pages($albumid)) {
        return "phalbum?albumid=$albumid&pagenr=$pagenr&size=$size";
    } else {
        return "";
    }
}

sub palb_page_get_nr_items {
    my $albumid = $_[0];
    my $pagenr = $_[1];

    palb_load_page($albumid, $pagenr);
    return $alb_page_data{"nr_items"};
}

sub palb_item_get_text {
    my $albumid = $_[0];
    my $pagenr = $_[1];
    my $itemnr = $_[2];

    palb_load_page($albumid, $pagenr);
    if (defined($alb_page_texts[$itemnr])) {
        return $alb_page_texts[$itemnr];
    } else {
        return "";
    }
}

sub palb_item_get_textsize {
    my $albumid = $_[0];
    my $pagenr = $_[1];
    my $itemnr = $_[2];

    palb_load_page($albumid, $pagenr);
    if (defined($alb_page_textsizes[$itemnr])) {
        return $alb_page_textsizes[$itemnr];
    } else {
        return "";
    }
}

sub palb_item_get_photo {
    my $albumid = $_[0];
    my $pagenr = $_[1];
    my $itemnr = $_[2];

    palb_load_page($albumid, $pagenr);
    if (defined($alb_page_photos[$itemnr])) {
        return $alb_page_photos[$itemnr];
    } else {
        return "";
    }
}

sub palb_get_dname {
    return $alb_datadir2;
}

sub palb_get_fname {
    my $albumid = $_[0];

    if (-f "$alb_datadir2/$albumid.alb") {
        return "$alb_datadir2/$albumid.alb";
    } else {
        return "";
    }
}

return 1;
