use utf8;
use Mojo::Base -strict;
use Mojo::IOLoop;
use Mojo::Server::TCP;
use Test::More;

my $port = Mojo::IOLoop->generate_port;
my($id, $tcp);

{
  $tcp = Mojo::Server::TCP->new;

  is $tcp->listen(["tcp://localhost:$port"]), $tcp, "listen() $port";
  is $tcp->start, $tcp, 'start()';

  is int(@{ $tcp->{acceptors} || [] }), 1, 'one acceptor';
  $id = $tcp->{acceptors}[0];
}

{
  my(@event, @sig);
  $tcp->on(close => sub { push @event, @_; Mojo::IOLoop->stop });
  $tcp->on(read => sub { push @event, @_; });

  Mojo::IOLoop->client(
    { port => $port },
    sub {
      my($loop, $err, $stream) = @_;
      diag $err || 'Connected to TCP server';
      @sig = @SIG{qw( INT TERM )};
      $stream->write("too cool o/ æøå!", sub { shift->close; });
    },
  );

  Mojo::IOLoop->timer(2 => sub { Mojo::IOLoop->stop; });
  $tcp->run;

  is $event[0], $tcp, 'event.0 = tcp';
  isa_ok $event[1], 'Mojo::IOLoop::Stream', 'event.1 = stream';
  is $event[2], "too cool o/ æøå!", 'event.2 = chunk';
  is $event[3], $tcp, 'event.3 = tcp';
  isa_ok $event[4], 'Mojo::IOLoop::Stream', 'event.4 = stream';

  is int(grep { $_ } @sig), 2, 'INT and TERM set up';

  @event = ();
  @sig = ();
}

{
  undef $tcp;
  is(Mojo::IOLoop->acceptor($id), undef, 'acceptor was destroyed');
}

done_testing;
