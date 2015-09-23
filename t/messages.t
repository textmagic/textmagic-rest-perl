use strict;
use warnings;

use JSON;
use Net::SMS::TextmagicRest;
use REST::Client;
use Test::MockModule;
use Test::More;

use Data::Dumper;

my $username = 'jessebangs';
my $token = 'S4y9ph4H5r4lcSG6ZFdffKUgWnpkAl';

# Variables capturing data passed into or out of the REST client.
my $injected_json = "{}";
my $injected_code = 200;
my $captured_self = undef;
my $captured_resource = "";
my $captured_data = "";
my $last_method = "";
my $get_called = 0;
my $post_called = 0;

# 
# These are the keys that we expect to be in the outgoing message, with their
# default values. When these values aren't overridden, we expect them to be
# present in the output.
#
my %send_keys = (
    contacts => undef,
    cutExtra => 0,
    dummy => 0,
    from => undef,
    lists => undef, 
    partsCount => undef,
    referenceId => undef,
    rrule => undef,
    sendingTime => undef,
    templateId => undef,
    text => undef,
);

#
# Create our mock REST client; doing this before creating the TextMagic object
# causes our mock definitions to be loaded by TextmagicRest
#
my $mock = Test::MockModule->new('REST::Client');
$mock->mock("GET", sub { ($captured_self, $captured_resource, $captured_data) = @_; $get_called++; });
$mock->mock("POST", sub { ($captured_self, $captured_resource, $captured_data) = @_; $post_called++; });
$mock->mock("buildQuery", sub { return " " . JSON::encode_json($_[1]) if $_[1] && keys %{$_[1]}; });
$mock->mock("responseContent", sub { return $injected_json; });
$mock->mock("responseCode", sub { return $injected_code });

my $tm = Net::SMS::TextmagicRest->new(username => $username, token => $token);

# 
# Test sending a basic message with explicit text
#
my $test_text = "Test message from TextMagic API";
my $test_tel1 = "+15555555555";
my $test_tel2 = "+15555555556";
$injected_code = 200;
$injected_json = JSON::encode_json({ success => "ok" });

my $resp = $tm->send(text => $test_text, phones => [ $test_tel1, $test_tel2 ]);

cmp_ok($post_called, '==', 1, "Should have posted a message");
cmp_ok($captured_resource, 'eq', '/messages', "Should post to /messages");
is_deeply(JSON::decode_json($captured_data), { text => $test_text, phones => "$test_tel1,$test_tel2", dummy => 0, contacts => undef, sendingTime => undef, cutExtra => 0, templateId => undef, partsCount => undef, lists => undef, referenceId => undef, from => undef, rrule => undef }, "Posted data should match arguments passed");
is_deeply($resp, { success => "ok" }, "Response JSON is as expected");

#
# Ensure that all available parameters are successfully passed through to the
# message
#
for my $param (keys %send_keys) {
    $post_called = 0;

    my %params = %send_keys;
    $params{text} = $test_text;
    $params{phones} = [ $test_tel1, $test_tel2 ];
    if ($param =~ /s$/) { # contacts, lists, phones
        $params{phones} = undef;
        $params{$param} = [ 1, 2, 3 ];
    } 
    else {
        $params{$param} = "testval";
    }

    eval {
        my $resp = $tm->send(%params);
    };
    if ($@) {
        fail("Unexpected exception when setting param $param: $@");
    }

    my %validate_params = %params;
    for my $key (keys %validate_params) {
        if (ref $validate_params{$key} eq "ARRAY") {
            $validate_params{$key} = join(",", @{$validate_params{$key}});
        }
    }

    cmp_ok($post_called, '==', 1, "Should have posted a message");
    is_deeply(JSON::decode_json($captured_data), \%validate_params, "Posted data should match arguments passed");
}

# 
# Handling of missing parameters
#

$post_called = 0;
eval {
    $tm->send(phones => [ $test_tel2 ]);
    fail("should throw when neither text nor template is included");
};
cmp_ok($post_called, '==', 0, "Should have posted a message");
like($@, qr/Either text or templateId should be specified/, "expected error message wasn't thrown");

eval {
    $tm->send(text => $test_text);
    fail("should throw when neither phones, lists, or contacts is supplied");
};
cmp_ok($post_called, '==', 0, "Should have posted a message");
like($@, qr/Either phones, contacts or lists should be specified/, "expected error message wasn't thrown");

