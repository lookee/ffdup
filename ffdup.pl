#!/usr/bin/perl -w

my $VERSION = '0.0.5';

############################################################################
#
# ffdup
#
# Duplicate file finder witten in Perl
#
# Copyright 2014, Luca Amore - luca.amore at gmail.com
# <http://www.lucaamore.com>
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
use File::Spec qw(rel2abs);
#use File::Compare;
use Getopt::Long;
use Time::HiRes qw(time);       # core v5.7.3
use Fcntl qw(SEEK_SET SEEK_CUR SEEK_END);

# Global Variables

# output file handle
my $STDOUT  = *STDOUT;
my $STDERR  = *STDERR;

# Set defaults
my %opt = (
    size_min        => 1024 ** 1,       # 1KB           
    size_max        => undef,
    print_size      => undef,
    output          => undef,
    hash            => 'MD5',
    follow_symlink  => 0,
    quiet           => undef,
    progress        => 0,
    verbose         => 1,
    fast_scan       => 1,               # enable crc check before hash
    fast_scan_blk   => 4 * 1024 ** 1,   # 4KB
    fast_scan_head  => 1,
    fast_scan_mid   => 1,
    fast_scan_tail  => 1,
);

# global variables
my @DIRS;
my $cmd = basename($0);

# processed file
my $file_processed = {
    name => {},         # processed files by name
    size => {},         # processed files clustered by size
    dup  => {},         # dup detected by name
    stat => {},         # processing stat
};

#------------------------------------------------
# D I R  A N D  F I L E  C R A W L E R
#------------------------------------------------

# processing files through directory trees
sub dir_crawler {
    my $dir = File::Spec->rel2abs(shift);
    msg_section("crawling dir start: $dir");
    find( { wanted => \&file_crawler, follow => $opt{follow_symlink} }, $dir );
    msg_section("crawling dir end: $dir");
}

# processing file
sub file_crawler {
    my $full_abs_path_file_name = $File::Find::name;

    ADD_FILE: {

        msg_verbose_ln($full_abs_path_file_name);

        # process only files
        last ADD_FILE unless -f $full_abs_path_file_name;

        # process only readable files
        last ADD_FILE unless -r $full_abs_path_file_name;

        # don't process more time the same file
        if ($opt{store_all_processed_full_abs_path_file_name}){

            last ADD_FILE 
                if defined $file_processed->{name}{$full_abs_path_file_name};
        }

        $file_processed->{stat}{file_processed}++;

        my $file_size = get_file_size($full_abs_path_file_name);

        # don't process zero size file
        last ADD_FILE 
            unless defined $file_size || 
                $file_size == 0;

        # don't process files with size over the min/max window size
        last ADD_FILE 
            if 
                defined $opt{size_min} && $file_size < $opt{size_min} ||
                defined $opt{size_max} && $file_size > $opt{size_max}
            ;


        # store the filename with absolutepath with filename as key
        $file_processed->{name}{$full_abs_path_file_name} = $file_size
            if ($opt{store_all_processed_full_abs_path_file_name});

        # store the filename with absolute path clustered by size as key
        push @{ $file_processed->{size}{$file_size} }, $full_abs_path_file_name;
        
        # update stats
        $file_processed->{stat}{file_added}++;
        $file_processed->{stat}{file_size_added} += $file_size;

        msg_verbose_ln($full_abs_path_file_name . ' : processed' );

    } # end: ADD_FILE
}

sub get_file_size {
    return ( stat(shift) )[7];
}

#------------------------------------------------
# H A S H I N G
#------------------------------------------------

