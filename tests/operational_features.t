#!/usr/bin/perl
use strict; use warnings; use Test::More; use FindBin; use File::Temp qw(tempdir);
BEGIN { $ENV{CLEANFEED_CONFIG_DIR}=''; package INN; sub syslog{1} sub newsgroup{''} sub addhist{1} sub cancel{1} sub filesfor{''} sub head{''} }
package main;
our (%hdr,%state,%config,@groups,%status,$now,$Start_Time,%timer,%Bad_File_Mtime,$Last_Bad_Mtime_Check,$Config_Fingerprint,%Peer_Policies,%Hierarchy_Policies,%gr,%Group_Class_Cache,$Group_Class_Cache_Size);
do "$FindBin::Bin/../cleanfeed" or die "$@ $!";

is(reject_code('binary.yenc'),'CF-BINARY-YENC','stable yEnc code');
is(reject_code('policy.size'),'CF-POLICY-SIZE','stable policy size code');
is(reject_code('yenc.metadata.part_size'),'CF-YENC-PART-SIZE','stable multipart yEnc size code');
is(reject_code('path.hop_count'),'CF-PATH-HOP-COUNT','stable path hop code');
ok(!external_regex_safe('(a+)+$','x'),'nested quantifier rejected');
ok(!external_regex_safe('(?{ die })','x'),'executable regex rejected');
ok(external_regex_safe('^safe-[0-9]+$','x'),'normal regex accepted');

%hdr=(__BODY__=>"x\n",Path=>'a!b!c','Content-Type'=>'multipart/mixed');
$config{malformed_encoding_check}=1;
my @f=encoding_findings();
is($f[0][0],'mime.multipart.boundary_missing','missing MIME boundary has granular rule');
$hdr{'Content-Type'}='text/plain'; delete $state{binary_scan_body}; $hdr{__BODY__}="=ybegin line=128 size=100 name=x.bin\nabc\n";
@f=encoding_findings();
is($f[0][0],'yenc.structure.missing_end','missing yend has granular rule');

delete $state{binary_scan_body};
# In multipart yEnc, =ybegin size is the complete file and =yend size is this part.
$hdr{__BODY__}="=ybegin part=2 total=20 line=128 size=488636416 name=x.bin\n=ypart begin=250001 end=500000\nabc\n=yend size=250000 part=2 pcrc32=12345678\n";
@f=encoding_findings();
is(scalar(@f),0,'valid multipart total/part size difference is not anomalous');
delete $state{binary_scan_body};
$hdr{__BODY__}="=ybegin part=2 total=20 line=128 size=488636416 name=x.bin\n=ypart begin=250001 end=500000\nabc\n=yend size=200000 part=2 pcrc32=12345678\n";
@f=encoding_findings();
is($f[0][0],'yenc.metadata.part_size','multipart part size checked against ypart range');
delete $state{binary_scan_body};
$hdr{__BODY__}="=ybegin line=128 size=250000 name=x.bin\nabc\n=yend size=250000 crc32=12345678\n";
@f=encoding_findings();
is(scalar(@f),0,'valid single-part sizes accepted');

$config{path_sanity_enabled}=1; $config{path_max_hops}=2; $hdr{Path}='a!b!c';
@f=path_sanity_findings();
is($f[0][0],'path.hop_count','excessive path hops have granular rule');
$config{path_max_hops}=100; $config{path_repeat_ceiling}=1; $hdr{Path}='a!b!a';
@f=path_sanity_findings();
is($f[0][0],'path.repeated_token','repeated path token has granular rule');

$config{binary_byte_profile_enabled}=1; $config{binary_ratio_min_bytes}=10; $config{binary_ratio_scan_bytes}=100;
$config{binary_nonprintable_ratio_percent}=10; $config{binary_byte_profile_scope}='all'; $hdr{__BODY__}="\x00"x20 . "a"x20;
@f=byte_profile_findings();
like($f[0][1],qr/nonprintable ratio/,'opaque byte profile detected');

# The recommended policy scope must not flag or reject a legitimate binary
# article when the effective policy explicitly allows binary payloads.
$config{binary_byte_profile_scope}='policy';
$config{policy_default_allow_binary}=1;
%Peer_Policies=(); %Hierarchy_Policies=();
@f=byte_profile_findings();
is(scalar(@f),0,'policy scope skips byte profile when binary is allowed');

