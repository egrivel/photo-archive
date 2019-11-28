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

## Initializing the database

The first time you need to initialize the database. This initialization
creates the database tables and the initial user who will be the administrator
of the archive; the administrator will be able to add more users later.

Go to the `util` directory and run `./phcreatetables`. This will prompt you
for the initial user name, full name and password.

## Starting the archive

You start the photo archive by going to `phbrowse` in the CGI script location.
For instance if you linked the archive software to `/cgi-bin/photos` on the
web server, you start by going to `http://localhost/cgi-bin/photos/phbrowse`.

From here you should be able to logon as the user you created when
initializing the database.

## Templates

There are a couple of places in the archive where you can insert your own
text: the welcome page (both above and below the list of years) and the
about page. This is done through _templates_.

To start using templates, copy the sample ones to the actual template (e.g.
copy `welcome1.tpl.sample` to `welcome1.tpl`) and then edit the template.
You should see the result when you refresh the page.

## Adding photos to the archive

Go to the `util` directory and copy the photos you want to add into this
directory. Then run `./process_digital` which will _move_ all the images
in the `util` directory into the archive.

Newly added photos are not yet visible to the public until the admistrator
has had an opportunity to process the photos and weed out any
inappropriate ones.

After having the photos added to the archive, go into the photo archive
and log in using the previously created initial account. After logging
in your should be able to navigate to the year and date of the added
photos.

When the set is displayed, select the `Edit` link. Most information is
optional, but the `Category` must be selected. Typically, you want to
select `regular` as the category for the set.

_After_ selecting the set category, click the `Show Images` button, which
will show all the images in the set. The set's category is automatically
copied to the individual images. You can now click the `Save` button at
the bottom, and both the set and individual images will become visible
for others.

Before saving, you can also choose to make individual images `private`,
meaning they will not be visible to visitors. Photos  can also be
deleted from here, by checking the `delete this image` checkbox before
using the `Save` button.
