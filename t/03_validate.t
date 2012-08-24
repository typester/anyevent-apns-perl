use utf8;
use Test::Base;

use AnyEvent::APNS;

use Test::Exception;
use Test::TCP;

plan tests => 4;

my $port = empty_port;

lives_ok {
    my $apns; $apns = AnyEvent::APNS->new(
        debug_port  => $port,
        certificate => 'dummy',
        private_key => 'dummy',
    );
} 'set certificate and private_key ok';

lives_ok {
    my $apns; $apns = AnyEvent::APNS->new(
        debug_port  => $port,
        certificate_raw => 'dummy',
        private_key_raw => 'dummy',
    );
} 'set certificate_raw and private_key_raw ok';

throws_ok {
    my $apns; $apns = AnyEvent::APNS->new(
        debug_port  => $port,
        private_key => 'dummy',
    );
} qr/required certificate or certificate_raw/
, 'not set both certificate and certificate_raw';

throws_ok {
    my $apns; $apns = AnyEvent::APNS->new(
        debug_port  => $port,
        certificate => 'dummy',
    );
} qr/required private_key or private_key_raw/
, 'not set both private_key and private_key_raw';
