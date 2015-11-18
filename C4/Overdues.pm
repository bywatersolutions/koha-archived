package C4::Overdues;


# Copyright 2000-2002 Katipo Communications
# copyright 2010 BibLibre
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

use strict;
#use warnings; FIXME - Bug 2505
use Date::Calc qw/Today Date_to_Days/;
use Date::Manip qw/UnixDate/;
use List::MoreUtils qw( uniq );

use C4::Circulation;
use C4::Context;
use C4::Log; # logaction
use C4::Debug;
use Koha::Database;
use Koha::DateUtils;
use Koha::Accounts;
use Koha::Accounts::OffsetTypes;
use Koha::Accounts::DebitTypes;

use vars qw($VERSION @ISA @EXPORT);

BEGIN {
	# set the version for version checking
    $VERSION = 3.07.00.049;
	require Exporter;
	@ISA    = qw(Exporter);
	# subs to rename (and maybe merge some...)
	push @EXPORT, qw(
        &CalcFine
        &Getoverdues
        &checkoverdues
        &UpdateFine
        &GetFine
        &get_chargeable_units
        &CheckItemNotify
        &GetOverduesForBranch
        &RemoveNotifyLine
        &AddNotifyLine
        &GetOverdueMessageTransportTypes
	);
	# subs to remove
	push @EXPORT, qw(
        &BorType
	);

	# check that an equivalent don't exist already before moving

	# subs to move to Circulation.pm
	push @EXPORT, qw(
        &GetIssuesIteminfo
	);

     # &GetIssuingRules - delete.
   # use C4::Circulation::GetIssuingRule instead.

	# subs to move to Biblio.pm
	push @EXPORT, qw(
        &GetItems
	);
}

=head1 NAME

C4::Circulation::Fines - Koha module dealing with fines

=head1 SYNOPSIS

  use C4::Overdues;

=head1 DESCRIPTION

This module contains several functions for dealing with fines for
overdue items. It is primarily used by the 'misc/fines2.pl' script.

=head1 FUNCTIONS

=head2 Getoverdues

  $overdues = Getoverdues( { minimumdays => 1, maximumdays => 30 } );

Returns the list of all overdue books, with their itemtype.

C<$overdues> is a reference-to-array. Each element is a
reference-to-hash whose keys are the fields of the issues table in the
Koha database.

=cut

#'
sub Getoverdues {
    my $params = shift;
    my $dbh = C4::Context->dbh;
    my $statement;
    if ( C4::Context->preference('item-level_itypes') ) {
        $statement = "
   SELECT issues.*, items.itype as itemtype, items.homebranch, items.barcode, items.itemlost
     FROM issues 
LEFT JOIN items       USING (itemnumber)
    WHERE date_due < NOW()
";
    } else {
        $statement = "
   SELECT issues.*, biblioitems.itemtype, items.itype, items.homebranch, items.barcode, items.itemlost
     FROM issues 
LEFT JOIN items       USING (itemnumber)
LEFT JOIN biblioitems USING (biblioitemnumber)
    WHERE date_due < NOW()
";
    }

    my @bind_parameters;
    if ( exists $params->{'minimumdays'} and exists $params->{'maximumdays'} ) {
        $statement .= ' AND TO_DAYS( NOW() )-TO_DAYS( date_due ) BETWEEN ? and ? ';
        push @bind_parameters, $params->{'minimumdays'}, $params->{'maximumdays'};
    } elsif ( exists $params->{'minimumdays'} ) {
        $statement .= ' AND ( TO_DAYS( NOW() )-TO_DAYS( date_due ) ) > ? ';
        push @bind_parameters, $params->{'minimumdays'};
    } elsif ( exists $params->{'maximumdays'} ) {
        $statement .= ' AND ( TO_DAYS( NOW() )-TO_DAYS( date_due ) ) < ? ';
        push @bind_parameters, $params->{'maximumdays'};
    }
    $statement .= 'ORDER BY borrowernumber';
    my $sth = $dbh->prepare( $statement );
    $sth->execute( @bind_parameters );
    return $sth->fetchall_arrayref({});
}


