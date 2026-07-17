#!/usr/bin/perl
use strict;
use warnings;
use Test::More;
use FindBin;

BEGIN {
    $ENV{CLEANFEED_CONFIG_DIR} = '';
    package INN;
    sub syslog {
        push @main::Captured_Syslog, [ @_ ];
        return 1;
    }
    sub newsgroup { return '' }
    sub addhist   { return 1 }
    sub cancel    { return 1 }
    sub filesfor  { return '' }
    sub head      { return '' }
}

package main;
our (@Captured_Syslog, %hdr, %state, %config, %Peer_Policies,
     %Hierarchy_Policies, %policy_rule_count, %policy_peer_count,
     %policy_hierarchy_count, @groups, @followups, %status, %timer,
     $MIDhistory, $MID_History_Reinit_Logged, $Runtime_Banner_Logged,
     $Study_Max_Lines_Configured, $Local_Config_Loaded, $Local_Conf_Err,
     $Last_Trim, $Last_Stats, $Last_Bad_Mtime_Check, $Do_Log, $now,
     $Start_Time);

do "$FindBin::Bin/../cleanfeed"
    or die "Cannot load cleanfeed: " . ($@ || $!);

# The runtime banner and deferred study() warning must be emitted only once
# after INN's syslog callback is available.
@Captured_Syslog = ();
$Runtime_Banner_Logged = 0;
$Study_Max_Lines_Configured = 1;
$Local_Config_Loaded = 1;
$Local_Conf_Err = 0;
log_runtime_banner();
log_runtime_banner();
my @runtime = grep { $_->[1] =~ /^cleanfeed-ng runtime\b/ } @Captured_Syslog;
my @deprecated = grep { $_->[1] =~ /^Deprecated option study_max_lines\b/ }
    @Captured_Syslog;
is(scalar @runtime, 1, 'runtime banner is logged once');
is(scalar @deprecated, 1, 'study_max_lines warning is deferred and logged once');

# A missing MID history queue must be recoverable and must never make trim or
# statistics processing terminate the embedded Perl filter.
@Captured_Syslog = ();
$MIDhistory = undef;
$MID_History_Reinit_Logged = 0;
my $mid = ensure_mid_history();
isa_ok($mid, 'Cleanfeed::Queue', 'missing MID history is reinitialized');
is(scalar grep({ $_->[1] =~ /MID history queue was unexpectedly undefined/ }
        @Captured_Syslog), 1, 'MID history recovery is logged once');
ensure_mid_history();
is(scalar grep({ $_->[1] =~ /MID history queue was unexpectedly undefined/ }
        @Captured_Syslog), 1, 'repeated MID checks do not repeat recovery log');

$MIDhistory = undef;
$Do_Log = 0;
$now = time;
ok(eval { trimhashes(); 1 }, 'trimhashes tolerates an undefined MID history');
$config{timer_info} = 0;
$config{metrics_enabled} = 0;
$config{html_statfile} = '';
$config{statfile} = '';
$config{inn_syslog_status} = 1;
ok(eval { writestats(1); 1 }, 'writestats tolerates an undefined MID history');
ensure_mid_history();

# Configure a deterministic policy test.  All new lightweight guards are off so
# the result demonstrates allexclude ordering and policy logging only.
$config{allexclude} = '^mailing\\.|^linux\\.';
$config{group_class_cache_enabled} = 1;
$config{group_class_cache_entries} = 8192;
$config{policy_enabled} = 1;
$config{policy_mode} = 'reject';
$config{policy_default_max_bytes} = 0;
$config{policy_default_allow_binary} = 0;
$config{policy_log_matches} = 1;
$config{policy_log_accepts} = 0;
$config{policy_include_message_id} = 1;
$config{policy_include_peer} = 1;
$config{policy_include_groups} = 1;
$config{metrics_enabled} = 1;
$config{metrics_by_rule} = 1;
$config{metrics_by_peer} = 1;
$config{metrics_by_hierarchy} = 1;
$config{long_line_mode} = 'off';
$config{malformed_encoding_check} = 0;
$config{binary_byte_profile_enabled} = 0;
$config{path_sanity_enabled} = 0;
$config{anomaly_rate_enabled} = 0;
$config{block_late_cancels} = 0;
$config{timer_info} = 0;
%Peer_Policies = ();
%Hierarchy_Policies = ();
%policy_rule_count = ();
%policy_peer_count = ();
%policy_hierarchy_count = ();
clear_group_class_cache();
$Runtime_Banner_Logged = 1;
$Study_Max_Lines_Configured = 0;
$Last_Trim = $Last_Stats = $now = time;

sub test_article_headers {
    my ($newsgroups, $message_id) = @_;
    return (
        __BODY__ => "=ybegin line=128 size=4 name=test.bin\nabcd\n=yend size=4\n",
        __LINES__ => 3,
        'Content-Transfer-Encoding' => '8bit',
        'Content-Type' => 'text/plain; charset=UTF-8',
        'Injection-Info' => '',
        'X-Trace' => '',
        Path => 'news.example!not-for-mail',
        Newsgroups => $newsgroups,
        'Followup-To' => '',
        'Message-ID' => $message_id,
        'NNTP-Posting-Host' => '',
        From => 'tester@example.invalid',
        Subject => 'test article',
    );
}

@Captured_Syslog = ();
%hdr = test_article_headers('linux.debian.changes.devel', '<linux-only@example>');
is(filter_art(), '', 'linux-only binary-looking article preserves historical allexclude bypass');
is(scalar grep({ $_->[1] =~ /^cleanfeed_event action=reject\b/ }
        @Captured_Syslog), 0, 'fully excluded hierarchy emits no reject event');

@Captured_Syslog = ();
%hdr = test_article_headers(
    'linux.debian.changes.devel,alt.test',
    '<linux-crosspost@example>',
);
my $result = filter_art();
like($result, qr/^\[CF-POLICY-BINARY\]/,
    'crosspost outside excluded hierarchy remains subject to binary policy');
my @reject_events = grep { $_->[1] =~ /^cleanfeed_event action=reject\b/ }
    @Captured_Syslog;
is(scalar @reject_events, 1, 'policy reject emits exactly one structured event');
like($reject_events[0][1], qr/\brule=policy\.binary\b/,
    'policy reject retains explicit policy.binary rule');
unlike($reject_events[0][1], qr/\brule=other\b/,
    'policy reject no longer produces duplicate rule=other event');
is($policy_rule_count{'policy.binary'}, 1,
    'policy.binary metrics counter is incremented exactly once');

# Direct helper coverage for Followup-To semantics.
ok(article_is_fully_excluded(['linux.debian.changes.devel', 'linux.kernel']),
    'all excluded Newsgroups/Followup-To targets bypass filtering');
ok(!article_is_fully_excluded(['linux.debian.changes.devel', 'alt.test']),
    'one non-excluded target disables the bypass');

done_testing();
