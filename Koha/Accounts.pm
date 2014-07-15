package Koha::Accounts;

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

use Carp;
use Data::Dumper qw(Dumper);

use C4::Context;
use C4::Log qw(logaction);
use Koha::DateUtils;
use Koha::Accounts::CreditTypes;
use Koha::Accounts::DebitTypes;
use Koha::Accounts::OffsetTypes;
use Koha::Database;

use vars qw($VERSION @ISA @EXPORT);

BEGIN {
    require Exporter;
    @ISA    = qw(Exporter);
    @EXPORT = qw(
      AddDebit
      AddCredit

      VoidCredit

      NormalizeBalances

      RecalculateAccountBalance

      DebitLostItem
      CreditLostItem
    );
}

=head1 NAME

Koha::Accounts - Functions for dealing with Koha accounts

=head1 SYNOPSIS

use Koha::Accounts;

=head1 DESCRIPTION

The functions in this module deal with the monetary aspect of Koha,
including looking up and modifying the amount of money owed by a
patron.

=head1 FUNCTIONS

=head2 AddDebit

my $debit = AddDebit({
    borrower       => $borrower,
    amount         => $amount,
    [ type         => $type,        ]
    [ itemnumber   => $itemnumber,  ]
    [ issue_id     => $issue_id,    ]
    [ description  => $description, ]
    [ notes        => $notes,       ]
    [ branchcode   => $branchcode,  ]
    [ manager_id   => $manager_id,  ]
    [ accruing     => $accruing,    ] # Default 0 if not accruing, 1 if accruing
});

Create a new debit for a given borrower. To standardize nomenclature, any charge
against a borrower ( e.g. a fine, a new card charge, the cost of losing an item )
will be referred to as a 'debit'.

=cut

sub AddDebit {
    my ($params) = @_;

    my $borrower    = $params->{borrower};
    my $amount      = $params->{amount};
    my $type        = $params->{type};
    my $itemnumber  = $params->{itemnumber};
    my $issue_id    = $params->{issue_id};
    my $description = $params->{description};
    my $notes       = $params->{notes};
    my $branchcode  = $params->{branchcode};
    my $manager_id  = $params->{manager_id};

    my $userenv = C4::Context->userenv;

    $branchcode ||=
        $userenv
      ? $userenv->{branch}
      : undef;

    $manager_id ||=
        $userenv
      ? $userenv->{number}
      : undef;

    my $accruing = $params->{accruing} || 0;

    croak("Required parameter 'borrower' not passed in.")
      unless ($borrower);
    croak("Required parameter 'amount' not passed in.")
      unless ($amount);
    croak("Invalid debit type: '$type'!")
      unless ( Koha::Accounts::DebitTypes::IsValid($type) );
    croak("No issue id passed in for accruing debit!")
      if ( $accruing && !$issue_id );

    my $debit =
      Koha::Database->new()->schema->resultset('AccountDebit')->create(
        {
            borrowernumber        => $borrower->borrowernumber(),
            itemnumber            => $itemnumber,
            issue_id              => $issue_id,
            type                  => $type,
            accruing              => $accruing,
            amount_original       => $amount,
            amount_outstanding    => $amount,
            amount_last_increment => $amount,
            description           => $description,
            notes                 => $notes,
            branchcode            => $branchcode,
            manager_id            => $manager_id,
            created_on            => Koha::DateUtils::get_timestamp(),
        }
      );

    if ($debit) {
        NormalizeBalances( { borrower => $borrower } );

        if ( C4::Context->preference("FinesLog") ) {
            logaction( "FINES", "CREATE_FEE", $debit->id,
                Dumper( $debit->get_columns() ) );
        }
    }
    else {
        carp("Something went wrong! Debit not created!");
    }

    return $debit;
}

=head2 DebitLostItem

my $debit = DebitLostItem({
    borrower       => $borrower,
    issue          => $issue,
});

DebitLostItem adds a replacement fee charge for the item
of the given issue.

=cut

sub DebitLostItem {
    my ($params) = @_;

    my $borrower = $params->{borrower};
    my $issue    = $params->{issue};

    croak("Required param 'borrower' not passed in!") unless ($borrower);
    croak("Required param 'issue' not passed in!")    unless ($issue);

# Don't add lost debit if borrower has already been charged for this lost item before,
# for this issue. It seems reasonable that a borrower could lose an item, find and return it,
# check it out again, and lose it again, so we should do this based on issue_id, not itemnumber.
    unless (
        Koha::Database->new()->schema->resultset('AccountDebit')->search(
            {
                borrowernumber => $borrower->borrowernumber(),
                issue_id       => $issue->issue_id(),
                type           => Koha::Accounts::DebitTypes::Lost
            }
        )->count()
      )
    {
        my $item = $issue->item();

        $params->{accruing}   = 0;
        $params->{type}       = Koha::Accounts::DebitTypes::Lost;
        $params->{amount}     = $item->replacementprice();
        $params->{itemnumber} = $item->itemnumber();
        $params->{issue_id}   = $issue->issue_id();
        $params->{description} =
            "Lost Item "
          . $issue->item()->biblio()->title() . " "
          . $issue->item()->barcode();

        #TODO: Shouldn't we have a default replacement price as a syspref?
        if ( $params->{amount} ) {
            return AddDebit($params);
        }
        else {
            carp("Cannot add lost debit! Item has no replacement price!");
        }
    }
}

