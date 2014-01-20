package Yagi::Config;
use strict;
use warnings;
use feature qw/ state /;
use File::Spec;
use TOML ( );
use constant CONFIG_FILE => File::Spec->catfile($ENV{HOME}, '.yagirc');

sub config
{
    state $config = load( );
    my ($class, $key, $value) = @_;

    return do {
        if (not defined $key) {
            $config;
        } elsif (not defined $value) {
            $config->{$key}
        } else {
            $config->{$key} = $value;
        }
    };
}

sub load
{
    return +{ } unless -f CONFIG_FILE;

    open my $fh, '<', CONFIG_FILE;
    return TOML::from_toml(do { local $/; <$fh> });
}

sub save
{
    open my $fh, '>', CONFIG_FILE;
    chmod 0600, CONFIG_FILE;
    print $fh TOML::to_toml( config( ) );
}

1;

__END__

=encoding utf-8

=head1 NAME

Yagi::Config - Yet Another Command-Line Interface for Gist

=head1 SYNOPSIS

  use Yagi::Config;

  my $config = Yagi::Config->config;
  my $value  = Yagi::Config->config($key);
  Yagi::Config->config($key, $new_value);
  Yagi::Config->save;  # saved at 

=head1 DESCRIPTION

=head1 METHODS

=head2 B<< Yagi::Config->config([$key :Str[, $value: Any]]) :Hash >>

=head2 B<< Yagi::Config->load( ) :Hash >>

=head2 B<< Yagi::Config->save( ) >>

=head1 LICENSE

Copyright (C) hatyuki.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHOR

hatyuki E<lt>hatyuki29@gmail.comE<gt>

=cut
