use strict;
use warnings;

use JSON;
use Net::SMS::TextmagicRest;
use REST::Client;
use Test::MockModule;
use Test::More;

# 
# This file contains tests for send and getSessionMessages. Most of the other
# messaging tests are in crud.t
#

# Variables capturing data passed into or out of the REST client.
my $injected_json = "{}";
my $injected_code = 200;
my $captured_self = undef;
my $captured_resource = "";
my $captured_data = "";
my %called = (
    GET => 0,
    POST => 0,
);

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
$mock->mock("GET", sub { ($captured_self, $captured_resource, $captured_data) = @_; $called{GET}++; });
$mock->mock("POST", sub { ($captured_self, $captured_resource, $captured_data) = @_; $called{POST}++; });
$mock->mock("buildQuery", sub { return " " . JSON::encode_json($_[1]) if $_[1] && keys %{$_[1]}; });
$mock->mock("responseContent", sub { return $injected_json; });
$mock->mock("responseCode", sub { return $injected_code });

my $tm = Net::SMS::TextmagicRest->new(username => "testusername", token => "testtoken");

# 
# Test sending a basic message with explicit text
#
my $test_text = "Test_message_from_TextMagic_API";
my $test_tel1 = "+15555555555";
my $test_tel2 = "+15555555556";
$injected_code = 200;
$injected_json = JSON::encode_json({ success => "ok" });

my $resp = $tm->send(text => $test_text, phones => [ $test_tel1, $test_tel2 ]);

cmp_ok($called{POST}, '==', 1, "Should have posted a message");
cmp_ok($captured_resource, 'eq', '/messages', "Should post to /messages");
is_deeply(JSON::decode_json($captured_data), { text => $test_text, phones => "$test_tel1,$test_tel2", contacts => undef, sendingTime => undef, cutExtra => 0, templateId => undef, partsCount => undef, lists => undef, referenceId => undef, from => undef, rrule => undef }, "Posted data should match arguments passed");
is_deeply($resp, { success => "ok" }, "Response JSON is as expected");

#
# Ensure that all available parameters are successfully passed through to the
# message
#
for my $param (keys %send_keys) {
    $called{POST} = 0;

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

    cmp_ok($called{POST}, '==', 1, "Should have posted a message");
    is_deeply(JSON::decode_json($captured_data), \%validate_params, "Posted data should match arguments passed");
}

# 
# Handling of missing parameters
#

eval {
    $called{POST} = 0;
    $tm->send(phones => [ $test_tel2 ]);
    fail("should throw when neither text nor template is included");
};
cmp_ok($called{POST}, '==', 0, "Should have posted a message");
like($@, qr/Either text or templateId should be specified/, "expected error message wasn't thrown");

eval {
    $tm->send(text => $test_text);
    fail("should throw when neither phones, lists, or contacts is supplied");
};
cmp_ok($called{POST}, '==', 0, "Should have posted a message");
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
cmp_ok($called{POST}, '==', 1, "Should have posted a message");
like($@, qr/test error message/, "expected error message wasn't thrown");

# 
# getSessionMessages success case
#
my $test_sess = [{ text => "session text 1" }, { text => "session text 2" }];
$injected_json = JSON::encode_json($test_sess);
$injected_code = 200;
$called{GET} = 0;

my $sess = $tm->getSessionMessages(id => 1234);
cmp_ok($called{GET}, '==', 1, "getSessionMessages should have made a called GET call");
cmp_ok((split /\s/, $captured_resource)[0], 'eq', "/sessions/1234/messages", "getSessionMessages called to the expected URI");
is_deeply(JSON::decode_json((split /\s/, $captured_resource)[1]), { page => 1, limit => 10 }, "default parameters were correctly applied");
is_deeply($sess, $test_sess, "Response JSON is as expected");

