#BEGIN { $ENV{PERL_DL_NONLAZY} = 0; } # XXX

use Test::Base;
use Test::TCP;

plan tests => 6;

use AnyEvent::APNS;
use AnyEvent::Socket;

my $port = empty_port;

my $apns; $apns = AnyEvent::APNS->new(
    debug_port  => $port,
    certificate => 'dummy',
    private_key => 'dummy',
    on_error    => sub { die $! },
    on_connect  => sub {
        $apns->send('d' x 32 => { foo => 'bar' });
    },
);

my $cv = AnyEvent->condvar;

# test server
my $connect_state = 'initial';
tcp_server undef, $port, sub {
    my ($fh) = @_
        or die $!;

    $connect_state = 'connected';

    my $handle; $handle = AnyEvent::Handle->new(
        fh       => $fh,
        on_eof   => sub {
            $connect_state = 'disconnected';
        },
        on_error => sub {
            die $!;
            undef $handle;
        },
        on_read => sub {
            $_[0]->unshift_read( chunk => 1, sub {} );
        },
    );

    $handle->push_read( chunk => 1, sub {
        is($_[1], pack('C', 0), 'command ok');
    });

    $handle->push_read( chunk => 2, sub {
        is($_[1], pack('n', 32), 'token size ok');
    });

    $handle->push_read( chunk => 32, sub {
        is($_[1], 'd'x32, 'token ok');
    });

    $handle->push_read( chunk => 2, sub {
        my $payload_length = unpack('n', $_[1]);

        $handle->push_read( chunk => $payload_length, sub {
            is(length $_[1], $payload_length, 'payload length ok');
            is($_[1], qq{{"foo":"bar"}}, 'payload ok');
        });

        undef $apns;

        my $t; $t = AnyEvent->timer(
            after => 0.5,
            cb    => sub {
                undef $t;
                is $connect_state, 'disconnected', 'disconnected ok';
                $cv->send;
            },
        );
    });
};

$apns->connect;

$cv->recv;
