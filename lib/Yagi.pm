package Yagi 0.0001;
use 5.014004;
use strict;
use warnings;
use Carp ( );
use Furl;
use JSON ( );
use MIME::Base64 ( );
use Sub::Retry qw/ retry /;
use URI::Escape ( );
use Yagi::Config;
use constant +{
    GITHUB_API_URL => 'https://api.github.com',
    GIT_IO_URL     => 'http://git.io',
    USER_AGENT     => "yagi/$Yagi::VERSION",
};

sub login
{
    my ($class, $username, $password, $pincode) = @_;
    my $url     = GITHUB_API_URL . '/authorizations';
    my $base64  = MIME::Base64::encode_base64("${username}:${password}");
    my $headers = [
        'Content-Type'  => 'application/json',
        'Authorization' => "Basic $base64",
    ];
    my $content = JSON::encode_json( +{
            scopes   => ['gist'],
            note     => 'Yet Another Gist Module',
            note_url => 'https://github.com/hatyuki/Yagi',
        },
    );

    my $response = http(POST => $url, $headers, $content);

    if ($response->status == 401 && $response->header('X-GitHub-OTP')) {
        $pincode = $pincode->( ) if ref $pincode eq 'CODE';
        push @$headers, ('X-GitHub-OTP' => $pincode);
        $response = http(POST => $url, $headers, $content);
    }

    if ($response->is_success) {
        my $json = JSON::decode_json($response->body);
        Yagi::Config->config(token => $json->{token});
        Yagi::Config->save;
        return;
    } elsif ($response->status == 401) {
        my $json = JSON::decode_json($response->body);
        return $json->{message};
    } else {
        Carp::croak(sprintf 'Got %s from gist: %s', $response->message, $response->body);
    }
}

sub gist
{
    my ($class, $gists, $options) = @_;

    my $json   = +{
        description => $options->{description} || '',
        public      => do {
            if (defined $options->{private}) {
                $options->{private} ? JSON::false : JSON::true;
            } else {
                my $private = Yagi::Config->config('private');
                defined $private ? ($private =~ m/^yes$/i ? JSON::false : JSON::true) : JSON::true;
            }
        },
    };

    while (my ($name, $content) = each %$gists) {
        $json->{files}->{$name} = +{ content => $content };
    }

    my $url = GITHUB_API_URL . '/gists';
    if (my $update = (split m|/|, ($options->{update} || ''))[-1]) {
        $url .= '/' . URI::Escape::uri_escape($update);
    }

    unless ($options->{anonymous}) {
        my $token = $options->{token} || Yagi::Config->config('token') || '';
        $url .= '?access_token=' . URI::Escape::uri_escape($token);
    }

    my $headers = ['Content-Type' => 'application/json'];
    my $content = JSON::encode_json($json);

    retry 2, 0, sub {
        my $response = http(POST => $url, $headers, $content);

        if ($response->is_success) {
            return on_success($response->body, $options);
        }

        Carp::croak(sprintf 'Got %s from gist: %s', $response->message, $response->body);
    };
}

sub on_success
{
    my ($body, $options) = @_;
    my $json   = JSON::decode_json($body);
    my $url    = $json->{html_url};
    my $output = $options->{output};

    return do {
        if ($output eq 'javascript') {
            sprintf qq|<script src="${url}.js"></script>|;
        } elsif ($output eq 'html') {
            $url;
        } elsif ($output eq 'short') {
            shorten($url);
        } else {
            $json;
        }
    };
}

sub shorten
{
    my $url = shift;
    my $response = http(POST => GIT_IO_URL, [ ], +{ url => $url });

    return do {
        if ($response->is_success) {
            $response->header('Location');
        } else {
            $url;
        }
    }
}

sub http
{
    my ($method, $url, $headers, $content) = @_;
    return user_agent( )->request(
        method  => uc $method,
        url     => $url,
        headers => $headers,
        content => $content,
    );
}

sub user_agent
{
    return Furl->new(
        agent   => USER_AGENT,
        timeout => 10,
        %{ Yagi::Config->config('user-agent') },
    );
}

1;

__END__

=encoding utf-8

=head1 NAME

Yagi - Yet Another Command-Line Interface for Gist

=head1 SYNOPSIS

  use Yagi;
  
  if (my $error = Yagi->login($username, $password, $pincode)) {
      die $error;
  }
  
  my $files = +{
      'README.mkd' => '...',
      'Yagi.pm'    => '...',
      ...
  };
  my $url = Yagi->gist($files, $options);

=head1 SEE ALSO

L<Yagi::CLI>

=head1 LICENSE

Copyright (C) hatyuki.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHOR

hatyuki E<lt>hatyuki29@gmail.comE<gt>

=cut
