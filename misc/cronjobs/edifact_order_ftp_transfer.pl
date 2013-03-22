#!/usr/bin/perl

# Copyright 2011,2012 Mark Gavillet & PTFS Europe Ltd
#
# This file is part of Koha.
#
# Koha is free software; you can redistribute it and/or modify it under the
# terms of the GNU General Public License as published by the Free Software
# Foundation; either version 2 of the License, or (at your option) any later
# version.
#
# Koha is distributed in the hope that it will be useful, but WITHOUT ANY
# WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
# A PARTICULAR PURPOSE.  See the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with Koha; if not, write to the Free Software Foundation, Inc.,
# 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.

use strict;
use warnings;
use C4::Context;
use C4::EDI qw ( GetEDIFTPAccounts ParseEDIQuote LogEDITransaction);
use Net::FTP;

my $ftpaccounts = GetEDIFTPAccounts;

my @errors;
my @putdirlist;
my $newerr;
my @files;
my $putdir = C4::Context->config('intranetdir');
$putdir .= '/misc/edi_files/';
my $ediparse;
opendir( my $dh, $putdir );
@putdirlist = readdir $dh;
closedir $dh;

foreach my $accounts (@$ftpaccounts) {
    my $ftp = Net::FTP->new( $accounts->{host}, Timeout => 10, Passive => 1 )
      or $newerr = 1;
    $ftp->binary();
    push @errors, "Can't ftp to $accounts->{host}: $!\n" if $newerr;
    myerr() if $newerr;
    if ( !$newerr ) {
        $newerr = 0;
        print "Connected to $accounts->{host}\n";

        $ftp->login( "$accounts->{username}", "$accounts->{password}" )
          or $newerr = 1;
        print "Getting file list\n";
        push @errors, "Can't login to $accounts->{host}: $!\n" if $newerr;
        $ftp->quit if $newerr;
        myerr() if $newerr;
        if ( !$newerr ) {
            print "Logged in\n";
            $ftp->cwd( $accounts->{in_dir} ) or $newerr = 1;
            push @errors, "Can't cd in server $accounts->{host} $!\n"
              if $newerr;
            myerr() if $newerr;
            $ftp->quit if $newerr;

            @files = $ftp->ls or $newerr = 1;
            push @errors,
              "Can't get file list from server $accounts->{host} $!\n"
              if $newerr;
            myerr() if $newerr;
            if ( !$newerr ) {
                print "Got  file list\n";
                foreach my $file (@files) {
                    if ( $file =~ m/\.ceq/i ) {
                        my $match;
                        foreach my $f (@putdirlist) {
                            if ( $f eq $file ) {
                                $match = 1;
                                last;
                            }
                        }
                        if ( $match != 1 ) {
                            chdir $putdir;
                            $ftp->get($file) or $newerr = 1;
                            push @errors,
"Can't transfer file ($file) from $accounts->{host} $!\n"
                              if $newerr;
                            $ftp->quit if $newerr;
                            myerr() if $newerr;
                            if ( !$newerr ) {
                                $ediparse =
                                  ParseEDIQuote( $file, $accounts->{provider} );
                            }
                            if ( $ediparse == 1 ) {
                                my $qext    = '.ceq';
                                my $rext    = '.eeq';
                                my $renamed = lc $file;
                                $renamed =~ s/$qext/$rext/g;
                                $ftp->rename( $file, $renamed );
                            }
                        }
                    }
                }
            }
        }
        if ( !$newerr ) {
            LogEDITransaction( $accounts->{id} );
        }
        $ftp->quit;
    }
    $newerr = 0;
}

print "\n@errors\n";

if (@errors) {
    my $logfile = C4::Context->config('intranetdir');
    $logfile .= '/misc/edi_files/edi_ftp_error.log';
    open my $fh, '>>', $logfile;
    my ( $sec, $min, $hour, $mday, $mon, $year ) = localtime(time);
    printf $fh "%4d-%02d-%02d %02d:%02d:%02d\n-----\n", $year + 1900,
      $mon + 1, $mday, $hour, $min, $sec;
    print $fh "@errors\n";
    close $fh;
}

sub myerr {
    print 'Error: ', @errors;
    return;
}
