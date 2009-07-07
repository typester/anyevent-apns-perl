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

our $VERSION = '0.01';

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

no Any::Moose;

sub BUILD {
    my ($self) = @_;
    $self->_connect;
}

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

sub _connect {
    my $self = shift;

    undef $self->handler;

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
    };
}

__PACKAGE__->meta->make_immutable;

__END__

=head1 NAME

AnyEvent::APNS - Module abstract (<= 44 characters) goes here

=head1 SYNOPSIS

    use AnyEvent::APNS;
    
    my $cv = AnyEvent->condvar;
    
    my $apns = AnyEvent::APNS->new(
        certificate => 'your apns certificate file',
        private_key => 'your apsn private key file',
        sandbox     => 1,
    );
    
    $apns->send( $device_token => {
        aps => {
            alert => 'Message received from Bob',
        },
    });
    
    # disconnect and exit program as soon as possible after sending a message
    # otherwise $apns makes persistent connection with apns server
    $apns->handler->on_drain(sub {
        undef $_[0];
        $cv->send;
    });
    
    $cv->recv;

=head1 DESCRIPTION

Stub documentation for this module was created by ExtUtils::ModuleMaker.
It looks like the author of the extension was negligent enough
to leave the stub unedited.

Blah blah blah.

=head1 AUTHOR

Daisuke Murase <typester@cpan.org>

=head1 COPYRIGHT AND LICENSE

Copyright (c) 2009 by KAYAC Inc.

This program is free software; you can redistribute
it and/or modify it under the same terms as Perl itself.

The full text of the license can be found in the
LICENSE file included with this module.

=cut