$called{GET} = 0;
$sess = $tm->getSessionMessages(id => 2345, page => 3, limit => 20);
cmp_ok($called{GET}, '==', 1, "getSessionMessages should have made a called GET call");
cmp_ok((split /\s/, $captured_resource)[0], 'eq', "/sessions/2345/messages", "getSessionMessages called to the expected URI");
is_deeply(JSON::decode_json((split /\s/, $captured_resource)[1]), { page => 3, limit => 20 }, "explicit parameters were correctly applied");
is_deeply($sess, $test_sess, "Response JSON is as expected");

# 
# getSessionMessages invalid arguments
#
eval {
    $called{GET} = 0;
    $sess = $tm->getSessionMessages();
    fail("should have thrown an exception calling getSessionMessages with missing id");
};
cmp_ok($called{GET}, '==', 0, "getSessionMessages should not have made a GET call");
like($@, qr/should be numeric/, "expected exception message not found");

eval {
    $called{GET} = 0;
    $sess = $tm->getSessionMessages(id => "foo");
    fail("should have thrown an exception calling getSessionMessages with non-numeric id");
};
cmp_ok($called{GET}, '==', 0, "getSessionMessages should not have made a GET call");
like($@, qr/should be numeric/, "expected exception message not found");

eval {
    $called{GET} = 0;
    $sess = $tm->getSessionMessages(id => 2345, page => "three");
    fail("should have thrown an exception calling getSessionMessages with non-numeric page");
};
cmp_ok($called{GET}, '==', 0, "getSessionMessages should not have made a GET call");
like($@, qr/should be numeric/, "expected exception message not found");

eval {
    $called{GET} = 0;
    $sess = $tm->getSessionMessages(id => 2345, limit => "three");
    fail("should have thrown an exception calling getSessionMessages with non-numeric limit");
};
cmp_ok($called{GET}, '==', 0, "getSessionMessages should not have made a GET call");
like($@, qr/should be numeric/, "expected exception message not found");

# 
# getSessionMessages server error response
#
$injected_json = JSON::encode_json({ message => "test error message" });
$injected_code = 500;

eval { 
    $called{GET} = 0;
    $sess = $tm->getSessionMessages(id => 1234);
    fail("should have thrown an exception calling getSessionMessages when server returns error");
};
cmp_ok($called{GET}, '==', 1, "getSsessionMessages should have made a GET call");
like($@, qr/test error message/, "expected error message was not thrown");

# 
# getChat success case
#
$injected_json = JSON::encode_json({ text => $test_text });
$injected_code = 200;
$called{GET} = 0;

my $chat = $tm->getChat(phone => $test_tel1);
cmp_ok($called{GET}, '==', 1, "getChat should have made a GET call");
cmp_ok((split /\s/, $captured_resource)[0], 'eq', "/chats/$test_tel1", "getSessionMessages called to the expected URI");
is_deeply(JSON::decode_json((split /\s/, $captured_resource)[1]), { page => 1, limit => 10 }, "default parameters were correctly applied");
is_deeply($chat, { text => $test_text }, "Response JSON is as expected");

$called{GET} = 0;
$chat = $tm->getChat(phone => $test_tel1, page => 3, limit => 20);
cmp_ok($called{GET}, '==', 1, "getSessionMessages should have made a called GET call");
cmp_ok((split /\s/, $captured_resource)[0], 'eq', "/chats/$test_tel1", "getSessionMessages called to the expected URI");
is_deeply(JSON::decode_json((split /\s/, $captured_resource)[1]), { page => 3, limit => 20 }, "explicit parameters were correctly applied");
is_deeply($chat, { text => $test_text }, "Response JSON is as expected");

# 
# getChat invalid parameters
#
eval {
    $called{GET} = 0;
    $tm->getChat();
    fail("should have thrown an exception calling getSessionMessages with missing phone number");
};
cmp_ok($called{GET}, '==', 0, "getSessionMessages should not have made a GET call");
like($@, qr/Specify a valid phone number/, "expected exception message not found");

eval {
    $called{GET} = 0;
    $tm->getChat(phone => "foo");
    fail("should have thrown an exception calling getChat with involid phone");
};
cmp_ok($called{GET}, '==', 0, "getChat should not have made a GET call");
like($@, qr/Specify a valid phone number/, "expected exception message not found");

