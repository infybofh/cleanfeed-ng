#!/usr/bin/perl
use strict;
use warnings;
use Test::More;
use FindBin;

BEGIN {
    $ENV{CLEANFEED_CONFIG_DIR} = '';
    package INN;
    sub syslog { return 1 }
    sub newsgroup { return '' }
}
package main;
our (%config, %Restricted_Groups);
do "$FindBin::Bin/../cleanfeed" or die "Cannot load cleanfeed: $@ $!";

get_config();
ok(validate_configuration(), 'shipped configuration validates');

local $config{maxgroups} = -1;
ok(!validate_configuration(), 'negative integer is rejected');

get_config();
local $config{bin_allowed} = '(';
ok(!validate_configuration(), 'invalid regular expression is rejected');

get_config();
local $config{MD5RateCutoff} = 10;
local $config{MD5RateCeiling} = 5;
ok(!validate_configuration(), 'cutoff above ceiling is rejected');

get_config();
local $config{group_class_cache_entries} = 65537;
ok(!validate_configuration(), 'group classification cache is bounded');

get_config();
local $config{group_class_cache_enabled} = 2;
ok(!validate_configuration(), 'group classification cache switch is boolean');

done_testing();