sub find_duplicates {
  FIND_DUP: for my $file_size ( sort {$b <=> $a} keys %{ $file_processed->{size} } ) {

        my $file_size_human = human_readable_size($file_size);

        my @files_with_same_size = @{ $file_processed->{size}{$file_size} };

        next FIND_DUP if scalar @files_with_same_size < 2;

        msg_section(
            sprintf "processing hash: %s size : %s files: %d",
                $opt{hash}, 
                $file_size_human, 
                scalar @files_with_same_size
        );

        if ($opt{fast_scan}){

            my $fast_hash = {};
            for my $file_name (@files_with_same_size) {
                msg_verbose_ln(
                    sprintf(
                        "%s : %s [%s]",
                        'CRC',
                        $file_name,
                        $file_size_human
                    )
                );
                my $hash = fast_hash_file($file_name, $file_size);
                push @{ $fast_hash->{$hash} }, $file_name;
                $file_processed->{stat}{file_fast_hash_calculated}++;
            }

            # only files with same crc
            @files_with_same_size = 
                map { @{$fast_hash->{$_}} }
                    grep { scalar @{$fast_hash->{$_}} >1 } 
                        keys %{$fast_hash}
                ;

        } # end: fast_scan

        # calculate hash only for file with the same size
        for my $file_name (@files_with_same_size) {
            msg_verbose_ln(
                sprintf(
                    "%s : %s [%s]",
                    $opt{hash},
                    $file_name,
                    $file_size_human
                )
            );
            my $hash = hash_file($file_name, $file_size);
            next FIND_DUP unless defined $hash;
            push @{ $file_processed->{dup}{$file_size}{$hash} }, $file_name;
            $file_processed->{stat}{file_hash_calculated}++;
            $file_processed->{stat}{file_hash_size_calculated}+= $file_size;
            msg_progress('*');
        }

        msg_progress_ln ("");

        # remove unique hashes (no duplicate)
        for my $hash ( keys %{ $file_processed->{dup}{$file_size} } ) {
            my $hash_multiplicity = 
                scalar @{ $file_processed->{dup}{$file_size}{$hash} };
            if ( $hash_multiplicity == 1 ) {
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

    my $fh;

    unless ( open( $fh, '<', $file ) ) {
        print $STDERR "ERROR: Can't open '$file' for reading: $!\n";
        return;
    }

    binmode($fh);
    my $digest = 
        $opt{hash} eq 'MD5'     ? Digest::MD5->new->addfile($fh)         :
        $opt{hash} eq 'SHA1'    ? Digest::SHA->new(256)->addfile($fh)    :
        $opt{hash} eq 'SHA256'  ? Digest::SHA->new(256)->addfile($fh)    :
        die sprintf "wrong hash algorithm '%s'\n", $opt{hash}||'';
    close($fh);

    $file_processed->{stat}{time_hash} += time - $hash_start_time;

    #sleep(rand(2));

    return $digest->b64digest;
}

sub fast_hash_file {
    my ($file_name, $file_size) = @_;

    my $fh;

    my $hash_start_time = time;

    my $block_size = $opt{fast_scan_blk}; 

    return '0' if $file_size < $block_size * 2;

    unless ( open( $fh, '<', $file_name ) ) {
        print $STDERR "ERROR: Can't open '$file_name' for reading: $!\n";
        return;
    }

    my @crc;

    my $buf;

    # crc head
    if ($opt{fast_scan_head}){
        read ($fh, $buf, $block_size);
        push @crc, unpack("%32C*", $buf) %32767;
    }

    # crc mid
    if ($opt{fast_scan_mid}){
        seek ($fh, int(($file_size - $block_size) / 2), SEEK_SET);
        read ($fh, $buf, $block_size );
        push @crc, unpack("%32C*", $buf) %32767;
    }

    # crc tail
    if ($opt{fast_scan_tail}){
        seek ($fh, -$block_size, SEEK_END);
        read ($fh, $buf, $block_size );
        push @crc, unpack("%32C*", $buf) %32767;
    }

    close($fh);

    my $crc = join('-', @crc);


    $file_processed->{stat}{time_fast_hash} += time - $hash_start_time;

    return $crc;
}

#------------------------------------------------
# T O O L S 
#------------------------------------------------

sub human_readable_size {
    my $num = shift;
    return sprintf("%s B" , 0                       ) if (!defined $num);
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
    return sprintf("%.2f", shift);
}

#------------------------------------------------
# M S G  O U T P U T
#------------------------------------------------

sub msg_section {
    msg_out_ln($_[0]) if $opt{verbose} || $opt{progress};
}

sub msg_verbose {
    msg_out($_[0]) if $opt{verbose};
}

sub msg_progress {
    msg_out($_[0]) if $opt{progress};
}

sub msg_verbose_ln {
    msg_out_ln($_[0]) if $opt{verbose};
}

sub msg_progress_ln {
    msg_out_ln($_[0]) if $opt{progress};
}

sub msg_out {
    print $STDERR $_[0];
}

sub msg_out_ln {
    print $STDERR $_[0], "\n";
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

#------------------------------------------------
# S T A T 
#------------------------------------------------

sub init_stat {
    $file_processed->{stat}{time_start} = time;
    for (qw(    file_processed 
                file_added 
                file_size_added 
                file_hash_calculated
                file_fast_hash_calculated
                file_hash_size_calculated 
                file_duplicated
                file_size_duplicated
                time_hash
                time_fast_hash
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
    return if $opt{quiet};
    my $stat = $file_processed->{stat};
    printf $STDERR "\nFFDUP STATS:\n";
    printf $STDERR "   duplicated files      : %d\n", $stat->{file_duplicated};
    printf $STDERR "   duplicated files size : %s\n", human_readable_size($stat->{file_size_duplicated});
    printf $STDERR "   processed files       : %d\n", $stat->{file_processed};
    printf $STDERR "   analyzed files        : %d\n", $stat->{file_added};
    printf $STDERR "   analyzed files size   : %s\n", human_readable_size($stat->{file_size_added});
    printf $STDERR "   execution time        : %.3f ms\n", $file_processed->{stat}{time_execution};
    printf $STDERR "   hash time             : %.3f ms\n", $file_processed->{stat}{time_hash};
    printf $STDERR "   hash fast time        : %.3f ms\n", $file_processed->{stat}{time_fast_hash};
    printf $STDERR "   throughput            : %s\\s\n", human_readable_size($file_processed->{stat}{troughput_all})
        if defined $file_processed->{stat}{troughput_all};
    printf $STDERR "   hash fast calulated   : %d\n", $stat->{file_fast_hash_calculated};
    printf $STDERR "   hash fast filtered    : %d\n", $stat->{file_fast_hash_calculated} - $stat->{file_hash_calculated} ;
    printf $STDERR "   hash calulated        : %d\n", $stat->{file_hash_calculated};
    printf $STDERR "   hash calculated size  : %s\n", human_readable_size($stat->{file_hash_size_calculated});
    printf $STDERR "   hash throughput       : %s\\s\n", human_readable_size($file_processed->{stat}{troughput_hash})
        if defined $file_processed->{stat}{troughput_all};
    printf $STDERR "   hash algorithm        : %s\n", $opt{hash};
    printf $STDERR "\n";
}

#------------------------------------------------
# U S A G E 
#------------------------------------------------
sub usage {
    my $msg = shift;
    
    print $STDERR $msg, "\n" if defined $msg;
    
    print $STDERR <<EOTEXT;

NAME
ffdup $VERSION - Duplicate file finder written in Perl.

SYNOPSIS
ffdup [OPTIONS] [DIR 1] ... [DIR N]

DESCRIPTION
Files with same size are compared by hash to detect duplicates.

OPTIONS
    --out = FILE         Output file name (default stdout)
    --cwd                Add current working directory as DIR
    --home               Add user home directory as DIR
    --print_size         Print file size into output
    --size_min = NUMBER  Don't compare files with size less than size_min
    --size_max = NUMBER  Don't compare files with size larger than size_max
    --hash = HASH        Hash algorithm: SHA256 (strong), SHA1, MD5 (fast) def: MD5
    --progress           Print progress messages
    --verbose            Print debug messages
    --quiet              Don't print verbose or debug messages
    --version            Print ffdup version
    --help               This help

AUTHOR
Written by Luca Amore.
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

#------------------------------------------------
# O P T S 
#------------------------------------------------
sub check_init_params {

    # get the root dir
    @DIRS = @ARGV;

    if ($opt{version}){
        printf "ffdup version: %s\n", $VERSION;
        exit 2;
    }

    unless ($opt{hash} =~ /^(SHA256|SHA1|MD5)$/){
        die "hash unhandled: '" . ($opt{hash} || '') . "'\n";
    }

    # only if required
    if ($opt{hash} =~ /^SHA/){
        require Digest::SHA;
    }
 
    if ($opt{cwd}){
        require Cwd;
        push @DIRS, Cwd::cwd;
    }

    if ($opt{home}){
        push @DIRS, $ENV{HOME};
    }

    unless (scalar @DIRS) {
            die "missing DIR to crawl\n";
    }

    if ($opt{verbose}){
        $opt{progress}=0;
    }

    if ($opt{quiet}){
        $opt{progress}=$opt{verbose}=0;
    }

    $opt{store_all_processed_full_abs_path_file_name} = scalar @DIRS > 1;

    # check dirs    
    for (@DIRS){
        unless ( -d $_ ) {
            die "cannot open root dir : $_\n";
        }
    }

    return 1;
}

#------------------------------------------------
# M A I N
#------------------------------------------------

# Gather the options from the command line
GetOptions(
    \%opt,
    'help',
    'size_min=i',
    'size_max=i',
    'print_size',
    'out=s',
    'cwd',
    'home',
    'hash=s',
    'verbose',
    'progress',
    'quiet',
    'version',
  )
  or exit 1;

# show usage
usage if $opt{help};

MAIN: {

    check_init_params;

    init_out_streams;

    init_stat;

    msg_section("CRAWLING DIRECTORIES");

    dir_crawler( $_ ) for @DIRS;

    msg_section("FIND DUPLICATES");

    find_duplicates;

    print_duplicates;

    stop_stat;

    print_stat;

    close_out_streams;

}

exit 0;