eval {
    $called{GET} = 0;
    $tm->getChat(phone => $test_tel1, page => "three");
    fail("should have thrown an exception calling getChat with non-numeric page");
};
cmp_ok($called{GET}, '==', 0, "getChat should not have made a GET call");
like($@, qr/should be numeric/, "expected exception message not found");

eval {
    $called{GET} = 0;
    $tm->getChat(phone => $test_tel1, limit => "three");
    fail("should have thrown an exception calling getChat with non-numeric limit");
};
cmp_ok($called{GET}, '==', 0, "getChat should not have made a GET call");
like($@, qr/should be numeric/, "expected exception message not found");

# 
# getChat server error response
#
$injected_json = JSON::encode_json({ message => "test error message" });
$injected_code = 500;

eval {
    $called{GET} = 0;
    $tm->getChat(phone => $test_tel1);
    fail("should have thrown an exception when server returns an error");
};
cmp_ok($called{GET}, '==', 1, "getChat should have made a GET call");
like($@, qr/test error message/, "expected exception message not found");

# 
# getPrice success case
#
$injected_code = 200;
$injected_json = JSON::encode_json({ success => "ok" });
$called{GET} = 0;

$resp = $tm->getPrice(text => $test_text, phones => [ $test_tel1, $test_tel2 ]);

cmp_ok($called{GET}, '==', 1, "Should have posted a message");
cmp_ok((split /\s/, $captured_resource)[0], 'eq', '/messages/price', "Should post to /messages/price");
is_deeply(JSON::decode_json((split /\s/, $captured_resource)[1]), { text => $test_text, phones => "$test_tel1,$test_tel2", dummy => 1, contacts => undef, sendingTime => undef, cutExtra => 0, templateId => undef, partsCount => undef, lists => undef, referenceId => undef, from => undef, rrule => undef }, "Posted data should match arguments passed");
is_deeply($resp, { success => "ok" }, "Response JSON is as expected");

#
# Ensure that all available parameters are successfully passed through to the
# message
#
for my $param (keys %send_keys) {
    $called{GET} = 0;

    my %params = %send_keys;
    $params{text} = $test_text;
    $params{phones} = [ $test_tel1, $test_tel2 ];
    $params{dummy} = 1;
    if ($param =~ /s$/) { # contacts, lists, phones
        $params{phones} = undef;
        $params{$param} = [ 1, 2, 3 ];
    } 
    elsif ($param ne "dummy") {
        $params{$param} = "testval";
    }

    eval {
        my $resp = $tm->getPrice(%params);
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

    cmp_ok($called{POST}, '==', 1, "Should have posted a message");
    is_deeply(JSON::decode_json((split /\s/, $captured_resource)[1]), \%validate_params, "Posted data should match arguments passed");
}

# 
# Handling of missing parameters
#
eval {
    $called{GET} = 0;
    $tm->getPrice(phones => [ $test_tel2 ]);
    fail("should throw when neither text nor template is included");
};
cmp_ok($called{GET}, '==', 0, "Should have posted a message");
like($@, qr/Either text or templateId should be specified/, "expected error message wasn't thrown");

eval {
    $tm->getPrice(text => $test_text);
    fail("should throw when neither phones, lists, or contacts is supplied");
};
cmp_ok($called{GET}, '==', 0, "Should have posted a message");
like($@, qr/Either phones, contacts or lists should be specified/, "expected error message wasn't thrown");

# 
# Handling of server error responses
#
$injected_json = JSON::encode_json({ message => "test error message" });
$injected_code = 500;

eval {
    $tm->getPrice(text => $test_text, phones => [ $test_tel1 ]);
    fail("should throw when the server returns a non-success error code");
};
cmp_ok($called{GET}, '==', 1, "Should have posted a message");
like($@, qr/test error message/, "expected error message wasn't thrown");

done_testing();
