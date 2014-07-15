#!/usr/bin/perl
#
# This Koha test module is a stub!
# Add more tests here!!!

use strict;
use warnings;

use Test::More tests => 19;

use C4::Context;

BEGIN {
    use_ok('Koha::Database');
    use_ok('Koha::Accounts');
    use_ok('Koha::Accounts::DebitTypes');
    use_ok('Koha::Accounts::CreditTypes');
}

## Intial Setup ##
my $borrower = Koha::Database->new()->schema->resultset('Borrower')->create(
    {
        surname         => 'Test',
        categorycode    => 'S',
        branchcode      => 'MPL',
        account_balance => 0,
    }
);

my $biblio =
  Koha::Database->new()->schema->resultset('Biblio')
  ->create( { title => "Test Record" } );
my $biblioitem =
  Koha::Database->new()->schema->resultset('Biblioitem')
  ->create( { biblionumber => $biblio->biblionumber() } );
my $item = Koha::Database->new()->schema->resultset('Item')->create(
    {
        biblionumber     => $biblio->biblionumber(),
        biblioitemnumber => $biblioitem->biblioitemnumber(),
        replacementprice => 25.00,
        barcode          => q{TEST_ITEM_BARCODE}
    }
);

my $issue = Koha::Database->new()->schema->resultset('Issue')->create(
    {
        borrowernumber => $borrower->borrowernumber(),
        itemnumber     => $item->itemnumber(),
    }
);
## END initial setup

ok( Koha::Accounts::DebitTypes::Fine eq 'FINE', 'Test DebitTypes::Fine' );
ok( Koha::Accounts::DebitTypes::Lost eq 'LOST', 'Test DebitTypes::Lost' );
ok(
    Koha::Accounts::DebitTypes::IsValid('FINE'),
    'Test DebitTypes::IsValid with valid debit type'
);
ok(
    !Koha::Accounts::DebitTypes::IsValid('Not A Valid Fee Type'),
    'Test DebitTypes::IsValid with an invalid debit type'
);
my $authorised_value =
  Koha::Database->new()->schema->resultset('AuthorisedValue')->create(
    {
        category         => 'MANUAL_INV',
        authorised_value => 'TEST',
        lib              => 'Test',
    }
  );
ok( Koha::Accounts::DebitTypes::IsValid('TEST'),
    'Test DebitTypes::IsValid with valid authorised value debit type' );
$authorised_value->delete();

my $debit = AddDebit(
    {
        borrower   => $borrower,
        amount     => 5.00,
        type       => Koha::Accounts::DebitTypes::Fine,
        branchcode => 'MPL',
    }
);
ok( $debit, "AddDebit returned a valid debit id " . $debit->id() );

ok(
    $borrower->account_balance() == 5.00,
    "Borrower's account balance updated correctly. Should be 5.00, is " . $borrower->account_balance()
);

my $debit2 = AddDebit(
    {
        borrower   => $borrower,
        amount     => 7.00,
        type       => Koha::Accounts::DebitTypes::Fine,
        branchcode => 'MPL',
    }
);

my $credit = AddCredit(
    {
        borrower   => $borrower,
        type       => Koha::Accounts::CreditTypes::Payment,
        amount     => 9.00,
        branchcode => 'MPL',
    }
);

RecalculateAccountBalance( { borrower => $borrower } );
ok(
    sprintf( "%.2f", $borrower->account_balance() ) eq "3.00",
    "RecalculateAccountBalance updated balance correctly."
);

Koha::Database->new()->schema->resultset('AccountCredit')->create(
    {
        borrowernumber   => $borrower->borrowernumber(),
        type             => Koha::Accounts::CreditTypes::Payment,
        amount_paid      => 3.00,
        amount_remaining => 3.00,
    }
);
NormalizeBalances( { borrower => $borrower } );
ok(
    $borrower->account_balance() == 0.00,
    "NormalizeBalances updated balance correctly."
);

# Adding advance credit with no balance due
$credit = AddCredit(
    {
        borrower   => $borrower,
        type       => Koha::Accounts::CreditTypes::Payment,
        amount     => 9.00,
        branchcode => 'MPL',
    }
);
ok(
    $borrower->account_balance() == -9,
'Adding a $9 credit for borrower with 0 balance results in a -9 dollar account balance'
);

my $debit3 = AddDebit(
    {
        borrower   => $borrower,
        amount     => 5.00,
        type       => Koha::Accounts::DebitTypes::Fine,
        branchcode => 'MPL',
    }
);
ok(
    $borrower->account_balance() == -4,
'Adding a $5 debit when the balance is negative results in the debit being automatically paid, resulting in a balance of -4'
);

my $debit4 = AddDebit(
    {
        borrower   => $borrower,
        amount     => 6.00,
        type       => Koha::Accounts::DebitTypes::Fine,
        branchcode => 'MPL',
    }
);
ok(
    $borrower->account_balance() == 2,
'Adding another debit ( 6.00 ) more than the negative account balance results in a partial credit and a balance due of 2.00'
);
$credit = AddCredit(
    {
        borrower   => $borrower,
        type       => Koha::Accounts::CreditTypes::WriteOff,
        amount     => 2.00,
        branchcode => 'MPL',
        debit_id   => $debit4->debit_id(),
    }
);
ok( $borrower->account_balance() == 0,
    'WriteOff of remaining 2.00 balance succeeds' );

my $debit5 = DebitLostItem(
    {
        borrower => $borrower,
        issue    => $issue,
    }
);
ok( $borrower->account_balance() == 25,
    'DebitLostItem adds debit for replacement price of item' );

my $lost_credit =
  CreditLostItem( { borrower => $borrower, debit => $debit5 } );
ok(
    $borrower->account_balance() == 0,
    'CreditLostItem adds credit for same about as the debit for the lost tiem'
);

## Post test cleanup ##
$issue->delete();
$item->delete();
$biblio->delete();
$borrower->delete();
