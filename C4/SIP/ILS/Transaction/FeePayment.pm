package C4::SIP::ILS::Transaction::FeePayment;

use warnings;
use strict;

# Copyright 2011 PTFS-Europe Ltd.
#
# This file is part of Koha.
#
# Koha is free software; you can redistribute it and/or modify it
# under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 3 of the License, or
# (at your option) any later version.
#
# Koha is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with Koha; if not, see <http://www.gnu.org/licenses>.

use C4::Accounts qw(recordpayment makepayment WriteOffFee);
use Koha::Account::Lines;
use parent qw(C4::SIP::ILS::Transaction);


our $debug   = 0;
our $VERSION = 3.07.00.049;

my %fields = ();

sub new {
    my $class = shift;
    my $self  = $class->SUPER::new();

    foreach ( keys %fields ) {
        $self->{_permitted}->{$_} = $fields{$_};    # overlaying _permitted
    }

    @{$self}{ keys %fields } = values %fields;    # copying defaults into object
    return bless $self, $class;
}

sub pay {
    my $self           = shift;
    my $borrowernumber = shift;
    my $amt            = shift;
    my $type           = shift;
    my $fee_id         = shift;
    my $is_writeoff    = shift;

    warn("RECORD:$borrowernumber::$amt");

    my $fee = $fee_id ? Koha::Account::Lines->find($fee_id) : undef;

    if ($is_writeoff) { # Writeoffs require a fee id to be sent
        if ( $fee && $fee->amountoutstanding == $amt ) {
            WriteOffFee( $borrowernumber, $fee_id, undef, undef, $amt );
            return 1;
        }
        else {
            return 0;
        }
    }

    if ($fee_id) { # If a given fee is to be paid, the amount must match. This is a limitation of makepayment
        if ( $fee && $fee->amountoutstanding == $amt ) {
            makepayment( $fee_id, $borrowernumber, undef, $amt );
            return 1;
        }
        else {
            return 0;
        }
    }
    else { # Simply pay by amount
        recordpayment( $borrowernumber, $amt, $type );
        return 1;
    }
}

#sub DESTROY {
#}

1;
__END__

