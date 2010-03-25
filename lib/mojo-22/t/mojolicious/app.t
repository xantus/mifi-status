#!/usr/bin/env perl

# Copyright (C) 2008-2010, Sebastian Riedel.

use strict;
use warnings;

use Mojo::IOLoop;
use Test::More;

# Make sure sockets are working
plan skip_all => 'working sockets required for this test!'
  unless Mojo::IOLoop->new->generate_port;
plan tests => 160;

use FindBin;
use lib "$FindBin::Bin/lib";

use File::stat;
use File::Spec;
use Mojo::Date;
use Mojo::Transaction::HTTP;
use Test::Mojo;
use Mojolicious;

# Congratulations Fry, you've snagged the perfect girlfriend.
# Amy's rich, she's probably got other characteristics...
use_ok('MojoliciousTest');

my $t = Test::Mojo->new(app => 'MojoliciousTest');

# SyntaxError::foo (syntax error in controller)
$t->get_ok('/syntax_error/foo')->status_is(500)
  ->header_is(Server         => 'Mojolicious (Perl)')
  ->header_is('X-Powered-By' => 'Mojolicious (Perl)')
  ->content_like(qr/Missing right curly/);

# Foo::exceptionduringpausedtransaction
# (syntax error in controller during paused transaction)
$t->get_ok('/foo/exceptionduringpausedtransaction')->status_is(500)
  ->header_is(Server         => 'Mojolicious (Perl)')
  ->header_is('X-Powered-By' => 'Mojolicious (Perl)')
  ->content_like(qr/Exception/);

# Foo::syntaxerror (syntax error in template)
$t->get_ok('/foo/syntaxerror')->status_is(500)
  ->header_is(Server         => 'Mojolicious (Perl)')
  ->header_is('X-Powered-By' => 'Mojolicious (Perl)')
  ->content_like(qr/^Missing right curly/);

# Foo::badtemplate (template missing)
$t->get_ok('/foo/badtemplate')->status_is(404)
  ->header_is(Server         => 'Mojolicious (Perl)')
  ->header_is('X-Powered-By' => 'Mojolicious (Perl)')
  ->content_like(qr/File Not Found/);

# Foo::test
$t->get_ok('/foo/test', {'X-Test' => 'Hi there!'})->status_is(200)
  ->header_is('X-Bender'     => 'Bite my shiny metal ass!')
  ->header_is(Server         => 'Mojolicious (Perl)')
  ->header_is('X-Powered-By' => 'Mojolicious (Perl)')
  ->content_like(qr/\/bar\/test/);

# Foo::index
$t->get_ok('/foo', {'X-Test' => 'Hi there!'})->status_is(200)
  ->header_is(Server         => 'Mojolicious (Perl)')
  ->header_is('X-Powered-By' => 'Mojolicious (Perl)')
  ->content_like(qr/<body>\n23Hello Mojo from the template \/foo! He/);

# Foo::Bar::index
$t->get_ok('/foo-bar', {'X-Test' => 'Hi there!'})->status_is(200)
  ->header_is(Server         => 'Mojolicious (Perl)')
  ->header_is('X-Powered-By' => 'Mojolicious (Perl)')
  ->content_like(qr/Hello Mojo from the other template \/foo-bar!/);

# Foo::something
$t->get_ok('/somethingtest', {'X-Test' => 'Hi there!'})->status_is(200)
  ->header_is(Server         => 'Mojolicious (Perl)')
  ->header_is('X-Powered-By' => 'Mojolicious (Perl)')
  ->content_is('/test4/42');

# Foo::url_for_missing
$t->get_ok('/something_missing', {'X-Test' => 'Hi there!'})->status_is(500)
  ->header_is(Server         => 'Mojolicious (Perl)')
  ->header_is('X-Powered-By' => 'Mojolicious (Perl)')
  ->content_like(
    qr/Route "something_missing" used in url_for does not exist/);

# Foo::templateless
$t->get_ok('/foo/templateless', {'X-Test' => 'Hi there!'})->status_is(200)
  ->header_is(Server         => 'Mojolicious (Perl)')
  ->header_is('X-Powered-By' => 'Mojolicious (Perl)')
  ->content_like(qr/Hello Mojo from a templateless renderer!/);

# Foo::withlayout
$t->get_ok('/foo/withlayout', {'X-Test' => 'Hi there!'})->status_is(200)
  ->header_is(Server         => 'Mojolicious (Perl)')
  ->header_is('X-Powered-By' => 'Mojolicious (Perl)')
  ->content_like(qr/Same old in green Seems to work!/);

# MojoliciousTest2::Foo::test
$t->get_ok('/test2', {'X-Test' => 'Hi there!'})->status_is(200)
  ->header_is('X-Bender'     => 'Bite my shiny metal ass!')
  ->header_is(Server         => 'Mojolicious (Perl)')
  ->header_is('X-Powered-By' => 'Mojolicious (Perl)')
  ->content_like(qr/\/test2/);

# MojoliciousTestController::index
$t->get_ok('/test3', {'X-Test' => 'Hi there!'})->status_is(200)
  ->header_is('X-Bender'     => 'Bite my shiny metal ass!')
  ->header_is(Server         => 'Mojolicious (Perl)')
  ->header_is('X-Powered-By' => 'Mojolicious (Perl)')
  ->content_like(qr/No class works!/);

# 404
$t->get_ok('/', {'X-Test' => 'Hi there!'})->status_is(404)
  ->header_is(Server         => 'Mojolicious (Perl)')
  ->header_is('X-Powered-By' => 'Mojolicious (Perl)')
  ->content_like(qr/File Not Found/);

