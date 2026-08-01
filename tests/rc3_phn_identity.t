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
our (@Captured_Syslog, %hdr, %state, %config, @groups, %status,
     %policy_rule_count, %policy_peer_count, %policy_hierarchy_count,
     $PHNhistory, $Runtime_Banner_Logged, $Study_Max_Lines_Configured,
     $Local_Config_Loaded, $Local_Conf_Err, $INN_Dontrejectfiltered,
     %Prepared_Output_Directory, %Output_Path_Warning_Logged);

do "$FindBin::Bin/../cleanfeed"
    or die "Cannot load cleanfeed: " . ($@ || $!);

is($config{phn_aggressive}, 0,
    'shipped phn_aggressive default disables shared-injector rejection');
is($config{phn_weak_identity_mode}, 1,
    'shipped weak identity mode retains shared-injector auditing');

sub reset_phn {
    my ($cutoff) = @_;
    $cutoff = 1 unless defined $cutoff;

    get_config();
    $config{PHNRateCutoff} = $cutoff;
    $config{PHNRateCeiling} = 20;
    $config{PHNRateBaseInterval} = 1800;
    $config{phn_aggressive} = 0;
    $config{phn_weak_identity_mode} = 1;
    $config{phn_exempt} = '^localhost$|^127\.0\.0\.1$';
    $config{bad_nph_hosts} = 'newsguy\.com|tornevall\.net';
    $config{policy_log_matches} = 1;
    $config{policy_include_peer} = 1;
    $config{policy_include_groups} = 1;
    $config{policy_include_message_id} = 1;
    $config{metrics_enabled} = 1;
    $config{metrics_by_rule} = 1;
    $config{metrics_by_peer} = 1;
    $config{metrics_by_hierarchy} = 1;
    $config{policy_max_peer_counters} = 100;
    $config{policy_max_hierarchy_counters} = 100;
    $config{block_late_cancels} = 0;
    $config{verbose} = 1;

    $PHNhistory = Cleanfeed::RateLimit->new();
    $PHNhistory->init($config{PHNRateCutoff}, $config{PHNRateCeiling},
        $config{PHNRateBaseInterval});

    %hdr = (
        'Injection-Info' => '',
        'NNTP-Posting-Host' => '',
        'Message-ID' => '<initial@example.invalid>',
        Path => 'inject.example!.POSTED!not-for-mail',
    );
    %state = (
        injection_host => 'inject.example',
        peer => 'inject.example',
    );
    @groups = ('fr.soc.politique');
    %status = (audited => 0, rejected => 0);
    %policy_rule_count = ();
    %policy_peer_count = ();
    %policy_hierarchy_count = ();
    @Captured_Syslog = ();
}

sub set_metadata {
    my (%args) = @_;
    $hdr{'Injection-Info'} = $args{injection_info} // '';
    $hdr{'NNTP-Posting-Host'} = $args{nntp_posting_host} // '';
    $hdr{Path} = $args{path} // 'inject.example!.POSTED!not-for-mail';
    $hdr{'Message-ID'} = $args{message_id} // '<test@example.invalid>';
    $state{injection_host} = $args{injection_host} // 'inject.example';
    $state{peer} = $state{injection_host};
    populate_posting_identity_state();
}

# Injection-Info parsing accepts folded fields and preserves opaque account case.
reset_phn();
set_metadata(
    injection_host => 'news.usenet.ovh',
    injection_info => "news.usenet.ovh;\r\n\tposting-account=\"Alice-Case\"; posting-host=192.0.2.10",
);
is($state{posting_account}, 'Alice-Case',
    'folded Injection-Info posting-account is parsed without lowercasing');
is($state{posting_host}, '192.0.2.10',
    'Injection-Info posting-host is parsed');
is($state{posting_host_source}, 'injection_posting_host',
    'posting-host source is recorded');
my (undef, $source, $strength) = phn_identity_for_article();
is($source, 'posting_account', 'posting-account has priority over posting-host');
is($strength, 'strong', 'posting-account is a strong PHN identity');

# Two accounts behind one public injector must never share a reject counter.
reset_phn(1);
set_metadata(
    injection_host => 'news.usenet.ovh',
    injection_info => 'news.usenet.ovh; posting-account="secret-user"',
    message_id => '<alice$1@news.usenet.ovh>',
);
my ($alice_key) = phn_identity_for_article();
my $alice_hash = phn_identity_hash($alice_key);
is(apply_phn_filter('fr.soc.politique'), '', 'first article from account alice passes');
ok(!exists $state{phn_identity_hash},
    'correlation hashing is deferred until a PHN event is emitted');

