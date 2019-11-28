# Setting up the photo archive

## Preparations

Make sure the prerequisites are installed:
 - exiftool
 - mysql (also known as mariadb)
 - apache (http Web server)
 - Perl
 - Perl module DBI: database interface
 - Perl module Image::ExifTool to extract EXIF info from the photos

## Create the Database

You need to think of:
 - a database name
 - the user to connect to the database
 - the password to use

First you need to create the database. To do this, you first log into the
database as the root user (use `-p` if you set a password for the root user,
which you definitely should do), then execute commands to create the database,
create the user, and give the user access to the just created database.

```
$ mysql --user=root -p mysql
[mysql]> CREATE DATABASE <dbname>;
[mysql]> CREATE USER '<dbuser>'@'localhost' IDENTIFIED BY '<dbpassword>';
[mysql]> GRANT ALL PRIVILEGES ON <dbname>.* TO '<dbuser>'@'localhost';
[mysql]> quit
```

## Create the photo archive data directory

The photo archive data directory is where all the actual image files are
going to be stored. Make sure you identify this location in a place with
enough free space to keep all the photos in the archive, in all the
different sizes you will be using.

The photo archive data directory must be writable by both the administrator
(when you are adding new photos to the archive) and the web server (when
generating photos in a desired size). A simple (but not very secure) way
to achieve this is to make the directory writable by "all". Better would
be to make sure both the web server and the administrator of the database
are members of a "photos" group.

## Make the links in your web server directories

Link the files into the web server structure. If you have the clone of this
repository in for instance `/home/john/photo-archive`, and your web server
has its file structure in `/var/apache/html` and `/var/apache/cgi-bin`,
then you want to create the following symlinks:

```
$ cd /var/apache/cgi-bin
$ ln -s /home/john/photo-archive/cgi-bin photos
$ cd /var/apache/html
$ ln -s /home/john/photo-archive/static photos-static
```

## Create the .ini file

The `.ini` file contains the configuration for the database. This file should
be placed in a `private` directory. The distribution contains a sample
file called `photos.ini.sample`; copy this to `photos.ini` and replace all
the values in angular brackets with the correct values.

The `photosdir` and `photos2dir` values must be the photo archive directory
that was previously created.

The `staticroot` is the location in the server root where the web server
will be serving the static files. In the example above, where the static
files will be in the `photos-static` location in the web server, the value
would be `/photos-static`.

The `dbname`, `dbuser` and `dbpasswd` values must match what you used when
creating the MySQL database.

The `startyear` should be the first year displayed on the overview page;
the `admin-email` probably your email (where guests of your photo archive
can contact you).
