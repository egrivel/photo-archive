#
# Photo Archive System - General Utility Functions
# This source is copyright (c) 2006 by Eric Grivel. All Rights Reserved.
#

# Include all the modules
use photos_common;
use photos_sql;
use photos_fs;
use photos_args;
use photos_html;
use photos_db;
use photos_session;
use photos_usr;
use photos_album;
use photos_person;

my $put_has_required;

#
# Initializes everything
#
sub put_init {
    psql_init();
    parg_init();
    pdb_init();
    pht_init();
    pses_init();
    pusr_init();
}

sub put_restore_session {
    # Restore the session
    my $session = pht_get_sessionid();
    if ($session eq "") {
        $session = pses_new();
        pht_set_sessionid($session);
    } else {
        pses_restore($session);
    }

    # Set the IP address of the user of this session
    if (defined($ENV{"REMOTE_ADDR"} && ($ENV{"REMOTE_ADDR"} ne ""))) {
        pses_set("client", $ENV{"REMOTE_ADDR"});
    }

    # If a user is logged in, re-login the user
    my $user = pses_get("user");
    if ($user ne "") {
        pusr_reload($user);
    } else {
        # Otherwise, load the "guest"  settings
        pusr_reload($PUSR_GUEST_ACCOUNT);
    }
}

sub put_login_link {
#    return "<a href='phlogin' onclick='doWindow(\"phlogin\", \"login\", \"width=500,height=300,scrollbars=1,resizable=1\"); return false;'>login</a>";
    return "<a href='phlogin'>login</a>";
}

sub put_logout_link {
    return "<a href='phlogin?do.logout'>logout</a>";
#    return "<a href='phlogin?do.logout' onclick='open(\"phlogin?do.logout\", \"login\", \"width=500,height=300,scrollbars=1,resizable=1\"); return false;'>logout</a>";
}

sub put_info_link {
    return "<a href='phinfo?imageid=$_[0]' onclick='doWindow(\"phinfo?imageid=$_[0]\", \"info\", \"screenX=\"+event.screenX+\",screenY=\"+event.screenY+\",width=300,height=500,scrollbars=1,resizable=1\"); return false;'>Info</a>";
}

sub put_map_link {
    return "<a href='phmap?imageid=$_[0]' onclick='doWindow(\"phmap?imageid=$_[0]\", \"mqp\", \"screenX=\"+event.screenX+\",screenY=\"+event.screenY+\",width=750,height=500,scrollbars=1,resizable=1\"); return false;'>map</a>";
}

sub put_mapset_link {
    return "<a href='phmap?setid=$_[0]' onclick='doWindow(\"phmap?setid=$_[0]\", \"mqp\", \"screenX=\"+event.screenX+\",screenY=\"+event.screenY+\",width=750,height=500,scrollbars=1,resizable=1\"); return false;'>map</a>";
}

sub put_comment_link {
    return "<a href='phcomment?imageid=$_[0]' onclick='doWindow(\"phcomment?imageid=$_[0]\", \"comment\", \"width=600,height=400,scrollbars=1,resizable=1\"); return false;'>$_[1]</a>";
}

sub put_help_link {
    my $helpid = $_[0];
    my $staticroot = get_static_root();
    return "<a href='phhelp?page=$_[0]' onclick='doWindow(\"phhelp?page=$_[0]\", \"help\", \"width=400,height=600,scrollbars=1,resizable=1\"); return false;'><img src='$staticroot/images/help.gif' title='More information' class='help' /></a>";
}

sub put_page_start {
    my $title = $_[0];
    pht_set_title($title);
    my $userid = pusr_get_userid();
    my $fullname = pusr_get_fullname();

    if (($userid eq "")
        || ($userid eq "guest")) {
        pht_set_banner("Currently not logged in. " . put_login_link());
    } else {
        pht_set_banner("Logged in as $fullname. " . put_logout_link());
    }
    pht_page_start();
}

sub put_page_end {
    pht_page_end();
}

#
# Form management functions
#

