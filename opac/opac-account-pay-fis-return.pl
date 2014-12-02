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
use URI::Escape qw(uri_unescape);
use LWP::UserAgent;

use C4::Auth;
use C4::Output;
use C4::Members;
use C4::Accounts qw(makepayment);

use Koha::Database;

my $query = new CGI;

my ( $template, $borrowernumber, $cookie ) = get_template_and_user(
    {
        template_name   => "opac-user.tt",
        query           => $query,
        type            => "opac",
        authnotrequired => 0,
        flagsrequired   => { borrow => 1 },
        debug           => 1,
    }
);

my $rs = Koha::Database->new()->schema()->resultset('Accountline');

my $transaction_id = $query->param('TransactionId');

my $merchant_code = C4::Context->preference('FisMerchantCode');    #33WSH-LIBRA-PDWEB-W
my $settle_code   = C4::Context->preference('FisSettleCode');      #33WSH-LIBRA-PDWEB-00
my $password      = C4::Context->preference('FisApiPassword');     #testpass;

my $ua       = LWP::UserAgent->new;
my $url      = C4::Context->preference('FisApiUrl'); #https://paydirectapi.ca.link2gov.com/ProcessTransactionStatus;
my $response = $ua->post(
    $url,
    {
        L2GMerchantCode       => $merchant_code,
        Password              => $password,
        SettleMerchantCode    => $settle_code,
        OriginalTransactionId => $transaction_id,
    }
);

my ( $m, $v );

if ( $response->is_success ) {
    my @params = split( '&', uri_unescape( $response->decoded_content ) );
    my $params;
    foreach my $p (@params) {
        my ( $key, $value ) = split( '=', $p );
        $params->{$key} = $value // q{};
    }

    if ( $params->{TransactionID} eq $transaction_id ) {

        my $note = "FIS ( $transaction_id  )";

        unless ( $rs->search( { note => $note } )->count() ) {

            my @line_items = split( /,/, $query->param('LineItems') );

            my @paid;
            foreach my $l (@line_items) {
                $l = substr( $l, 1, length($l) - 2 );
                my ( undef, $id, $description, $amount ) = split( /[\*,\~]/, $l );
                push( @paid, { accountlines_id => $id, description => $description, amount => $amount } );

                makepayment( $id, $borrowernumber, undef, $amount, undef, undef, $note );
            }

            $m = 'valid_payment';
            $v = $params->{TransactionAmount};;
        }
        else {
            $m = 'duplicate_payment';
            $v = $transaction_id;
        }
    }
    else {
        $m = 'invalid_payment';
        $v = $transaction_id;
    }
}
else {
    die( $response->status_line );
}

print $query->redirect("/cgi-bin/koha/opac-account.pl?message=$m&message_value=$v");
