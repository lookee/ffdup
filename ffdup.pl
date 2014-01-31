#!/usr/bin/perl -W

############################################################################
#
# ffdup 0.0.1
#
# Duplicate files finder witten in Perl using standard libraries
# Luca Amore - luca.amore at gmail.com - <http://www.lucaamore.com>
#
# Git repository available at http://github.com/...
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#
############################################################################

use strict;
use warnings;
use utf8;

use Cwd;
use Data::Dumper;
use Digest::MD5;
use Digest::SHA;
use File::Basename;
use File::Find;
use Getopt::Long;

# Global Variables

my $VERSION = '0.0.1';

# output file handle
my $STDOUT  = *STDOUT;
my $STDERR = *STDERR;

# Set defaults
my %opt = (
    dir      => undef,
    size_min => undef,           
    size_max => undef,
    output   => undef,
    hash     => 'MD5',
);

# global variables
my $cmd = basename($0);

# processed file buffer
my $file_processed = {
    size => {},
    dup  => {},
    stat => {},
};

#------------------------------------------------
# D I R  C R A W L E R
#------------------------------------------------

# processing files through directory trees
sub dir_crawler {
    my $dir = shift;
    find( { wanted => \&file_crawler, follow => 0 }, $dir );
}

# processing file
sub file_crawler {
    my $file_name = $File::Find::name;

  ADD_FILES: {
        last ADD_FILES unless -f $file_name;

        $file_processed->{stat}{file_processed}++;

        my $file_size = get_file_size($file_name);

        last ADD_FILES 
            if 
                !defined $file_size ||
                $file_size == 0 ||
                defined $opt{size_min} && $file_size <= $opt{size_min} ||
                defined $opt{size_max} && $file_size >= $opt{size_max}
            ;

        $file_processed->{stat}{file_added}++;
        push @{ $file_processed->{size}{$file_size} }, $file_name;
    }
}

sub get_file_size {
    return ( stat($_) )[7];
}

#------------------------------------------------
# H A S H I N G
#------------------------------------------------

sub find_duplicates {
  FIND_DUP: for my $file_size ( keys %{ $file_processed->{size} } ) {

        my @files_with_same_size = @{ $file_processed->{size}{$file_size} };

        next FIND_DUP if scalar @files_with_same_size < 2;

        # calculate hash only for file with the same size
        for my $file_name (@files_with_same_size) {
            my $hash = hash_file($file_name);
            next FIND_DUP unless defined $hash;
            push @{ $file_processed->{dup}{$file_size}{$hash} }, $file_name;
            $file_processed->{stat}{file_hash_calculated}++;
        }

        # remove unique hashes (no duplicates)
        for my $hash ( keys %{ $file_processed->{dup}{$file_size} } ) {
            my $hash_multiplicity = 
                scalar @{ $file_processed->{dup}{$file_size}{$hash} };
            if ( $hash_multiplicity < 2 ) {
                delete $file_processed->{dup}{$file_size}{$hash};
            } else {
                $file_processed->{stat}{file_duplicated} += 
                    $hash_multiplicity; 
            }
        }

        # remove file sizes with no duplicate
        if ( scalar keys %{ $file_processed->{dup}{$file_size} } == 0 ) {
            delete $file_processed->{dup}{$file_size};
        }
    }    # FIND_DUP
}

sub hash_file {
    my $file = shift;

    unless ( open( F, $file ) ) {
        print $STDERR "Can't open '$file' for reading: $!\n";
        return undef;
    }

    binmode(F);
    my $digest = 
        $opt{hash} eq 'MD5'     ? Digest::MD5->new->addfile(*F)     :
        $opt{hash} eq 'SHA1'    ? Digest::SHA1->new->addfile(*F)    :
        die sprintf "wrong hash algorithm '%s'\n", $opt{hash}||'';
    close(F);
    return $digest->b64digest;
}

#------------------------------------------------
# O U T P U T
#------------------------------------------------

sub init_out_file {
    # open output file (default STDOUT)
    my $outfile = $opt{out};

    if (defined $outfile){
        open($STDOUT, ">", $outfile) 
            or die "cannot open > $outfile: $!";
    } else {
    }
}

sub close_out_file {
    close $STDOUT;
}

sub print_duplicates {

    # descending file size
    for my $file_size ( sort { $b <=> $a } keys %{ $file_processed->{dup} } ) {

        # every hash collect duplicates
        for my $hash ( sort keys %{ $file_processed->{dup}{$file_size} } ) {
              
            # files 
            for my $file_name (
                sort @{ $file_processed->{dup}{$file_size}{$hash} } )
            {
                printf $STDOUT "%s\n", $file_name;
            }
            print $STDOUT "\n";
        }
    }    
}

sub init_stat {
    for (qw(file_processed file_added file_hash_calculated file_duplicated)){
        $file_processed->{stat}{$_} = 0;
    }
}

sub print_stat {
    my $stat = $file_processed->{stat};
    printf $STDERR "\nSTATS:\n";
    printf $STDERR "   processed files  : %d\n", $stat->{file_processed};
    printf $STDERR "   analyzed files   : %d\n", $stat->{file_added};
    printf $STDERR "   hash calulated   : %d\n", $stat->{file_hash_calculated};
    printf $STDERR "   duplicated files : %d\n", $stat->{file_duplicated};
    printf $STDERR "\n";
}

sub usage {
    my $msg = shift;
    
    print $STDERR $msg, "\n" if defined $msg;
    
    print $STDERR <<EOTEXT;

NAME
ffdup $VERSION - Light duplicate file finder written in Perl

SYNOPSIS
ffdup [OPTIONS] DIR

DESCRIPTION
Files with same size are compared by MD5 hash to detect duplicates.

OPTIONS
    --out              Output file name (default stdout)
    --size_min         Don't compare files with size less than size_min
    --size_max         Don't compare files with size larger than size_max
    --help             This help

AUTHOR
Written by Luca Amore (lookee).
For the latest updates, please visit <http://www.lucaamore.com>
Git repository available at <http://github.com/...>

COPYRIGHT
Copyright (c) 2014 Free Software Foundation, Inc.  License GPLv3+: GNU GPL version 3
or later <http://gnu.org/licenses/gpl.html>.
This is free software: you are free to change and redistribute it. There is NO
WARRANTY, to the extent permitted by law.
                              
EOTEXT

    exit 1;
}

#------------------------------------------------
# M A I N
#------------------------------------------------

# Gather the options from the command line
GetOptions(
    \%opt,
    'help!',
    'size_min=i',
    'size_max=i',
    'out=s',
  )
  or usage;

# show usage
usage if $opt{help};

# get the root dir
$opt{dir}=$ARGV[0];

# check params
unless ( -d $opt{dir} ) {

    if (defined $opt{dir}){
        print 'cannot open root dir : ' . $opt{dir} . "\n";
    } else {
    	print "missing mandatory DIR parameter\n"
    }
    
    usage();
    
}

init_out_file;

init_stat;

dir_crawler( $opt{dir} );

find_duplicates;

print_duplicates;

print_stat;

close_out_file;

exit 0;