my %put_errors = ();
sub put_form_start {
    my $action = $_[0];
    my $method = $_[1];
    my $title = $_[2];
    my $onsubmit = $_[3];
    $method = "post" if (!defined($method) || ($method eq ""));
    $title = "" if (!defined($title));
    if (defined($onsubmit) && ($onsubmit ne "")) {
        $onsubmit = " onsubmit=\"$onsubmit\"";
    } else {
        $onsubmit = "";
    }

    pht_output "<form method='$method' name='form' action='$action'$onsubmit>\n";
    pht_output "<table class='form'>\n";
    if ($title ne "") {
        pht_output "<tr><th colspan='2'>$title</th></tr>\n";
    }
    $put_has_required = 0;
}

sub put_form_error {
    $put_errors{$_[0]} = $_[1];
}

sub put_form_hidden {
    my $fieldname = $_[0];
    my $value = pht_value_escape(parg_get($fieldname));
    pht_output "<input type='hidden' name='$fieldname' value='$value' />";
}

sub put_form_text {
    my $label = $_[0];
    my $fieldname = $_[1];
    my $required = $_[2];
    my $helptext = $_[3];
    if (!defined($required)) {
        $required = 0;
    }
    if (!defined($helptext)) {
        $helptext = "";
    }

    pht_output "<tr>";
    pht_output "<th class='label";
    pht_output " required" if ($required);
    pht_output "'>$label";
    if ($helptext ne "") {
        pht_output " <span class='helptext'>$helptext</span>";
    }
    pht_output "</th>\n";
    my $value = pht_value_escape(parg_get($fieldname));
    pht_output "<td><input type='text' class='edit' name='$fieldname' value='$value' />";
    pht_output "</td></tr>\n";
    $put_has_required++ if ($required);
}

sub put_form_textlong {
    my $label = $_[0];
    my $fieldname = $_[1];
    my $required = $_[2];
    my $accesskey = $_[3];
    if (!defined($required)) {
        $required = 0;
    }
    if (!defined($accesskey)) {
        $accesskey = "";
    }

    pht_output "<tr>";
    pht_output "<th class='label";
    pht_output " required" if ($required);
    pht_output "'>$label</th>\n";
    my $value = pht_value_escape(parg_get($fieldname));
    pht_output "<td>";
    put_output_error($fieldname);
    pht_output "<input type='text' class='edit' name='$fieldname' ";
    if ($accesskey ne "") {
        pht_output "accesskey='$accesskey' ";
    }
    pht_output "value='$value' size='50' />";
    pht_output "</td></tr>\n";
    $put_has_required++ if ($required);
}

sub put_form_textarea {
    my $label = $_[0];
    my $fieldname = $_[1];
    my $required = $_[2];
    if (!defined($required)) {
        $required = 0;
    }

    pht_output "<tr>";
    pht_output "<th class='label";
    pht_output " required" if ($required);
    pht_output "'>$label</th>\n";
    my $value = pht_value_escape(parg_get($fieldname));
    pht_output "<td><textarea class='edit' name='$fieldname' rows='7' cols='60'>$value</textarea>";
    pht_output "</td></tr>\n";
    $put_has_required++ if ($required);
}

sub put_form_protected {
    my $label = $_[0];
    my $fieldname = $_[1];

    pht_output "<tr>";
    pht_output "<th class='label";
    pht_output " required" if ($required);
    pht_output "'>$label</th>\n";
    my $value = pht_value_escape(parg_get($fieldname));
    pht_output "<td>";
    put_output_error($fieldname);
    pht_output "<input type='hidden' name='$fieldname' value='$value' /><span class='edit'>$value</value></td></tr>";
}

sub put_form_password {
    my $label = $_[0];
    my $fieldname = $_[1];
    my $required = $_[2];
    if (!defined($required)) {
        $required = 0;
    }

    pht_output "<tr>";
    pht_output "<th class='label";
    pht_output " required" if ($required);
    pht_output "'>$label</th>\n";
    my $value = "";
    pht_output "<td>";
    put_output_error($fieldname);
    pht_output "<input type='password' class='edit' name='$fieldname' value='$value' />";
    pht_output "</td></tr>\n";
    $put_has_required++ if ($required);
}