set_metadata(
    injection_host => 'news.usenet.ovh',
    injection_info => 'news.usenet.ovh; posting-account="bob"',
    message_id => '<bob$1@news.usenet.ovh>',
);
my ($bob_key) = phn_identity_for_article();
my $bob_hash = phn_identity_hash($bob_key);
is(apply_phn_filter('fr.soc.politique'), '',
    'first article from account bob does not inherit alice counter');
isnt($alice_hash, $bob_hash, 'different posting accounts have different correlation hashes');

set_metadata(
    injection_host => 'news.usenet.ovh',
    injection_info => 'news.usenet.ovh; posting-account="secret-user"',
    message_id => '<alice$2@news.usenet.ovh>',
);
like(apply_phn_filter('fr.soc.politique'), qr/^\[CF-EMP-PHN\]/,
    'second article from the same account crosses the test cutoff');
is($status{rejected}, 1, 'strong-identity PHN increments reject count');
my ($account_event) = map { $_->[1] }
    grep { $_->[1] =~ /^cleanfeed_event action=reject rule=emp\.phn\b/ }
    @Captured_Syslog;
like($account_event, qr/\bidentity_source=posting_account\b/,
    'PHN reject logs posting_account source');
like($account_event, qr/\bidentity_strength=strong\b/,
    'PHN reject logs strong identity');
like($account_event, qr/\bcount=2\b.*\bcutoff=1\b/,
    'PHN reject logs current count and cutoff');
like($account_event, qr/\bmessage_id=<alice\$2\@news\.usenet\.ovh>/,
    'structured event preserves an exact copyable Message-ID');
unlike($account_event, qr/secret-user/,
    'raw posting-account is not disclosed in the event');

# The legacy NNTP-Posting-Host remains a usable strong identity, including
# opaque hash-like values such as the value emitted by tcpreset.net.
reset_phn(0);
set_metadata(
    injection_host => 'news.tcpreset.net',
    injection_info => 'news.tcpreset.net; logging-data="3216074"',
    nntp_posting_host => 'c3066ed76bae8bcc0e476efb157ff758',
    path => 'upstream!news.tcpreset.net!.POSTED!not-for-mail',
    message_id => '<1zv7fm41hf.fsf@tilde.institute>',
);
like(apply_phn_filter('aioe.test'), qr/^\[CF-EMP-PHN\]/,
    'NNTP-Posting-Host can enforce PHN when no account is present');
is($state{phn_identity_source}, 'nntp_posting_host',
    'legacy header source is identified in state');

# A .POSTED.<source> Path token is the next strong fallback.  A bare .POSTED
# marker is intentionally not treated as a poster identity.
reset_phn(0);
set_metadata(
    injection_host => 'inject.example',
    path => 'upstream!inject.example!.POSTED.198.51.100.44!not-for-mail',
    message_id => '<path-source@example.invalid>',
);
like(apply_phn_filter('example.discussion'), qr/^\[CF-EMP-PHN\]/,
    'Path .POSTED source can enforce PHN');
is($state{phn_identity_source}, 'path_posted_source',
    'Path source is logged with its own identity type');
is(path_posted_source('inject.example!.POSTED!not-for-mail'), '',
    'bare .POSTED marker is not a per-poster identity');

# bad_nph_hosts invalidates host metadata, but an account remains strong.
reset_phn(0);
set_metadata(
    injection_host => 'reader.newsguy.com',
    injection_info => 'reader.newsguy.com; posting-account="real-account"; posting-host="unlinkable"',
    message_id => '<bad-nph-account@example.invalid>',
);
like(apply_phn_filter('example.discussion'), qr/^\[CF-EMP-PHN\]/,
    'posting-account remains usable for a bad_nph_hosts injector');
is($state{phn_identity_source}, 'posting_account',
    'account takes priority over unlinkable host metadata');

# With no per-poster metadata, the shipped defaults audit the shared injector
# rather than rejecting unrelated users.
reset_phn(1);
set_metadata(
    injection_host => 'public.example',
    injection_info => 'public.example; logging-data="one"',
    path => 'upstream!public.example!.POSTED!not-for-mail',
    message_id => '<weak$1@public.example>',
);
is(apply_phn_filter('example.discussion'), '', 'first weak-identity article passes');
$hdr{'Message-ID'} = '<weak$2@public.example>';
is(apply_phn_filter('example.discussion'), '',
    'weak shared-injector threshold is audit-only by default');
