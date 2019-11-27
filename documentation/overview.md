# Overview of the Photo Archive

## Program Files

The following files are the main program (executable) files:
 - phabout: the 'about' tab
 - phbrowse: main entry point for browsing the archive
 - phcomment: manage comments
 - phdisp: displaying an individual photo page
 - phedit: editing a photo or set
 - phhelp: provide help pages
 - phimg: display actual image
 - phinfo: displaying information about the photo (from the EXIF)
 - phlogin: login and logout function
 - phmov: display actual movie
 - phperson: display person information
 - phpref: preferences
 - phsearch: search functions

The following filles are support modules needed:
 - photos_args.pm (GET, POST and command line arguments)
 - photos_common.pm (common functions)
 - photos_db.pm (database functions)
 - photos_fs.pm (file system functions)
 - photos_html.pm (HTML functions)
 - photos_person.pm (supporting the person database)
 - photos_session.pm (session management)
 - photos_sql.pm (low-level database functions)
 - photos_user.pm (user management functions)
 - photos_util.pm (general utilities)


## Prerequisites

The following Perl modules must be installed to run this archive:
 - DBI: database interface
 - Image::ExifTool to extract EXIF info from the photos