# Check Last-Modified header for static files
my $path  = File::Spec->catdir($FindBin::Bin, 'public_dev', 'hello.txt');
my $stat  = stat($path);
my $mtime = Mojo::Date->new(stat($path)->mtime)->to_string;

# Static file /hello.txt
$t->get_ok('/hello.txt')->status_is(200)
  ->header_is(Server           => 'Mojolicious (Perl)')
  ->header_is('X-Powered-By'   => 'Mojolicious (Perl)')
  ->header_is('Last-Modified'  => $mtime)
  ->header_is('Content-Length' => $stat->size)->content_type_is('text/plain')
  ->content_like(qr/Hello Mojo from a development static file!/);

# Try to access a file which is not under the web root via path
# traversal
$t->get_ok('../../mojolicious/secret.txt')->status_is(404)
  ->header_is(Server         => 'Mojolicious (Perl)')
  ->header_is('X-Powered-By' => 'Mojolicious (Perl)')
  ->content_like(qr/File Not Found/);

# Check If-Modified-Since
$t->get_ok('/hello.txt', {'If-Modified-Since' => $mtime})->status_is(304)
  ->header_is(Server         => 'Mojolicious (Perl)')
  ->header_is('X-Powered-By' => 'Mojolicious (Perl)')->content_is('');

# Check develpment mode log level
my $app = Mojolicious->new;
is($app->log->level, 'debug');

# Make sure we can override attributes with constructor arguments
$app = MojoliciousTest->new({mode => 'test'});
is($app->mode, 'test');

# Persistent error
$app = MojoliciousTest->new;
my $tx = Mojo::Transaction::HTTP->new;
$tx->req->method('GET');
$tx->req->url->parse('/foo');
$app->handler($tx);
is($tx->res->code, 200);
like($tx->res->body, qr/Hello Mojo from the template \/foo! Hello World!/);
$tx = Mojo::Transaction::HTTP->new;
$tx->req->method('GET');
$tx->req->url->parse('/foo/willdie');
$app->handler($tx);
is($tx->res->code, 500);
like($tx->res->body, qr/Foo\.pm/);
$tx = Mojo::Transaction::HTTP->new;
$tx->req->method('GET');
$tx->req->url->parse('/foo');
$app->handler($tx);
is($tx->res->code, 200);
like($tx->res->body, qr/Hello Mojo from the template \/foo! Hello World!/);

$t = Test::Mojo->new(app => 'SingleFileTestApp');

# SingleFileTestApp::Foo::index
$t->get_ok('/foo')->status_is(200)->header_is(Server => 'Mojolicious (Perl)')
  ->header_is('X-Powered-By' => 'Mojolicious (Perl)')
  ->content_like(qr/Same old in green Seems to work!/);

# SingleFileTestApp::Foo::data_template
$t->get_ok('/foo/data_template')->status_is(200)
  ->header_is(Server         => 'Mojolicious (Perl)')
  ->header_is('X-Powered-By' => 'Mojolicious (Perl)')
  ->content_is("23 works!\n");

# SingleFileTestApp::Foo::data_template
$t->get_ok('/foo/data_template2')->status_is(200)
  ->header_is(Server         => 'Mojolicious (Perl)')
  ->header_is('X-Powered-By' => 'Mojolicious (Perl)')
  ->content_is("This one works too!\n");

# SingleFileTestApp::Foo::bar
$t->get_ok('/foo/bar')->status_is(200)
  ->header_is('X-Bender'     => 'Bite my shiny metal ass!')
  ->header_is(Server         => 'Mojolicious (Perl)')
  ->header_is('X-Powered-By' => 'Mojolicious (Perl)')->content_is('/foo/bar');

# SingleFileTestApp::Baz::does_not_exist
$t->get_ok('/baz/does_not_exist')->status_is(404)
  ->header_is(Server         => 'Mojolicious (Perl)')
  ->header_is('X-Powered-By' => 'Mojolicious (Perl)')
  ->content_like(qr/File Not Found/);

$t = Test::Mojo->new(app => 'MojoliciousTest');

# MojoliciousTestController::Foo::stage2
$t->get_ok('/staged', {'X-Pass' => '1'})->status_is(200)
  ->header_is(Server         => 'Mojolicious (Perl)')
  ->header_is('X-Powered-By' => 'Mojolicious (Perl)')
  ->content_is('Welcome aboard!');

# MojoliciousTestController::Foo::stage1
$t->get_ok('/staged')->status_is(200)
  ->header_is(Server         => 'Mojolicious (Perl)')
  ->header_is('X-Powered-By' => 'Mojolicious (Perl)')->content_is('Go away!');

# MojoliciousTest::Foo::config
$t->get_ok('/stash_config')->status_is(200)
  ->header_is(Server         => 'Mojolicious (Perl)')
  ->header_is('X-Powered-By' => 'Mojolicious (Perl)')->content_is('123');

# Shortcuts to controller#action
$t->get_ok('/shortcut/ctrl-act')->status_is(200)
  ->header_is(Server         => 'Mojolicious (Perl)')
  ->header_is('X-Powered-By' => 'Mojolicious (Perl)')->content_is('ctrl-act');
$t->get_ok('/shortcut/ctrl')->status_is(200)
  ->header_is(Server         => 'Mojolicious (Perl)')
  ->header_is('X-Powered-By' => 'Mojolicious (Perl)')->content_is('ctrl');
$t->get_ok('/shortcut/act')->status_is(200)
  ->header_is(Server         => 'Mojolicious (Perl)')
  ->header_is('X-Powered-By' => 'Mojolicious (Perl)')->content_is('act');

# Session with domain
$t->get_ok('/foo/session')->status_is(200)
  ->header_like('Set-Cookie' => qr/; Domain=\.example\.com/)
  ->content_is('Bender rockzzz!');