=head2 checkoverdues

    ($count, $overdueitems) = checkoverdues($borrowernumber);

Returns a count and a list of overdueitems for a given borrowernumber

=cut

sub checkoverdues {
    my $borrowernumber = shift or return;
    # don't select biblioitems.marc or biblioitems.marcxml... too slow on large systems
    my $sth = C4::Context->dbh->prepare(
        "SELECT biblio.*, items.*, issues.*,
                biblioitems.volume,
                biblioitems.number,
                biblioitems.itemtype,
                biblioitems.isbn,
                biblioitems.issn,
                biblioitems.publicationyear,
                biblioitems.publishercode,
                biblioitems.volumedate,
                biblioitems.volumedesc,
                biblioitems.collectiontitle,
                biblioitems.collectionissn,
                biblioitems.collectionvolume,
                biblioitems.editionstatement,
                biblioitems.editionresponsibility,
                biblioitems.illus,
                biblioitems.pages,
                biblioitems.notes,
                biblioitems.size,
                biblioitems.place,
                biblioitems.lccn,
                biblioitems.url,
                biblioitems.cn_source,
                biblioitems.cn_class,
                biblioitems.cn_item,
                biblioitems.cn_suffix,
                biblioitems.cn_sort,
                biblioitems.totalissues
         FROM issues
         LEFT JOIN items       ON issues.itemnumber      = items.itemnumber
         LEFT JOIN biblio      ON items.biblionumber     = biblio.biblionumber
         LEFT JOIN biblioitems ON items.biblioitemnumber = biblioitems.biblioitemnumber
            WHERE issues.borrowernumber  = ?
            AND   issues.date_due < NOW()"
    );
    # FIXME: SELECT * across 4 tables?  do we really need the marc AND marcxml blobs??
    $sth->execute($borrowernumber);
    my $results = $sth->fetchall_arrayref({});
    return ( scalar(@$results), $results);  # returning the count and the results is silly
}

=head2 CalcFine

    ($amount, $chargename,  $daycounttotal) = &CalcFine($item,
                                  $categorycode, $branch,
                                  $start_dt, $end_dt );

Calculates the fine for a book.

The issuingrules table in the Koha database is a fine matrix, listing
the penalties for each type of patron for each type of item and each branch (e.g., the
standard fine for books might be $0.50, but $1.50 for DVDs, or staff
members might get a longer grace period between the first and second
reminders that a book is overdue).


C<$item> is an item object (hashref).

C<$categorycode> is the category code (string) of the patron who currently has
the book.

C<$branchcode> is the library (string) whose issuingrules govern this transaction.

C<$start_date> & C<$end_date> are DateTime objects
defining the date range over which to determine the fine.

Fines scripts should just supply the date range over which to calculate the fine.

C<&CalcFine> returns four values:

C<$amount> is the fine owed by the patron (see above).

C<$chargename> is the chargename field from the applicable record in
the categoryitem table, whatever that is.

C<$unitcount> is the number of chargeable units (days between start and end dates, Calendar adjusted where needed,
minus any applicable grace period, or hours)

FIXME - What is chargename supposed to be ?

FIXME: previously attempted to return C<$message> as a text message, either "First Notice", "Second Notice",
or "Final Notice".  But CalcFine never defined any value.

=cut

sub CalcFine {
    my ( $item, $bortype, $branchcode, $due_dt, $end_date  ) = @_;
    my $start_date = $due_dt->clone();
    # get issuingrules (fines part will be used)
    my $itemtype = $item->{itemtype} || $item->{itype};
    my $data = C4::Circulation::GetIssuingRule($bortype, $itemtype, $branchcode);
    my $fine_unit = $data->{lengthunit};
    $fine_unit ||= 'days';

    my $chargeable_units = get_chargeable_units($fine_unit, $start_date, $end_date, $branchcode);
    my $units_minus_grace = $chargeable_units - $data->{firstremind};
    my $amount = 0;
    if ($data->{'chargeperiod'}  && ($units_minus_grace > 0)  ) {
        if ( C4::Context->preference('FinesIncludeGracePeriod') ) {
            $amount = int($chargeable_units / $data->{'chargeperiod'}) * $data->{'fine'};# TODO fine calc should be in cents
        } else {
            $amount = int($units_minus_grace / $data->{'chargeperiod'}) * $data->{'fine'};
        }
    } else {
        # a zero (or null) chargeperiod or negative units_minus_grace value means no charge.
    }
    $amount = $data->{overduefinescap} if $data->{overduefinescap} && $amount > $data->{overduefinescap};
    $debug and warn sprintf("CalcFine returning (%s, %s, %s, %s)", $amount, $data->{'chargename'}, $units_minus_grace, $chargeable_units);
    return ($amount, $data->{'chargename'}, $units_minus_grace, $chargeable_units);
    # FIXME: chargename is NEVER populated anywhere.
}


