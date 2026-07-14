#!/usr/bin/env perl
use 5.038;
use strict;
use warnings;
use Benchmark qw(cmpthese);

# Micro-benchmark for scanning primitives used by cleanfeed-ng.  It does not
# load INN, does not make filtering decisions, and is intentionally separate
# from production.  Run it before/after hot-path changes to catch regressions.
my $size = shift(@ARGV) || 8 * 1024 * 1024;
my $text = ("ordinary text line\n" x int($size / 19));
my $limit = 1_048_576;
sub index_scan {
    my ($s,$l)=@_; my $start=0;
    while (1) { my $n=index($s,"\n",$start); return length($s)-$start>$l if $n<0; return 1 if $n-$start>$l; $start=$n+1; }
}
sub split_scan { my ($s,$l)=@_; for my $line (split(/\n/,$s,-1)) { return 1 if length($line)>$l } return 0 }
print "Body bytes: ", length($text), "\n";
cmpthese(-3,{index_scan=>sub{index_scan($text,$limit)},split_scan=>sub{split_scan($text,$limit)}});
