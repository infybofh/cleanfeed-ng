#!/usr/bin/perl
use strict;
use warnings;
use Test::More;
use FindBin;
use File::Temp qw(tempdir);

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

    package INN::Config;
    our $dontrejectfiltered = 0;
    $INC{'INN/Config.pm'} = __FILE__;
}

package main;
our (@Captured_Syslog, %hdr, %state, %config, %Peer_Policies,
     %Hierarchy_Policies, %policy_rule_count, %policy_peer_count,
     %policy_hierarchy_count, @groups, @followups, %status, %timer,
     $MIDhistory, $MID_History_Reinit_Logged, $Runtime_Banner_Logged,
     $INN_Dontrejectfiltered, $Study_Max_Lines_Configured,
     $Local_Config_Loaded, $Local_Conf_Err,
     $Last_Trim, $Last_Stats, $Last_Bad_Mtime_Check, $Last_Metrics_CSV,
     $Do_Log, $now, $Start_Time, $Cleanfeed_Bootstrap_OK,
     $Cleanfeed_Bootstrap_Error, $Cleanfeed_Bootstrap_Error_Logged,
     %Prepared_Output_Directory, %Output_Path_Warning_Logged);

do "$FindBin::Bin/../cleanfeed"
    or die "Cannot load cleanfeed: " . ($@ || $!);

# Redirect all newly enabled default outputs to a temporary tree.  This keeps
# the test independent of host permissions while exercising automatic path
# preparation exactly as the production runtime banner does.
my $output_tmp = tempdir(CLEANUP => 1);
$config{statfile} = "$output_tmp/www/cleanfeed.stat";
$config{html_statfile} = "$output_tmp/www/cleanfeed.html";
$config{inn_syslog_status} = 1;
$config{metrics_enabled} = 1;
$config{metrics_status_file} = "$output_tmp/log/cleanfeed.status";
$config{metrics_csv_file} = "$output_tmp/log/cleanfeed-statistics.csv";
$config{metrics_csv_interval} = 0;
$config{debug_batch_directory} = "$output_tmp/spool/cleanfeed";
$config{debug_batch_size} = 10485760;
%Prepared_Output_Directory = ();
%Output_Path_Warning_Logged = ();

# The runtime banner and deferred study() warning must be emitted only once
# after INN's syslog callback is available.
@Captured_Syslog = ();
$Runtime_Banner_Logged = 0;
$Study_Max_Lines_Configured = 1;
$Local_Config_Loaded = 1;
$Local_Conf_Err = 0;
$INN::Config::dontrejectfiltered = 1;
$INN_Dontrejectfiltered = detect_inn_dontrejectfiltered();
log_runtime_banner();
log_runtime_banner();
my @runtime = grep { $_->[1] =~ /^cleanfeed-ng runtime\b/ } @Captured_Syslog;
my @deprecated = grep { $_->[1] =~ /^Deprecated option study_max_lines\b/ }
    @Captured_Syslog;
my @dontreject_warning = grep { $_->[1] =~ /WARNING dontrejectfiltered=true/ }
    @Captured_Syslog;
is(scalar @runtime, 1, 'runtime banner is logged once');
is(scalar @deprecated, 1, 'study_max_lines warning is deferred and logged once');
like($runtime[0][1], qr/\bperl=v?5\./,
    'runtime banner reports the interpreter version used by the filter');
like($runtime[0][1], qr/\binitialization=ok\b/,
    'runtime banner confirms completed initialization');
like($runtime[0][1], qr/\bdontrejectfiltered=1\b/,
    'runtime banner exposes effective INN dontrejectfiltered state');
is(scalar @dontreject_warning, 1,
    'enabled dontrejectfiltered produces one explicit warning per load');
ok(-f $config{statfile}, 'runtime preparation creates legacy statistics file');
ok(-f $config{html_statfile}, 'runtime preparation creates HTML statistics file');
ok(-f $config{metrics_status_file}, 'runtime preparation creates metrics status file');
ok(-f $config{metrics_csv_file}, 'runtime preparation creates metrics CSV file');
ok(-d $config{debug_batch_directory}, 'runtime preparation creates debug batch directory');
$INN::Config::dontrejectfiltered = 0;
$INN_Dontrejectfiltered = detect_inn_dontrejectfiltered();

# A broken configured path must produce one actionable complaint, not one line
# per article or per periodic statistics run.
{
    my $blocker = "$output_tmp/not-a-directory";
    open my $blocker_fh, '>', $blocker or die "Cannot create $blocker: $!";
    print {$blocker_fh} "blocker\n";
    close $blocker_fh;

    @Captured_Syslog = ();
    ok(!ensure_output_directory("$blocker/subdir", 'test output', 0750),
        'directory preparation rejects a regular-file parent');
    ok(!ensure_output_directory("$blocker/subdir", 'test output', 0750),
        'repeated directory preparation remains safely disabled');
    is(scalar grep({ $_->[1] =~ /Cannot create test output directory/ } @Captured_Syslog), 1,
        'unusable output path is reported exactly once');
}

# A surviving filter_art() from an earlier successful load must fail open and
# log once when a later reload leaves the bootstrap state incomplete.
@Captured_Syslog = ();
$Cleanfeed_Bootstrap_OK = 0;
$Cleanfeed_Bootstrap_Error = 'cleanfeed-ng initialization failed: simulated';
$Cleanfeed_Bootstrap_Error_Logged = 0;
$MIDhistory = undef;
is(filter_art(), '', 'incomplete bootstrap bypasses filtering without dying');
is(filter_art(), '', 'repeated incomplete-bootstrap call still fails open');
is(scalar grep({ $_->[1] =~ /initialization failed: simulated/ }
        @Captured_Syslog), 1, 'incomplete bootstrap is logged exactly once');
