use strict;
use warnings;
use Test::More;
use Test::TCP;
use AnyEvent::APNS;
use AnyEvent::Socket;

my $port = empty_port;

my $apns; $apns = AnyEvent::APNS->new(
    debug_port  => $port,
    certificate => 'dummy',
    private_key => 'dummy',
    on_error    => sub { die $! },
    on_connect  => sub {
        $apns->send('d' x 32 => { aps => { badge => "110" } });
    },
);

my $cv = AnyEvent->condvar;

tcp_server undef, $port, sub {
    my ($fh) = @_
        or die $!;

    my $handle; $handle = AnyEvent::Handle->new(
        fh       => $fh,
        on_eof   => sub {},
        on_error => sub {
            die $!;
            undef $handle;
        },
        on_read => sub {},
    );

    $handle->push_read( chunk => 43, sub {}); # all before payload

    $handle->push_read( chunk => 2, sub {
        my $payload_length = unpack('n', $_[1]);

        $handle->push_read( chunk => $payload_length, sub {
            my $payload = $_[1];
			is($payload, '{"aps":{"badge":110}}');
			$cv->send;
        });

        undef $apns;
    });
};

$apns->connect;

$cv->recv;

done_testing;
