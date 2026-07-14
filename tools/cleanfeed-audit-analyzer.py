#!/usr/bin/env python3
"""Summarize cleanfeed-ng audit/reject logs without contacting INN.

The tool accepts news.notice files or stdin, recognizes structured
cleanfeed_event lines and legacy rejecting[perl] lines, and prints bounded
counters useful for deciding which audit findings deserve manual review.
"""
from __future__ import annotations
import argparse, collections, re, sys
EVENT=re.compile(r'cleanfeed_event action=(\S+) rule=(\S+)(?: peer=(\S+))?(?: groups=(\S+))?.*?reason="([^"]*)"')
LEGACY=re.compile(r'rejecting\[perl\].*?\s\d+\s+(.+)$')
def lines(paths):
    if not paths:
        yield from sys.stdin
    else:
        for path in paths:
            with open(path,encoding='utf-8',errors='replace') as fh: yield from fh
def main():
    ap=argparse.ArgumentParser(); ap.add_argument('logs',nargs='*'); ap.add_argument('--top',type=int,default=20)
    a=ap.parse_args(); actions=collections.Counter(); rules=collections.Counter(); peers=collections.Counter(); groups=collections.Counter(); reasons=collections.Counter(); legacy=collections.Counter(); total=0
    for line in lines(a.logs):
        m=EVENT.search(line)
        if m:
            total+=1; action,rule,peer,group,reason=m.groups(); actions[action]+=1; rules[rule]+=1; reasons[reason]+=1
            if peer: peers[peer]+=1
            if group:
                for g in group.split(','): groups[g]+=1
            continue
        m=LEGACY.search(line)
        if m: legacy[m.group(1).strip()]+=1
    print(f'structured_events={total}')
    for title,counter in [('actions',actions),('rules',rules),('peers',peers),('groups',groups),('reasons',reasons),('legacy_rejects',legacy)]:
        print(f'\n[{title}]')
        for key,count in counter.most_common(a.top): print(f'{count:10d}  {key}')
if __name__=='__main__': main()
