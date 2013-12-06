package Mojo::Server::TCP;

=head1 NAME

Mojo::Server::TCP - Generic TCP server based on Mojo::Server::Prefork

=head1 SYNOPSIS

  use Mojo::Server::TCP;
  my $echo = Mojo::Server::TCP->new(listen => ['tcp//*:9000']);

  $echo->on(read => sub {
    my($echo, $stream, $chunk) = @_;
    $stream->write($chunk);
  });

  $echo->start;

=head1 DESCRIPTION

L<Mojo::Server::TCP> extends L<Mojo::Server::Prefork>, so it has all the
awesomeness you need for a full featured UNIX optimized TCP server.

For better scalability (epoll, kqueue) and to provide IPv6 as well as TLS
support, the optional modules L<EV>, L<IO::Socket::IP> and L<IO::Socket::SSL>
will be used automatically by L<Mojo::IOLoop> if they are installed.

See L<Mojo::Server::TCP/DESCRIPTION> for more details.

=cut

use Mojo::Base 'Mojo::Server::Prefork';
use constant DEBUG => $ENV{MOJO_SERVER_DEBUG} ? 1 : 0;

=head1 ATTRIBUTES

=head2 app

Holds a L<Mojo> object.

=cut

has app => sub {
  require Mojo::Base;
  Mojo->new;
};

=head1 EVENTS

=head2 read

  $self->read($stream, $chunk);

Emitted when new data is received over the wire.

=cut

sub _read {
  my ($self, $id, $chunk) = @_;

  return unless my $c = $self->{connections}{$id};
  $c->{stream} ||= $self->ioloop->stream($id);
  warn "-- Server <<< Client (@{[$c->{stream}->handle->peerhost]})\n$chunk\n" if DEBUG;
  $self->emit(read => $c->{stream}, $chunk);
}

=head1 AUTHOR

Jan Henning Thorsen - C<jhthorsen@cpan.org>

=cut

1;
