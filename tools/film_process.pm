$proc_size_long = 900;
$proc_size_short = 600;

$proc_resize_long_film = 900;
$proc_resize_short_film = 605;
$proc_resize_long_digital = 905;
$proc_resize_short_digital = 600;

$proc_size_long_thumbnail = 150;
$proc_size_short_thumbnail = 100;

$proc_sharpen = "-sharpen 1x1";
$proc_quality = "-quality 85";
$proc_quality_thumbnail = "-quality 75";

sub set_sizes {
    my $long_size = $_[0];
    my $short_size = $_[1];

    $proc_size_long = $long_size;
    $proc_size_short = $short_size;
    $proc_resize_long_film = $proc_size_long;
    $proc_resize_short_film = $proc_size_short + 5;
    $proc_resize_long_digital = $proc_size_long + 5;
    $proc_resize_short_digital = $proc_size_short;
}


sub get_command {
    my $infile = $_[0];
    my $outfile = $_[1];
    my $is_digital = ($outfile =~ /\d\d\d\d\d\d\d\d\-\d\d\d\d\d\d/);
    my $is_special = ($outfile =~ /[tx]\d\d\d\d\.jpg$/);
    my $is_portrait = $_[2];
    my $rotate = $_[3];

    my $resize_long = $is_digital ? $proc_resize_long_digital : $proc_resize_long_film;
    my $resize_short = $is_digital ? $proc_resize_short_digital : $proc_resize_short_film;
    my $resize_superlong = 2 * $resize_short;

    my $size = $is_portrait 
      ? $proc_size_short . "x" . $proc_size_long
      : $proc_size_long . "x" . $proc_size_short;
    my $resize = $is_portrait
      ? $resize_short . "x" . $resize_long
      : $resize_long . "x" . $resize_short;

    if ($is_portrait) {
        $rotate = "-rotate $rotate";
    } elsif ($rotate > 0) {
        $rotate = "-rotate $rotate";
    } else {
        $rotate = "";
    }

    # For 'special' photos (Theo's uploaded ones, as well as the 'x' type
    # irregular ones), use the actual dimensions to determine the
    # real parameters
    if (!$is_digital) {
        open(SIZE, "identify $infile|");
        my $width = 0;
        my $height = 0;
        while (<SIZE>) {
            if (/(\d+)x(\d+)/) {
                $width = $1;
                $height = $2;
                last;
            }
        }
        close SIZE;
        if ($width && $height) {
            if ($height > $width) {
                if ((1.5 * $width) > $height) {
                    # resize based on height, crop width
                    $resize = "${resize_long}x${resize_long}";
                } else {
                    $resize = "${resize_short}x${resize_superlong}";
                }
                $size = "${resize_short}x${resize_long}";
                # The image is already portrait, no need to rotate
                $is_portrait = 1;
                $rotate = "";
            } else {
                if ($is_portrait) {
                    # remember the rotation that will have preceded the
                    # resizing: when resizing, height and width will have
                    # been swapped
                    if ((1.5 * $height) > $width) {
                        # resize based on width, crop height
                        $resize = "${resize_long}x${resize_long}";
                    } else {
                        $resize = "${resize_short}x${resize_superlong}";
                    }
                    $size = "${resize_short}x${resize_long}";
                } else {
                    if ((1.5 * $height) > $width) {
                        # resize based on width, crop height
                        $resize = "${resize_long}x${resize_long}";
                    } else {
                        $resize = "${resize_superlong}x${resize_short}";
                    }
                    $size = "${resize_long}x${resize_short}";
                }
            }
        }
    }

    return "convert -size $size $infile $rotate -resize $resize -crop $size $proc_quality $proc_sharpen $outfile";
}

return 1;
