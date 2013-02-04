#!/usr/bin/perl
use strict;
use warnings;
use Getopt::Long;
use Data::Dumper;
use C4::Auth;
use C4::Output;
use C4::Dates qw(format_date_in_iso);
use C4::Context;
use C4::Branch qw(GetBranchName);
use C4::Members;
use C4::Members::Attributes qw(:all);
use C4::Members::AttributeTypes;
use C4::Members::Messaging;

use Text::CSV;

my @errors;
my $extended = C4::Context->preference('ExtendedPatronAttributes');
my $set_messaging_prefs = C4::Context->preference('EnhancedMessagingPreferences');
my @columnkeys = C4::Members->columns;
if ($extended) {
    push @columnkeys, 'patron_attributes';
}
my $columnkeystpl = [ map { {'key' => $_} }  grep {$_ ne 'borrowernumber' && $_ ne 'cardnumber'} @columnkeys ];  # ref. to array of hashrefs.

my $uploadborrowers="";
my $matchpoint="cardnumber";
my $overwrite_cardnumber=0;
my $ext_preserve=0;
my $debug=0;
my $verbose=0;

my $result = GetOptions(
   'file=s' => \$uploadborrowers,
   'match=s' => \$matchpoint,
   'overwrite' => \$overwrite_cardnumber,
   'preserve'  => \$ext_preserve,
   'v' => \$verbose,
   'd' => \$debug,
);

our $csv  = Text::CSV->new({binary => 1});  # binary needed for non-ASCII Unicode

if ($matchpoint) {
    $matchpoint =~ s/^patron_attribute_//;
}

