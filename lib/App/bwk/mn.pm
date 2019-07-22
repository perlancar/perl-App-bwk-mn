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

sub _zfs_list_snapshots {
    my %res;
    for (`zfs list -t snapshot -H`) {
        chomp;
        my @row = split /\t/, $_;
        $row[0] =~ m!(.+?)/(.+?)@(.+)!;
        $res{$row[0]} = {
            full_name => $row[0],
            pool => $1,
            fs => $2,
            snapshot_name => $3,
            used => $row[1],
            avail => $row[2],
            refer => $row[3],
            mountpoint => $row[4],
        };
    }
    \%res;
}

$SPEC{restore_from_zfs_snapshot} = {
    v => 1.1,
    summary => 'Restore broken installation from ZFS snapshot',
    description => <<'_',

This subcommand will:

1. stop bulwarkd
2. rollback to a specific ZFS snapshot
3. restart bulwarkd again
4. wait until node is fully sync-ed (not yet implemented)

For this to work, a specific setup is required. First, at least the `blocks/`
and `chainstate` directory are put in a ZFS filesystem (this part is assumed and
not checked) and a snapshot of that filesytem has been made. The ZFS filesystem
needs to have "bulwark" or "bwk" as part of its name, and the snapshot must be
named using YYYY-MM-DD. The most recent snapshot will be selected.

Rationale: as of this writing (2019-07-22, Bulwark version 2.2.0.0) a Bulwark
masternode still from time to time gets corrupted with this message in the
`debug.log`:

    2019-07-22 02:30:17 ERROR: VerifyDB() : *** irrecoverable inconsistency in block data at xxxxxx, hash=xxxxxxxx

(It used to happen more often prior to 2.1.0 release, and less but still happens
from time to time since 2.1.0.)

Resync-ing from scratch will take at least 1-2 hours, and if this happens on
each masternode every few days then resync-ing will waste a lot of time. Thus
the ZFS snapshot. Snapshots will of course need to be created regularly for this
setup to benefit.

_
    args => {
    },
    deps => {
        all => [
            {prog => 'systemctl'},
            {prog => 'bulwark-cli'},
            {prog => 'zfs'},
        ],
    },
};
sub restore_from_zfs_snapshot {
    my %args = @_;

    my $picked_snapshot;
    my $snapshot_date;
  PICK_SNAPSHOT: {
        my $snapshots = _zfs_list_snapshots();
        for my $full_name (keys %$snapshots) {
            unless ($full_name =~ /bwk|bulwark/i) {
                log_trace "Snapshot '$full_name' does not have bwk|bulwark in its name, skipped";
                next;
            }
            my $s = $snapshots->{$full_name};
            unless ($s->{snapshot_name} =~ /\A(\d{4})-(\d{2})-(\d{2})/) {
                log_trace "Snapshot '$full_name' is not named using YYYY-MM-DD format, skipped";
                next;
            }
            if (!$picked_snapshot || $snapshot_date lt $s->{snapshot_name}) {
                $picked_snapshot = $full_name;
                $snapshot_date = $s->{snapshot_name};
            }
        }
        unless ($picked_snapshot) {
            return [412, "Cannot find any suitable ZFS snapshot"];
        }
    }

    system({log=>1, die=>1}, "systemctl", "stop", "bulwarkd");

    system({log=>1, die=>1}, "zfs", "rollback", $picked_snapshot);

    system({log=>1, die=>1}, "systemctl", "start", "bulwarkd");

    # TODO: wait until fully sync-ed

    [200];
}

1;
# ABSTRACT:

=head1 SYNOPSIS

Please see included script L<bwk-mn>.


=head1 SEE ALSO

L<cryp-mn> from L<App::cryp::mn>

Other C<App::cryp::*> modules.
