package Koha::Accounts::OffsetTypes;

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

Koha::AccountsOffsetTypes - Module representing the enumerated data types for account fees

=head1 SYNOPSIS

use Koha::Accounts::OffsetTypes;

my $type = Koha::Accounts::OffsetTypes::Dropbox;

=head1 DESCRIPTION

The subroutines in this modules act as enumerated data types for the
different automatic offset types in Koha ( i.e. forgiveness, dropbox mode, etc )

These types are used for account offsets that have no corrosponding account credit,
e.g. automatic fine increments, dropbox mode, etc.

=head1 FUNCTIONS

=cut

=head2 Dropbox

Offset type for automatic fine reductions
via dropbox mode.

=cut

sub Dropbox {
    return 'DROPBOX';
}

=head2 Fine

Indicates this offset was an automatically
generated fine increment/decrement.

=cut

sub Fine {
    return 'FINE';
}

=head2 VOID

Indicates this offset was an automatically
generated in response to a voided credit

=cut

sub Void {
    return 'VOID';
}

1;

=head1 AUTHOR

Kyle M Hall <kyle@bywatersolutions.com>

=cut
