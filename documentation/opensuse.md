# Eric’s OpenSuSE Notes

When installing OpenSuSE,
 - have a 50 Gb volume for the OS, to be mounted on `/`
 - have a separate 50-10 Gb volume for `/home`. Having `home` on a separate
   volume makes it easier to re-install, without having to re-do all the
   home directories
 - put all the other disks on `/mnt/<computername>/d<nr>`, e.g.
   I have "/mnt/washington/d1", "/mnt/washington/d2" etc. for the data
   volumes
 - Using the computer name makes it possible to remote-mount data volumes
   from other computers and share data in a consistent way

## Installing Apache web server

 - install through YaST
 - make sure you install yast2-http-server as well, to manage the server
 - make sure Perl and PHP scripting are enabled
 - select the right port to run
 - update document root to /home/httpd/html
 - update script root to /home/httpd/cgi-bin
 - make sure the directory statements include `FollowSymLinks`
 - Open the port in the firewall, of course, and make sure that the router
   redirects to the port

# Installing MySQL
 - Install through YaST
 - Make sure it's running
    - sudo systemctl enable mysql
    - sudo systemctl start mysql

# Installing ffmpeg
 - Note that the `ffmpeg-3` package needs installing.
 - Make sure the MP4 codecs are installed (they have to come
   from the pacman repo)
