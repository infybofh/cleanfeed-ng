#!/usr/bin/perl
use strict;
use warnings;
use Test::More;
use FindBin;

my $file = "$FindBin::Bin/../cleanfeed";
open my $fh, '<', $file or die $!;
local $/;
my $source = <$fh>;
close $fh;

my ($block) = $source =~ /%config\s*=\s*\((.*?)\n\s*\);/s;
ok(defined $block, 'default configuration block found');
my %defined = map { $_ => 1 } ($block =~ /^\s*([A-Za-z_][A-Za-z0-9_]*)\s*=>/mg);
my %used = map { $_ => 1 } ($source =~ /\$config\{['"]?([A-Za-z_][A-Za-z0-9_]*)['"]?\}/g);
my @missing = grep { !$defined{$_} && $_ ne 'nobase64' } sort keys %used;
is_deeply(\@missing, [], 'all runtime configuration keys have defaults');

open my $cfh, '<', "$FindBin::Bin/../cleanfeed.local.example" or die $!;
local $/;
my $example = <$cfh>;
close $cfh;
my %example_keys = map { $_ => 1 }
    ($example =~ /^\s*([A-Za-z_][A-Za-z0-9_]*)\s*=>/mg);
my @example_missing = grep { !$example_keys{$_} } sort keys %defined;
is_deeply(\@example_missing, [],
    'canonical example contains every built-in runtime parameter');
ok($example_keys{nobase64},
    'canonical example documents the optional nobase64 override');

ok($defined{fsl_exclude}, 'fsl_exclude is defined');
unlike($source, qr/\$config\{fslexclude\}/, 'obsolete fslexclude typo is absent');

for my $name (qw(
    verbose aggressive block_binaries block_all_binaries do_md5 do_phl do_phn
    do_phr do_fsl do_scoring_filter do_ratio_scoring maxgroups bin_allowed
    bad_bin allexclude fsl_exclude phl_exclude phn_exclude block_mime_html
    block_html block_html_images do_mid_filter do_supersedes_filter
    binary_scan_bytes binary_scan_tail_bytes detect_mime_binaries
    detect_malformed_yenc body_preview_bytes validate_config
)) {
    ok($defined{$name}, "parameter $name is represented in defaults");
}

done_testing();
