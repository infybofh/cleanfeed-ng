#!/usr/bin/env perl
use strict;
use warnings;
use Getopt::Long qw(GetOptions);
use Digest::SHA qw(sha256_hex);
use File::Spec;

my ($config_dir,$check,$dump,$article,$help) = ('',0,0,'',0);
GetOptions(
  'config-dir=s' => \$config_dir,
  'check-config' => \$check,
  'dump-rules'   => \$dump,
  'test-article=s' => \$article,
  'help' => \$help,
) or usage(2);
usage(0) if $help || (!$check && !$dump && !$article);
$config_dir ||= $ENV{CLEANFEED_CONFIG_DIR} || '/usr/local/news/cleanfeed/etc';

my @files = qw(bad_paths bad_cancel_paths bad_adult_paths bad_hosts bad_hosts_central
               bad_from bad_subject bad_body bad_url bad_url_central trusted_paths
               trusted_hosts trusted_from trusted_message_ids);
my @errors; my @warnings; my %summary;
my $local = File::Spec->catfile($config_dir,'cleanfeed.local');
if (-f $local) {
  my $txt = slurp($local); $summary{'cleanfeed.local'} = line_count($txt);
  push @errors, "cleanfeed.local contains executable regex code" if $txt =~ /\(\?\??\{/;
  my $ok = system($^X,'-c',$local); push @errors, 'cleanfeed.local failed perl -c' if $ok != 0;
} else { push @warnings, "cleanfeed.local not found at $local"; }

for my $f (@files) {
  my $p=File::Spec->catfile($config_dir,$f); next unless -e $p;
  my @rules = rules_from($p); $summary{$f}=scalar @rules;
  for my $r (@rules) {
    push @errors, "$f contains executable regex code" if $r =~ /\(\?\??\{/;
    push @warnings, "$f contains a very long rule (".length($r)." chars)" if length($r)>4096;
    my $ok=eval { qr/$r/; 1 }; push @errors, "$f invalid regex '$r': $@" unless $ok;
  }
}

if ($check) {
  print "Configuration directory: $config_dir\n";
  print "Result: ",(@errors?'ERROR':'OK'),"\n";
  print "Files/rules:\n"; print "  $_: $summary{$_}\n" for sort keys %summary;
  print "Warnings:\n  $_\n" for @warnings;
  print "Errors:\n  $_\n" for @errors;
  exit(@errors?1:0) unless $dump || $article;
}
if ($dump) {
  print "Rule inventory and SHA-256 fingerprints:\n";
  for my $f ('cleanfeed.local',@files) {
    my $p=File::Spec->catfile($config_dir,$f); next unless -f $p;
    my $txt=slurp($p); printf "%-24s rules=%-6d sha256=%s\n",$f,($summary{$f}//line_count($txt)),sha256_hex($txt);
  }
}
if ($article) {
  my $raw=slurp($article); my ($head,$body)=split(/\r?\n\r?\n/,$raw,2); $body//=q{};
  my %h; my $last=''; for my $l(split(/\r?\n/,$head||'')){ if($l=~/^[ \t]/&&$last){$h{$last}.=' '.$l;next} if($l=~/^([^:]+):\s*(.*)$/){$last=$1;$h{$last}=$2;} }
  my @m;
  push @m,'CF-BINARY-YENC' if $body =~ /(?:^|\n)\s*=ybegin\b/i;
  push @m,'CF-BINARY-UUENCODE' if $body =~ /(?:^|\n)begin\s+[0-7]{3}\s+\S+/i;
  push @m,'CF-BINARY-MIME' if ($h{'Content-Type'}||'') =~ m{^(?:application|audio|video|image|model|font)/}i;
  push @m,'CF-MALFORMED-ENCODING' if ($h{'Content-Type'}||'') =~ /^multipart\//i && ($h{'Content-Type'}||'') !~ /boundary\s*=/i;
  my $max=0; for(split(/\n/,$body,-1)){ $max=length($_) if length($_)>$max; } push @m,'CF-LONG-LINE' if $max>1048576;
  my @path=split(/!/,$h{Path}||'',-1); push @m,'CF-PATH-SANITY' if @path>100 || grep { $_ eq '' || length($_)>255 } @path;
  print "Article: $article\nResult: ",(@m?'MATCH':'NO LIGHTWEIGHT MATCH'),"\n";
  print "Matches:\n  $_\n" for @m;
  print "Note: this standalone command exercises lightweight structural signatures; the authoritative result is produced by cleanfeed inside INN with the complete configuration and history state.\n";
}
exit(@errors?1:0);
sub rules_from { my($p)=@_; my @r; open my $fh,'<',$p or return; while(<$fh>){s/#.*//;s/^\s+|\s+$//g;next unless length;push @r,split(/\s+/);}close$fh;return @r; }
sub slurp { my($p)=@_; open my $fh,'<',$p or die "$p: $!\n"; local $/; my $x=<$fh>;close$fh;return$x; }
sub line_count { my($x)=@_; my @l=grep { /\S/ && !/^\s*#/ } split(/\n/,$x); return scalar@l; }
sub usage { my($e)=@_; print <<'EOF';
Usage:
  cleanfeed-admin.pl --config-dir DIR --check-config
  cleanfeed-admin.pl --config-dir DIR --dump-rules
  cleanfeed-admin.pl --config-dir DIR --test-article ARTICLE
Options may be combined. The tool never modifies the configuration or INN spool.
EOF
exit$e; }
