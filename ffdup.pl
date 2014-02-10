#!/usr/bin/perl -w

my $VERSION = '0.0.2';

############################################################################
#
# ffdup
#
# Light duplicate files finder witten in Perl
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

# vim: set autoindent expandtab tabstop=4 shiftwidth=4 shiftround

use strict;
use warnings;
use utf8;

#use Cwd qw(cwd);
use Data::Dumper;               
use Digest::MD5;                # core v5.7.3
#use Digest::SHA;               # core v5.9.3
use File::Basename;
use File::Find;
#use File::Compare;
use Getopt::Long;
use Time::HiRes qw(time);       # core v5.7.3

# Global Variables

# output file handle
my $STDOUT  = *STDOUT;
my $STDERR  = *STDERR;

# Set defaults
my %opt = (
    dir         => undef,
    size_min    => 1024 ** 1,           
    size_max    => undef,
    print_size  => undef,
    output      => undef,
    hash        => 'MD5',
    verbose     => undef,
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
                defined $opt{size_min} && $file_size < $opt{size_min} ||
                defined $opt{size_max} && $file_size > $opt{size_max}
            ;

        push @{ $file_processed->{size}{$file_size} }, $file_name;
        
        $file_processed->{stat}{file_added}++;
        $file_processed->{stat}{file_size_added} += $file_size;
    }
}

sub get_file_size {
    return ( stat($_) )[7];
}

#------------------------------------------------
# H A S H I N G
#------------------------------------------------

sub find_duplicates {
  FIND_DUP: for my $file_size ( sort {$a <=> $b} keys %{ $file_processed->{size} } ) {

        my @files_with_same_size = @{ $file_processed->{size}{$file_size} };

        next FIND_DUP if scalar @files_with_same_size < 2;

        if ($opt{verbose}){
            printf $STDERR "processing hash: %s size : %s files: %d\n",
                $opt{hash}, 
                human_readable_size($file_size), 
                scalar @files_with_same_size;
        }

        # calculate hash only for file with the same size
        for my $file_name (@files_with_same_size) {
            my $hash = hash_file($file_name,$file_size);
            next FIND_DUP unless defined $hash;
            push @{ $file_processed->{dup}{$file_size}{$hash} }, $file_name;
            $file_processed->{stat}{file_hash_calculated}++;
            $file_processed->{stat}{file_hash_size_calculated}+= $file_size;
            print $STDERR '*' if ($opt{verbose});
        }

        print $STDERR "\n" if ($opt{verbose});

        # remove unique hashes (no duplicates)
        for my $hash ( keys %{ $file_processed->{dup}{$file_size} } ) {
            my $hash_multiplicity = 
                scalar @{ $file_processed->{dup}{$file_size}{$hash} };
            if ( $hash_multiplicity < 2 ) {
                delete $file_processed->{dup}{$file_size}{$hash};
            } else {
                $file_processed->{stat}{file_duplicated} += 
                    $hash_multiplicity - 1;
                $file_processed->{stat}{file_size_duplicated} += 
                    $file_size * ($hash_multiplicity -1);
            }
        }

        # remove file sizes with no duplicate
        if ( scalar keys %{ $file_processed->{dup}{$file_size} } == 0 ) {
            delete $file_processed->{dup}{$file_size};
        }
    }    # FIND_DUP
}

sub hash_file {
    my ($file, $file_size) = @_;

    my $hash_start_time = time;

    unless ( open( F, $file ) ) {
        print $STDERR "Can't open '$file' for reading: $!\n";
        return undef;
    }

    binmode(F);
    my $digest = 
        $opt{hash} eq 'MD5'     ? Digest::MD5->new->addfile(*F)         :
        $opt{hash} eq 'SHA1'    ? Digest::SHA->new(256)->addfile(*F)    :
        $opt{hash} eq 'SHA256'  ? Digest::SHA->new(256)->addfile(*F)    :
        die sprintf "wrong hash algorithm '%s'\n", $opt{hash}||'';
    close(F);

    $file_processed->{stat}{time_hash} += time - $hash_start_time;

    #sleep(rand(2));

    return $digest->b64digest;
}

#------------------------------------------------
# T O O L S 
#------------------------------------------------

sub human_readable_size {
    my $num = shift;
    #return $num unless $num =~ /^\d+$/;
    return sprintf("%s B" , round_size($num        )) if ($num < 1024**1);
    return sprintf("%s KB", round_size($num/1024**1)) if ($num < 1024**2);
    return sprintf("%s MB", round_size($num/1024**2)) if ($num < 1024**3);
    return sprintf("%s GB", round_size($num/1024**3)) if ($num < 1024**4);
    return sprintf("%s TB", round_size($num/1024**4)) if ($num < 1024**5);
    return sprintf("%s PB", round_size($num/1024**5)) if ($num < 1024**6);
    return sprintf("%s EB", round_size($num/1024**6)) if ($num < 1024**7);
    return sprintf("%s ZB", round_size($num/1024**7)) if ($num < 1024**8);
    return sprintf("%s EB", round_size($num/1024**8)) if ($num < 1024**9);
    return $num;
}

sub round_size {
    my $num = shift;
    return sprintf("%.2f", $num);
}

#------------------------------------------------
# O U T P U T
#------------------------------------------------

