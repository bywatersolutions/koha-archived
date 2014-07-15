package C4::Barcodes::prefix;

# Copyright 2011 ByWater Solutions
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

use strict;
use warnings;
use Carp;

use C4::Context;
use C4::Branch;
use C4::Debug;
use C4::Dates;

use vars qw($VERSION @ISA);
use vars qw($debug $cgi_debug);        # from C4::Debug, of course
use vars qw($branch $width);

BEGIN {
    $VERSION = 0.01;
    @ISA = qw(C4::Barcodes);
    $width = C4::Context->preference('itembarcodelength');
    my $prefix = '';
}


# This package generates auto-incrementing barcodes where branch-specific prefixes are being used.
# For a library with 10-digit barcodes, and a prefix of T123, this should generate on a range of
# T123000000 and T123999999
#
# There are a couple of problems with treating barcodes as straight-numerics and just incrementing
# them.  The first, and most-obvious, is that barcodes need not be numeric, particularly in the prefix
# part!  The second, as noted in C4::Barcodes.pm, is that you might not actually be able to handle very
# large ints like that...


sub db_max ($;$) {
        my $self = shift;
        my $sth = C4::Context->dbh->prepare("SELECT MAX(barcode) AS biggest FROM items where barcode LIKE ? AND length(barcode) =?");
        my $prefix_search = $self->prefix . '%';
        $sth->execute($prefix_search, $self->width);
        return $self->initial unless ($sth->rows);
        my ($row) = $sth->fetchrow_hashref();

        my $max = $row->{biggest};
        return ($max || 0);
}

sub initial () {
        my $self = shift;
        my $increment_width = $self->width - length($self->prefix);
        return $self->prefix . sprintf("%"."$increment_width.$increment_width"."d",1);
}

sub parse ($;$) {   # return 3 parts of barcode: non-incrementing, incrementing, non-incrementing
        my $self = shift;
        my $barcode = (@_) ? shift : $self->value;
        my $prefix = $self->prefix;
        unless ($barcode =~ /($prefix)(.+)$/) {
           return($barcode,undef,undef);
        }
        return ($1,$2,'');  # the third part is in anticipation of barcodes that include checkdigits
}

sub prefix ($;$) {
        my $self = shift;
        (@_) and $self->{prefix} = shift;
        return C4::Branch::GetBranchDetail(C4::Context->userenv->{'branch'})->{'itembarcodeprefix'};
}

sub width ($;$) {
       my $self = shift;
       (@_) and $width = shift;        # hitting the class variable.
       return $width;
}

sub next_value ($;$) {
    my $self = shift;
    my $specific = (scalar @_) ? 1 : 0;
    my $max = $specific ? shift : $self->max;
    return $self->initial unless ($max);
    my ($head,$incr,$tail) = $self->parse($max);
    return undef unless (defined $incr);
    my $incremented = '';

    while ($incr =~ /([a-zA-Z]*[0-9]*)\z/ ){
       my $fragment = $1;
       $fragment++;   #yes, you can do that with strings.  Clever.
       if (length($fragment) > length($1)){   #uhoh.  got to carry something over.
          $incremented = substr($fragment,1) . $incremented;
          $incr = $`;    #prematch.  grab everything *before* $1 from above, and go back thru this.
       }
       else {   #we're okay now.
          $incr = $` . $fragment . $incremented;
          last;
       }
    }

    my $next_val = $head . $incr .$tail;
    return $next_val;
}

sub new_object {
        my $class_or_object = shift;
        my $type = ref($class_or_object) || $class_or_object;
        my $self = $type->default_self('prefix_incr');
        # take the prefix from argument, or the existing object, or get it from the userenv, in that order
        return bless $self, $type;
}

1;
__END__