# The same opaque body becomes relevant when the effective policy forbids
# binaries.  This proves that reject mode would act only in the intended scope.
$config{policy_default_allow_binary}=0;
@f=byte_profile_findings();
is($f[0][0],'binary.byte_profile','policy scope profiles body when binary is forbidden');

# Historical EMP reasons must remain precisely classified even when an old
# local hook still uses the text classifier instead of an explicit rule.
is(policy_reason_key('EMP (md5)'),'emp.md5','legacy MD5 reason is not other');
is(policy_reason_key('EMP (phl)'),'emp.phl','legacy PHL reason is not other');
is(policy_reason_key('EMP (phn)'),'emp.phn','legacy PHN reason is not other');
is(policy_reason_key('EMP (phr)'),'emp.phr','legacy PHR reason is not other');
is(policy_reason_key('EMP (fsl)'),'emp.fsl','legacy FSL reason is not other');

# Representative historical reasons must have stable categories.  These tests
# protect against future reordering that would collapse precise findings into
# rule=other or an unrelated broad category.
my %historical_reason_rules = (
    'Bot signature'              => 'bot.signature',
    'HTML'                       => 'html.article',
    'Rogue cancel'               => 'cancel.rogue',
    'Invalid Header'             => 'header.invalid',
    'Bad site'                   => 'site.path',
    'Bad Reply-To'               => 'header.reply_to',
    'Bad Sender'                 => 'header.sender',
    'U2 violation'               => 'distribution.invalid',
    'Topic Filter'               => 'crosspost.topic',
    'Too many newsgroups'        => 'crosspost',
    'Scoring filter'             => 'scoring',
    'Bad control message'        => 'control.invalid',
);
for my $reason (sort keys %historical_reason_rules) {
    is(policy_reason_key($reason), $historical_reason_rules{$reason},
        "historical reason '$reason' has a stable rule");
}

$config{top_offenders_enabled}=1; $config{top_offenders_max_keys}=10; $config{top_offenders_limit}=3;
$state{peer}='peer.example'; $state{posting_host}='host.example'; @groups=('it.test');
record_top_offender('x'); my @lines; append_top_metrics(\@lines);
like(join("\n",@lines),qr/top_reject_peer_1=peer.example,1/,'top peer metric emitted');


# External body regexes historically matched a lowercase representation.  The
# bounded 2026 scan must preserve that behavior, otherwise a lowercase sample
# rule silently stops matching uppercase or mixed-case spam text.
$config{external_regex_body_bytes}=65536;
$config{nobase64}=0;
%hdr=(__BODY__=>'Buy CIALIS now; cheap Cialis',
     'Content-Type'=>'text/plain; charset=UTF-8',
     'Content-Transfer-Encoding'=>'8bit');
%state=();
like(external_regex_body(), qr/cialis/, 'external regex body is normalized to lowercase');
my $case_rule=qr/(cialis)/i;
like(external_regex_body(), $case_rule, 'bad_body-style rule matches mixed-case body');

# Textual Base64 articles were decoded before administrator bad_body/bad_url
# checks in historical Cleanfeed.  Preserve that security behavior while still
# bounding and caching the decoded prefix.
require MIME::Base64;
my $decoded_text='Visit https://spam.example/path and BUY CIALIS now';
%hdr=(__BODY__=>MIME::Base64::encode_base64($decoded_text),
     'Content-Type'=>'text/plain; charset=UTF-8',
     'Content-Transfer-Encoding'=>'base64');
%state=();
like(external_regex_body(), qr/spam\.example/, 'external regex body decodes text/plain Base64 URLs');
like(external_regex_body(), qr/buy cialis/, 'decoded Base64 text is lowercased for bad_body compatibility');
my $cached=external_regex_body();
is($cached, $state{external_regex_body}, 'normalized external body is cached per article');


