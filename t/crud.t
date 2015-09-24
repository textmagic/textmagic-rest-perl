use strict;
use warnings;

use JSON;
use Net::SMS::TextmagicRest;
use REST::Client;
use Test::MockModule;
use Test::More;

# 
# This file contains tests for all of the basic getSomething, deleteSomething,
# and getSomethings methods. These all have the same argument structure and
# identical validations, so they're abstracted out into a convenient array that
# lets us cover all of them at once.
#

my $username = 'jessebangs';
my $token = 'S4y9ph4H5r4lcSG6ZFdffKUgWnpkAl';

# Variables capturing data passed into or out of the REST client.
my $injected_json = "{}";
my $injected_code = 200;
my $captured_self = undef;
my $captured_resource = "";
my $captured_data = "";
my $last_method = "";
my %called = (
    GET => 0,
    DELETE => 0
);

#
# Create our mock REST client; doing this before creating the TextMagic object
# causes our mock definitions to be loaded by TextmagicRest
#
my $mock = Test::MockModule->new('REST::Client');
$mock->mock("GET", sub { ($captured_self, $captured_resource, $captured_data) = @_; $called{GET}++; });
$mock->mock("DELETE", sub { ($captured_self, $captured_resource, $captured_data) = @_; $called{DELETE}++; });
$mock->mock("buildQuery", sub { return " " . JSON::encode_json($_[1]) if $_[1] && keys %{$_[1]}; });
$mock->mock("responseContent", sub { return $injected_json; });
$mock->mock("responseCode", sub { return $injected_code });

my $tm = Net::SMS::TextmagicRest->new(username => $username, token => $token);

# 
# So we have a bunch of methods with the exact same argument (a single integer
# ID) and very similar error conditions. To reduce repetiton, we put the
# metadata about these methods in an array and execute the same block of code
# for all of them.
#
my @method_metadata = (
    {
        method => "getMessage",
        http_method => "GET",
        target => "messages"
    },
    {
        method => "getReply",
        http_method => "GET",
        target => "replies"
    },
    {
        method => "getSession",
        http_method => "GET",
        target => "sessions"
    },
    {
        method => "getSchedule",
        http_method => "GET",
        target => "schedules",
    },
    {
        method => "getBulk",
        http_method => "GET",
        target => "bulks"
    },
    {
        method => "deleteMessage",
        http_method => "DELETE",
        target => "messages"
    },
    {
        method => "deleteReply",
        http_method => "DELETE",
        target => "replies"
    },
    {
        method => "deleteSchedule",
        http_method => "DELETE",
        target => "schedules"
    },
    {
        method => "deleteSession",
        http_method => "DELETE",
        target => "sessions"
    },
    {
        method => "getTemplate",
        http_method => "GET",
        target => "templates"
    },
    {
        method => "deleteTemplate",
        http_method => "DELETE",
        target => "templates"
    },
    {
        method => "getContact",
        http_method => "GET",
        target => "contacts",
    },
    {
        method => "deleteContact",
        http_method => "DELETE",
        target => "contacts",
    },
    {
        method => "getCustomField",
        http_method => "GET",
        target => "customfields",
    },
    {
        method => "deleteCustomField",
        http_method => "DELETE",
        target => "customfields",
    },
    {
        method => "getList",
        http_method => "GET",
        target => "lists",
    },
    {
        method => "deleteList",
        http_method => "DELETE",
        target => "lists",
    },
    {
        method => "getDedicatedNumber",
        http_method => "GET",
        target => "numbers",
    }
);
for my $metadata (@method_metadata) {
    my $method = $metadata->{method};
    my $http_method = $metadata->{http_method};
    my $target = $metadata->{target};

    my $test_resp = { test_key => 4321 };
    $injected_json = JSON::encode_json($test_resp);
    if ($http_method eq "GET") {
        $injected_code = 200;
    } 
    elsif ($http_method eq "DELETE") {
        $injected_code = 204;
    }
    $called{$http_method} = 0;

    # 
    # success case
    #
    my $resp = $tm->$method(1234);
    cmp_ok($called{$http_method}, '==', 1, "calling $method should make a $http_method call to the server");
    cmp_ok($captured_resource, 'eq', "/$target/1234", "$method called to the expected uri /$target/{id}");
    if ($http_method eq "GET") {
        is_deeply($resp, $test_resp, "the message returned from $method was successfully decoded from JSON");
    }
    elsif ($http_method eq "DELETE") {
        cmp_ok($resp, '==', 1, "the return value from $method was success");
    }

    # 
    # missing parameter
    #
    eval {
        $called{$http_method} = 0;
        $resp = $tm->$method();
        fail("$method should throw when no parameter is supplied");
    };
    cmp_ok($called{$http_method}, '==', 0, "no call should be made to the server when required parameter is missing");
    like($@, qr/should be numeric/, "expected error message wasn't thrown from $method");

    # 
    # non-numeric parameter
    #
    eval {
        $called{$http_method} = 0;
        $resp = $tm->$method("foo");
        fail("$method should throw when a non-numeric parameter is supplied");
    };
    cmp_ok($called{$http_method}, '==', 0, "no call should be made to the server when required parameter is non-numeric");
    like($@, qr/should be numeric/, "expected error message wasn't thrown from $method");

    # 
    # server error response
    #
    $injected_code = 500;
    $injected_json = JSON::encode_json({ message => "test error message" });
    eval {
        $called{$http_method} = 0;
        $tm->$method(1234);
        fail("$method should throw when the server returns an error code");
    };
    cmp_ok($called{$http_method}, '==', 1, "calling $method should make a $http_method call to the server");
    like($@, qr/test error message/, "expected error message wasn't thrown");
}

