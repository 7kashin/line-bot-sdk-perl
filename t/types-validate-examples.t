#!/usr/bin/env perl
use strict;



use FindBin '$Bin';
use File::Spec;
use JSON::XS qw(decode_json);
use Test::More;

use LINE::Bot::API::Types qw<MessageEvent ErrorResponse FollowEvent UnfollowEvent JoinEvent LeaveEvent MemberJoinedEvent MemberLeftEvent>;

sub verify {
    my ($type, $file) = @_;

    $file = File::Spec->join($Bin, 'examples', $file);

    open my $fh, '<', $file;
    my $c = do { local $/; <$fh> };
    close($fh);

    eval {
        my $val = decode_json($c);

        my $error = $type->validate($val);
        if ($error) {
            fail "$type: $file";
            diag $error;
        } else {
            pass "$type: $file";
        }
        1;
    } or do {
        my $err = $_;
        fail "ERROR: $type: $file";
        diag $c;
    };
}

my @tests = (
    [ MemberJoinedEvent, 'member-joined-event.json'],
    [ MemberLeftEvent, 'member-left-event.json'],
    [ LeaveEvent, 'leave-event.json'],
    [ JoinEvent, 'join-event.json'],
    [ UnfollowEvent, 'unfollow-event.json'],
    [ FollowEvent, 'follow-event.json'],
    [ ErrorResponse, 'error-response-1.json'],
    [ MessageEvent, 'text-message-1.json'],
    [ MessageEvent, 'image-message-1.json'],
    [ MessageEvent, 'video-message-1.json'],
    [ MessageEvent, 'audio-message-1.json'],
);

for (@tests){
    verify(@$_);
}
done_testing;
