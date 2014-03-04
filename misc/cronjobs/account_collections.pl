#!/usr/bin/perl

# Copyright 2014 ByWater Solutions
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

use Getopt::Long;
use File::Spec;
use Text::CSV;

use C4::Context;
use Koha::Accounts qw(AddDebit);

my $help;
my $verbose;
my $directory;

my $minimum_balance = "0.01";
my $begin_date;
my $end_date;
my @exclude_fee_types;
my @branchcodes;
my @exclude_patron_types;
my $processing_fee;
my $processing_fee_type;
my $processing_fee_description;
my $can_collect_attribute_code;
my $in_collections_attribute_code;
my $last_updated_attribute_code;
my $previous_balance_attribute_code;
my $report_type;
my @where;
my $separator = ",";

GetOptions(
    'h|help'    => \$help,
    'v|verbose' => \$verbose,
    'd|dir:s'   => \$directory,

    'f|fee:s'              => \$processing_fee,
    'ft|fee-type:s'        => \$processing_fee_type,
    'fd|fee-description:s' => \$processing_fee_description,

    'mb|min-balance:s'         => \$minimum_balance,
    'bd|begin-date:s'          => \$begin_date,
    'ed|end-date:s'            => \$end_date,
    'et|exclude-fee-type:s'    => \@exclude_fee_types,
    'b|branchcode:s'           => \@branchcodes,
    'ep|exclude-patron-type:s' => \@exclude_patron_types,

    'c|can-collect-attribute-code:s'      => \$can_collect_attribute_code,
    'i|in-collections-attribute-code:s'   => \$in_collections_attribute_code,
    'l|last-updated-attribute-code:s'     => \$last_updated_attribute_code,
    'p|previous-balance-attribute-code:s' => \$previous_balance_attribute_code,

    'r|report-type:s' => \$report_type,

    'w|where:s' => \@where,

    's|separator:s' => \$separator,
);
my $usage = << 'ENDUSAGE';

This script has the following parameters :
    -h  --help: this message
    -d  --dir:  ouput directory (defaults to /tmp if !exist)
    -v  --verbose

    The following parameters are required for the submission report
    -mb --min-balance:         Minimum monetary value associated with a particular set of defined library branches
    -bd --begin-date:          Date before which that unpaid fines DO NOT apply to the Minimum Balance criterion
    -ed --end-date:            Date after which unpaid fines DO NOT apply to the Minimum Balance criterion
    -et --exclude-fee-type:    Fine codes/types which should NOT apply to the Minimum Balance criterion, repeatable
    -b  --branchcode:          Only unpaid fines/fees of patrons associated with specified branches should be considered, repeatable
    -ep --exclude-patron-type: Patron or borrower types which should NOT be referred to the collections agency, repeatable
    -f --fee:              Fee to charge patrons who enter into collections
    -ft --fee-type:        Fee type to charge
    -fd --fee-description: Description to use for fee

    -c --can-collect-attribute-code:      The patron attribute code that defines if a patron can be collected from ( YES_NO authorized value )
    -i --in-collections-attribute-code:   The patron attribute code that defines if a patron is currently in collecions ( YES_NO authorised value )
    -l --last-updated-attribute-code:     The patron attribute code that defines the date the patron was last updated for collections purposes
    -p --previous-balance-attribute-code: The patron balance of the last time the update report was run

    -r --report-type: The report type to execute:
        submission    Output the submission report, new patrons that meet library defined criteria for referral to collection agency.
        update        Output the update report, previously referred accounts that have had a change in balance (positive or negative) 
                      since the last time the update report was generated.
        sync          Output the sync report, a list of all accounts currently referred to the collections agency

    -w --where: Additional clauses you want added to the WHERE statment, repeatable

    -s --separator: The character used for separating fields, default is a comma (,)

ENDUSAGE

if (
    $help
    || !(
           $report_type
        && $can_collect_attribute_code
        && $in_collections_attribute_code
        && $last_updated_attribute_code
        && $previous_balance_attribute_code
    )
    || (
        $report_type eq 'submission'
        && !(
               $processing_fee
            && $processing_fee_type
            && $processing_fee_description
            && $minimum_balance
        )
    )
  )
{
    print $usage;
    exit;
}

