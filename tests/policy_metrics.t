#!/usr/bin/perl
use strict;
use warnings;
use Test::More;
use FindBin;
use File::Temp qw(tempdir);

BEGIN {
    $ENV{CLEANFEED_CONFIG_DIR} = '';
    package INN;
    sub syslog { return 1 }
    sub newsgroup { return '' }
    sub addhist { return 1 }
    sub cancel { return 1 }
    sub filesfor { return '' }
    sub head { return '' }
}

package main;
our (%hdr, %state, %config, %Peer_Policies, %Hierarchy_Policies,
     %policy_rule_count, %policy_peer_count, %policy_hierarchy_count,
     @groups, %status, $now, $Start_Time, %timer);

do "$FindBin::Bin/../cleanfeed" or die "Cannot load cleanfeed: $@ $!";

$config{policy_enabled} = 1;
$config{policy_mode} = 'audit';
$config{policy_default_max_bytes} = 0;
$config{policy_default_allow_binary} = 1;
$config{policy_log_matches} = 0;
$config{metrics_enabled} = 1;
$config{metrics_by_rule} = 1;
$config{metrics_by_peer} = 1;
$config{metrics_by_hierarchy} = 1;
$config{policy_max_peer_counters} = 10;
$config{policy_max_hierarchy_counters} = 10;

%Peer_Policies = (
    '^text-peer\\.example$' => { mode => 'reject', max_bytes => 100, allow_binary => 0 },
);
%Hierarchy_Policies = (
    '^it\\.' => { mode => 'audit', max_bytes => 50, allow_binary => 0 },
    '^it\\.binaries\\.' => { mode => 'off', max_bytes => 0, allow_binary => 1 },
);

$state{peer} = 'text-peer.example';
$state{article_bytes} = 200;
@groups = ('it.test');
%hdr = (Newsgroups => 'it.test', 'Message-ID' => '<x@example>', __BODY__ => 'x' x 200);
my $p = policy_for_article();
is($p->{mode}, 'audit', 'hierarchy policy overrides peer mode');
is($p->{max_bytes}, 50, 'hierarchy max size selected');
is($p->{allow_binary}, 0, 'text hierarchy disallows binary');

@groups = ('it.binaries.test');
$p = policy_for_article();
is($p->{mode}, 'off', 'more specific hierarchy policy applied last');
is($p->{allow_binary}, 1, 'binary hierarchy override allows binary');

is(policy_reason_key('EMP (md5)'), 'emp.md5', 'MD5 rejection categorized');
is(policy_reason_key('UUencoded payload'), 'binary.uuencode', 'uuencode categorized');
is(policy_reason_key('Excessive Supersedes'), 'supersedes', 'Supersedes categorized');

my $dir = tempdir(CLEANUP => 1);
my $status_file = "$dir/status";
$config{metrics_status_file} = $status_file;
$config{metrics_csv_file} = '';
$config{metrics_syslog} = 0;
$status{articles}=10; $status{accepted}=8; $status{rejected}=2;
$now=time; $Start_Time=$now-60;
write_metrics();
ok(-s $status_file, 'atomic key=value status file written');
open my $fh, '<', $status_file or die $!;
my $text = do { local $/; <$fh> };
like($text, qr/^articles=10$/m, 'status contains article count');
like($text, qr/^accepted=8$/m, 'status contains accepted count');

done_testing();
