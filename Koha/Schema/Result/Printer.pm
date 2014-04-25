package Koha::Schema::Result::Printer;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';


=head1 NAME

Koha::Schema::Result::Printer

=cut

__PACKAGE__->table("printers");

=head1 ACCESSORS

=head2 id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0

=head2 name

  data_type: 'varchar'
  default_value: (empty string)
  is_nullable: 0
  size: 40

=head2 queue

  data_type: 'varchar'
  is_nullable: 1
  size: 20

=head2 type

  data_type: 'text'
  is_nullable: 1

=cut

__PACKAGE__->add_columns(
  "id",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "name",
  { data_type => "varchar", default_value => "", is_nullable => 0, size => 40 },
  "queue",
  { data_type => "varchar", is_nullable => 1, size => 20 },
  "type",
  { data_type => "text", is_nullable => 1 },
);
__PACKAGE__->set_primary_key("id");


# Created by DBIx::Class::Schema::Loader v0.07000 @ 2014-05-19 09:04:19
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:uapO0jjBiwFJZjpbJMas/g

sub print {
    my ( $self, $params ) = @_;

    my $data    = $params->{data};
    my $is_html = $params->{is_html};

    return unless ($data);

    if ($is_html) {
        require HTML::HTMLDoc;
        my $htmldoc = new HTML::HTMLDoc();
        $htmldoc->set_output_format('ps');
        $htmldoc->set_html_content($data);
        my $doc = $htmldoc->generate_pdf();
        $data = $doc->to_string();
    }

    my ( $result, $error );

    if ( $self->queue() =~ /:/ ) {

        # Printer has a server:port address, use Net::Printer
        require Net::Printer;

        my ( $server, $port ) = split( /:/, $self->queue() );

        my $printer = new Net::Printer(
            printer     => $self->name(),
            server      => $server,
            port        => $port,
            lineconvert => "YES"
        );

        $result = $printer->printstring($data);

        $error = $printer->printerror();
    }
    else {
        require Printer;

        my $printer_name = $self->name();

        my $printer = new Printer( 'linux' => 'lp' );
        $printer->print_command(
            linux => {
                type    => 'pipe',
                command => "lp -d $printer_name",
            }
        );

        $result = $printer->print($data);
    }

    return ( $result eq '1', $error );
}

1;
