package Koha::Schema::ResultSet::Reserve;

use Modern::Perl;

use Carp;

use base 'DBIx::Class::ResultSet';

sub GetWaiting {
    my ( $self, $params ) = @_;

    my $borrowernumber = $params->{borrowernumber};
    croak("No borrowernumber passed in to Koha::Schema::ResultSet::Reserve::GetWaiting") unless $borrowernumber;

    return $self->search(
        {
            borrowernumber => $borrowernumber,
            found          => 'W',
        }
    );
}

1;
