#!/usr/bin/perl -w

# Copyright 2010 Biblibre SARL
#
# This file is part of Koha.
#
# Koha is free software; you can redistribute it and/or modify it under the
# terms of the GNU General Public License as published by the Free Software
# Foundation; either version 3 of the License, or (at your option) any later
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
use utf8;
use v5.10;

BEGIN {

    # find Koha's Perl modules
    # test carefully before changing this
    use FindBin;
    eval { require "$FindBin::Bin/../kohalib.pl" };
}

use Getopt::Long;

use Pod::Usage;
use Koha::Database;
use Koha::Accounts;

my ($help, $verbose, $borrower);

GetOptions(
    'h|help'         => \$help,
    'v|verbose'      => \$verbose,
    'b|borrower:s'   => \$borrower,
);

if($help){
    print <<EOF
    This script recalculates all patron account balances
    Parameters :
    -h --help This message
    -v --verbose
    -b --borrower - Recalculate only this borrower's account balance
EOF
;
    exit;
}

say "Finding borrowers..." if ( $verbose );

my $params;
$params->{borrowernumber} = $borrower if ( $borrower );

my $borrowers_rs = Koha::Database->new()->schema->resultset('Borrower')->search( $params );

while ( my $borrower = $borrowers_rs->next() ) {
    print "Setting balance for " . $borrower->firstname() . " " . $borrower->surname() . " ( " . $borrower->cardnumber() . " ) to " if ( $verbose );
    my $account_balance = NormalizeBalances({
        borrower => $borrower
    });
    say $account_balance if ( $verbose );
}