# 
# Handling of server error responses
#
$injected_json = JSON::encode_json({ message => "test error message" });
$injected_code = 500;

eval {
    $tm->send(text => $test_text, phones => [ $test_tel1 ]);
    fail("should throw when the server returns a non-success error code");
};
cmp_ok($post_called, '==', 1, "Should have posted a message");
like($@, qr/test error message/, "expected error message wasn't thrown");

# 
# getMessage success case
#
my $test_msg = { messageId => 1234, sessionId => 4321 };
$injected_json = JSON::encode_json($test_msg);
$injected_code = 200;

my $msg = $tm->getMessage(1234);
cmp_ok($get_called, '==', 1, "calling getMessage should make a GET call to the server");
cmp_ok($captured_resource, 'eq', '/messages/1234', "getMessages() called to the expected URI");
is_deeply($msg, $test_msg, "the message returned was successfully decoded from JSON");

# 
# getMessage missing parameters
#
eval {
    $get_called = 0;
    $tm->getMessage();
    fail("should throw when no parameter is supplied to getMessage");
};
cmp_ok($get_called, '==', 0, "no call should be made to the server when the required parameter is missing");
like($@, qr/should be numeric/, "expected error message wasn't thrown");

# 
# getMessage server error response
#
$injected_code = 500;
$injected_json = JSON::encode_json({ message => "test error message" });
eval {
    $get_called = 0;
    $tm->getMessage(1234);
    fail("should throw when the server returns an error code");
};
cmp_ok($get_called, '==', 1, "calling getMessage should make a GET call to the server");
like($@, qr/test error message/, "expected error message wasn't thrown");

# 
# getMessages success case
#
my $test_msgs = [{ messageId => 1234, text => "test reply" }, { messageId => 2345, text => "test text" }];
$injected_json = JSON::encode_json($test_msgs);
$injected_code = 200;
$get_called = 0;

# N.B. we've mocked the function which encodes query params to use JSON and
# separate the query params from the base URI with a space. This makes it easier
# for us to validate that query params are present without worrying about
# ordering, etc.

my $msgs = $tm->getMessages();
cmp_ok($get_called, '==', 1, "calling getMessages should make a GET call to the server");
cmp_ok((split /\s/, $captured_resource)[0], 'eq', '/messages', "getMessages() called to the expected URI");
is_deeply(JSON::decode_json((split /\s/, $captured_resource)[1]), { page => 1, limit => 10 }, "default parameters were correctly applied");
is_deeply($msgs, $test_msgs, "the messages returned were successfully decoded from JSON");

$get_called = 0;
$msgs = $tm->getMessages(page => 2, limit => 15);
cmp_ok($get_called, '==', 1, "calling getMessages should make a GET call to the server");
cmp_ok((split /\s/, $captured_resource)[0], 'eq', '/messages', "getMessages() called to the expected URI");
is_deeply(JSON::decode_json((split /\s/, $captured_resource)[1]), { page => 2, limit => 15 }, "explicit parameters were correctly applied");
is_deeply($msgs, $test_msgs, "the messages returned were successfully decoded from JSON");

# 
# getMessages server error response
#
$injected_code = 500;
$injected_json = JSON::encode_json({ message => "test error message" });
eval {
    $tm->getMessages();
    fail("should throw when the server returns an error code");
};
like($@, qr/test error message/, "expected error message wasn't thrown");

# 
# getReply success case
#
my $test_reply = { messageId => 1234, text => "test reply" };
$injected_json = JSON::encode_json($test_reply);
$injected_code = 200;
$get_called = 0;

my $reply = $tm->getReply(1234);
cmp_ok($get_called, '==', 1, "calling getReply should make a GET call to the server");
cmp_ok($captured_resource, 'eq', '/replies/1234', "getReply() called to the expected URI");
is_deeply($reply, $test_reply, "the reply returned was successfully decoded from JSON");

# 
# getReply missing parameters
#
eval {
    $get_called = 0;
    $tm->getReply();
    fail("should throw when no parameter is supplied to getReply");
};
cmp_ok($get_called, '==', 0, "no call should be made to the server when the required parameter is missing");
like($@, qr/should be numeric/, "expected error wasn't thrown");

# 
# getReply server error response
#
$injected_code = 500;
$injected_json = JSON::encode_json({ message => "test error message" });
eval {
    $tm->getReply(1234);
    fail("should throw when the server returns an error code");
};
like($@, qr/test error message/, "expected error message wasn't thrown");

