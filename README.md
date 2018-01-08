### ffdup ###

ffdup is a portable ultra fast light duplicate files finder written in Perl released as Free Software.

#### What does ffdup do? ####

It crawls directories and detects quickly duplicated files.

#### More info about ffdup ####

* it is written in Perl using only core modules
* it uses a fast scan algorithm to detect duplicated files
* it works greatly installed into NAS with Perl support (eg. Synology, D-LINK 323)

#### Install ####

Quick Install
```
wget https://raw.githubusercontent.com/lookee/ffdup/master/ffdup.pl 
chmod +x ffdup.pl
```

Project
```
git clone https://github.com/lookee/ffdup.git
```

#### Example ####

```
./ffdup $DIR

```

#### Unit Test ####

A directory tree maker with duplicates file is available under directory: t