sub put_form_checkboxes {
    my $label = shift(@_);
    my $fldname = shift(@_);
    my $fldlabel = shift(@_);
    my  $count = 0;

    pht_output "<tr><th class='label'>$label</th>";
    pht_output "<td>";
    put_output_error($fldname);
    while (defined($fldname) && defined($fldlabel)) {
#        pht_output " &nbsp; " if ($count);
        my $checked = "";
        if ((parg_get($fldname) ne "") && parg_get($fldname)) {
            $checked = " checked='checked'";
        }
        pht_output "<label for='i.$fldname'>";
        pht_output "<input type='checkbox' name='$fldname' id='i.$fldname' value='1'$checked />";
        pht_output $fldlabel;
        pht_output "</label><br />";
        $fldname = shift(@_);
        $fldlabel = shift(@_);
        $count++;
    }
    pht_output "</td></tr>\n";
}

sub put_form_dropdown {
    my $label = shift(@_);
    my $name = shift(@_);
    my $fldname = shift(@_);
    my $fldlabel = shift(@_);
    my $count = 0;


    pht_output "<tr><th class='label'>$label</th>";
    pht_output "<td>";
    put_output_error($fldname);
    pht_output "<select name='$name'>";
    my $cur_value = parg_get($name);
    while (defined($fldname) && defined($fldlabel)) {
        my $selected = "";
        if ($cur_value eq $fldname) {
            $selected = " selected='selected'";
        }
        $fldname = pht_value_escape($fldname);
        pht_output "<option value='$fldname'$selected>$fldlabel</option>\n";
        $fldname = shift(@_);
        $fldlabel = shift(@_);
        $count++;
    }
    pht_output "</select></td></tr>\n";
}

sub put_form_radio {
    my $label = shift(@_);
    my $name = shift(@_);
    my $fldlabel = shift(@_);
    my $count = 0;

    pht_output "<tr><th class='label'>$label</th>";
    pht_output "<td>";
    put_output_error($name);
    my $cur_value = parg_get($name);
    while (defined($fldlabel)) {
        my $selected = "";
        my $fldvalue = $fldlabel;
        if ($fldlabel =~ s/^(.*?)://) {
            $fldvalue = $1;
        }
        if ($cur_value eq $fldvalue) {
            $selected = " checked='checked'";
        }
        $fldvalue = pht_value_escape($fldvalue);
        pht_output "<label for='$name.$fldvalue'><input type='radio' name='$name' id='$name.$fldvalue' value='$fldvalue'$selected />$fldlabel</label>\n";
        $fldlabel = shift(@_);
        $count++;
    }
    pht_output "</td></tr>\n";
}

sub put_form_buttons {
    my $name = shift(@_);
    my $label = shift(@_);
    my $count = 0;

    pht_output "<tr><td>&nbsp;</td><td>";
    while (defined($name) && defined($label)) {
        pht_output " &nbsp; " if ($count);
        my $accesskey = "";
        if ($label =~ s/\^(\w)/$1/) {
            $accesskey = " accesskey='$1' ";
        }
        pht_output "<input type='submit' name='do.$name' value='$label' $accesskey />\n";
        $count++;
        $name = shift(@_);
        $label = shift(@_);
    }
    pht_output "</td></tr>";
}

sub put_output_error {
    my $fieldname = $_[0];
    if (defined($put_errors{$fieldname})
        && ($put_errors{$fieldname} ne "")) {
        pht_output "<div class='error'>$put_errors{$fieldname}</div>";
    }
}

#
# Display an image in the form
#
sub put_form_image {
    my $imageid = $_[0];
    my $size = pusr_get_setting($PUSR_EDIT_SIZE);
    if ($size eq "") {
        $size = "small";
    }
    pht_output "<tr><td colspan='2' align='center'>";
    pht_output "<a href='single.pl?page=$imageid' target='imagewindow'><img src='phimg?$size=$imageid' /></a></td></tr>\n";
}

sub put_form_thumbnail {
    my $imageid = $_[0];
    my $size = "thumbnail";
    pht_output "<tr><td colspan='2' align='center'>";
    pht_output "<a href='single.pl?page=$imageid' target='imagewindow'><img src='phimg?$size=$imageid' /></a></td></tr>\n";
}

sub put_form_end {
    if ($put_has_required) {
        pht_output "<tr class='noborder'><td colspan='2'><span class='required'>denotes a required field</span></td></tr>\n";
    }
    pht_output "</table>\n";
    pht_output "</form>\n";
}

