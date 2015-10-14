use utf8;
package Koha::Schema::Result::AccountCredit;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Koha::Schema::Result::AccountCredit

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<account_credits>

=cut

__PACKAGE__->table("account_credits");

=head1 ACCESSORS

=head2 credit_id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0

=head2 borrowernumber

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

=head2 type

  data_type: 'varchar'
  is_nullable: 0
  size: 255

=head2 amount_received

  data_type: 'decimal'
  is_nullable: 1
  size: [28,6]

=head2 amount_paid

  data_type: 'decimal'
  is_nullable: 0
  size: [28,6]

=head2 amount_remaining

  data_type: 'decimal'
  is_nullable: 0
  size: [28,6]

=head2 amount_voided

  data_type: 'decimal'
  is_nullable: 1
  size: [28,6]

=head2 notes

  data_type: 'text'
  is_nullable: 1

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

=head2 branchcode

  data_type: 'varchar'
  is_nullable: 1
  size: 10

=cut

__PACKAGE__->add_columns(
  "credit_id",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "borrowernumber",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "type",
  { data_type => "varchar", is_nullable => 0, size => 255 },
  "amount_received",
  { data_type => "decimal", is_nullable => 1, size => [28, 6] },
  "amount_paid",
  { data_type => "decimal", is_nullable => 0, size => [28, 6] },
  "amount_remaining",
  { data_type => "decimal", is_nullable => 0, size => [28, 6] },
  "amount_voided",
  { data_type => "decimal", is_nullable => 1, size => [28, 6] },
  "notes",
  { data_type => "text", is_nullable => 1 },
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
  "branchcode",
  { data_type => "varchar", is_nullable => 1, size => 10 },
);

=head1 PRIMARY KEY

=over 4

=item * L</credit_id>

=back

=cut

__PACKAGE__->set_primary_key("credit_id");

=head1 RELATIONS

=head2 account_offsets

Type: has_many

Related object: L<Koha::Schema::Result::AccountOffset>

=cut

__PACKAGE__->has_many(
  "account_offsets",
  "Koha::Schema::Result::AccountOffset",
  { "foreign.credit_id" => "self.credit_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 borrowernumber

Type: belongs_to

Related object: L<Koha::Schema::Result::Borrower>

=cut

__PACKAGE__->belongs_to(
  "borrowernumber",
  "Koha::Schema::Result::Borrower",
  { borrowernumber => "borrowernumber" },
  { is_deferrable => 1, on_delete => "CASCADE", on_update => "CASCADE" },
);


# Created by DBIx::Class::Schema::Loader v0.07043 @ 2015-10-14 08:41:52
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:uF7ltOCQCrABK9oEuQZJCg

__PACKAGE__->belongs_to(
  "borrower",
  "Koha::Schema::Result::Borrower",
  { borrowernumber => "borrowernumber" },
);

__PACKAGE__->belongs_to(
    "branch",
    "Koha::Schema::Result::Branch",
    { branchcode => "branchcode" },
);
1;
