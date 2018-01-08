### ffdup ###

ffdup is a portable ultra fast light duplicate files finder written in Perl released as Free Software.

#### What does ffdup do? ####

It crawls directories and detects quickly duplicated files.

#### More info about ffdup ####

* it is written in Perl using only core modules
* it uses a fast scan algorithm to detect duplicated files
* it works greatly installed into NAS with Perl support (eg. Synology, D-LINK 323)

#### Quick Install ####

```
wget http://ffdup.pl
chmod +x ffdup.pl
```

#### Example ####

```
./ffdup /home/spoc/test

```

#### Unit Test ####

A directory tree maker with duplicates file is available under directory: t

