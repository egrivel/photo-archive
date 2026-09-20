use Cwd;
use Cwd 'abs_path';

# By using the abs_path, it is possible to create a directory with just a few
# linked scripts to access the functionality of the full photo archive.
my $script = abs_path(__FILE__);
my $localdir = ".";
if ($script =~ s/\/[^\/]*$//) {
  $localdir = $script;
}
push @INC, "$localdir/../inc";

require 'photos_util.pm';
