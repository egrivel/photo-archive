# Backup

The photo archive provides two ways to maintain a backup: one through a
_pull_ mechanism and one through a _push_ mechanism. Both mechanisms rely
on a concept called _hashes_, which are unique strings that allow the
system to verify whether a backup is up-to-date or not.

Of course, it is possible to make a backup of the photo archive by simply
copying all the files with the photos over to a backup, and saving a copy
of the database. Nothing wrong with that way of making a backup, and it
works fine in many cases.

If you don’t always want to copy over multiple terabytes of data, though
(and the photo archive can easily grow that large), there are tools included
that make it possible to have a “shadow” of the backup, on a different
server, possibly in a different country. All it takes is having a friend who
has his or her own Linux servers and is willing to host the copy of your
photo archive.

## Build the Hashes

The first tool to use when setting up a remote backup is the `util/phbuildhash`
tool. This tool will go through the entire archive and look at the content for
each “entity” (files, images, sets, persons, and users). Each of those entities
receives a unique, long string that reflects the current value of the entity.

The `phbuildhash` tool should be run on a regular basis, and especially before
making a backup. The backup process will check the hashes in the photo archive
against the hashes in the backup, and if they mash, it will not backup the
entity again. Only those entities where the hashes don't match will be
backed up.

## Push Me, Pull You

Or, in other words: to push or to pull, that is the question.

There are two ways in which the backup can be maintained:

- The server which hosts the backup will, on a regular basis, check the
  photo archive and _pull_ any changes down.
- The server on which the actual photo archive is located will, on a regular
  bases, check the backup and _push_ any changes to the backup.

The pull mechanism should be preferred, since it is the most secure. With the
push mechanism, anyone could theoretically push changes to your backup. There
is some basic authentication between the archive and the backup, but no
industry-level security.

With the pull mechanism, on the other hand, anyone would theoretically be able
to pull down a copy of your photo archive. There is currently no checks at
all in place (there are plans to add checks in the future).

In both cases, at least one of the servers must have a fixed Internet address
(hostname or IP address). With the pull mechanism, the photo archive’s address
has to be fixed; with the push mechanism, the backup’s address has to be fixed.
If only one of the servers has a fixed Internet address, then that determines
which backup mechanism is to be used. If both have a fixed Internet address,
the choice can be done based on preference. If neither have a fixed Internet
address, you’re going to have to rely on basic file backups.

## Private Photos and the Backup

Currently, the online backup tools do _not_ copy over any photos marked
as “private” to avoid allowing strangers access to your restricted photos.
There are plans to make copying over private photos an option in the future,
but this has not yet been implemented.

## Implement Pull Backup

The pull backup is implemented through the `util/synchronize.pl` tool.
You start out by setting up the backup as a complete (albeit empty) photo
archive, with the SQL setup, the directory structure and everything.

Once the backup has been setup, the following entry must be added to the
backup’s `photos.ini` file:

```
master = ... location of the archive's "phmaster" script ...
```

With that in place, simply run the `util/synchronize.pl` script to start the
synchronization process. The backup server will call the `phmaster` script,
asking for information on the photo archive, and (given enough time) will copy
the entire photo archive over.

It is recommended to run the `synchronize.pl` utility on a regular basis. After
the first copy of the entire archive, subsequent runs should be relatively
quick, since it uses the hash values to only copy over what has changed.

## Implement Push Backup

The implementation of the push backup is very similar, except that it is now
the photo archive server which will “push” data to the backup.

There is a little bit of extra setup needed for this scenario:

- The `photos.ini` on the _backup server_ must have an entry called
  `remote-key` with as value a string that contains the secret password the
  archive server will use to connect.
- The `photos.ini` on the _archive server_ must have an entry called
  `master-key` with the same string containing the secret password. It also
  must have the entry defining the `master` location of the backup server’s
  `phmaster` script.

With this configuration in place, the backup is initiated by, on the photo
archive server, running the `util/synchronize-up.pl` script (after, of
course, building the hashes using the `util/phbuildhash` script). This, again
will the first time it is run start copying over the full, entire photo
archive; subsequent runs should only copy over data that has changed.
