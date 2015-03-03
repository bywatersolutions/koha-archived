#!/usr/bin/perl

# Copyright 2000-2002 Katipo Communications
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
use C4::Dates qw/format_date/;
use C4::Members;
use C4::Branch;
use C4::Members::Attributes qw(GetBorrowerAttributes);
use Koha::Database;

my $cgi = new CGI;

my ( $template, $loggedinuser, $cookie ) = get_template_and_user(
    {
        template_name   => "members/account.tt",
        query           => $cgi,
        type            => "intranet",
        authnotrequired => 0,
        flagsrequired   => { borrowers => 1, updatecharges => 1 },
        debug           => 1,
    }
);

my $show_all = $cgi->param('show_all');

my $borrowernumber = $cgi->param('borrowernumber');

my $borrower = GetMember( 'borrowernumber' => $borrowernumber );

my $schema = Koha::Database->new()->schema();

my %params;
$params{-not} = { amount_outstanding => '0' } unless $show_all;
my @debits = $schema->resultset('AccountDebit')->search(
    {
        'me.borrowernumber' => $borrowernumber,
        %params,
    },
    {
        prefetch => { account_offsets => 'credit' },
        order_by => { -desc           => 'me.created_on' }
    }
);

%params = ();
$params{-not} = { amount_remaining => '0' } unless $show_all;
my @credits = $schema->resultset('AccountCredit')->search(
    {
        'me.borrowernumber' => $borrowernumber,
        %params,
    },
    {
        prefetch => { account_offsets => 'debit' },
        order_by => { -desc           => 'me.created_on' }
    }
);

$template->param(
    debits   => \@debits,
    credits  => \@credits,
    borrower => $borrower,

    # IDs for automatic receipt printing
    debit_id  => $cgi->param('debit_id')  || undef,
    credit_id => $cgi->param('credit_id') || undef,

    show_all => $show_all,
);

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

output_html_with_http_headers $cgi, $cookie, $template->output;
