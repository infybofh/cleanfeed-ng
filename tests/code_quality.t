#!/usr/bin/perl
use strict;
use warnings;
use Test::More;
use FindBin;

my $path = "$FindBin::Bin/../cleanfeed";
open my $fh, '<', $path or die "Cannot open $path: $!";
local $/;
my $source = <$fh>;
close $fh;

# Track subroutine names per package.  Cleanfeed contains small helper classes
# whose methods may legitimately share names such as add() or init(); only two
# definitions of the same name inside the same package are accidental.
my %seen;
my $package = 'main';
for my $line (split /\n/, $source) {
    $package = $1 if $line =~ /^package\s+([A-Za-z_][A-Za-z0-9_:]*)\s*;/;
    $seen{"$package\::$1"}++
        if $line =~ /^sub\s+([A-Za-z_][A-Za-z0-9_]*)\s*\{/;
}
my @duplicates = sort grep { $seen{$_} > 1 } keys %seen;
is_deeply(\@duplicates, [], 'no duplicate named subroutine definitions within a package');

unlike($source, qr/return\s+reject\([^\n;]*['"]EMP['"]\s*\)/,
    'historical EMP rejects do not use the ambiguous generic EMP rule');
like($source, qr/binary_byte_profile_scope\s*=>\s*['"]policy['"]/,
    'safe policy scope is the built-in byte-profile default');
like($source, qr/sub\s+binary_byte_profile_in_scope\s*\{/,
    'byte-profile scope decision has a dedicated documented helper');
unlike($source, qr/study\s+\$hdr\{__BODY__\}/,
    'obsolete study() call is absent from the article hot path');
like($source, qr/sub\s+group_classification\s*\{/,
    'bounded newsgroup classification cache helper exists');
like($source, qr/Group_Class_Cache_Size\s*>?=\s*\$config\{group_class_cache_entries\}/,
    'group classification cache has an explicit entry bound');

# Generic fallback remains available for third-party local hooks, but all rule
# families known to the maintained tree must have explicit stable mappings.
for my $rule (qw(
    emp.md5 emp.phl emp.phn emp.phr emp.fsl bot.signature html.article
    cancel.rogue distribution.invalid crosspost.topic header.invalid
    yenc.metadata.part_size binary.byte_profile
)) {
    like($source, qr/\Q'$rule'\E/, "stable mapping exists for $rule");
}

done_testing();
