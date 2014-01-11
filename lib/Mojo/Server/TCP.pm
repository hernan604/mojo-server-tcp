package Mojo::Server::TCP;

=head1 NAME

Mojo::Server::TCP - Generic TCP server

=head1 SYNOPSIS

  use Mojo::Server::TCP;
  my $echo = Mojo::Server::TCP->new(listen => ['tcp//*:9000']);

  $echo->on(read => sub {
    my($echo, $stream, $chunk) = @_;
    $stream->write($chunk);
  });

  $echo->start;

=head1 DESCRIPTION

L<Mojo::Server::TCP> is a generic TCP server based on the logic of
the L<Mojo::Server::Daemon>.

=cut

use Mojo::Base 'Mojo::EventEmitter';
use Mojo::Loader;
use Mojo::URL;
use constant DEBUG => $ENV{MOJO_SERVER_DEBUG} ? 1 : 0;

=head1 EVENTS

=head2 close

  $self->on(close => sub { my($self, $stream) = @_ });

Emitted safely if the stream gets closed.

=head2 error

  $self->on(error => sub { my($self, $stream, $str) = @_ });

=head2 read

  $self->on(error => sub { my($self, $stream, $chunk) = @_ });

Emitted safely if new data arrives on the stream.

=head2 timeout

  $self->on(timeout => sub { my($self, $stream) = @_ });

Emitted safely if the stream has been inactive for too long and will get
closed automatically.

=head1 ATTRIBUTES

=head2 daemon_class

=head2 listen

  my $listen = $daemon->listen;
  $daemon    = $daemon->listen(['tcp://localhost:3000']);

List of one or more locations to listen on, defaults to "tcp://*:3000".

=cut

has daemon_class => 'Mojo::Server::Daemon';
has listen => sub { ['tcp://*:3000']; };
has _server => sub {
  my $self = shift;
  my $e = Mojo::Loader->new->load($self->daemon_class);
  
  $e and die $e;
  $self->daemon_class->new(listen => []);
};

=head1 METHODS

=head2 run

  $self = $self->run;

Start accepting connections and run the server.

=cut

sub run {
  my $self = shift;

  local $SIG{INT} = local $SIG{TERM} = sub { $self->_server->ioloop->stop };
  $self->start->_server->setuidgid->ioloop->start;
  $self;
}

=head2 start

  $self = $self->start;

Start listening for connections. See also L</run>.

=cut

sub start {
  my $self = shift;

  if(!$self->{acceptors}) {
    $self->_listen($_) for @{ $self->listen };
  }
  if($self->{acceptors}) {
    $self->_server->acceptors($self->{acceptors});
  }

  $self->_server->start;
  $self;
}

=head2 stop

  $self = $self->stop;

Stop the server.

=cut

sub stop {
  my $self = shift;

  $self->_server->stop;
  $self;
}

sub _listen {
  my $self   = shift;
  my $url    = Mojo::URL->new(shift);
  my $query  = $url->query;
  my $verify = $query->param('verify');
  my($options, $tls);

  $options = {
    address => $url->host,
    backlog => $self->_server->backlog,
    port    => $url->port,
    reuse   => scalar $query->param('reuse'),
  };

  $options->{"tls_$_"} = scalar $query->param($_) for qw(ca cert ciphers key);
  $options->{tls_verify} = hex $verify if defined $verify;
  delete $options->{address} if $options->{address} eq '*';
  $tls = $options->{tls} = $url->protocol eq 'tcps';
 
  Scalar::Util::weaken($self);
  push @{$self->{acceptors}}, $self->_server->ioloop->server(
    $options => sub {
      my ($loop, $stream, $id) = @_;
 
      warn "-- Accept (@{[$stream->handle->peerhost]})\n" if DEBUG;
      $stream->timeout($self->_server->inactivity_timeout);
      $stream->on(close => sub { $self->emit(close => @_); });
      $stream->on(error => sub { $self and $self->emit(error => @_); });
      $stream->on(read => sub { $self->emit(read => @_); });
      $stream->on(timeout => sub { $self->emit(timeout => @_); });
    }
  );
}

=head1 AUTHOR

Jan Henning Thorsen - C<jhthorsen@cpan.org>

=cut

1;
