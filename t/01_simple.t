use Test::Base;
use Test::TCP;

plan tests => 5;

use AnyEvent::APNS;
use AnyEvent::Socket;

my $cv = AnyEvent->condvar;

my $port = empty_port;

# test server
my $sh;
tcp_server undef, $port, sub {
    my ($fh) = @_
        or die $!;

    $sh = AnyEvent::Handle->new(
        fh       => $fh,
        on_error => sub { die $! },
    );

    $sh->push_read( chunk => 1, sub {
        is($_[1], pack('C', 0), 'command ok');
    });

    $sh->push_read( chunk => 2, sub {
        is($_[1], pack('n', 32), 'token size ok');
    });

    $sh->push_read( chunk => 32, sub {
        is($_[1], 'd'x32, 'token ok');
    });

    my $payload_length;
    $sh->push_read( chunk => 2, sub {
        $payload_length = unpack('n', $_[1]);

        $sh->push_read( chunk => $payload_length, sub {
            is(length $_[1], $payload_length, 'payload length ok');
            is($_[1], qq{{"foo":"bar"}}, 'payload ok');
            $cv->send;
        });
    });
};

# client XXX: a bit hacky
no warnings 'redefine';
*AnyEvent::APNS::_connect = sub {
    my $self = shift;

    undef $self->{handler};

    tcp_connect '127.0.0.1', $port, sub {
        my ($fh) = @_
            or return $self->on_error($!);

        my $handle = AnyEvent::Handle->new(
            fh       => $fh,
            on_error => sub { $self->_error_handler(@_) },
        );
        $self->handler( $handle );
        $self->on_connect->();
    };
};

my $apns; $apns = AnyEvent::APNS->new(
    certificate => 'dummy',
    private_key => 'dummy',
    on_error    => sub { die $! },
    on_connect  => sub {
        $apns->send('d' x 32 => { foo => 'bar' });
    },
);

$cv->recv;
