#!/usr/bin/perl

#written 11/1/2000 by chris@katipo.oc.nz
#script to display borrowers account details

# Copyright 2000-2002 Katipo Communications
# Copyright 2010 BibLibre
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

use CGI;

use C4::Auth;
use C4::Output;
use C4::Members;
use C4::Items;
use C4::Branch;
use C4::Members::Attributes qw(GetBorrowerAttributes);
use C4::Koha;
use Koha::Accounts;
use Koha::Database;

my $input = new CGI;

my $borrowernumber = $input->param('borrowernumber');

my $borrower = GetMember( 'borrowernumber' => $borrowernumber );

my ( $template, $loggedinuser, $cookie ) = get_template_and_user(
    {
        template_name   => "members/account_debit.tt",
        query           => $input,
        type            => "intranet",
        authnotrequired => 0,
        flagsrequired   => { borrowers => 1, updatecharges => 1 },
        debug           => 1,
    }
);

$template->param( invoice_types_loop => GetAuthorisedValues('MANUAL_INV') );

# Standard /members/ borrower details data
## FIXME: This code is in every /members/ script and should be unified

if ( $borrower->{'category_type'} eq 'C' ) {
    my ( $catcodes, $labels ) =
      GetborCatFromCatType( 'A', 'WHERE category_type = ?' );
    my $cnt = scalar(@$catcodes);
    $template->param( 'CATCODE_MULTI' => 1 ) if $cnt > 1;
    $template->param( 'catcode' => $catcodes->[0] ) if $cnt == 1;
}

my ( $picture, $dberror ) = GetPatronImage( $borrower->{'borrowernumber'} );
$template->param( picture => 1 ) if $picture;

if ( C4::Context->preference('ExtendedPatronAttributes') ) {
    my $attributes = GetBorrowerAttributes($borrowernumber);
    $template->param(
        ExtendedPatronAttributes => 1,
        extendedattributes       => $attributes
    );
}

$template->param(
    borrowernumber => $borrowernumber,
    firstname      => $borrower->{'firstname'},
    surname        => $borrower->{'surname'},
    cardnumber     => $borrower->{'cardnumber'},
    categorycode   => $borrower->{'categorycode'},
    category_type  => $borrower->{'category_type'},
    categoryname   => $borrower->{'description'},
    address        => $borrower->{'address'},
    address2       => $borrower->{'address2'},
    city           => $borrower->{'city'},
    state          => $borrower->{'state'},
    zipcode        => $borrower->{'zipcode'},
    country        => $borrower->{'country'},
    phone          => $borrower->{'phone'},
    email          => $borrower->{'email'},
    branchcode     => $borrower->{'branchcode'},
    branchname     => GetBranchName( $borrower->{'branchcode'} ),
    is_child       => ( $borrower->{'category_type'} eq 'C' ),
    activeBorrowerRelationship =>
      ( C4::Context->preference('borrowerRelationship') ne '' ),
    RoutingSerials => C4::Context->preference('RoutingSerials'),
);

output_html_with_http_headers $input, $cookie, $template->output;