=head2 get_chargeable_units

    get_chargeable_units($unit, $start_date_ $end_date, $branchcode);

return integer value of units between C<$start_date> and C<$end_date>, factoring in holidays for C<$branchcode>.

C<$unit> is 'days' or 'hours' (default is 'days').

C<$start_date> and C<$end_date> are the two DateTimes to get the number of units between.

C<$branchcode> is the branch whose calendar to use for finding holidays.

=cut

sub get_chargeable_units {
    my ($unit, $date_due, $date_returned, $branchcode) = @_;

    # If the due date is later than the return date
    return 0 unless ( $date_returned > $date_due );

    my $charge_units = 0;
    my $charge_duration;
    if ($unit eq 'hours') {
        if(C4::Context->preference('finesCalendar') eq 'noFinesWhenClosed') {
            my $calendar = Koha::Calendar->new( branchcode => $branchcode );
            $charge_duration = $calendar->hours_between( $date_due, $date_returned );
        } else {
            $charge_duration = $date_returned->delta_ms( $date_due );
        }
        if($charge_duration->in_units('hours') == 0 && $charge_duration->in_units('seconds') > 0){
            return 1;
        }
        return $charge_duration->in_units('hours');
    }
    else { # days
        if(C4::Context->preference('finesCalendar') eq 'noFinesWhenClosed') {
            my $calendar = Koha::Calendar->new( branchcode => $branchcode );
            $charge_duration = $calendar->days_between( $date_due, $date_returned );
        } else {
            $charge_duration = $date_returned->delta_days( $date_due );
        }
        return $charge_duration->in_units('days');
    }
}


=head2 GetSpecialHolidays

    &GetSpecialHolidays($date_dues,$itemnumber);

return number of special days  between date of the day and date due

C<$date_dues> is the envisaged date of book return.

C<$itemnumber> is the book's item number.

=cut

sub GetSpecialHolidays {
    my ( $date_dues, $itemnumber ) = @_;

    # calcul the today date
    my $today = join "-", &Today();

    # return the holdingbranch
    my $iteminfo = GetIssuesIteminfo($itemnumber);

    # use sql request to find all date between date_due and today
    my $dbh = C4::Context->dbh;
    my $query =
      qq|SELECT DATE_FORMAT(concat(year,'-',month,'-',day),'%Y-%m-%d') as date
FROM `special_holidays`
WHERE DATE_FORMAT(concat(year,'-',month,'-',day),'%Y-%m-%d') >= ?
AND   DATE_FORMAT(concat(year,'-',month,'-',day),'%Y-%m-%d') <= ?
AND branchcode=?
|;
    my @result = GetWdayFromItemnumber($itemnumber);
    my @result_date;
    my $wday;
    my $dateinsec;
    my $sth = $dbh->prepare($query);
    $sth->execute( $date_dues, $today, $iteminfo->{'branchcode'} )
      ;    # FIXME: just use NOW() in SQL instead of passing in $today

    while ( my $special_date = $sth->fetchrow_hashref ) {
        push( @result_date, $special_date );
    }

    my $specialdaycount = scalar(@result_date);

    for ( my $i = 0 ; $i < scalar(@result_date) ; $i++ ) {
        $dateinsec = UnixDate( $result_date[$i]->{'date'}, "%o" );
        ( undef, undef, undef, undef, undef, undef, $wday, undef, undef ) =
          localtime($dateinsec);
        for ( my $j = 0 ; $j < scalar(@result) ; $j++ ) {
            if ( $wday == ( $result[$j]->{'weekday'} ) ) {
                $specialdaycount--;
            }
        }
    }

    return $specialdaycount;
}

