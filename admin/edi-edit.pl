#!/usr/bin/perl

# Copyright 2011 Mark Gavillet & PTFS Europe Ltd
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

use strict;
use warnings;
use CGI;
use C4::Auth;
use C4::Output;
use C4::EDI qw( GetVendorList GetEDIAccountDetails);

my $input = CGI->new();

my ( $template, $loggedinuser, $cookie ) = get_template_and_user(
    {
        template_name   => 'admin/edi-edit.tmpl',
        query           => $input,
        type            => 'intranet',
        authnotrequired => 0,
        flagsrequired   => { borrowers => 1 },
    }
);
my $vendorlist = GetVendorList();

my $op = $input->param('op');
$template->param( op => $op );

if ( $op eq 'add' ) {
    $template->param( opaddsubmit => 'addsubmit' );
}
if ( $op eq 'edit' ) {
    $template->param( opeditsubmit => 'editsubmit' );
    my $edi_details      = GetEDIAccountDetails( $input->param('id') );
    my $selectedprovider = $edi_details->{provider};
    foreach my $prov (@$vendorlist) {
        $prov->{selected} = 'selected'
          if $prov->{id} == $selectedprovider;
    }
    $template->param(
        editid      => $edi_details->{id},
        description => $edi_details->{description},
        host        => $edi_details->{host},
        user        => $edi_details->{username},
        pass        => $edi_details->{password},
        provider    => $edi_details->{provider},
        in_dir      => $edi_details->{in_dir},
        san         => $edi_details->{san},
        library_san => $edi_details->{library_san},
        options     => $edi_details->{options},
    );
}
if ( $op eq 'del' ) {
    $template->param(
        opdelsubmit => 'delsubmit',
        opdel       => 1,
        id          => $input->param('id')
    );
}

$template->param( vendorlist => $vendorlist );

output_html_with_http_headers $input, $cookie, $template->output;
