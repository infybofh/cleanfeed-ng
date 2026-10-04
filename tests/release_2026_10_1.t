#!/usr/bin/perl
use strict;
use warnings;
use Test::More;
use FindBin;
use File::Temp qw(tempdir);

BEGIN {
    $ENV{CLEANFEED_CONFIG_DIR} = '';
    package INN;
    sub syslog { push @main::Captured_Syslog, [ @_ ]; return 1 }
    sub newsgroup { return '' }
    sub addhist { return 1 }
    sub cancel { return 1 }
    sub filesfor { return '' }
    sub head { return '' }
}

package main;
our (@Captured_Syslog, %hdr, %state, %config, @groups, @followups, %status,
     %timer, $Start_Time, $Last_Metrics_CSV, $Runtime_Banner_Logged,
     $Study_Max_Lines_Configured, $Local_Config_Loaded, $Local_Conf_Err,
     $INN_Dontrejectfiltered, %policy_rule_count, %policy_peer_count,
     %policy_hierarchy_count, $Config_Fingerprint, $cleanfeed_ng_version);

do "$FindBin::Bin/../cleanfeed"
    or die "Cannot load cleanfeed: " . ($@ || $!);

is($cleanfeed_ng_version, '2026.10.1', 'runtime uses the October 2026 CalVer release');

# Jesse Rehmer regression: union classifications must not be subtracted from
# fupcnt.  Newsgroups can contain meow/topic groups that are absent from an
# explicit Followup-To target set.
get_config();
$config{group_class_cache_enabled} = 0;
$config{meow_groups} = '^alt\\.flame$';
$config{topic1_groups} = '^comp\\.topic1$';
$config{topic2_groups} = '^comp\\.topic2$';

my @effective_followups = ('comp.followups');
my $fc = followup_policy_counts(\@effective_followups);
is($fc->{meow}, 0, 'Newsgroups-only meow match is not counted as a followup meow target');
is($fc->{topic1}, 0, 'Newsgroups-only topic1 match is not counted as a followup topic1 target');
is($fc->{topic2}, 0, 'Newsgroups-only topic2 match is not counted as a followup topic2 target');
is(scalar(@effective_followups) - $fc->{meow}, 1,
    'off-meow followup arithmetic cannot become zero from a Newsgroups-only match');

@effective_followups = ('alt.flame', 'comp.topic1', 'comp.other');
$fc = followup_policy_counts(\@effective_followups);
is($fc->{meow}, 1, 'followup meow target is counted from the followup set');
is($fc->{topic1}, 1, 'followup topic1 target is counted from the followup set');
is(scalar(@effective_followups) - $fc->{meow}, 2,
    'meow external-target arithmetic uses like-for-like followup counts');
is(scalar(@effective_followups) - $fc->{topic1}, 2,
    'topic external-target arithmetic uses like-for-like followup counts');

# Julien Elie regression: the first runtime banner after load/reload must force
# current-version output files immediately, including a CSV boundary row and a
# consistent set of active warnings.
my $dir = tempdir(CLEANUP => 1);
get_config();
$config{statfile} = "$dir/cleanfeed.stats";
$config{html_statfile} = "$dir/cleanfeed.html";
$config{metrics_enabled} = 1;
$config{metrics_status_file} = "$dir/cleanfeed.status";
$config{metrics_csv_file} = "$dir/cleanfeed.csv";
$config{metrics_csv_interval} = 3600;
$config{metrics_syslog} = 0;
$config{inn_syslog_status} = 1;
$config{phn_aggressive} = 1;
$config{debug_batch_directory} = '';
$INN_Dontrejectfiltered = '1';
$Local_Conf_Err = 0;
$Local_Config_Loaded = 1;
$Study_Max_Lines_Configured = 0;
$Runtime_Banner_Logged = 0;
$Start_Time = time - 10;
$Last_Metrics_CSV = time; # force path must ignore the normal interval
%status = (articles => 1, accepted => 1, rejected => 0, refused => 0,
           audited => 0, quarantined => 0);
%timer = ();
%policy_rule_count = (); %policy_peer_count = (); %policy_hierarchy_count = ();
$Config_Fingerprint = '';
@Captured_Syslog = ();

log_runtime_banner();

for my $file (qw(cleanfeed.stats cleanfeed.html cleanfeed.status cleanfeed.csv)) {
    ok(-s "$dir/$file", "$file is published immediately at runtime initialization");
}

open my $sf, '<', "$dir/cleanfeed.status" or die $!;
my $status_text = do { local $/; <$sf> };
close $sf;
like($status_text, qr/^cleanfeed_version=2026\.10\.1$/m,
    'key/value status immediately reports the running version');
like($status_text, qr/^runtime_warning_phn_aggressive=1$/m,
    'key/value status exposes phn_aggressive warning');
like($status_text, qr/^runtime_warning_dontrejectfiltered=1$/m,
    'key/value status exposes dontrejectfiltered warning');

open my $hf, '<', "$dir/cleanfeed.html" or die $!;
my $html = do { local $/; <$hf> };
close $hf;
like($html, qr/cleanfeed-ng 2026\.10\.1/, 'HTML status immediately reports the running version');
like($html, qr/phn_aggressive=1 enables legacy PHN rejection/, 'HTML contains phn_aggressive warning');
like($html, qr/dontrejectfiltered is enabled/, 'HTML contains dontrejectfiltered warning');

open my $cf, '<', "$dir/cleanfeed.csv" or die $!;
my @csv = <$cf>;
close $cf;
is(scalar(@csv), 2, 'forced startup/reload snapshot writes CSV header and one data row');

is(scalar grep({ $_->[1] =~ /^WARNING / } @Captured_Syslog), 2,
    'runtime warning source produces the two active generic WARNING lines');

# RFC 5536/5537 diag-match regression carried into this release.
$config{path_sanity_enabled} = 1;
$config{path_max_hops} = 100;
$config{path_max_token_bytes} = 255;
$config{path_repeat_ceiling} = 3;
$hdr{Path} = 'fontana.bofh.team!news.bofh.team!nnrp.usenet.blueworldhosting.com!!news.usenet.blueworldhosting.com!spool1.usenet.blueworldhosting.com!injection-bsd1!not-for-mail';
my @findings = path_sanity_findings();
ok(!grep($_->[0] eq 'path.empty_token', @findings),
    'RFC diag-match double bang remains valid in 2026.10.1');

done_testing();