=head2 GetRepeatableHolidays

    &GetRepeatableHolidays($date_dues, $itemnumber, $difference,);

return number of day closed between date of the day and date due

C<$date_dues> is the envisaged date of book return.

C<$itemnumber> is item number.

C<$difference> numbers of between day date of the day and date due

=cut

sub GetRepeatableHolidays {
    my ( $date_dues, $itemnumber, $difference ) = @_;
    my $dateinsec = UnixDate( $date_dues, "%o" );
    my ( $sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst ) =
      localtime($dateinsec);
    my @result = GetWdayFromItemnumber($itemnumber);
    my @dayclosedcount;
    my $j;

    for ( my $i = 0 ; $i < scalar(@result) ; $i++ ) {
        my $k = $wday;

        for ( $j = 0 ; $j < $difference ; $j++ ) {
            if ( $result[$i]->{'weekday'} == $k ) {
                push( @dayclosedcount, $k );
            }
            $k++;
            ( $k = 0 ) if ( $k eq 7 );
        }
    }
    return scalar(@dayclosedcount);
}


=head2 GetWayFromItemnumber

    &Getwdayfromitemnumber($itemnumber);

return the different week day from repeatable_holidays table

C<$itemnumber> is  item number.

=cut

sub GetWdayFromItemnumber {
    my ($itemnumber) = @_;
    my $iteminfo = GetIssuesIteminfo($itemnumber);
    my @result;
    my $query = qq|SELECT weekday
    FROM repeatable_holidays
    WHERE branchcode=?
|;
    my $sth = C4::Context->dbh->prepare($query);

    $sth->execute( $iteminfo->{'branchcode'} );
    while ( my $weekday = $sth->fetchrow_hashref ) {
        push( @result, $weekday );
    }
    return @result;
}


=head2 GetIssuesIteminfo

    &GetIssuesIteminfo($itemnumber);

return all data from issues about item

C<$itemnumber> is  item number.

=cut

sub GetIssuesIteminfo {
    my ($itemnumber) = @_;
    my $dbh          = C4::Context->dbh;
    my $query        = qq|SELECT *
    FROM issues
    WHERE itemnumber=?
    |;
    my $sth = $dbh->prepare($query);
    $sth->execute($itemnumber);
    my ($issuesinfo) = $sth->fetchrow_hashref;
    return $issuesinfo;
}


=head2 UpdateFine

    UpdateFine(
        {
            itemnumber     => $itemnumber,
            borrowernumber => $borrowernumber,
            amount         => $amount,
            due            => $due,
            issue_id       => $issue_id
        }
    );

Updates the fine owed on an overdue item.

C<$itemnumber> is the items's id.

C<$borrowernumber> is the id of the patron who currently
has the item on loan.

C<$amount> is the total amount of the fine owed by the patron.

C<&UpdateFine> updates the amount owed for a given fine if an issue_id
is passed to it. Otherwise, a new fine will be created.

=cut