my $ymd = DateTime->now( time_zone => C4::Context->tz() )->ymd();

my $csv = Text::CSV->new( { sep_char => $separator } )
  or die "Cannot use CSV: " . Text::CSV->error_diag();
$csv->eol("\r\n");

my $fh;
$directory ||= File::Spec->tmpdir();
my $name = "$report_type-$ymd.csv";
my $file = File::Spec->catfile( $directory, $name );
say "Opening CSV file $file for writing..." if $verbose;
open $fh, ">:encoding(utf8)", $file or die "$file: $!";

my $dbh = C4::Context->dbh();

my @parameters;
my $insert_attribute_sql = q{
    INSERT INTO borrower_attributes ( borrowernumber, code, attribute ) VALUES ( ?, ?, ? )
};
my $delete_attribute_sql = q{
    DELETE FROM borrower_attributes WHERE borrowernumber = ? AND code = ?
};
my $sql = q{
    SELECT 
        borrowers.*,
        guarantor.firstname AS guarantor_firstname,
        guarantor.surname AS guarantor_surname,
        DATE(account_debits.created_on) AS most_recent_unpaid_fine_date,
        SUM(account_debits.amount_outstanding) AS computed_account_balance,
        COALESCE( ba_c.attribute, 1 ) AS can_collect,
        COALESCE( ba_i.attribute, 0 ) AS in_collections,
        COALESCE( ba_l.attribute, 0 ) AS last_updated,
        COALESCE( ba_p.attribute, 0 ) AS previous_balance
    FROM borrowers 
        LEFT JOIN account_debits USING ( borrowernumber )
        LEFT JOIN borrower_attributes ba_c ON borrowers.borrowernumber = ba_c.borrowernumber AND ( ba_c.code = ? OR ba_c.code IS NULL )
        LEFT JOIN borrower_attributes ba_i ON borrowers.borrowernumber = ba_i.borrowernumber AND ( ba_i.code = ? OR ba_i.code IS NULL )
        LEFT JOIN borrower_attributes ba_l ON borrowers.borrowernumber = ba_l.borrowernumber AND ( ba_l.code = ? OR ba_l.code IS NULL )
        LEFT JOIN borrower_attributes ba_p ON borrowers.borrowernumber = ba_p.borrowernumber AND ( ba_p.code = ? OR ba_p.code IS NULL )
        LEFT JOIN borrowers guarantor ON ( borrowers.guarantorid = guarantor.borrowernumber )
    WHERE 
        COALESCE( ba_c.attribute, 1 ) != '0'
};

push( @parameters, $can_collect_attribute_code );
push( @parameters, $in_collections_attribute_code );
push( @parameters, $last_updated_attribute_code );
push( @parameters, $previous_balance_attribute_code );

$sql .= 'AND ' . join( ' AND ', @where ) if @where;

if ( $report_type eq 'submission' )
{ # Don't select patrons who have already been sent to collections for submissions report
    $sql .= q{ AND COALESCE( ba_i.attribute, 0 ) != '1' };
}
elsif ( $report_type eq 'update' )
{ # Select only patrons who have already been sent to collections and have had a change in balance for update report
    $sql .= q{ AND COALESCE( ba_i.attribute, 0 ) = '1' };
}
elsif ( $report_type eq 'sync' )
{ # Select only patrons who have already been sent to collections and have owe a balance for sync report
    $sql .= q{ AND ba_i.attribute = '1' };
}

if (@exclude_patron_types) {
    $sql .= ' AND borrowers.categorycode NOT IN ( '
      . join( ',', ('?') x @exclude_patron_types ) . ' ) ';

    push( @parameters, @exclude_patron_types );
}

if (@branchcodes) {
    $sql .= ' AND borrowers.branchcode IN ( '
      . join( ',', ('?') x @branchcodes ) . ' ) ';

    push( @parameters, @branchcodes );
}

