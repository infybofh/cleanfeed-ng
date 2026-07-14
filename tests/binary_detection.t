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
    sub addhist { return 1 }
    sub cancel { return 1 }
    sub filesfor { return '' }
    sub head { return '' }
}

package main;
our (%hdr, %state, %config);
our $body;

do "$FindBin::Bin/../cleanfeed" or die "Cannot load cleanfeed: $@ $!";

sub classify {
    my (%a) = @_;
    %hdr = (
        Newsgroups => ($a{groups} || 'comp.test'),
        'Content-Type' => ($a{content_type} || ''),
        'Content-Disposition' => ($a{content_disposition} || ''),
        'Content-Transfer-Encoding' => ($a{cte} || ''),
        __BODY__ => ($a{body} || ''),
    );
    %state = (lines => (($hdr{__BODY__} =~ tr/\n//)));
    undef $body;
    return is_binary();
}

ok(classify(body => "=ybegin line=128 size=3 name=a.rar\nabc\n=yend size=3 crc32=00000000\n"),
   'short single-part yEnc detected');
ok(classify(body => "intro\n=ybegin part=1 line=128 size=100 name=a.bin\n=ypart begin=1 end=3\nabc\n=yend size=3 part=1 pcrc32=0\n"),
   'multipart yEnc detected');
ok(classify(body => ("ordinary text\n" x 500) . "=ybegin line=128 size=3 name=late.bin\nabc\n=yend size=3\n"),
   'yEnc marker beyond old 4 kB preview detected');
like(classify(content_type => 'application/octet-stream; name="x.zip"', cte => 'base64', body => "QUJDRA==\n"),
     qr/^MIME binary/, 'short top-level MIME binary detected');
like(classify(content_type => 'multipart/mixed; boundary=x', body => "--x\nContent-Type: application/zip; name=\"x.zip\"\nContent-Transfer-Encoding: base64\n\nQUJDRA==\n--x--\n"),
     qr/^MIME binary part/, 'short multipart MIME binary detected');
is(classify(content_type => 'text/plain', cte => 'base64', body => "SGVsbG8=\n"), 0,
   'base64 text/plain is not classified as binary');
is(classify(body => "This article discusses the literal marker =ybegin in prose.\n"), 0,
   'mere inline mention of ybegin is not a binary');
is(classify(body => "=ybegin is discussed here without attributes or terminator\n"), 0,
   'standalone discussion marker without evidence is not a binary');
ok(classify(body => "begin 644 payload.exe\n" . ("M" . ("A" x 60) . "\n") x 4),
   'uuencode detected');

done_testing();
