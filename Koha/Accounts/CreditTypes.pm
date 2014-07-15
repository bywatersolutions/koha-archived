package Koha::Accounts::CreditTypes;

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

=head1 NAME

Koha::AccountsCreditTypes - Module representing the enumerated data types for account fees

=head1 SYNOPSIS

use Koha::Accounts::CreditTypes;

my $type = Koha::Accounts::CreditTypes::Payment;

=head1 DESCRIPTION

The subroutines in this modules act as enumerated data types for the
different credit types in Koha ( i.e. payments, writeoffs, etc. )

=head1 FUNCTIONS

=head2 IsValid

This subroutine takes a given string and returns 1 if
the string matches one of the data types, and 0 if not.

FIXME: Perhaps we should use Class::Inspector instead of hard
coding the subs? It seems like it would be a major trade off
of speed just so we don't update something in two separate places
in the same file.

=cut

sub IsValid {
    my ($string) = @_;

    my $is_valid =
      (      $string eq Koha::Accounts::CreditTypes::Payment()
          || $string eq Koha::Accounts::CreditTypes::WriteOff()
          || $string eq Koha::Accounts::CreditTypes::Found()
          || $string eq Koha::Accounts::CreditTypes::Credit()
          || $string eq Koha::Accounts::CreditTypes::Forgiven() );

    unless ($is_valid) {
        $is_valid =
          Koha::Database->new()->schema->resultset('AuthorisedValue')
          ->count(
            { category => 'MANUAL_CREDIT', authorised_value => $string } );
    }

    return $is_valid;
}

=head2 Credit

=cut

sub Credit {
    return 'CREDIT';
}

=head2 Payment

=cut

sub Payment {
    return 'PAYMENT';
}

=head2 Writeoff

=cut

sub WriteOff {
    return 'WRITEOFF';
}

=head2 Writeoff

=cut

sub Found {
    return 'FOUND';
}

=head2 Forgiven

=cut

sub Forgiven {
    return 'FORGIVEN';
}

=head2 Fine reduction

=cut

sub FineReduction {
    return 'FINE_REDUCTION';
}

1;

=head1 AUTHOR

Kyle M Hall <kyle@bywatersolutions.com>

=cut