sub UpdateFine {
    my ($params) = @_;

    my $itemnumber     = $params->{itemnumber};
    my $borrowernumber = $params->{borrowernumber};
    my $amount         = $params->{amount};
    my $due            = $params->{due};
    my $issue_id       = $params->{issue_id};

warn "UpdateFine";
warn "ITEMNUMBER: $itemnumber";
warn "BORROWERNUMBER: $borrowernumber";
warn "AMOUNT: $amount";
warn "DUE: $due";
warn "ISSUE ID: $issue_id";

    my $schema = Koha::Database->new()->schema;

    my $borrower = $schema->resultset('Borrower')->find($borrowernumber);

    if ( my $maxfine = C4::Context->preference('MaxFine') ) {
        if ( $borrower->account_balance() + $amount > $maxfine ) {
            my $new_amount = $maxfine - $borrower->account_balance();
            warn "Reducing fine for item $itemnumber borrower $borrowernumber from $amount to $new_amount - MaxFine reached";
            if ( $new_amount <= 0 ) {
                warn "Fine reduced to a non-positive ammount. Fine not created.";
                return;
            }
            $amount = $new_amount;
        }
    }

    my $timestamp = get_timestamp();

    my $fine = $schema->resultset('AccountDebit')->single(
        {
            issue_id => $issue_id,
            type     => Koha::Accounts::DebitTypes::Fine,
            accruing => 1,
        }
    );

    my $offset = 0;
    my $credit;
    if ($fine) {
        if ( $fine->accruing() ) { # Don't update or recreate fines no longer accruing
            if (
                sprintf( "%.6f", $fine->amount_original() )
                ne
                sprintf( "%.6f", $amount ) )
            {
                my $difference = $amount - $fine->amount_original();

                # Fine was reduced by a change in circulation rules or another reason
                # we need to credit the account the difference and zero out the amount outstanding
                if ( $difference < 0 ) {
                    $fine->amount_outstanding( $fine->amount_outstanding() + $difference );

                    $credit =
                      Koha::Database->new()->schema->resultset('AccountCredit')
                      ->create(
                        {
                            borrowernumber => $borrowernumber,
                            type => Koha::Accounts::CreditTypes::FineReduction(),
                            amount_remaining => abs($difference),
                            created_on       => $timestamp,
                        }
                      );

                } else {
                    $fine->amount_outstanding( $amount );
                }

                $fine->amount_last_increment($difference);
                $fine->amount_original( $fine->amount_original() + $difference );
                $fine->updated_on($timestamp);
                $fine->update();

                $offset = 1;
            }
        }
    }
    elsif ( $amount ) { # No fine to update, don't insert fines of $0.00
        my $item = $schema->resultset('Item')->find($itemnumber);

        $fine = $schema->resultset('AccountDebit')->create(
            {
                borrowernumber        => $borrowernumber,
                itemnumber            => $itemnumber,
                issue_id              => $issue_id,
                type                  => Koha::Accounts::DebitTypes::Fine(),
                accruing              => 1,
                amount_original       => $amount,
                amount_outstanding    => $amount,
                amount_last_increment => $amount,
                description           => $item->biblio()->title() . " / Due:$due",
                created_on            => $timestamp,
            }
        );

        $offset = 1;
    } else { # No fine to update, amount is 0, just return
        return;
    }

    $schema->resultset('AccountOffset')->create(
        {
            debit_id   => $fine->debit_id(),
            credit_id  => $credit ? $credit->credit_id() : undef,
            amount     => $fine->amount_last_increment(),
            created_on => $timestamp,
            type       => Koha::Accounts::OffsetTypes::Fine(),
        }
    ) if $offset;

    RecalculateAccountBalance( { borrower => $borrower } );

    logaction( "FINES", Koha::Accounts::DebitTypes::Fine(),
        $borrowernumber,
        "due=" . $due . "  amount=" . $amount . " itemnumber=" . $itemnumber )
      if C4::Context->preference("FinesLog");
}

=head2 BorType

    $borrower = &BorType($borrowernumber);

Looks up a patron by borrower number.

C<$borrower> is a reference-to-hash whose keys are all of the fields
from the borrowers and categories tables of the Koha database. Thus,
C<$borrower> contains all information about both the borrower and
category he or she belongs to.

=cut

sub BorType {
    my ($borrowernumber) = @_;
    my $dbh              = C4::Context->dbh;
    my $sth              = $dbh->prepare(
        "SELECT * from borrowers
      LEFT JOIN categories ON borrowers.categorycode=categories.categorycode 
      WHERE borrowernumber=?"
    );
    $sth->execute($borrowernumber);
    return $sth->fetchrow_hashref;
}

=head2 GetFine

    $data->{'sum(amountoutstanding)'} = &GetFine($itemnum,$borrowernumber);

return the total of fine

C<$itemnum> is item number

C<$borrowernumber> is the borrowernumber