=head2 CreditLostItem

my $debit = CreditLostItem(
    {
        borrower => $borrower,
        debit    => $debit,
    }
);

CreditLostItem creates a payment in the amount equal
to the replacement price charge created by DebitLostItem.

=cut

sub CreditLostItem {
    my ($params) = @_;

    my $borrower = $params->{borrower};
    my $debit    = $params->{debit};

    croak("Required param 'borrower' not passed in!") unless ($borrower);
    croak("Required param 'debit' not passed in!")
      unless ($debit);

    my $item =
      Koha::Database->new()->schema->resultset('Item')
      ->find( $debit->itemnumber() );
    carp("No item found!") unless $item;

    $params->{type}     = Koha::Accounts::CreditTypes::Found;
    $params->{amount}   = $debit->amount_original();
    $params->{debit_id} = $debit->debit_id();
    $params->{notes}    = "Lost item found: " . $item->barcode();

    return AddCredit($params);
}

=head2 AddCredit

AddCredit({
    borrower       => $borrower,
    amount         => $amount,
    [ branchcode   => $branchcode, ]
    [ manager_id   => $manager_id, ]
    [ debit_id     => $debit_id, ] # The primary debit to be paid
    [ notes        => $notes, ]
});

Record credit by a patron. C<$borrowernumber> is the patron's
borrower number. C<$credit> is a floating-point number, giving the
amount that was paid.

Amounts owed are paid off oldest first. That is, if the patron has a
$1 fine from Feb. 1, another $1 fine from Mar. 1, and makes a credit
of $1.50, then the oldest fine will be paid off in full, and $0.50
will be credited to the next one.

debit_id can be passed as a scalar or an array ref to make the passed
in debit or debits the first to be credited.

=cut

sub AddCredit {
    my ($params) = @_;

    my $type            = $params->{type};
    my $borrower        = $params->{borrower};
    my $amount          = $params->{amount};
    my $amount_received = $params->{amount_received};
    my $debit_id        = $params->{debit_id};
    my $notes           = $params->{notes};
    my $branchcode      = $params->{branchcode};
    my $manager_id      = $params->{manager_id};

    my $userenv = C4::Context->userenv;

    $branchcode ||=
        $userenv
      ? $userenv->{branch}
      : undef;

    $manager_id ||=
        $userenv
      ? $userenv->{number}
      : undef;

    unless ($borrower) {
        croak("Required parameter 'borrower' not passed in");
    }
    unless ($amount) {
        croak("Required parameter amount not passed in");
    }

    unless ($type && Koha::Accounts::CreditTypes::IsValid($type) ) {
        carp("Invalid type $type passed in, assuming Payment");
        $type = Koha::Accounts::CreditTypes::Payment;
    }

    # First, we make the credit. We'll worry about what we paid later on
    my $credit =
      Koha::Database->new()->schema->resultset('AccountCredit')->create(
        {
            borrowernumber   => $borrower->borrowernumber(),
            type             => $type,
            amount_received  => $amount_received,
            amount_paid      => $amount,
            amount_remaining => $amount,
            notes            => $notes,
            branchcode       => $branchcode,
            manager_id       => $manager_id,
            created_on       => Koha::DateUtils::get_timestamp(),
        }
      );

    if ( C4::Context->preference("FinesLog") ) {
        logaction( "FINES", "CREATE_PAYMENT", $credit->id,
            Dumper( $credit->get_columns() ) );
    }

    # If we are given specific debits, pay those ones first.
    if ($debit_id) {
        my @debit_ids = ref($debit_id) eq "ARRAY" ? @$debit_id : $debit_id;
        foreach my $debit_id (@debit_ids) {
            my $debit =
              Koha::Database->new()->schema->resultset('AccountDebit')
              ->find($debit_id);

            if ($debit) {
                CreditDebit( { credit => $credit, debit => $debit } );
            }
            else {
                carp("Invalid debit_id passed in!");
            }
        }
    }

    NormalizeBalances( { borrower => $borrower } );

    return $credit;
}

=head2 CreditDebit

$account_offset = CreditDebit({
    credit => $credit,
    debit => $debit,
});

Given a credit and a debit, this subroutine
will pay the appropriate amount of the debit,
update the debit's amount outstanding, the credit's
amout remaining, and create the appropriate account
offset.

=cut

