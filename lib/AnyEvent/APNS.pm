package AnyEvent::APNS;
use utf8;
use Any::Moose;

use AnyEvent 4.80;
use AnyEvent::Handle;
use AnyEvent::Socket;
use AnyEvent::TLS;

require bytes;
use Encode;
use JSON::Any;

our $VERSION = '0.01002';

has certificate => (
    is       => 'rw',
    isa      => 'Str',
    required => 1,
);

has private_key => (
    is       => 'rw',
    isa      => 'Str',
    required => 1,
);

has sandbox => (
    is      => 'rw',
    isa     => 'Bool',
    default => 0,
);

has handler => (
    is  => 'rw',
    isa => 'AnyEvent::Handle',
);

has json_driver => (
    is      => 'rw',
    isa     => 'Object',
    lazy    => 1,
    default => sub {
        JSON::Any->new( utf8 => 1 );
    },
);

has on_error => (
    is      => 'rw',
    isa     => 'CodeRef',
    default => sub { sub { warn @_ } },
);

has on_connect => (
    is      => 'rw',
    isa     => 'CodeRef',
    default => sub { sub {} },
);

no Any::Moose;

sub send {
    my $self = shift;
    my ($token, $payload) = @_;

    my $json = encode_utf8( $self->json_driver->encode($payload) );

    my $h = $self->handler;
    $h->push_write( pack('C', 0) ); # command

    $h->push_write( pack('n', bytes::length($token)) ); # token length
    $h->push_write( $token );                           # device token

    $h->push_write( pack('n', bytes::length($json)) ); # payload length
    $h->push_write( $json );                           # payload
}

sub _error_handler {
    my $self = shift;
    my ($handle, $fatal, $message) = @_;

    $self->on_error(@_);
}

sub connect {
    my $self = shift;

    if ($self->handler) {
        warn 'Already connected!';
        return;
    }

    my $host = $self->sandbox
        ? 'gateway.sandbox.push.apple.com'
        : 'gateway.push.apple.com';

    tcp_connect $host, 2195, sub {
        my ($fh) = @_
            or return $self->on_error($!);

        my $handle = AnyEvent::Handle->new(
            fh       => $fh,
            on_error => sub { $self->_error_handler(@_) },
            tls      => 'connect',
            tls_ctx  => {
                cert_file => $self->certificate,
                key_file  => $self->private_key,
            },
        );
        $self->handler( $handle );

        $self->on_connect->();
    };
}

__PACKAGE__->meta->make_immutable;

__END__

=head1 NAME

AnyEvent::APNS - Simple wrapper for Apple Push Notifications Service (APNS) provider

=head1 SYNOPSIS

    use AnyEvent::APNS;
    
    my $cv = AnyEvent->condvar;
    
    my $apns; $apns = AnyEvent::APNS->new(
        certificate => 'your apns certificate file',
        private_key => 'your apns private key file',
        sandbox     => 1,
        on_error    => sub { # something went wrong },
        on_connect  => sub {
            $apns->send( $device_token => {
                aps => {
                    alert => 'Message received from Bob',
                },
            });
        },
    );
    
    # disconnect and exit program as soon as possible after sending a message
    # otherwise $apns makes persistent connection with apns server
    $apns->handler->on_drain(sub {
        undef $_[0];
        $cv->send;
    });
    
    $cv->recv;

=head1 DESCRIPTION

This module helps you to create Apple Push Notifications Service (APNS) Provider.

=head1 METHODS

=head2 new

Create APNS object and connect to apns service.

    my $apns = AnyEvent::APNS->new(
        certificate => 'your apns certificate file',
        private_key => 'your apns private key file',
        sandbox     => 1,
        on_error    => sub { # something went wrong },
    );

Supported arguments are:

=over 4

=item certificate => 'your apns certificate file'

Required

=item private_key => 'your apns private key file',

Required

=item sandbox => 0|1

This is a flag indicate target service is provisioning (sandbox => 1) or distribution (sandbox => 0)

Optional (Default: 0)

=item on_error => $cb->($handle, $fatal, $message)

Callback to be called when something error occurs.
This is wrapper for L<AnyEvent::Handle>'s on_error callbacks. Look at the document for more detail.

Optional (Default: just warn error)

=item on_connect => $cb->()

Callback to be called when connection established to apns server.

Optional (Default: empty coderef)

=back

=head2 $apns->send( $device_token, \%payload )

Send apns messages with C<\%payload> to device speficied C<$device_token>.

    $apns->send( $device_token => {
        aps => {
            alert => 'Message received from Bob',
        },
    });

C<$device_token> shuould be a binary 32bytes device token provided by iPhone SDK (3.0 or above)

C<\%payload> should be a hashref suitable to apple document: L<http://developer.apple.com/iPhone/library/documentation/NetworkingInternet/Conceptual/RemoteNotificationsPG/ApplePushService/ApplePushService.html>

Note: If you involve multi-byte strings in C<\%payload>, it should be utf8 decoded strings not utf8 bytes.

=head2 $apns->handler

Return L<AnyEvent::Handle> object which is used to current established connection. It returns undef before connection completed.

=head1 TODO

=over 4

=item *

More correct error handling

=item *

Auto recconection

=back

=head1 AUTHOR

Daisuke Murase <typester@cpan.org>

=head1 COPYRIGHT AND LICENSE

Copyright (c) 2009 by KAYAC Inc.

This program is free software; you can redistribute
it and/or modify it under the same terms as Perl itself.

The full text of the license can be found in the
LICENSE file included with this module.

=cut