# 
# getReplies success case
#
my $test_replies = [{ messageId => 1234, text => "test reply" }, { messageId => 2345, text => "test text" }];
$injected_json = JSON::encode_json($test_replies);
$injected_code = 200;
$get_called = 0;

my $replies = $tm->getReplies();
cmp_ok($get_called, '==', 1, "calling getReplies should make a GET call to the server");
cmp_ok((split /\s/, $captured_resource)[0], 'eq', '/replies', "getReplies() called to the expected URI");
is_deeply(JSON::decode_json((split /\s/, $captured_resource)[1]), { page => 1, limit => 10 }, "default parameters were correctly applied");
is_deeply($replies, $test_replies, "the messages returned were successfully decoded from JSON");

$get_called = 0;
$replies = $tm->getReplies(page => 2, limit => 15);
cmp_ok($get_called, '==', 1, "calling getReplies should make a GET call to the server");
cmp_ok((split /\s/, $captured_resource)[0], 'eq', '/replies', "getReplies() called to the expected URI");
is_deeply(JSON::decode_json((split /\s/, $captured_resource)[1]), { page => 2, limit => 15 }, "explicit parameters were correctly applied");
is_deeply($replies, $test_replies, "the messages returned were successfully decoded from JSON");

# 
# getReplies server error response
#
$injected_code = 500;
$injected_json = JSON::encode_json({ message => "test error message" });
eval {
    $tm->getReplies();
    fail("should throw when the server returns an error code");
};
like($@, qr/test error message/, "expected error message wasn't thrown");

# 
# getSession success case
#
my $test_session = { sessionId => 4321 };
$injected_json = JSON::encode_json($test_session);
$injected_code = 200;
$get_called = 0;

my $session = $tm->getSession(1234);
cmp_ok($get_called, '==', 1, "calling getSession should make a GET call to the server");
cmp_ok($captured_resource, 'eq', '/sessions/1234', "getSessions() called to the expected URI");
is_deeply($session, $test_session, "the session returned was successfully decoded from JSON");

# 
# getSession missing parameters
#
eval {
    $get_called = 0;
    $tm->getSession();
    fail("should throw when no parameter is supplied to getSession");
};
cmp_ok($get_called, '==', 0, "no call should be made to the server when the required parameter is missing");
like($@, qr/should be numeric/, "expected error message wasn't thrown");

# 
# getSession server error response
#
$injected_code = 500;
$injected_json = JSON::encode_json({ message => "test error message" });
eval {
    $get_called = 0;
    $tm->getSession(1234);
    fail("should throw when the server returns an error code");
};
cmp_ok($get_called, '==', 1, "calling getSession should make a GET call to the server");
like($@, qr/test error message/, "expected error message wasn't thrown");

# 
# getSessions success case
#
my $test_sessions = [{ messageId => 1234, text => "test reply" }, { messageId => 2345, text => "test text" }];
$injected_json = JSON::encode_json($test_sessions);
$injected_code = 200;
$get_called = 0;

my $sessions = $tm->getSessions();
cmp_ok($get_called, '==', 1, "calling getSessions should make a GET call to the server");
cmp_ok((split /\s/, $captured_resource)[0], 'eq', '/sessions', "getSessions() called to the expected URI");
is_deeply(JSON::decode_json((split /\s/, $captured_resource)[1]), { page => 1, limit => 10 }, "default parameters were correctly applied");
is_deeply($sessions, $test_sessions, "the messages returned were successfully decoded from JSON");

$get_called = 0;
$sessions = $tm->getSessions(page => 2, limit => 15);
cmp_ok($get_called, '==', 1, "calling getSessions should make a GET call to the server");
cmp_ok((split /\s/, $captured_resource)[0], 'eq', '/sessions', "getSessions() called to the expected URI");
is_deeply(JSON::decode_json((split /\s/, $captured_resource)[1]), { page => 2, limit => 15 }, "explicit parameters were correctly applied");
is_deeply($sessions, $test_sessions, "the messages returned were successfully decoded from JSON");

# 
# getSessions server error response
#
$injected_code = 500;
$injected_json = JSON::encode_json({ message => "test error message" });
eval {
    $tm->getSessions();
    fail("should throw when the server returns an error code");
};
like($@, qr/test error message/, "expected error message wasn't thrown");

done_testing();
