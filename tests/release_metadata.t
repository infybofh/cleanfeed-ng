#!/usr/bin/perl
use strict; use warnings; use Test::More; use FindBin;
my $root="$FindBin::Bin/..";
open my $vf,'<',"$root/VERSION" or die $!; chomp(my $version=<$vf>); close $vf;
like($version,qr/^\d{4}-\d{2}-\d{2}$/,'version uses YYYY-MM-VV');
open my $cf,'<',"$root/cleanfeed" or die $!; local $/; my $src=<$cf>; close $cf;
like($src,qr/\$cleanfeed_ng_version\s*=\s*'\Q$version\E'/,'runtime version matches VERSION');
unlike($src,qr/'(?:malformed\.encoding|structure\.path|anomaly\.rate|structure\.long_line)'/,'obsolete generic new-check rules are not emitted');
for my $f (qw(README.md README.txt CHANGELOG.md CONTRIBUTING.md SECURITY.md TECHNICAL-REVIEW.md LICENSE)) { ok(-f "$root/$f","$f exists"); }
my $code = $src;
like($code, qr/require\s+5\.038/, 'Perl 5.38 minimum is enforced');
unlike($code, qr/metrics_prometheus_file/, 'Prometheus runtime output is absent');
like($code, qr/sub\s+external_regex_body\b/, 'bounded external regex body helper exists');
like($code, qr/sub\s+line_exceeds_limit\b/, 'constant-memory line scanner exists');

done_testing();
