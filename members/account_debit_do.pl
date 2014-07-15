#!/usr/bin/perl

# Copyright 2013 ByWater Solutions
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

use Modern::Perl;

use CGI;

use C4::Auth;
use C4::Output;
use C4::Members;
use C4::Items;
use C4::Branch;
use C4::Members::Attributes qw(GetBorrowerAttributes);
use Koha::Accounts;
use Koha::Database;

my $cgi = new CGI;

my $borrowernumber = $cgi->param('borrowernumber');
my $borrower =
  Koha::Database->new()->schema->resultset('Borrower')->find($borrowernumber);

if ( checkauth( $cgi, 0, { borrowers => 1 }, 'intranet' ) ) {

    #  print $cgi->header;
    my $barcode     = $cgi->param('barcode');
    my $itemnumber  = $cgi->param('itemnumber');
    my $description = $cgi->param('description');
    my $amount      = $cgi->param('amount');
    my $type        = $cgi->param('type');
    my $notes       = $cgi->param('notes');

    if ( !$itemnumber && $barcode ) {
        $itemnumber = GetItemnumberFromBarcode($barcode);
    }

    my $debit = AddDebit(
        {
            borrower    => $borrower,
            amount      => $amount,
            type        => $type,
            itemnumber  => $itemnumber,
            description => $description,
            notes       => $notes,

        }
    );

    my $debit_id = $debit->debit_id();

    print $cgi->redirect(
        "/cgi-bin/koha/members/account.pl?borrowernumber=$borrowernumber");
}
