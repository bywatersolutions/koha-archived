package Koha::Accounts::DebitTypes;

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

Koha::Accounts::DebitTypes - Module representing an enumerated data type for account fees

=head1 SYNOPSIS

use Koha::Accounts::DebitTypes;

my $type = Koha::Accounts::DebitTypes::Fine;

=head1 DESCRIPTION

The subroutines in this modules act as an enumerated data type
for debit types ( stored in account_debits.type ) in Koha.

=head1 FUNCTIONS

=head2 IsValid

This subroutine takes a given string and returns 1 if
the string matches one of the data types, and 0 if not.

=cut

sub IsValid {
    my ($string) = @_;

    my $is_valid =
      (      $string eq Koha::Accounts::DebitTypes::Fine()
          || $string eq Koha::Accounts::DebitTypes::AccountManagementFee()
          || $string eq Koha::Accounts::DebitTypes::Sundry()
          || $string eq Koha::Accounts::DebitTypes::Lost()
          || $string eq Koha::Accounts::DebitTypes::Hold()
          || $string eq Koha::Accounts::DebitTypes::Rental()
          || $string eq Koha::Accounts::DebitTypes::NewCard() );

    unless ($is_valid) {
        $is_valid =
          Koha::Database->new()->schema->resultset('AuthorisedValue')
          ->count( { category => 'MANUAL_INV', authorised_value => $string } );
    }

    return $is_valid;
}

=head2 Fine

This data type represents a standard fine within Koha.

A fine still accruing no longer needs to be differiated by type
from a fine done accuring. Instead, that differentication is made
by which table the fine exists in, account_fees_accruing vs account_fees_accrued.

In addition, fines can be checked for correctness based on the issue_id
they have. A fine in account_fees_accruing should always have a matching
issue_id in the issues table. A fine done accruing will almost always have
a matching issue_id in the old_issues table. However, in the case of an overdue
item with fines that has been renewed, and becomes overdue again, you may have
a case where a given issue may have a matching fine in account_fees_accruing and
one or more matching fines in account_fees_accrued ( one for each for the first
checkout and one each for any subsequent renewals )

=cut

sub Fine {
    return 'FINE';
}

=head2 AccountManagementFee

This fee type is usually reserved for payments for library cards,
in cases where a library must charge a patron for the ability to
check out items.

=cut

sub AccountManagementFee {
    return 'ACCOUNT_MANAGEMENT_FEE';
}

=head2 Sundry

This fee type is basically a 'misc' type, and should be used
when no other fee type is more appropriate.

=cut

sub Sundry {
    return 'SUNDRY';
}

=head2 Lost

This fee type is used when a library charges for lost items.

=cut

sub Lost {
    return 'LOST';
}

=head2 Hold

This fee type is used when a library charges for holds.

=cut

sub Hold {
    return 'HOLD';
}

=head2 Rental

This fee type is used when a library charges a rental fee for the item type.

=cut

sub Rental {
    return 'RENTAL';
}

=head2 NewCard

This fee type is used when a library charges for replacement
library cards.

=cut

sub NewCard {
    return 'NEW_CARD';
}

1;

=head1 AUTHOR

Kyle M Hall <kyle@bywatersolutions.com>

=cut
