# Setting up the photo archive

## Preparations

Make sure the prerequisites are installed:
 - exiftool
 - mysql (also known as mariadb)
 - apache (http Web server)
 - Perl
 - Perl module DBI: database interface
 - Perl module Image::ExifTool to extract EXIF info from the photos

Identify the directory layout
 - you need a directory to place the web server files (called cgi-bin)
 - you need a directory to put the utility files (called util)
 - you need a directory to put the include files (called inc)
 - you need a directory to put the actual photos (called photos)

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
[mysql]> CREATE USER '<user>'@'localhost' IDENTIFIED BY '<password>';
[mysql]> GRANT ALL PRIVILEGES ON <dbname>.* TO '<user>'@'localhost';
[mysql]> quit
```

## Create the .ini file

The `.ini` file contains the configuration for the database. This file should
be placed in a `private` directory. The distribution contains a sample
file called `photos.ini.sample`; copy this to `photos.ini` and replace all
the names in angular brackets with the correct values:

## Create the photo archive data directory

Create the directory that was named as `photosdir` in the `photos.ini` file,
and make sure that directory is writable for everyone (the photo archive
will create sub-folders and files in there, so it must have write permission).

Eventually you may want to make sure that both you, as the adminstrator, and
the web server, have write access, but noone else. However, that is for later.

## Make the links in your web server directories

Link the 
