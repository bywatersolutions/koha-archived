#!/usr/bin/perl

# Copyright ByWater Solutions 2014
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

use Modern::Perl;

use CGI;

use C4::Members;
use C4::Circulation;
use C4::Auth;
use C4::Output;

use Koha::Database;

my $query = new CGI;

my ( $template, $borrowernumber, $cookie ) = get_template_and_user(
    {
        template_name   => "opac-account-pay.tt",
        query           => $query,
        type            => "opac",
        authnotrequired => 0,
        flagsrequired   => { borrow => 1 },
        debug           => 1,
    }
);

my $borrower = GetMemberDetails($borrowernumber);

my @accountline_ids = $query->param('accountline');

my $rs = Koha::Database->new()->schema()->resultset('Accountline');
my @accountlines = map { $rs->find($_) } @accountline_ids;

$template->param(
    borrower       => $borrower,
    payment_method => $query->param('payment_method'),
    accountlines   => \@accountlines,
);

output_html_with_http_headers $query, $cookie, $template->output;