if ( $uploadborrowers && length($uploadborrowers) > 0 ) {
    open my $handle, "<$uploadborrowers";
    my $read =0;
    my $imported    = 0;
    my $alreadyindb = 0;
    my $overwritten = 0;
    my $invalid     = 0;
    my $matchpoint_attr_type;

    # use header line to construct key to column map
    my $borrowerline = <$handle>;
    my $status = $csv->parse($borrowerline);
    ($status) or push @errors, {badheader=>1,line=>$., lineraw=>$borrowerline};
    my @csvcolumns = $csv->fields();
    my %csvkeycol;
    my $col = 0;
    foreach my $keycol (@csvcolumns) {
    # columnkeys don't contain whitespace, but some stupid tools add it
    $keycol =~ s/ +//g;
        $csvkeycol{$keycol} = $col++;
    }
    $debug and warn Dumper(@csvcolumns);
    $debug and warn Dumper(%csvkeycol);
    #$debug and warn($borrowerline);
    if ($extended) {
        $matchpoint_attr_type = C4::Members::AttributeTypes->fetch($matchpoint);
    }

    my $today_iso = C4::Dates->new()->output('iso');
    my @criticals = qw(surname branchcode categorycode);    # there probably should be others
    my @bad_dates;  # I've had a few.
    my $date_re = C4::Dates->new->regexp('syspref');
    my  $iso_re = C4::Dates->new->regexp('iso');
    LINE: while ( my $borrowerline = <$handle> ) {
        $read++;
        $verbose and print ".";
        $verbose and print " $read\n" unless ($read % 100);
        my %borrower;
        my @missing_criticals;
        my $patron_attributes;
        my $status  = $csv->parse($borrowerline);
        my @columns = $csv->fields();
        if (! $status) {
            push @missing_criticals, {badparse=>1, line=>$., lineraw=>$borrowerline};
        } elsif (@columns == @columnkeys) {
            @borrower{@columnkeys} = @columns;
        } else {
            foreach my $key (@columnkeys) {
$debug and warn $key;
             if (defined($csvkeycol{$key}) and defined $columns[$csvkeycol{$key}] ){
#d $columns[$csvkeycol{$key}] =~ /\S/) {
                   $borrower{$key} = $columns[$csvkeycol{$key}];
              } elsif ( scalar grep {$key eq $_} @criticals ) {
                  # a critical field is undefined
                push @missing_criticals, {key=>$key, line=>$., lineraw=>$borrowerline};
            } else {
                       $borrower{$key} = '';
          }
            }
        }
        $debug and warn join(':',%borrower);
        if ($borrower{categorycode}) {
            push @missing_criticals, {key=>'categorycode', line=>$. , lineraw=>$borrowerline, value=>$borrower{categorycode}, category_map=>1}
                unless GetBorrowercategory($borrower{categorycode});
        } else {
            push @missing_criticals, {key=>'categorycode', line=>$. , lineraw=>$borrowerline};
        }
        if ($borrower{branchcode}) {
            push @missing_criticals, {key=>'branchcode', line=>$. , lineraw=>$borrowerline, value=>$borrower{branchcode}, branch_map=>1}
                unless GetBranchName($borrower{branchcode});
        } else {
            push @missing_criticals, {key=>'branchcode', line=>$. , lineraw=>$borrowerline};
        }
        if (@missing_criticals) {
            foreach (@missing_criticals) {
                $_->{borrowernumber} = $borrower{borrowernumber} || 'UNDEF';
                $_->{surname}        = $borrower{surname} || 'UNDEF';
            }
            $invalid++;
            (25 > scalar @errors) and push @errors, {missing_criticals=>\@missing_criticals};
            # The first 25 errors are enough.  Keeping track of 30,000+ would destroy performance.
            next LINE;
        }
        if ($extended) {
            my $attr_str = $borrower{patron_attributes};
            delete $borrower{patron_attributes};    # not really a field in borrowers, so we don't want to pass it to ModMember.
            $patron_attributes = extended_attributes_code_value_arrayref($attr_str);
        }
     # Popular spreadsheet applications make it difficult to force date outputs to be zero-padded, but we require it.
        foreach (qw(dateofbirth dateenrolled dateexpiry)) {
            my $tempdate = $borrower{$_} or next;
            if ($tempdate =~ /$date_re/) {
                $borrower{$_} = format_date_in_iso($tempdate);
            } elsif ($tempdate =~ /$iso_re/) {
                $borrower{$_} = $tempdate;
            } else {
                $borrower{$_} = '';
                push @missing_criticals, {key=>$_, line=>$. , lineraw=>$borrowerline, bad_date=>1};
            }
        }
        $borrower{dateenrolled} = $today_iso unless $borrower{dateenrolled};
   $borrower{dateexpiry} = GetExpiryDate($borrower{categorycode},$borrower{dateenrolled}) unless $borrower{dateexpiry};
        my $borrowernumber;
        my $member;
        if ( ($matchpoint eq 'cardnumber') && ($borrower{'cardnumber'}) ) {
            $member = GetMember( 'cardnumber' => $borrower{'cardnumber'} );
            if ($member) {
                $borrowernumber = $member->{'borrowernumber'};
            }
        } elsif ($extended) {
            if (defined($matchpoint_attr_type)) {
                foreach my $attr (@$patron_attributes) {
                    if ($attr->{code} eq $matchpoint and $attr->{value} ne '') {
                        my @borrowernumbers = $matchpoint_attr_type->get_patrons($attr->{value});
                        $borrowernumber = $borrowernumbers[0] if scalar(@borrowernumbers) == 1;
                        last;
                    }
                }
            }
        }

        if ($borrowernumber) {
            # borrower exists
            unless ($overwrite_cardnumber) {
                $alreadyindb++;
                next LINE;
            }
            $borrower{'borrowernumber'} = $borrowernumber;
            for my $col (keys %borrower) {
                # use values from extant patron unless our csv file includes this column or we provided a default.
                # FIXME : You cannot update a field with a  perl-evaluated false value using the defaults.
                unless(exists($csvkeycol{$col})) {
                    $borrower{$col} = $member->{$col} if($member->{$col}) ;
                }
            }
            unless (ModMember(%borrower)) {
                $invalid++;
                next LINE;
            }
            if ($extended) {
                if ($ext_preserve) {
                    my $old_attributes = GetBorrowerAttributes($borrowernumber);
                    $patron_attributes = extended_attributes_merge($old_attributes, $patron_attributes);  #TODO: expose repeatable options in template
                }
                SetBorrowerAttributes($borrower{'borrowernumber'}, $patron_attributes);
            }
            $overwritten++;
        } else {
            # FIXME: fixup_cardnumber says to lock table, but the web interface doesn't so this doesn't either.
            # At least this is closer to AddMember than in members/memberentry.pl
            if (!$borrower{'cardnumber'}) {
                $borrower{'cardnumber'} = fixup_cardnumber(undef);
            }
            if ($borrowernumber = AddMember(%borrower)) {
                if ($extended) {
                    SetBorrowerAttributes($borrowernumber, $patron_attributes);
                }
                if ($set_messaging_prefs) {
                    C4::Members::Messaging::SetMessagingPreferencesFromDefaults({ borrowernumber => $borrowernumber,
                                                                                  categorycode => $borrower{categorycode} });
                }
                $imported++;
            } else {
                $invalid++;
            }
        }
    }
    (@errors  ) and warn Dumper(@errors  );
    $verbose and print "Read: $read\nImported: $imported\nNot imported: $alreadyindb\nOverwritten: $overwritten\nInvalid: $invalid\n\n";
}
