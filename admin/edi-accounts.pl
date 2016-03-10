#!/usr/bin/perl

# Copyright 2011,2012 Mark Gavillet & PTFS Europe Ltd
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
use C4::EDI
  qw( CreateEDIDetails UpdateEDIDetails GetEDIAccounts DeleteEDIDetails);

my $input = CGI->new();

my ( $template, $loggedinuser, $cookie ) = get_template_and_user(
    {
        template_name   => 'admin/edi-accounts.tt',
        query           => $input,
        type            => 'intranet',
        authnotrequired => 0,
        flagsrequired   => { borrowers => 1 },
    }
);

my $op = $input->param('op');
$template->param( op => $op );

if ( $op eq 'delsubmit' ) {
    my $del = DeleteEDIDetails( $input->param('id') );
    $template->param( opdelsubmit => 1 );
}

if ( $op eq 'addsubmit' ) {
    CreateEDIDetails(
        $input->param('provider'), $input->param('description'),
        $input->param('host'),     $input->param('user'),
        $input->param('pass'),     $input->param('path'),
        $input->param('in_dir'),   $input->param('san')
    );
    $template->param( opaddsubmit => 1 );
}

if ( $op eq 'editsubmit' ) {
    UpdateEDIDetails(
        $input->param('editid'), $input->param('description'),
        $input->param('host'),   $input->param('user'),
        $input->param('pass'),   $input->param('provider'),
        $input->param('path'),   $input->param('in_dir'),
        $input->param('san')
    );
    $template->param( opeditsubmit => 1 );
}

my $ediaccounts = GetEDIAccounts();
$template->param( ediaccounts => $ediaccounts );

output_html_with_http_headers $input, $cookie, $template->output;