is($status{rejected}, 0, 'weak default does not reject');
is($status{audited}, 1, 'weak default increments audited count');
my ($weak_event) = map { $_->[1] }
    grep { $_->[1] =~ /^cleanfeed_event action=audit rule=emp\.phn\b/ }
    @Captured_Syslog;
like($weak_event, qr/\bidentity_source=shared_injector\b/,
    'weak event identifies shared injector fallback');
like($weak_event, qr/\bidentity_strength=weak\b/,
    'weak event is explicitly marked weak');

# Explicit legacy aggressive mode still rejects the same weak key.
reset_phn(1);
$config{phn_aggressive} = 1;
set_metadata(
    injection_host => 'legacy.example',
    injection_info => 'legacy.example; logging-data="one"',
    path => 'upstream!legacy.example!.POSTED!not-for-mail',
);
is(apply_phn_filter('example.discussion'), '', 'legacy weak counter starts below cutoff');
like(apply_phn_filter('example.discussion'), qr/^\[CF-EMP-PHN\]/,
    'phn_aggressive=1 restores legacy weak-identity rejection');

# Both switches off means the weak key is not even retained.
reset_phn(1);
$config{phn_aggressive} = 0;
$config{phn_weak_identity_mode} = 0;
set_metadata(
    injection_host => 'disabled.example',
    injection_info => 'disabled.example; logging-data="one"',
);
is(apply_phn_filter('example.discussion'), '', 'disabled weak mode passes first article');
is(apply_phn_filter('example.discussion'), '', 'disabled weak mode passes later article');
is($PHNhistory->count(), 0, 'disabled weak mode stores no shared-injector counter');

# phn_exempt applies to both the selected identity and its injector namespace.
reset_phn(0);
$config{phn_exempt} = '^exempt\.example$';
set_metadata(
    injection_host => 'exempt.example',
    injection_info => 'exempt.example; posting-account="alice"',
);
is(apply_phn_filter('example.discussion'), '', 'exempt injector bypasses PHN');
is($PHNhistory->count(), 0, 'exempt identity is not counted');

# Structured logging no longer runs header values through the 120-byte metrics
# sanitizer.  This protects direct article retrieval and long crosspost review.
reset_phn(1);
my $long_groups = join(',', map { 'example.very-long-newsgroup-name-' . $_ } 1..8);
@groups = split(/,/, $long_groups);
$hdr{'Message-ID'} = '<Mixed_Case$123@News.Example>';
$state{phn_identity_source} = 'shared_injector';
$state{phn_identity_strength} = 'weak';
$state{phn_identity_hash} = '0123456789abcdef';
$state{phn_count} = 2;
policy_log_event('audit', 'emp.phn', 'reason with "quotes" and \\ slash');
my $log = $Captured_Syslog[-1][1];
ok(index($log, 'message_id=<Mixed_Case$123@News.Example>') >= 0,
    'Message-ID punctuation and case are preserved');
ok(index($log, 'groups=' . $long_groups) >= 0,
    'complete group list is preserved beyond 120 bytes');
like($log, qr/reason="reason with \\"quotes\\" and \\\\ slash"/,
    'quoted reason escapes quotes and backslashes');

# New option is validated as a boolean and appears in the runtime banner.
get_config();
$config{phn_weak_identity_mode} = 2;
ok(!validate_configuration(), 'phn_weak_identity_mode rejects non-boolean values');
get_config();
@Captured_Syslog = ();
$Runtime_Banner_Logged = 0;
$Study_Max_Lines_Configured = 0;
$Local_Config_Loaded = 0;
$Local_Conf_Err = 0;
$INN_Dontrejectfiltered = '0';
$config{statfile} = '';
$config{html_statfile} = '';
$config{metrics_status_file} = '';
$config{metrics_csv_file} = '';
$config{debug_batch_directory} = '';
log_runtime_banner();
my ($banner) = map { $_->[1] }
    grep { $_->[1] =~ /^cleanfeed-ng runtime\b/ } @Captured_Syslog;
like($banner, qr/\bphn_aggressive=0\b/, 'runtime banner reports safe PHN default');
like($banner, qr/\bphn_weak_identity_mode=1\b/,
    'runtime banner reports weak-identity audit switch');

# Explicit aggressive mode emits an actionable warning once per runtime banner.
@Captured_Syslog = ();
$Runtime_Banner_Logged = 0;
$config{phn_aggressive} = 1;
log_runtime_banner();
is(scalar grep({ $_->[1] =~ /WARNING phn_aggressive=1/ } @Captured_Syslog), 1,
    'legacy weak reject mode emits one startup warning');

done_testing();