sub CreditDebit {
    my ($params) = @_;

    my $credit = $params->{credit};
    my $debit  = $params->{debit};

    croak("Required parameter 'credit' not passed in!")
      unless $credit;
    croak("Required parameter 'debit' not passed in!")
      unless $debit;

    my $amount_to_pay =
      ( $debit->amount_outstanding() > $credit->amount_remaining() )
      ? $credit->amount_remaining()
      : $debit->amount_outstanding();

    if ( $amount_to_pay > 0 ) {
        $debit->amount_outstanding(
            $debit->amount_outstanding() - $amount_to_pay );
        $debit->updated_on( Koha::DateUtils::get_timestamp() );
        $debit->update();

        $credit->amount_remaining(
            $credit->amount_remaining() - $amount_to_pay );
        $credit->updated_on( Koha::DateUtils::get_timestamp() );
        $credit->update();

        my $offset =
          Koha::Database->new()->schema->resultset('AccountOffset')->create(
            {
                amount     => $amount_to_pay * -1,
                debit_id   => $debit->id(),
                credit_id  => $credit->id(),
                created_on => Koha::DateUtils::get_timestamp(),
            }
          );

        if ( C4::Context->preference("FinesLog") ) {
            logaction( "FINES", "MODIFY", $offset->id,
                Dumper( $offset->get_columns() ) );
        }

        return $offset;
    }
}

=head2 RecalculateAccountBalance

$account_balance = RecalculateAccountBalance({
    borrower => $borrower
});

Recalculates a borrower's balance based on the
sum of the amount outstanding for the borrower's
debits minus the sum of the amount remaining for
the borrowers credits.

TODO: Would it be better to use af.amount_original - ap.amount_paid for any reason?
      Or, perhaps calculate both and compare the two, for error checking purposes.
=cut

sub RecalculateAccountBalance {
    my ($params) = @_;

    my $borrower = $params->{borrower};
    croak("Requred parameter 'borrower' not passed in!")
      unless ($borrower);

    my $debits =
      Koha::Database->new()->schema->resultset('AccountDebit')
      ->search( { borrowernumber => $borrower->borrowernumber() } );
    my $amount_outstanding = $debits->get_column('amount_outstanding')->sum()
      || 0;

    my $credits =
      Koha::Database->new()->schema->resultset('AccountCredit')
      ->search( { borrowernumber => $borrower->borrowernumber() } );
    my $amount_remaining = $credits->get_column('amount_remaining')->sum() || 0;

    my $account_balance = $amount_outstanding - $amount_remaining;
    $borrower->account_balance($account_balance);
    $borrower->update();

    return $account_balance;
}

=head2 VoidCredit
    $account_balance = VoidCredit({ id => $credit_id });

    Reverts a payment. All debits paid by this payment will be
    updated such that the amount offset is reinstated for the debit.
=cut

sub VoidCredit {
    my ($params) = @_;

    my $id = $params->{id};

    croak("No id passed in!") unless $id;

    my $schema = Koha::Database->new()->schema();

    my $credit = $schema->resultset('AccountCredit')->find($id);

    foreach my $offset ( $credit->account_offsets() ) {
        my $debit = $offset->debit();

        $debit->amount_outstanding(
            $debit->amount_outstanding() - $offset->amount() );
        $debit->updated_on( Koha::DateUtils::get_timestamp() );
        $debit->update();

        Koha::Database->new()->schema->resultset('AccountOffset')->create(
            {
                amount     => $offset->amount() * -1,
                debit_id   => $debit->id(),
                credit_id  => $credit->id(),
                created_on => Koha::DateUtils::get_timestamp(),
                type       => Koha::Accounts::OffsetTypes::Void(),
            }
        );
    }

    $credit->amount_voided( $credit->amount_paid );
    $credit->amount_paid(0);
    $credit->amount_remaining(0);
    $credit->updated_on( Koha::DateUtils::get_timestamp() );
    $credit->update();

    return RecalculateAccountBalance( { borrower => $credit->borrower() } );
}

=head2 NormalizeBalances

    $account_balance = NormalizeBalances({ borrower => $borrower });

    For a given borrower, this subroutine will find all debits
    with an outstanding balance and all credits with an unused
    amount remaining and will pay those debits with those credits.

=cut

sub NormalizeBalances {
    my ($params) = @_;

    my $borrower = $params->{borrower};

    croak("Required param 'borrower' not passed in!") unless $borrower;

    my $schema = Koha::Database->new()->schema();

    my @credits = $schema->resultset('AccountCredit')->search(
        {
            borrowernumber   => $borrower->borrowernumber(),
            amount_remaining => { '>' => '0' }
        }
    );

    my @debits = $schema->resultset('AccountDebit')->search(
        {
            borrowernumber     => $borrower->borrowernumber(),
            amount_outstanding => { '>' => '0' }
        }
    );

    foreach my $credit (@credits) {
        foreach my $debit (@debits) {
            if (   $credit->amount_remaining()
                && $debit->amount_outstanding() )
            {
                CreditDebit( { credit => $credit, debit => $debit } );
            }
        }
    }

    return RecalculateAccountBalance( { borrower => $borrower } );
}

1;
__END__

=head1 AUTHOR

Kyle M Hall <kyle@bywatersolutions.com>

=cut
