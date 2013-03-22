#!/usr/bin/env perl

use strict;
use warnings;
use Test::More qw/no_plan/;
use Test::MockModule;
use DBD::Mock;

my $module_context = new Test::MockModule('C4::Context');
my $module_budgets = new Test::MockModule("C4::Budgets");

$module_context->mock(
    '_new_dbh',
    sub {
        my $dbh = DBI->connect( 'DBI:Mock:', '', '' )
       || die "Cannot create handle: $DBI::errstr\n";
        return $dbh;
    }
    );

my $dbh = C4::Context->dbh();

$module_context->mock("EDIfactEAN",sub{ return 1; });
$module_budgets->mock('GetCurrency',sub{ return {currency => "USD"}; });

use_ok('C4::EDI');
 SKIP: {
     skip "DBD::Mock is too old", 33
   unless $DBD::Mock::VERSION >= 1.45;

     $dbh->{mock_session} = DBD::Mock::Session->new('EDI_session' => (
                                                   { #GetVendorList
                                                           statement => "select id, name from aqbooksellers order by name asc",
                                                           results => [
                                                               ["id","name"],
                                                         [1,"Amazon"],
                                                          ]
                                                      },
                                                     { #GetEDIAccounts
                                                          statement => "select vendor_edi_accounts.id, aqbooksellers.id as providerid, aqbooksellers.name as vendor, vendor_edi_accounts.description, vendor_edi_accounts.last_activity from vendor_edi_accounts inner join aqbooksellers on vendor_edi_accounts.provider = aqbooksellers.id order by aqbooksellers.name asc",
                                                           results => [
                                                               ["vendor_edi_accounts.id", "providerid", "vendor", "vendor_edi_accounts.description", "vendor_edi_accounts.last_activity"],
                                                            [1,1,"Amazon", "Online Bookseller","2013-01-01 00:00:00"],
                                                             ]
                                                      },
                                                     { #GetEDIAccounts
                                                          statement => "select san from vendor_edi_accounts where provider=?",
                                                           results => [
                                                               ["san"],
                                                               [1],
                                                           ]
                                                      },
                                                     {
                                                          statement => "select message_type from edifact_messages where basketno=?",
                                                     results => [
                                                               ["message_type"],
                                                              ["QUOTE"],
                                                             ]
                                                      }
                                                  )
   );
     cmp_ok(C4::EDI->GetVendorList()->[0]->{name}, 'eq', 'Amazon');
     cmp_ok(C4::EDI->GetEDIAccounts->[0]->{vendor}, 'eq', 'Amazon');

my $module_acquisition = new Test::MockModule("C4::Acquisition");
$module_acquisition->mock('GetOrderItemInfo',sub{ return ("MPL","npl.lgf","BOOK","1234","Emergency"); });
$module_acquisition->mock('GetOrders',sub{
    return ({title => "test",
          author => "test",
      publishercode => '1',
          isbn => '1234567890',
          publicationyear => "1996",
             quantity => '1',
       ordernumber => '35',
           notes => "test_notes",
        });

});

my ($basketno, $booksellerid) = 1;
(-e C4::EDI->CreateEDIOrder($basketno,$booksellerid)) ?
    pass("Create EDI File!") :
    fail("Create EDI file!");

} # End Skip Block