is(scalar grep({ $_->[1] =~ /MID history queue was unexpectedly undefined/ }
        @Captured_Syslog), 0, 'MID recovery does not run before initialization succeeds');
$Cleanfeed_Bootstrap_OK = 1;
$Cleanfeed_Bootstrap_Error = '';
$Cleanfeed_Bootstrap_Error_Logged = 0;
ensure_mid_history();

# Exercise the minimum-version bootstrap guard under the current interpreter by
# raising only the temporary copy's required version.  The test runs outside
# innd, so the fallback remains visible on stderr instead of touching syslog.
{
    my $tmpdir = tempdir(CLEANUP => 1);
    my $source = "$FindBin::Bin/../cleanfeed";
    my $copy = "$tmpdir/cleanfeed-too-new";
    open my $in, '<', $source or die "Cannot read $source: $!";
    local $/;
    my $text = <$in>;
    close $in;
    my $old_guard = 'if ($] < 5.038) {';
    my $new_guard = 'if ($] < 99.999) {';
    my $guard_pos = index($text, $old_guard);
    die 'Cannot locate bootstrap version guard in temporary source'
        if $guard_pos < 0;
    substr($text, $guard_pos, length($old_guard), $new_guard);
    $text =~ s/require 5\.038;/require 5.000;/;
    open my $out, '>', $copy or die "Cannot write $copy: $!";
    print {$out} $text;
    close $out;

    my $output = qx{$^X "$copy" 2>&1};
    my $exit = $?;
    isnt($exit, 0, 'unsupported-Perl bootstrap guard aborts loading');
    like($output, qr/Perl 5\.38\.0 or newer is required/,
        'unsupported-Perl bootstrap guard reports the required version');
    like($output, qr/filter not loaded/,
        'unsupported-Perl bootstrap guard clearly reports filter refusal');
}

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

# Statistics generated during reload must use their own current timestamp.
# Historically writestats() reused the article-path global $now, producing an
# empty generated_epoch and a very large negative uptime before the next article.
{
    $Start_Time = time - 120;
    $now = undef;
    $Last_Metrics_CSV = 0;
    $config{timer_info} = 1;
    $config{metrics_enabled} = 1;
    $config{metrics_status_file} = "$output_tmp/log/cleanfeed.status";
    $config{metrics_csv_file} = "$output_tmp/log/cleanfeed-statistics.csv";
    $config{metrics_csv_interval} = 0;
    $config{html_statfile} = "$output_tmp/www/cleanfeed.html";
    $config{statfile} = "$output_tmp/www/cleanfeed.stat";
    $config{inn_syslog_status} = 1;

    ok(eval { writestats(1); 1 },
        'reload-time statistics do not depend on article-path $now');

    open my $status_fh, '<', $config{metrics_status_file}
        or die "Cannot read $config{metrics_status_file}: $!";
    my $status_text = do { local $/; <$status_fh> };
    close $status_fh;
    like($status_text, qr/^generated_epoch=\d+$/m,
        'metrics snapshot contains a numeric generated_epoch');
    like($status_text, qr/^uptime_seconds=\d+$/m,
        'metrics snapshot contains a non-negative uptime');
    like($status_text, qr/^inn_dontrejectfiltered=0$/m,
        'metrics snapshot exposes effective dontrejectfiltered state');
    unlike($status_text, qr/^uptime_seconds=-/m,
        'metrics snapshot never reports a negative uptime');

    open my $stat_fh, '<', $config{statfile}
        or die "Cannot read $config{statfile}: $!";
    my $stat_text = do { local $/; <$stat_fh> };
    close $stat_fh;
    like($stat_text, qr/^Uptime: \d+ seconds$/m,
        'legacy stat file contains a numeric non-negative uptime');
    unlike($stat_text, qr/^Uptime: -/m,
        'legacy stat file never reports a negative uptime');

    open my $html_fh, '<', $config{html_statfile}
        or die "Cannot read $config{html_statfile}: $!";
    my $html_text = do { local $/; <$html_fh> };
    close $html_fh;
    like($html_text, qr/uptime\s+\d+ seconds/i,
        'HTML report contains a numeric non-negative uptime');

    ok(eval { checkrotate("$output_tmp/spool/cleanfeed/not-yet-created"); 1 },
        'debug rotation tolerates a batch file that does not yet exist');
}

is(policy_reason_key('Binary Image: misplaced jpg'), 'binary.image',
    'legacy binary-image prose maps to the stable binary.image rule');
is(reject_code('binary.image'), 'CF-BINARY-IMAGE',
    'binary.image has a dedicated stable rejection code');

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
my $accepted_before_exclude = $status{accepted} || 0;
my $articles_before_exclude = $status{articles} || 0;
%hdr = test_article_headers('linux.debian.changes.devel', '<linux-only@example>');
is(filter_art(), '', 'linux-only binary-looking article preserves historical allexclude bypass');
is($status{accepted}, $accepted_before_exclude + 1,
    'fully excluded article is counted as accepted');
is($status{articles}, $articles_before_exclude + 1,
    'fully excluded article remains counted in total articles');
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