# 
# As above, there are a number of methods which retrieve paged lists, getting
# the exact same parameters, etc. These are also included in a list
#
my @lists_metadata = (
    {
        method => "getMessages",
        http_method => "GET",
        target => "messages"
    },
    {
        method => "getReplies",
        http_method => "GET",
        target => "replies"
    },
    {
        method => "getSessions",
        http_method => "GET",
        target => "sessions"
    },
    {
        method => "getSchedules",
        http_method => "GET",
        target => "schedules"
    },
    {
        method => "getBulks",
        http_method => "GET",
        target => "bulks"
    },
    {
        method => "getChats",
        http_method => "GET",
        target => "chats"
    },
    {
        method => "getTemplates",
        http_method => "GET",
        target => "templates"
    },
    {
        method => "getCustomFields",
        http_method => "GET",
        target => "customfields"
    },
    {
        method => "getLists",
        http_method => "GET",
        target => "lists"
    },
);
for my $metadata (@lists_metadata) {
    my $method = $metadata->{method};
    my $http_method = $metadata->{http_method};
    my $target = $metadata->{target};

    my $test_msgs = [{ id => 1234, text => "test reply" }, { id => 2345, text => "test text" }];
    $injected_json = JSON::encode_json($test_msgs);
    $injected_code = 200;
    $called{$http_method} = 0;

    # 
    # success case
    #

    # N.B. we've mocked the function which encodes query params to use JSON and
    # separate the query params from the base URI with a space. This makes it easier
    # for us to validate that query params are present without worrying about
    # ordering, etc.

    # Default parameters
    my $msgs = $tm->$method();
    cmp_ok($called{$http_method}, '==', 1, "calling $method should make a $http_method call to the server");
    cmp_ok((split /\s/, $captured_resource)[0], 'eq', "/$target", "$method() called to the expected URI");
    is_deeply(JSON::decode_json((split /\s/, $captured_resource)[1]), { page => 1, limit => 10 }, "default parameters for $method were correctly applied");
    is_deeply($msgs, $test_msgs, "the response was successfully decoded from JSON");

    # Explicit parameters
    $called{$http_method} = 0;
    $msgs = $tm->$method(page => 2, limit => 15);
    cmp_ok($called{$http_method}, '==', 1, "calling $method should make a $http_method call to the server");
    cmp_ok((split /\s/, $captured_resource)[0], 'eq', "/$target", "$method called to the expected URI");
    is_deeply(JSON::decode_json((split /\s/, $captured_resource)[1]), { page => 2, limit => 15 }, "explicit parameters were correctly applied");
    is_deeply($msgs, $test_msgs, "the response was successfully decoded from JSON");

    # 
    # invalid page parameter
    #
    eval {
        $called{$http_method} = 0;
        $msgs = $tm->$method(page => "foo");
        fail("should throw when an invalid page parameter is supplied");
    };
    cmp_ok($called{$http_method}, '==', 0, "calling $method should not make a $http_method call to the server");
    like($@, qr/should be numeric/, "expected error message was thrown when invalid page parameter is supplied to $method");

    # 
    # invalid limit parameter
    #
    eval {
        $called{$http_method} = 0;
        $msgs = $tm->$method(limit => "foo");
        fail("should throw when an invalid limit parameter is supplied");
    };
    cmp_ok($called{$http_method}, '==', 0, "calling $method should not make a $http_method call to the server");
    like($@, qr/should be numeric/, "expected error message was thrown when invalid limit parameter is supplied to $method");

    # 
    # server error response
    #
    $injected_code = 500;
    $injected_json = JSON::encode_json({ message => "test error message" });
    eval {
        $tm->$method();
        fail("should throw when the server returns an error code");
    };
    like($@, qr/test error message/, "expected error message wasn't thrown");
}

done_testing();
