package App::bwk::mn;

# DATE
# VERSION

use 5.010001;
use strict;
use warnings;
use Log::ger;

use IPC::System::Options qw(system readpipe);

our %SPEC;

$SPEC{':package'} = {
    v => 1.1,
    summary => 'Some commands to manage Bulwark masternode',
};

$SPEC{status} = {
    v => 1.1,
    summary => 'bulwark-cli getblockcount + masternode status',
    description => <<'_',

This is mostly just a shortcut for running `bulwark-cli getblockcount` and
`bulwark-cli masternode status`.

_
    args => {
    },
    deps => {
        prog => 'bulwark-cli',
    },
};
sub status {
    my %args = @_;

    system({log=>1}, "bulwark-cli", "getblockcount");
    system({log=>1}, "bulwark-cli", "masternode", "status");
    [200];
}

1;
# ABSTRACT:

=head1 SYNOPSIS

Please see included script L<bwk-mn>.


=head1 SEE ALSO

L<cryp-mn> from L<App::cryp::mn>

Other C<App::cryp::*> modules.