if (@exclude_fee_types) {
    $sql .= ' AND account_debits.type NOT IN ( '
      . join( ',', ('?') x @exclude_fee_types ) . ' ) ';

    push( @parameters, @exclude_fee_types );
}

if ($begin_date) {
    $sql .= ' AND DATE(account_debits.created_on) >= DATE(?) ';
    push( @parameters, $begin_date );
}

if ($end_date) {
    $sql .= ' AND DATE(account_debits.created_on) <= DATE(?) ';
    push( @parameters, $end_date );
}

$sql .= q{ GROUP BY borrowernumber };

if ( $report_type eq 'submission' )
{ # Don't select patrons who have already been sent to collections for submissions report
    $sql .= ' HAVING SUM(account_debits.amount_outstanding) >= ? ';
    push( @parameters, $minimum_balance );
}
elsif ( $report_type eq 'sync' )
{ # Select only patrons who have already been sent to collections and have owe a balance for sync report
    $sql .= q{ HAVING SUM(account_debits.amount_outstanding) > 0 };
}
elsif ( $report_type eq 'update' ) {
    $sql .=
      q{ HAVING computed_account_balance != previous_balance };
}

$sql .= q{ ORDER BY account_debits.created_on DESC };

my $sth = $dbh->prepare($sql);
$sth->execute(@parameters);

$csv->print(
    $fh,
    [
        'firstname',                    'surname',
        'address1',                     'address2',
        'city',                         'state',
        'zipcode',                      'phone',
        'borrowernumber',               'cardnumber',
        'date_of_birth',                'category',
        'account_balance',              'library',
        'most_recent_unpaid_fine_date', 'guarantor_firstname',
        'guarantor_surname',
    ]
);

while ( my $r = $sth->fetchrow_hashref() ) {

    $csv->print(
        $fh,
        [
            $r->{firstname},                    $r->{surname},
            $r->{address1},                     $r->{address2},
            $r->{city},                         $r->{state},
            $r->{zipcode},                      $r->{phone},
            $r->{borrowernumber},               $r->{cardnumber},
            $r->{dateofbirth},                  $r->{categorycode},
            $r->{computed_account_balance},      $r->{branchcode},
            $r->{most_recent_unpaid_fine_date}, $r->{guarantor_firstname},
            $r->{guarantor_surname},
        ]
    );

    if ( $report_type eq 'submission' ) {

        # Set patron as being in collections
        $dbh->do( $delete_attribute_sql, undef,
            ( $r->{borrowernumber}, $in_collections_attribute_code ) );
        $dbh->do( $insert_attribute_sql, undef,
            ( $r->{borrowernumber}, $in_collections_attribute_code, '1' ) );

        if ($processing_fee) {
            AddDebit(
                {
                    borrower =>
                      Koha::Database->new()->schema->resultset('Borrower')
                      ->find( $r->{borrowernumber} ),
                    amount      => $processing_fee,
                    type        => $processing_fee_type,
                    description => $processing_fee_description,
                }
            );
        }

    }

    if ( $report_type eq 'submission' || $report_type eq 'update' ) {

        # Store patron's current account balance
        $dbh->do( $delete_attribute_sql, undef,
            ( $r->{borrowernumber}, $previous_balance_attribute_code ) );
        $dbh->do(
            $insert_attribute_sql,
            undef,
            (
                $r->{borrowernumber}, $previous_balance_attribute_code,
                $r->{computed_account_balance}
            )
        );

        # Store today's date as the date last updated for collections
        $dbh->do( $delete_attribute_sql, undef,
            ( $r->{borrowernumber}, $last_updated_attribute_code ) );
        $dbh->do( $insert_attribute_sql, undef,
            ( $r->{borrowernumber}, $last_updated_attribute_code, $ymd ) );
    }

    if ( $report_type eq 'update' && $r->{computed_account_balance} ) {
        # If the patron is in collections, but now has a 0 balance
        # set the patron to no longer being in collections

        $dbh->do( $delete_attribute_sql, undef,
            ( $r->{borrowernumber}, $in_collections_attribute_code ) );
    }
}

close $fh or die "$file: $!";
