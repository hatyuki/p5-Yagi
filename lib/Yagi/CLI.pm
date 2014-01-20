package Yagi::CLI;
use strict;
use warnings;
use feature qw/ say /;
use Caroline;
use Carp ( );
use Encode ( );
use File::Basename ( );
use File::Slurp ( );
use Getopt::Long ( );
use Term::Encoding;
use Term::ReadKey ( );
use Yagi;

sub run
{
    my $class = shift;
    my ($files, $options) = parse_options(@_);

    eval {
        if ($options->{login}) {
            $class->login;
        } else {
            usage( ) if scalar @$files == 0;
            $class->gist($files, $options);
        }
    };
    if ($@) {
        print "Error: $@";
        exit 1;
    }
}

sub parse_options
{
    local @ARGV = @_;
    my $options = +{ };
    my $parser  = Getopt::Long::Parser->new(
        config => [qw/ posix_default no_ignore_case bundling /],
    );

    $parser->getoptions(
        $options,
        'login',
        'filename|f=s@',
        'private|p!',
        'description|d=s',
        'shorten|s',
        'update|u=s',
        'anonymous|a',
        'embed|e',
        'version|v' => sub { version( ) and exit },
        'help|h'    => sub { usage( ) },
    ) or usage( );

    return [ @ARGV ], $options;
}

sub version
{
    my $version = $Yagi::VERSION;
    say "yagi $version on perl $]";
}

sub usage
{
    require Pod::Usage;

    version( ) and say '';
    Pod::Usage::pod2usage( +{
            -input    => __FILE__,
            -verbose  => 99,
            -sections => 'SYNOPSIS|OPTIONS|EXAMPLES',
        },
    );
}

sub login
{
    my $class    = shift;
    my $caroline = Caroline->new;

    say 'Obtaining OAuth2 access_token from github.';

    while (1) {
        my $username = $caroline->readline('GitHub username: ');
        my $password = do {
            print 'GitHub password: ';
            STDOUT->flush;

            Term::ReadKey::ReadMode('noecho');
            chomp(my $line = <STDIN>);
            Term::ReadKey::ReadMode('restore');

            $line;
        };
        say '';

        my $error = Yagi->login($username, $password, sub {
                my $pincode = $caroline->readline('2-factor auth code: ');
                say '';
                return $pincode;
            },
        );

        if ($error) {
            say "Error: $error";
        } else {
            say 'Success! https://github.com/settings/applications';
            last;
        }
    }
}

sub gist
{
    my ($class, $files, $options) = @_;
    $options->{output} = do {
        if ($options->{embed} && $options->{shorten}) {
            Carp::croak '--embed does not make sense with --shorten';
        } elsif ($options->{embed}) {
            'javascript';
        } elsif ($options->{shorten}) {
            'short';
        } else {
            'html'
        }
    };

    my $gists;
    my $idx     = 0;
    my $encoder = Encode::find_encoding(Term::Encoding::get_encoding);
    my $utf8    = Encode::find_encoding('utf8');
    foreach my $file (@$files) {
        my $content  = File::Slurp::read_file($file);
        my $basename = do {
            if (defined $options->{filename}->[$idx]) {
                $options->{filename}->[$idx];
            } else {
                File::Basename::basename($file);
            }
        };

        $basename = $encoder->decode($basename, Encode::FB_CROAK);
        $content  = $utf8->decode($content, Encode::FB_CROAK);
        $gists->{$basename} = $content;
        $idx++;
    }

    if (defined $options->{description}) {
        $options->{description} = $encoder->decode($options->{description}, Encode::FB_CROAK);
    }

    say Yagi->gist($gists, $options);
}

1;

=head1 NAME

  Yagi::CLI - Lets you upload to https://gist.github.com/

=head1 SYNOPSIS

  yagi [Options] File [...]
  yagi --login

=head1 OPTIONS

      --login                      Authenticate gist on this computer.
  -f, --filename [NAME.EXTENSION]  Sets the filename and syntax type.
  -d, --description DESCRIPTION    Adds a description to your gist.
  -u, --update [URL|ID]            Update an existing gist.
  -a, --anonymous                  Create an anonymous gist.
  -p, --private                    Makes your gist private.
      --no-private
  -e, --embed                      Copy the embed code for the gist to the clipboard
  -s, --shorten                    Shorten the gist URL using git.io.
  -h, --help                       Show this message.
  -v, --version                    Print the version.

=head1 EXAMPLES

  yagi --login
  yagi sample.pl
  yagi --description "foo bar" sample.pl sample.rb
  yagi --private sample.py sample.js
  yagi --private --shorten sample.php

=cut
