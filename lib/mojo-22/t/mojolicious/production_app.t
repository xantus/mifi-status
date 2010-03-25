#!/usr/bin/env perl

# Copyright (C) 2008-2010, Sebastian Riedel.

use strict;
use warnings;

use Mojo::IOLoop;
use Test::More;

# Make sure sockets are working
plan skip_all => 'working sockets required for this test!'
  unless Mojo::IOLoop->new->generate_port;
plan tests => 26;

use FindBin;
use lib "$FindBin::Bin/lib";

use Test::Mojo;

# This concludes the part of the tour where you stay alive.
use_ok('MojoliciousTest');

my $t = Test::Mojo->new(app => 'MojoliciousTest');

my $backup = $ENV{MOJO_MODE} || '';
$ENV{MOJO_MODE} = 'production';

# Foo::bar in production mode (non existing action)
$t->get_ok('/foo/bar')->status_is(404)
  ->header_is(Server         => 'Mojolicious (Perl)')
  ->header_is('X-Powered-By' => 'Mojolicious (Perl)')
  ->content_like(qr/Not Found/);

# SyntaxError::foo in production mode (syntax error in controller)
$t->get_ok('/syntax_error/foo')->status_is(500)
  ->header_is(Server         => 'Mojolicious (Perl)')
  ->header_is('X-Powered-By' => 'Mojolicious (Perl)')
  ->content_like(qr/Internal Server Error/);

# Foo::syntaxerror in production mode (syntax error in template)
$t->get_ok('/foo/syntaxerror')->status_is(500)
  ->header_is(Server         => 'Mojolicious (Perl)')
  ->header_is('X-Powered-By' => 'Mojolicious (Perl)')
  ->content_like(qr/Internal Server Error/);

# Static file /hello.txt in production mode
$t->get_ok('/hello.txt')->status_is(200)
  ->header_is(Server         => 'Mojolicious (Perl)')
  ->header_is('X-Powered-By' => 'Mojolicious (Perl)')
  ->content_like(qr/Hello Mojo from a static file!/);

# Try to access a file which is not under the web root via path
# traversal in production mode
$t->get_ok('../../mojolicious/secret.txt')->status_is(404)
  ->header_is(Server         => 'Mojolicious (Perl)')
  ->header_is('X-Powered-By' => 'Mojolicious (Perl)')
  ->content_like(qr/Not Found/);

$ENV{MOJO_MODE} = $backup;