=cut 

sub GetFine {
    my ( $itemnum, $borrowernumber ) = @_;
    my $dbh   = C4::Context->dbh();
    my $query = q|SELECT sum(amountoutstanding) as fineamount FROM accountlines
    where accounttype like 'F%'
  AND amountoutstanding > 0 AND borrowernumber=?|;
    my @query_param;
    push @query_param, $borrowernumber;
    if (defined $itemnum )
    {
        $query .= " AND itemnumber=?";
        push @query_param, $itemnum;
    }
    my $sth = $dbh->prepare($query);
    $sth->execute( @query_param );
    my $fine = $sth->fetchrow_hashref();
    if ($fine->{fineamount}) {
        return $fine->{fineamount};
    }
    return 0;
}


=head2 NumberNotifyId

    my $schema = Koha::Database->new()->schema;

    my $amount_outstanding = $schema->resultset('AccountDebit')->search(
        {
            itemnumber     => $itemnumber,
            borrowernumber => $borrowernumber,
            type           => Koha::Accounts::DebitTypes::Fine(),
        },
    )->get_column('amount_outstanding')->sum();

    return $amount_outstanding;
}

=head2 GetItems

    ($items) = &GetItems($itemnumber);

Returns the list of all delays from overduerules.

C<$items> is a reference-to-hash whose keys are all of the fields
from the items tables of the Koha database. Thus,

C<$itemnumber> contains the borrower categorycode

=cut

# FIXME: This is a bad function to have here.
# Shouldn't it be in C4::Items?
# Shouldn't it be called GetItem since you only get 1 row?
# Shouldn't it be called GetItem since you give it only 1 itemnumber?

sub GetItems {
    my $itemnumber = shift or return;
    my $query = qq|SELECT *
             FROM items
              WHERE itemnumber=?|;
    my $sth = C4::Context->dbh->prepare($query);
    $sth->execute($itemnumber);
    my ($items) = $sth->fetchrow_hashref;
    return ($items);
}

=head2 GetBranchcodesWithOverdueRules

    my @branchcodes = C4::Overdues::GetBranchcodesWithOverdueRules()

returns a list of branch codes for branches with overdue rules defined.

=cut

sub GetBranchcodesWithOverdueRules {
    my $dbh               = C4::Context->dbh;
    my $branchcodes = $dbh->selectcol_arrayref(q|
        SELECT DISTINCT(branchcode)
        FROM overduerules
        WHERE delay1 IS NOT NULL
        ORDER BY branchcode
    |);
    if ( $branchcodes->[0] eq '' ) {
        # If a default rule exists, all branches should be returned
        my $availbranches = C4::Branch::GetBranches();
        return keys %$availbranches;
    }
    return @$branchcodes;
}

=head2 GetOverduesForBranch

Sql request for display all information for branchoverdues.pl
2 possibilities : with or without location .
display is filtered by branch

FIXME: This function should be renamed.

=cut

sub GetOverduesForBranch {
    my ( $branch, $location) = @_;
	my $itype_link =  (C4::Context->preference('item-level_itypes')) ?  " items.itype " :  " biblioitems.itemtype ";
    my $dbh = C4::Context->dbh;
    my $select = "
    SELECT
            borrowers.cardnumber,
            borrowers.borrowernumber,
            borrowers.surname,
            borrowers.firstname,
            borrowers.phone,
            borrowers.email,
               biblio.title,
               biblio.author,
               biblio.biblionumber,
               issues.issue_id,
               issues.date_due,
               issues.returndate,
               issues.branchcode,
             branches.branchname,
                items.barcode,
                items.homebranch,
                items.itemcallnumber,
                items.location,
                items.itemnumber,
            itemtypes.description,
            account_debits.amount_outstanding
    FROM  account_debits
    LEFT JOIN issues      ON    issues.itemnumber     = account_debits.itemnumber
                          AND   issues.borrowernumber = account_debits.borrowernumber
    LEFT JOIN borrowers   ON borrowers.borrowernumber = account_debits.borrowernumber
    LEFT JOIN items       ON     items.itemnumber     = issues.itemnumber
    LEFT JOIN biblio      ON      biblio.biblionumber =  items.biblionumber
    LEFT JOIN biblioitems ON biblioitems.biblioitemnumber = items.biblioitemnumber
    LEFT JOIN itemtypes   ON itemtypes.itemtype       = $itype_link
    LEFT JOIN branches    ON  branches.branchcode     = issues.branchcode
    WHERE (account_debits.amount_outstanding  != '0.000000')
      AND (account_debits.type = 'FINE')
      AND (account_debits.accruing = 1 )
      AND (issues.branchcode =  ?   )
      AND (issues.date_due  < NOW())
    ";
    my @getoverdues;
    my $sth;
    if ($location) {
        $sth = $dbh->prepare("$select AND items.location = ? ORDER BY borrowers.surname, borrowers.firstname");
        $sth->execute($branch, $location);
    } else {
        $sth = $dbh->prepare("$select ORDER BY borrowers.surname, borrowers.firstname");
        $sth->execute($branch);
    }
    while ( my $data = $sth->fetchrow_hashref ) {
        push( @getoverdues, $data );
    }
    return (@getoverdues);
}


