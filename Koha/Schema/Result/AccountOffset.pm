use utf8;
package Koha::Schema::Result::AccountOffset;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

Koha::Schema::Result::AccountOffset

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<account_offsets>

=cut

__PACKAGE__->table("account_offsets");

=head1 ACCESSORS

=head2 offset_id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0

=head2 debit_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 1

=head2 credit_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 1

=head2 type

  data_type: 'varchar'
  is_nullable: 1
  size: 255

=head2 amount

  data_type: 'decimal'
  is_nullable: 0
  size: [28,6]

A positive number here represents a payment, a negative is a increase in a fine.

=head2 created_on

  data_type: 'timestamp'
  datetime_undef_if_invalid: 1
  default_value: current_timestamp
  is_nullable: 0

=cut

__PACKAGE__->add_columns(
  "offset_id",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "debit_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
  "credit_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
  "type",
  { data_type => "varchar", is_nullable => 1, size => 255 },
  "amount",
  { data_type => "decimal", is_nullable => 0, size => [28, 6] },
  "created_on",
  {
    data_type => "timestamp",
    datetime_undef_if_invalid => 1,
    default_value => \"current_timestamp",
    is_nullable => 0,
  },
);

=head1 PRIMARY KEY

=over 4

=item * L</offset_id>

=back

=cut

__PACKAGE__->set_primary_key("offset_id");

=head1 RELATIONS

=head2 credit

Type: belongs_to

Related object: L<Koha::Schema::Result::AccountCredit>

=cut

__PACKAGE__->belongs_to(
  "credit",
  "Koha::Schema::Result::AccountCredit",
  { credit_id => "credit_id" },
  {
    is_deferrable => 1,
    join_type     => "LEFT",
    on_delete     => "CASCADE",
    on_update     => "CASCADE",
  },
);

=head2 debit

Type: belongs_to

Related object: L<Koha::Schema::Result::AccountDebit>

=cut

__PACKAGE__->belongs_to(
  "debit",
  "Koha::Schema::Result::AccountDebit",
  { debit_id => "debit_id" },
  {
    is_deferrable => 1,
    join_type     => "LEFT",
    on_delete     => "CASCADE",
    on_update     => "CASCADE",
  },
);


# Created by DBIx::Class::Schema::Loader v0.07040 @ 2014-07-15 10:03:45
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:CQJiVGoCnQEzkVu9ssgU/Q


# You can replace this text with custom content, and it will be preserved on regeneration
1;
