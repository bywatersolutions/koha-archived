#!/usr/bin/perl

# This file is part of Koha.
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

use Modern::Perl;

use lib("/usr/share/koha/lib");
use lib("/usr/share/koha/lib/installer");

use Plack::Builder;
use Plack::App::CGIBin;
use Plack::App::Directory;
use Plack::App::URLMap;

# Pre-load libraries
use C4::Boolean;
use C4::Branch;
use C4::Category;
use C4::Koha;
use C4::Languages;
use C4::Letters;
use C4::Members;
use C4::XSLT;
use Koha::Cache;
use Koha::Cache::Memory::Lite;
use Koha::Database;
use Koha::DateUtils;

use CGI qw(-utf8 ); # we will loose -utf8 under plack, otherwise
{
    no warnings 'redefine';
    my $old_new = \&CGI::new;
    *CGI::new = sub {
        my $q = $old_new->( @_ );
        $CGI::PARAM_UTF8 = 1;
        Koha::Cache->flush_L1_cache();
        Koha::Cache::Memory::Lite->flush();
        return $q;
    };
}

my $intranet = Plack::App::CGIBin->new(
    root => '/usr/share/koha/intranet/cgi-bin'
)->to_app;

my $opac = Plack::App::CGIBin->new(
    root => '/usr/share/koha/opac/cgi-bin/opac'
)->to_app;

# my $api  = Plack::App::CGIBin->new(
#     root => '/usr/share/koha/api/'
# )->to_app;

my $allowed_setenvs = qr/^(
    MEMCACHED_SERVERS |
    MEMCACHED_NAMESPACE |
    OVERRIDE_SYSPREF_(\w+) |
    OVERRIDE_SYSPREF_NAMES |
    OPAC_CSS_OVERRIDE |
    OPAC_SEARCH_LIMIT |
    OPAC_LIMIT_OVERRIDE |
    TMPDIR
)\ /x;

builder {

    enable "ReverseProxy";
    enable "Plack::Middleware::Static";
    # Pass through config options as SetEnv
    enable sub {
        my ($app) = @_;

        return sub {
            my ($env) = @_;
            my $req = Plack::Request->new($env);

            # Transforms X-Koha-SetEnv: OPAC_SEARCH_LIMIT potato to OPAC_SEARCH_LIMIT=potato
            $env = {
                %$env,
                map { /(\w+) (.*)/ }
                grep /$allowed_setenvs/,
                split( /, /, $req->header('X-Koha-SetEnv') || '' )
            };

            return $app->($env);
        };
    };

    mount '/opac'     => $opac;
    mount '/intranet' => $intranet;
    # mount '/api'       => $api;
};
