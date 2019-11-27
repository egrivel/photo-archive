use photos_common;

use Encode qw(decode encode);

my %parg_list = ();
my $parg_button = "";

# Support command line arguments, for testing
my $parg_cmdline = "";
my $arg_nr;
for ($arg_nr = 0; defined($ARGV[$arg_nr]); $arg_nr++) {
    $parg_cmdline .= "&" if ($parg_cmdline ne "");
    $parg_cmdline .= $ARGV[$arg_nr];
}

sub url_decode {
   my $text = $_[0];
   $text =~ s/\+/ /g;

   # Convert %XX from hex numbers to alphanumeric
   $text =~ s/%(..)/pack("C",hex($1))/ge;

   # Decode the series of octets into an internal Perl string
   return decode('UTF-8', $text);
}

sub parg_init {
    my $query = "";
    if (defined($ENV{"REQUEST_METHOD"})) {
        my $method = uc($ENV{"REQUEST_METHOD"});
        if ($method eq "POST") {
            my $content_length = $ENV{"CONTENT_LENGTH"};
            while (<>) {
                $query .= $_;
                last if (length($query) >= $content_length);
            }
        } elsif ($method eq "GET") {
            if (defined($ENV{"QUERY_STRING"})) {
                $query = $ENV{"QUERY_STRING"};
            }
        }
    } else {
        # if no request method, maybe command line?
        $query = $parg_cmdline;
    }
    pcom_log($PCOM_DEBUG, "Query: '$query'");
    my @query = split(/\&/, $query);
    for (my $i = 0; defined($query[$i]); $i++) {
        my $name = "";
        my $value = "";
        if ($query[$i] =~ /^(.*?)=(.*)$/) {
            $name = url_decode($1);
            $value = url_decode($2);
        } else {
            $name = url_decode($query[$i]);
        }
        if ($name ne "") {
            $parg_list{$name} = $value;
        }
        if ($name =~ /^do\.(.*)$/) {
            $parg_button = $1;
        }
    }
}

sub parg_get {
    my $name = $_[0];
    if (defined($parg_list{$name})) {
        return $parg_list{$name};
    }
    return "";
}

#
# Usually, the value of an argument is enough. Sometimes, the applications
# needs to be able to distinguish between an argument explicitly set to
# an empty string or the absence of an argument. In that case, the
# parg_exists function is useful.
#
sub parg_exists {
    my $name = $_[0];
    return defined($parg_list{$name});
}

# Get an argument value, but only if it is numeric; if the argument
# isn't there, or is non-numeric, return blank
sub parg_get_numeric {
    my $arg = parg_get($_[0]);
    if (!($arg =~ /^\d+$/)) {
        $arg = "";
    }
    return $arg;
}

# Allow program to set arguments programmatically. This can be used
# to pre-fill forms; the form will be able to the field values from the
# arguments, even when they're actually pre-filled by the program.
sub parg_set {
    $parg_list{$_[0]} = $_[1];
}

sub parg_get_button {
    return $parg_button;
}

return 1;
