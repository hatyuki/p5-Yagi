# NAME

Yagi - Yet Another Command-Line Interface for Gist

# SYNOPSIS

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

# SEE ALSO

[Yagi::CLI](https://metacpan.org/pod/Yagi::CLI)

# LICENSE

Copyright (C) hatyuki.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

# AUTHOR

hatyuki <hatyuki29@gmail.com>