=head2 AddNotifyLine

    &AddNotifyLine($borrowernumber, $itemnumber, $overduelevel, $method, $notifyId)

Create a line into notify, if the method is phone, the notification_send_date is implemented to

=cut

sub AddNotifyLine {
    my ( $borrowernumber, $itemnumber, $overduelevel, $method, $notifyId ) = @_;
    my $dbh = C4::Context->dbh;
    if ( $method eq "phone" ) {
        my $sth = $dbh->prepare(
            "INSERT INTO notifys (borrowernumber,itemnumber,notify_date,notify_send_date,notify_level,method,notify_id)
        VALUES (?,?,now(),now(),?,?,?)"
        );
        $sth->execute( $borrowernumber, $itemnumber, $overduelevel, $method,
            $notifyId );
    }
    else {
        my $sth = $dbh->prepare(
            "INSERT INTO notifys (borrowernumber,itemnumber,notify_date,notify_level,method,notify_id)
        VALUES (?,?,now(),?,?,?)"
        );
        $sth->execute( $borrowernumber, $itemnumber, $overduelevel, $method,
            $notifyId );
    }
    return 1;
}

=head2 RemoveNotifyLine

    &RemoveNotifyLine( $borrowernumber, $itemnumber, $notify_date );

Cancel a notification

=cut

sub RemoveNotifyLine {
    my ( $borrowernumber, $itemnumber, $notify_date ) = @_;
    my $dbh = C4::Context->dbh;
    my $sth = $dbh->prepare(
        "DELETE FROM notifys 
            WHERE
            borrowernumber=?
            AND itemnumber=?
            AND notify_date=?"
    );
    $sth->execute( $borrowernumber, $itemnumber, $notify_date );
    return 1;
}

=head2 GetOverdueMessageTransportTypes

    my $message_transport_types = GetOverdueMessageTransportTypes( $branchcode, $categorycode, $letternumber);

    return a arrayref with all message_transport_type for given branchcode, categorycode and letternumber(1,2 or 3)

=cut

sub GetOverdueMessageTransportTypes {
    my ( $branchcode, $categorycode, $letternumber ) = @_;
    return unless $categorycode and $letternumber;
    my $dbh = C4::Context->dbh;
    my $sth = $dbh->prepare("
        SELECT message_transport_type FROM overduerules_transport_types
        WHERE branchcode = ? AND categorycode = ? AND letternumber = ?
    ");
    $sth->execute( $branchcode, $categorycode, $letternumber );
    my @mtts;
    while ( my $mtt = $sth->fetchrow ) {
        push @mtts, $mtt;
    }

    # Put 'print' in first if exists
    # It avoid to sent a print notice with an email or sms template is no email or sms is defined
    @mtts = uniq( 'print', @mtts )
        if grep {/^print$/} @mtts;

    return \@mtts;
}

1;
__END__

=head1 AUTHOR

Koha Development Team <http://koha-community.org/>

=cut
