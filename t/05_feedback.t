use strict;
use warnings;
use Test::More;
use Test::TCP;

use AnyEvent;
use AnyEvent::Socket;
use AnyEvent::Handle;

use AnyEvent::APNS::Feedback;

my $port = empty_port;

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
            delete $_[0]->{rbuf};
        },
    );

    # timestamp
    my $token1 = 'foobar';
    my $token2 = 'hogefuga';

    $handle->push_write(pack 'N', 1234);
    $handle->push_write(pack 'n', length $token1);
    $handle->push_write($token1);

    $handle->push_write(pack 'N', 5678);
    $handle->push_write(pack 'n', length $token2);
    $handle->push_write($token2);
};

my $count = 0;
my $feedback; $feedback = AnyEvent::APNS::Feedback->new(
    _debug_port  => $port,
    certificate => 'dummy',
    private_key => 'dummy',
    on_feedback => sub {
        my ($timestamp, $token) = @_;

        $count++;

        if (1 == $count) {
            is $timestamp, 1234, 'timestamp1 ok';
            is $token, 'foobar', 'token1 ok';
        }
        elsif (2 == $count) {
            is $timestamp, 5678, 'timestamp2 ok';
            is $token, 'hogefuga', 'token2 ok';

            undef $feedback;

            my $t; $t = AnyEvent->timer(
                after => 0.5,
                cb    => sub {
                    undef $t;
                    $cv->send;
                },
            );
        }
    },
);

$cv->recv;

is $connect_state, 'disconnected', 'disconnected ok';
is $count, 2, 'feedback count ok';


done_testing;
