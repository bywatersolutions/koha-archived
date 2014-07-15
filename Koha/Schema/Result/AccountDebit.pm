use utf8;
package Koha::Schema::Result::AccountDebit;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Koha::Schema::Result::AccountDebit

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<account_debits>

=cut

__PACKAGE__->table("account_debits");

=head1 ACCESSORS

=head2 debit_id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0

=head2 borrowernumber

  data_type: 'integer'
  default_value: 0
  is_nullable: 0

=head2 itemnumber

  data_type: 'integer'
  is_nullable: 1

=head2 issue_id

  data_type: 'integer'
  is_nullable: 1

=head2 type

  data_type: 'varchar'
  is_nullable: 0
  size: 255

=head2 accruing

  data_type: 'tinyint'
  default_value: 0
  is_nullable: 0

=head2 amount_original

  data_type: 'decimal'
  is_nullable: 1
  size: [28,6]

=head2 amount_outstanding

  data_type: 'decimal'
  is_nullable: 1
  size: [28,6]

=head2 amount_last_increment

  data_type: 'decimal'
  is_nullable: 1
  size: [28,6]

=head2 description

  data_type: 'mediumtext'
  is_nullable: 1

=head2 notes

  data_type: 'text'
  is_nullable: 1

=head2 branchcode

  data_type: 'varchar'
  is_nullable: 1
  size: 10

=head2 manager_id

  data_type: 'integer'
  is_nullable: 1

=head2 created_on

  data_type: 'timestamp'
  datetime_undef_if_invalid: 1
  is_nullable: 1

=head2 updated_on

  data_type: 'timestamp'
  datetime_undef_if_invalid: 1
  is_nullable: 1

=cut

__PACKAGE__->add_columns(
  "debit_id",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "borrowernumber",
  { data_type => "integer", default_value => 0, is_nullable => 0 },
  "itemnumber",
  { data_type => "integer", is_nullable => 1 },
  "issue_id",
  { data_type => "integer", is_nullable => 1 },
  "type",
  { data_type => "varchar", is_nullable => 0, size => 255 },
  "accruing",
  { data_type => "tinyint", default_value => 0, is_nullable => 0 },
  "amount_original",
  { data_type => "decimal", is_nullable => 1, size => [28, 6] },
  "amount_outstanding",
  { data_type => "decimal", is_nullable => 1, size => [28, 6] },
  "amount_last_increment",
  { data_type => "decimal", is_nullable => 1, size => [28, 6] },
  "description",
  { data_type => "mediumtext", is_nullable => 1 },
  "notes",
  { data_type => "text", is_nullable => 1 },
  "branchcode",
  { data_type => "varchar", is_nullable => 1, size => 10 },
  "manager_id",
  { data_type => "integer", is_nullable => 1 },
  "created_on",
  {
    data_type => "timestamp",
    datetime_undef_if_invalid => 1,
    is_nullable => 1,
  },
  "updated_on",
  {
    data_type => "timestamp",
    datetime_undef_if_invalid => 1,
    is_nullable => 1,
  },
);

=head1 PRIMARY KEY

=over 4

=item * L</debit_id>

=back

=cut

__PACKAGE__->set_primary_key("debit_id");

=head1 RELATIONS

=head2 account_offsets

Type: has_many

Related object: L<Koha::Schema::Result::AccountOffset>

=cut

__PACKAGE__->has_many(
  "account_offsets",
  "Koha::Schema::Result::AccountOffset",
  { "foreign.debit_id" => "self.debit_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);


# Created by DBIx::Class::Schema::Loader v0.07040 @ 2015-01-14 08:52:49
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:M6yz+EMdQ1c79RewRIXX1g

__PACKAGE__->belongs_to(
  "item",
  "Koha::Schema::Result::Item",
  { itemnumber => "itemnumber" }
);

__PACKAGE__->belongs_to(
  "deleted_item",
  "Koha::Schema::Result::Deleteditem",
  { itemnumber => "itemnumber" }
);

__PACKAGE__->belongs_to(
  "issue",
  "Koha::Schema::Result::Issue",
  { issue_id => "issue_id" }
);

__PACKAGE__->belongs_to(
  "old_issue",
  "Koha::Schema::Result::OldIssue",
  { issue_id => "issue_id" }
);

__PACKAGE__->belongs_to(
  "borrower",
  "Koha::Schema::Result::Borrower",
  { borrowernumber => "borrowernumber" },
  { on_delete => "CASCADE", on_update => "CASCADE" },
);

# You can replace this text with custom content, and it will be preserved on regeneration
1;