# Compare the cached bitmask against the historical per-regex semantics for
# representative group names before testing cache mechanics.
sub historical_group_mask {
    my ($group)=@_;
    local $_=$group;
    my $mask=0;
    $mask |= GC_BINARY()    if $config{bin_allowed} and /$config{bin_allowed}/;
    $mask |= GC_IMAGE()     if $config{image_allowed} and /$config{image_allowed}/;
    $mask |= GC_BAD_BIN()   if $config{bad_bin} and /$config{bad_bin}/;
    $mask |= GC_HTML()      if $config{html_allowed} and /$config{html_allowed}/;
    $mask |= GC_MIME_HTML() if $config{mime_html_allowed} and /$config{mime_html_allowed}/;
    $mask |= GC_POISON()    if $config{poison_groups} and /$config{poison_groups}/;
    $mask |= GC_REPORTS()   if $config{spam_report_groups} and /$config{spam_report_groups}/;
    $mask |= GC_NO_CANCEL() if $config{no_cancel_groups} and /$config{no_cancel_groups}/;
    $mask |= GC_TEST()      if /$config{test_groups}/;
    $mask |= GC_ADULT()     if /$config{adult_groups}/ and not /$config{not_adult_groups}/;
    $mask |= GC_FAQ()       if /$config{faq_groups}/;
    $mask |= GC_RATIO()     if /$config{ratio_exclude}/;
    $mask |= GC_APPROVED()  if /$config{local_approved_groups}/;
    $mask |= GC_SKIP()      if $config{allexclude} and /$config{allexclude}/;
    $mask |= GC_FSLSKIP()   if $config{fsl_exclude} and /$config{fsl_exclude}/;
    $mask |= GC_MD5SKIP()   if $config{md5exclude} and /$config{md5exclude}/;
    $mask |= GC_PHNSKIP()   if $config{phn_exclude} and /$config{phn_exclude}/;
    $mask |= GC_PHLSKIP()   if $config{phl_exclude} and /$config{phl_exclude}/;
    $mask |= GC_SCORESKIP() if $config{score_exclude} and /$config{score_exclude}/;
    $mask |= GC_PHRINC()    if $config{flood_groups} and /$config{flood_groups}/;
    $mask |= GC_LOW_XPOST() if $config{low_xpost_groups} and /$config{low_xpost_groups}/;
    $mask |= GC_MEOW()      if $config{meow_groups} and /$config{meow_groups}/;
    $mask |= GC_TOPIC1()    if $config{topic1_groups} and /$config{topic1_groups}/;
    $mask |= GC_TOPIC2()    if $config{topic2_groups} and /$config{topic2_groups}/;
    $mask |= GC_LOCALHIER() if /^local\./;
    return $mask;
}
for my $group (qw(
    alt.binaries.test
    news.admin.net-abuse.test
    soc.sexual.abuse
    fr.misc.bavardages.dinosaures
    local.example
    misc.jobs
    alt.fan.karl-malden.nose
)) {
    is(classify_group_uncached($group),historical_group_mask($group),
       "cached mask preserves historical classification for $group");
}

# The group cache stores only deterministic regex classifications. Repeated
# groups must hit the cache without growing it; disabling and bounds must remain
# predictable and light.
$config{group_class_cache_enabled}=1;
$config{group_class_cache_entries}=2;
clear_group_class_cache();
my $group_mask=group_classification('alt.binaries.test');
ok($group_mask & GC_BINARY(), 'binary-group classification bit is set');
ok($group_mask & GC_TEST(), 'test-group classification bit is set');
is($Group_Class_Cache_Size,1,'first group classification populates one cache entry');
is(group_classification('alt.binaries.test'),$group_mask,'repeated group returns identical cached mask');
is($Group_Class_Cache_Size,1,'cache hit does not grow the cache');
group_classification('news.admin.net-abuse.test');
is($Group_Class_Cache_Size,2,'second distinct group reaches configured cache bound');
group_classification('local.example');
is($Group_Class_Cache_Size,1,'next miss clears the bounded cache before insertion');
ok(!exists $Group_Class_Cache{'alt.binaries.test'},'full-clear policy removes the previous generation');
ok(group_classification('local.example') & GC_LOCALHIER(),'local hierarchy bit survives cached classification');
clear_group_class_cache();
$config{group_class_cache_enabled}=0;
group_primary_classification('alt.binaries.test');
group_followup_classification('alt.binaries.test');
is($Group_Class_Cache_Size,0,'disabled group cache stores no entries');
$config{group_class_cache_enabled}=1;
$config{group_class_cache_entries}=8192;
clear_group_class_cache();
group_classification('x' x 256);
is($Group_Class_Cache_Size,0,'oversized group name is classified but not cached');

done_testing();
