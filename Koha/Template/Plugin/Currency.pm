package Koha::Template::Plugin::Currency;

# Copyright ByWater Solutions 2013

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

use base qw( Template::Plugin::Filter );

use Locale::Currency::Format;

use C4::Context;
use Koha::DateUtils;

sub init {
    my $self = shift;
    $self->{ _DYNAMIC } = 1;

    my $active_currency = C4::Context->dbh->selectrow_hashref(
        'SELECT * FROM currency WHERE active = 1', {} );
    $self->{active_currency} = $active_currency;

    return $self;
}

sub filter {
    my ( $self, $amount, $args, $conf ) = @_;

    return $self->format( $amount, undef, $conf->{highlight} );
}

sub format {
    my ( $self, $amount, $format, $highlight ) = @_;

    $amount ||= 0;
    my $is_negative = $amount < 0;
    $amount = abs( $amount ) if $highlight;

    # A negative debit is a credit and visa versa
    if ($highlight) {
        if ( $highlight eq 'debit' ) {
            if ($is_negative) {
                $highlight = 'credit';
            }
        }
        elsif ( $highlight eq 'credit' ) {
            if ($is_negative) {
                $highlight = 'debit';
            }

        }
        elsif ( $highlight eq 'offset' ) {
            $highlight = $is_negative ? 'credit' : 'debit';
        }
    }

    my $formatted = currency_format( $self->{active_currency}->{currency},
        $amount, $format || FMT_HTML );

    $formatted = "<span class='$highlight'>$formatted</span>" if ( $highlight && $amount );

    return $formatted;
}

sub format_without_symbol {
    my ( $self, $amount ) = @_;

    return substr(
        $self->format( $amount, FMT_SYMBOL ),
        length(
            currency_symbol( $self->{active_currency}->{'currency'} )
        )
    );
}

sub symbol {
    my ($self) = @_;

    return currency_symbol( $self->{active_currency}->{'currency'}, SYM_HTML );
}

1;