sub put_form_focus {
    my $field = $_[0];
    if ($field ne "") {
        pht_output "<script>document.form.$field.focus();</script>\n";
    }
}

# Get the 'class' of a photo or a set. The class defines a sequence that can be
# walked through in 'prev' and 'next' steps. There are three special
# classes:
#  - the "specials" starting with an "x"
#  - dad's photos, starting with a "d", "p" or "q"
#  - Theo's photos, starting with a "t"
#
sub put_get_class {
    my $id = $_[0];
    my $class = "normal";
    if ($id =~ /^x/) {
        $class = "special";
    } elsif ($id =~ /^[adpq]/) {
        $class = "pa";
    } elsif ($id =~ /^t/) {
        $class = "theo";
    }
    return $class;
}

# Get the next image, based on the current image, and taking into account
# the user preferences
sub put_get_next {
    my $imageid = $_[0];
    my $class = put_get_class($imageid);

    my $iter = pdb_iter_new($imageid, 2);
    pdb_iter_filter_category($iter, put_types());
    pdb_iter_filter_min_quality($iter, put_quality());
    pdb_iter_filter_max_quality($iter, put_max_quality());

    my $next = pdb_iter_next($iter);
    if ($next eq $imageid) {
        $next = pdb_iter_next($iter);
    }
    pdb_iter_done($iter);

    if (put_get_class($next) ne $class) {
        # different class, so do not walk over into it
        $next = "";
    }
    return $next;
}

sub put_get_prev {
    my $imageid = $_[0];
    my $class = put_get_class($imageid);

    my $iter = pdb_iter_new($imageid);
    pdb_iter_filter_category($iter, put_types());
    pdb_iter_filter_min_quality($iter, put_quality());
    pdb_iter_filter_max_quality($iter, put_max_quality());

    my $prev = pdb_iter_previous($iter);
    pdb_iter_done($iter);

    if (put_get_class($prev) ne $class) {
        # different class, so do not walk over into it
        $prev = "";
    }
    return $prev;
}

# Get the next set, based on the current set, and taking into account
# the user preferences
sub put_get_next_set {
    my $setid = $_[0];
    my $class = put_get_class($setid);

    my $iter = pdb_iter_set_new($setid, 2);
    pdb_iter_filter_category($iter, put_types());
    pdb_iter_filter_min_quality($iter, put_quality());
    pdb_iter_filter_max_quality($iter, put_max_quality());

    my $next = pdb_iter_next($iter);
    if ($next eq $setid) {
        $next = pdb_iter_next($iter);
    }
    pdb_iter_done($iter);

    if (put_get_class($next) ne $class) {
        # different class, so do not walk over into it
        $next = "";
    }
    return $next;
}

sub put_get_prev_set {
    my $setid = $_[0];
    my $class = put_get_class($setid);

    my $iter = pdb_iter_set_new($setid);
    pdb_iter_filter_category($iter, put_types());
    pdb_iter_filter_min_quality($iter, put_quality());
    pdb_iter_filter_max_quality($iter, put_max_quality());

    my $prev = pdb_iter_previous($iter);
    pdb_iter_done($iter);

    if (put_get_class($prev) ne $class) {
        # different class, so do not walk over into it
        $prev = "";
    }
    return $prev;
}

#
# Determine the default copyright, depending on the image ID.
#
sub put_default_copyright {
    my $imageid = $_[0];
    my $year = pdb_get_year($imageid);

    if ($year > 9000) {
        $year = "";
        my $firstyear = 9999;
        my $lastyear = 0;
        my $date = pdb_get_datetime($imageid);
        if ($date eq "") {
            my $setid = pcom_get_set($imageid);
            $date = pdb_get_setdatetime($setid);
        }
        while ($date =~ s/(\d\d\d\d)//) {
            my $newyear = $1;
            if ($newyear < $firstyear) {
                $firstyear = $newyear;
            }
            if ($newyear > $lastyear) {
                $lastyear = $newyear;
            }
        }
        if ($lastyear > 0) {
            $year = $firstyear;
            if ($lastyear != $firstyear) {
                $year .= "-$lastyear";
            }
        }
    }

    my $owner = "";
    if ($imageid =~ /^\d/) {
        $owner = "Eric Grivel";
        if ($year >= 1991) {
            $owner .= " and Nicoline Smits";
        }
    } elsif ($imageid =~ /^f/) {
        $owner = "Frank Grivel";
    } elsif ($imageid =~ /^m/) {
        $owner = "Mark Grivel";
    } elsif ($imageid =~ /^[dpq]/) {
        $owner = "Albert Grivel";
    } elsif ($imageid =~ /^t/) {
        $owner = "Theo Grivel";
    }

    my $copyright = $year;
    if ($owner ne "") {
        $copyright .= " by $owner";
    }
    return $copyright;
}