sub init_out_streams {
    # open output file (default STDOUT)
    my $outfile = $opt{out};

    if (defined $outfile){
        open($STDOUT, ">", $outfile) 
            or die "cannot open > $outfile: $!";
    } else {
    }
}

sub close_out_streams {
    close $STDOUT;
    close $STDERR;
}

sub print_duplicates {

    # descending file size
    for my $file_size ( sort { $b <=> $a } keys %{ $file_processed->{dup} } ) {

        if ($opt{print_size}){
            printf $STDOUT "# size: %s\n", human_readable_size($file_size);
        }

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
    $file_processed->{stat}{time_start} = time;
    for (qw(    file_processed 
                file_added 
                file_size_added 
                file_hash_calculated
                file_hash_size_calculated 
                file_duplicated
                file_size_duplicated
                time_hash
        )){
        $file_processed->{stat}{$_} = 0;
    }
}

sub stop_stat {

    $file_processed->{stat}{time_end} = time;

    $file_processed->{stat}{time_execution} = 
        $file_processed->{stat}{time_end} - 
        $file_processed->{stat}{time_start};

    if ($file_processed->{stat}{time_execution} > 0){
        $file_processed->{stat}{troughput_all} = 
            1000 * 
            $file_processed->{stat}{file_size_added} / 
            $file_processed->{stat}{time_execution};
    }

    if ($file_processed->{stat}{time_hash} > 0){
        $file_processed->{stat}{troughput_hash} = 
            1000 * 
            $file_processed->{stat}{file_hash_size_calculated} / 
            $file_processed->{stat}{time_hash};
    }
}

sub print_stat {
    my $stat = $file_processed->{stat};
    printf $STDERR "\nSTATS:\n";
    printf $STDERR "   duplicated files      : %d\n", $stat->{file_duplicated};
    printf $STDERR "   duplicated files size : %s\n", human_readable_size($stat->{file_size_duplicated});
    printf $STDERR "   processed files       : %d\n", $stat->{file_processed};
    printf $STDERR "   analyzed files        : %d\n", $stat->{file_added};
    printf $STDERR "   analyzed files size   : %s\n", human_readable_size($stat->{file_size_added});
    printf $STDERR "   execution time        : %.3f ms\n", $file_processed->{stat}{time_execution};
    printf $STDERR "   throughput            : %s\\s\n", human_readable_size($file_processed->{stat}{troughput_all})
        if defined $file_processed->{stat}{troughput_all};
    printf $STDERR "   hash calulated        : %d\n", $stat->{file_hash_calculated};
    printf $STDERR "   hash calculated size  : %s\n", human_readable_size($stat->{file_hash_size_calculated});
    printf $STDERR "   hash time             : %.3f ms\n", $file_processed->{stat}{time_hash};
    printf $STDERR "   hash throughput       : %s\\s\n", human_readable_size($file_processed->{stat}{troughput_hash})
        if defined $file_processed->{stat}{troughput_all};
    printf $STDERR "   hash algorithm        : %s\n", $opt{hash};
    printf $STDERR "\n";
}

sub usage {
    my $msg = shift;
    
    print $STDERR $msg, "\n" if defined $msg;
    
    print $STDERR <<EOTEXT;

NAME
ffdup $VERSION - Light duplicate file finder written in Perl.

SYNOPSIS
ffdup [OPTIONS] DIR

DESCRIPTION
Files with same size are compared by hash to detect duplicates.

OPTIONS
    --out = filename   Output file name (default stdout)
    --cwd              Current working directory as DIR
    --print_size       Print file size into output
    --size_min = int   Don't compare files with size less than size_min
    --size_max = int   Don't compare files with size larger than size_max
    --hash = string    Hash algorithm: SHA256 (strong), SHA1, MD5 (fast) def: MD5
    --verbose          Print debug messages
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

    exit 2;
}

sub check_params {

    # get the root dir
    $opt{dir}=$ARGV[0];

    unless ($opt{hash} =~ /^(SHA256|SHA1|MD5)$/){
        die "hash unhandled: '" . ($opt{hash} || '') . "'\n";
    }

    # only if required
    if ($opt{hash} =~ /^SHA/){
        require Digest::SHA;
    }

    unless ( defined $opt{dir} ) {
        if ($opt{cwd}){
            require Cwd;
            $opt{dir} = Cwd::cwd;
        } else {
            die "missing mandatory DIR argument or --cwd option\n";
        }
    } else {
        if ($opt{cwd}){
            die "DIE argument and --cwd option are incompatible\n";
        }
    }

    unless ( -d $opt{dir} ) {
        die 'cannot open root dir : ' . $opt{dir} . "\n";
    }

    return 1;
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
    'print_size!',
    'out=s',
    'cwd!',
    'hash=s',
    'verbose!',
  )
  or exit 1;

# show usage
usage if $opt{help};

MAIN: {

    check_params;

    init_out_streams;

    init_stat;

    print $STDERR "crawlig directories\n" if ($opt{verbose});

    dir_crawler( $opt{dir} );

    print $STDERR "find duplicates\n" if ($opt{verbose});

    find_duplicates;

    print_duplicates;

    stop_stat;

    print_stat;

    close_out_streams;

}

exit 0;
