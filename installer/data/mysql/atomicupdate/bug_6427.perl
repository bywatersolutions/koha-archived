my $dbh = C4::Context->dbh();

$dbh->do(q{
    UPDATE accountlines a LEFT JOIN issues i USING ( borrowernumber, itemnumber ) SET accounttype = 'F' WHERE i.issue_id IS NULL
});

$dbh->do("
    CREATE TABLE IF NOT EXISTS account_credits (
        credit_id int(11) NOT NULL AUTO_INCREMENT,
        borrowernumber int(11) NOT NULL,
        `type` varchar(255) NOT NULL,
        amount_received decimal(28,6) DEFAULT NULL,
        amount_paid decimal(28,6) NOT NULL,
        amount_remaining decimal(28,6) NOT NULL,
        amount_voided decimal(28,6) NULL DEFAULT NULL,
        notes text,
        branchcode VARCHAR( 10 ) NULL DEFAULT NULL,
        manager_id int(11) DEFAULT NULL,
        created_on timestamp NULL DEFAULT NULL,
        updated_on timestamp NULL DEFAULT NULL,
        PRIMARY KEY (credit_id),
        KEY borrowernumber (borrowernumber),
        KEY branchcode (branchcode)
    ) ENGINE=InnoDB  DEFAULT CHARSET=utf8;
");
$dbh->do("
    CREATE TABLE IF NOT EXISTS account_debits (
        debit_id int(11) NOT NULL AUTO_INCREMENT,
        borrowernumber int(11) NOT NULL DEFAULT '0',
        itemnumber int(11) DEFAULT NULL,
        issue_id int(11) DEFAULT NULL,
        `type` varchar(255) NOT NULL,
        accruing tinyint(1) NOT NULL DEFAULT '0',
        amount_original decimal(28,6) DEFAULT NULL,
        amount_outstanding decimal(28,6) DEFAULT NULL,
        amount_last_increment decimal(28,6) DEFAULT NULL,
        description mediumtext,
        notes text,
        branchcode VARCHAR( 10 ) NULL DEFAULT NULL,
        manager_id int(11) DEFAULT NULL,
        created_on timestamp NULL DEFAULT NULL,
        updated_on timestamp NULL DEFAULT NULL,
        PRIMARY KEY (debit_id),
        KEY acctsborridx (borrowernumber),
        KEY itemnumber (itemnumber),
        KEY borrowernumber (borrowernumber),
        KEY issue_id (issue_id),
        KEY branchcode (branchcode)
    ) ENGINE=InnoDB  DEFAULT CHARSET=utf8;
");

$dbh->do("
    CREATE TABLE account_offsets (
        offset_id int(11) NOT NULL AUTO_INCREMENT,
        debit_id int(11) DEFAULT NULL,
        credit_id int(11) DEFAULT NULL,
        `type` varchar(255) DEFAULT NULL,
        amount decimal(28,6) NOT NULL COMMENT 'A positive number here represents a payment, a negative is a increase in a fine.',
        created_on timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        PRIMARY KEY (offset_id),
        KEY fee_id (debit_id),
        KEY payment_id (credit_id)
    ) ENGINE=InnoDB  DEFAULT CHARSET=utf8;
");

$dbh->do("
    ALTER TABLE `account_credits`
      ADD CONSTRAINT account_credits_ibfk_1 FOREIGN KEY (borrowernumber) REFERENCES borrowers (borrowernumber) ON DELETE CASCADE ON UPDATE CASCADE,
      ADD CONSTRAINT account_credits_ibfk_2 FOREIGN KEY (branchcode) REFERENCES branches (branchcode) ON DELETE CASCADE ON UPDATE CASCADE;
");
$dbh->do("
    ALTER TABLE `account_debits`
      ADD CONSTRAINT account_debits_ibfk_1 FOREIGN KEY (borrowernumber) REFERENCES borrowers (borrowernumber) ON DELETE CASCADE ON UPDATE CASCADE,
      ADD CONSTRAINT account_debits_ibfk_2 FOREIGN KEY (branchcode) REFERENCES branches (branchcode) ON DELETE CASCADE ON UPDATE CASCADE;
");
$dbh->do("
    ALTER TABLE `account_offsets`
      ADD CONSTRAINT account_offsets_ibfk_1 FOREIGN KEY (debit_id) REFERENCES account_debits (debit_id) ON DELETE CASCADE ON UPDATE CASCADE,
      ADD CONSTRAINT account_offsets_ibfk_2 FOREIGN KEY (credit_id) REFERENCES account_credits (credit_id) ON DELETE CASCADE ON UPDATE CASCADE;
");

$dbh->do("
    ALTER TABLE borrowers ADD account_balance DECIMAL( 28, 6 ) NOT NULL;
");

my $schema = Koha::Database->new()->schema;
my $debit_rs = $schema->resultset('AccountDebit');
my $credit_rs = $schema->resultset('AccountCredit');
my $issues_rs = $schema->resultset('Issue');

use Koha::Accounts::DebitTypes;
use Koha::Accounts::CreditTypes;

my $debit_types_map = {
    'A'    => Koha::Accounts::DebitTypes::AccountManagementFee,
    'F'    => Koha::Accounts::DebitTypes::Fine,
    'FU'   => Koha::Accounts::DebitTypes::Fine,
    'L'    => Koha::Accounts::DebitTypes::Lost,
    'M'    => Koha::Accounts::DebitTypes::Sundry,
    'N'    => Koha::Accounts::DebitTypes::NewCard,
    'Rent' => Koha::Accounts::DebitTypes::Rental,
};

my $credit_types_map = {
    'FOR' => Koha::Accounts::CreditTypes::Forgiven,
    'LR'  => Koha::Accounts::CreditTypes::Found,
    'Pay' => Koha::Accounts::CreditTypes::Payment,
    'PAY' => Koha::Accounts::CreditTypes::Payment,
    'WO'  => Koha::Accounts::CreditTypes::WriteOff,
    'W'   => Koha::Accounts::CreditTypes::WriteOff,
    'C'   => Koha::Accounts::CreditTypes::Credit,
    'CR'  => Koha::Accounts::CreditTypes::Credit,
};

my $sth = $dbh->prepare("SELECT * FROM accountlines");
$sth->execute();
while ( my $a = $sth->fetchrow_hashref() ) {
    if ( $debit_types_map->{ $a->{accounttype} } ) {
        $debit_rs->create(
            {
                borrowernumber     => $a->{borrowernumber},
                itemnumber         => $a->{itemnumber},
                amount_original    => $a->{amount},
                amount_outstanding => $a->{amountoutstanding},
                created_on         => $a->{timestamp},
                description        => $a->{description},
                notes              => $a->{note},
                manager_id         => $a->{manager_id},
                accruing           => $a->{accounttype} eq 'FU',
                type     => $debit_types_map->{ $a->{accounttype} },
                issue_id => $a->{accounttype} eq 'FU'
                ? $issues_rs->single(
                    {
                        borrowernumber => $a->{borrowernumber},
                        itemnumber     => $a->{itemnumber},
                    }
                  )->issue_id()
                : undef,
            }
        );
    }
    elsif ( $credit_types_map->{ $a->{accounttype} } ) {
        $credit_rs->create(
            {
                borrowernumber   => $a->{borrowernumber},
                amount_paid      => $a->{amount} * -1,
                amount_remaining => $a->{amountoutstanding} * -1,
                created_on       => $a->{timestamp},
                notes            => $a->{note},
                manager_id       => $a->{manager_id},
                type => $credit_types_map->{ $a->{accounttype} },
            }
        );
    }
    else {
        # Everything else must be a MANUAL_INV
        $debit_rs->create(
            {
                borrowernumber     => $a->{borrowernumber},
                itemnumber         => $a->{itemnumber},
                amount_original    => $a->{amount},
                amount_outstanding => $a->{amountoutstanding},
                created_on         => $a->{timestamp},
                description        => $a->{description},
                notes              => $a->{note},
                manager_id         => $a->{manager_id},
                type               => Koha::Accounts::DebitTypes::Sundry,
            }
        );
    }
}

$dbh->do("DROP TABLE accountoffsets");
$dbh->do("DROP TABLE accountlines");

print "Upgrade to $DBversion done ( Bug 6427 - Rewrite of the accounts system )\n";
