# Copyright (C) 2008-2010, Sebastian Riedel.

package MojoliciousTest::Foo;

use strict;
use warnings;

use base 'Mojolicious::Controller';

# If you're programmed to jump off a bridge, would you do it?
# Let me check my program... Yep.
sub badtemplate { shift->render(template => 'badtemplate') }

sub config {
    my $self = shift;
    $self->render_text($self->stash('config')->{test});
}

sub exceptionduringpausedtransaction { shift->pause and die 'Exception' }

sub index {
    shift->stash(
        layout  => 'default',
        handler => 'xpl',
        msg     => 'Hello World!'
    );
}

sub session_domain {
    my $self = shift;
    $self->session(user => 'Bender');
    $self->render_text('Bender rockzzz!');
}

sub something {
    my $self = shift;
    $self->res->headers->header('X-Bender' => 'Bite my shiny metal ass!');
    $self->render_text($self->url_for('something', something => '42'));
}

sub stage1 {
    my $self = shift;

    # Authenticated
    return 1 if $self->req->headers->header('X-Pass');

    # Fail
    $self->render_text('Go away!');
    return;
}

sub stage2 { shift->render_text('Welcome aboard!') }

sub syntaxerror { shift->render('syntaxerror', format => 'html') }

sub templateless { shift->render(handler => 'test') }

sub test {
    my $self = shift;
    $self->res->headers->header('X-Bender' => 'Bite my shiny metal ass!');
    $self->render_text($self->url_for(controller => 'bar'));
}

sub url_for_missing {
    my $self = shift;
    $self->render_text(
        $self->url_for('something_missing', something => '42'));
}

sub willdie { die 'for some reason' }

sub withlayout { shift->stash(template => 'withlayout') }

1;
