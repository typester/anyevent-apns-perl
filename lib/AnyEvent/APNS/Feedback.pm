package AnyEvent::APNS::Feedback;
use utf8;
use Any::Moose;

use AnyEvent 4.80;
use AnyEvent::Handle;
use AnyEvent::Socket;
use AnyEvent::TLS;

has certificate => (
    is       => 'rw',
    isa      => 'Str | ScalarRef',
    required => 1,
);

has private_key => (
    is       => 'rw',
    isa      => 'Str | ScalarRef',
    required => 1,
);

has sandbox => (
    is      => 'rw',
    isa     => 'Bool',
    default => 0,
);

has on_feedback => (
    is      => 'rw',
    isa     => 'CodeRef',
    lazy    => 1,
    default => sub {
        sub {},
    },
);

has on_error => (
    is      => 'rw',
    isa     => 'CodeRef',
    lazy    => 1,
    default => sub {
        sub {
            warn $_[2];
        },
    },
);

has _handle => (
    is        => 'rw',
    isa       => 'AnyEvent::Handle',
    predicate => 'connected',
    clearer   => 'clear_handle',
);

has _con_guard => (
    is  => 'rw',
    isa => 'Object',
);

has _debug_port => (
    is        => 'rw',
    isa       => 'Int',
    predicate => 'is_debug',
);

no Any::Moose;

sub BUILD {
    my ($self) = @_;
    $self->connect;
}

sub connect {
    my ($self) = @_;

    if ($self->connected && $self->handler) {
        warn 'Already connected!';
        return;
    }

    my $host = $self->sandbox
        ? 'feedback.sandbox.push.apple.com'
        : 'feedback.push.apple.com';
    my $port = 2196;

    if ($self->is_debug) {
        $host = '127.0.0.1';
        $port = $self->_debug_port;
    }

    my $g = tcp_connect $host, $port, sub {
        my ($fh) = @_
            or return $self->on_error->(undef, 1, $!);

        my $tls_setting = {};
        if (ref $self->certificate) {
            $tls_setting->{cert}      = ${ $self->certificate };
        }
        else {
            $tls_setting->{cert_file} = $self->certificate;
        }

        if (ref $self->private_key) {
            $tls_setting->{key}       = ${ $self->private_key };
        }
        else {
            $tls_setting->{key_file}  = $self->private_key;
        }

        my $handle = AnyEvent::Handle->new(
            fh       => $fh,
            on_error => sub {
                $self->on_error->(@_);
                $self->clear_handler;
                $_[0]->destroy;

                # reconnect
                $self->connect;
            },
            !$self->is_debug ? (
                tls      => 'connect',
                tls_ctx  => $tls_setting,
            ) : (),
        );
        $self->_handle($handle);

        $handle->on_read(sub {
            $_[0]->push_read( chunk => 4, sub {
                my $ts = unpack 'N', $_[1];

                $_[0]->push_read( chunk => 2, sub {
                    my $len = unpack 'n', $_[1];

                    $_[0]->push_read( chunk => $len, sub {
                        my $token = $_[1];
                        $self->on_feedback->($ts, $token);
                    });
                });
            })
        });
    };

    Scalar::Util::weaken($self);
    $self->_con_guard($g);
}

__PACKAGE__->meta->make_immutable;