#
# Determine the default copyright, depending on the set ID.
#
sub put_default_set_copyright {
    my $setid = $_[0];
    my $year = pdb_get_setyear($setid);

    if ($year > 9000) {
        $year = "";
        my $firstyear = 9999;
        my $lastyear = 0;
        my $date = pdb_get_setdatetime($setid);
        while ($date =~ s/(\d\d\d\d)//) {
            my $newyear = $1;
            if ($newyear < $firstyear) {
                $firstyear = $newyear;
            }
            if ($newyear > $lastyear) {
                $lastyear = $newyear;
            }
        }
        if ($lastyear > 0) {
            $year = $firstyear;
            if ($lastyear != $firstyear) {
                $year .= "-$lastyear";
            }
        }
    }

    my $owner = "";
    if ($setid =~ /^\d/) {
        $owner = "Eric Grivel";
        if ($year >= 1991) {
            $owner .= " and Nicoline Smits";
        }
    } elsif ($setid =~ /^f/) {
        $owner = "Frank Grivel";
    } elsif ($setid =~ /^m/) {
        $owner = "Mark Grivel";
    } elsif ($setid =~ /^[dpq]/) {
        $owner = "Albert Grivel";
    } elsif ($setid =~ /^t/) {
        $owner = "Theo Grivel";
    }

    my $copyright = $year;
    if ($owner ne "") {
        $copyright .= " by $owner";
    }
    return $copyright;
}

# This function gets the default display size from the user's
# settings, or from the session if no user is logged in. This
# allows guest users to select a display size.
sub put_display_size {
    my $size = "";
    if (pusr_get_userid() eq $PUSR_GUEST_ACCOUNT) {
        $size = pses_get($PUSR_IMAGE_SIZE);
    }
    if ($size eq "") {
        $size = pusr_get_setting($PUSR_IMAGE_SIZE);
    }
    return $size;
}

sub put_quality {
    my $quality = "";
    if (pusr_get_userid() eq $PUSR_GUEST_ACCOUNT) {
        $quality = pses_get($PUSR_VIEW_QUALITY);
    }
    if ($quality eq "") {
        $quality = pusr_get_setting($PUSR_VIEW_QUALITY);
    }
    return $quality;
}

sub put_disp_quality {
    my $quality = "";
    if (pusr_get_userid() eq $PUSR_GUEST_ACCOUNT) {
        $quality = pses_get($PUSR_DISPLAY_QUAL);
    }
    if ($quality eq "") {
        $quality = pusr_get_setting($PUSR_DISPLAY_QUAL);
    }
    return $quality;
}

# Maximum quality is kept in a session only; used for browsing photos
# of a specific quality level only
sub put_max_quality {
    my $quality = "";

    $quality = pses_get($PUSR_VIEW_MAX_QUALITY);
    if ($quality eq "") {
        # maximum quality defaults to the hightest possible
        $quality = 5;
    }

    return $quality;
}

sub put_types {
    my $types = "";
    if (pusr_get_userid() eq $PUSR_GUEST_ACCOUNT) {
        $types = pses_get($PUSR_VIEW_TYPES);
    }
    if ($types eq "") {
        $types = pusr_get_setting($PUSR_VIEW_TYPES);
    }
    return $types;
}

sub put_tags {
    my $tags = "";
    if (pusr_get_userid() eq $PUSR_GUEST_ACCOUNT) {
        $tags = pses_get($PUSR_VIEW_TAGS);
    }
    if ($tags eq "") {
        $tags = pusr_get_setting($PUSR_VIEW_TAGS);
    }
    return $tags;
}

return 1;
