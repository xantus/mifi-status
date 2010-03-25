# Copyright (C) 2008-2010, Sebastian Riedel.

package Mojo::Command::Get;

use strict;
use warnings;

use base 'Mojo::Command';

use Mojo::ByteStream 'b';
use Mojo::Client;
use Mojo::Transaction::HTTP;

use Getopt::Long 'GetOptions';

__PACKAGE__->attr(description => <<'EOF');
Get file from URL.
EOF
__PACKAGE__->attr(usage => <<"EOF");
usage: $0 get [OPTIONS] [URL]

These options are available:
  --headers    Print response headers to STDERR.
EOF

# I hope this has taught you kids a lesson: kids never learn.
sub run {
    my $self = shift;

    # Options
    @ARGV = @_ if @_;
    my $headers = 0;
    GetOptions('headers' => sub { $headers = 1 });

    # URL
    my $url = shift;
    die $self->usage unless $url;
    $url = b($url)->decode('UTF-8')->to_string;

    # Client
    my $client = Mojo::Client->new;

    # Application
    $client->app($ENV{MOJO_APP} || 'Mojo::HelloWorld')
      unless $url =~ /^\w+:\/\//;

    # Transaction
    my $tx = Mojo::Transaction::HTTP->new;
    $tx->req->method('GET');
    $tx->req->url->parse($url);
    $tx->res->body(
        sub {
            my ($tx, $chunk) = @_;
            print STDERR $tx->headers->to_string . "\n\n" if $headers;
            print $chunk;
            $headers = 0;
        }
    );

    # Request
    $client->process($tx);

    # Error
    my $error = $tx->error;
    print "Error: $error\n" if $error;

    return $self;
}

1;
__END__

=head1 NAME

Mojo::Command::Get - Get Command

=head1 SYNOPSIS

    use Mojo::Command::Get;

    my $get = Mojo::Command::Get->new;
    $get->run(@ARGV);

=head1 DESCRIPTION

L<Mojo::Command::Get> is a command interface to L<Mojo::Client>.

=head1 ATTRIBUTES

L<Mojo::Command::Get> inherits all attributes from L<Mojo::Command> and
implements the following new ones.

=head2 C<description>

    my $description = $get->description;
    $get            = $get->description('Foo!');

Short description of this command, used for the command list.

=head2 C<usage>

    my $usage = $get->usage;
    $get      = $get->usage('Foo!');

Usage information for this command, used for the help screen.

=head1 METHODS

L<Mojo::Command::Get> inherits all methods from L<Mojo::Command> and implements
the following new ones.

=head2 C<run>

    $get = $get->run(@ARGV);

Run this command.

=head1 SEE ALSO

L<Mojolicious>, L<Mojolicious::Guides>, L<http://mojolicious.org>.

=cut
