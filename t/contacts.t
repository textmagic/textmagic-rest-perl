use strict;
use warnings;

use JSON;
use Net::SMS::TextmagicRest;
use REST::Client;
use Test::MockModule;
use Test::More;

# 
# This file contains tests for addContact and updateContact. The methods
# getContact, getContacts, and deleteContact are tested in crud.t.
#

my $username = 'jessebangs';
my $token = 'S4y9ph4H5r4lcSG6ZFdffKUgWnpkAl';

# Variables capturing data passed into or out of the REST client.
my $injected_json = "{}";
my $injected_code = 200;
my $captured_self = undef;
my $captured_resource = "";
my $captured_data = "";
my %called = (
    PUT => 0,
    POST => 0
);

my %contact_keys = (
    firstName => undef,
    lastName => undef,
    phone => undef,
    email => undef,
    companyName => undef,
    country => undef,
    lists => undef
);

#
# Create our mock REST client; doing this before creating the TextMagic object
# causes our mock definitions to be loaded by TextmagicRest
#
my $mock = Test::MockModule->new('REST::Client');
$mock->mock("PUT", sub { ($captured_self, $captured_resource, $captured_data) = @_; $called{PUT}++; });
$mock->mock("POST", sub { ($captured_self, $captured_resource, $captured_data) = @_; $called{POST}++; });
$mock->mock("buildQuery", sub { return " " . JSON::encode_json($_[1]) if $_[1] && keys %{$_[1]}; });
$mock->mock("responseContent", sub { return $injected_json; });
$mock->mock("responseCode", sub { return $injected_code });

my $tm = Net::SMS::TextmagicRest->new(username => $username, token => $token);

# 
# addContact success tests
#
my $test_tel = "+0012315555555";
my @list = (1);
my $contact_id = 234;
$injected_json = JSON::encode_json({ contactId => $contact_id });
$injected_code = 201;

my %expected_data = %contact_keys;
$expected_data{phone} = $test_tel;
$expected_data{lists} = join(",", @list);

# minimal set of params
my $result = $tm->addContact(phone => $test_tel, lists => \@list);
cmp_ok($called{POST}, '==', 1, "addContact should have made a POST request");
cmp_ok($captured_resource, 'eq', "/contacts", "addTemplate should POST to /contacts");
is_deeply(JSON::decode_json($captured_data), \%expected_data, "data passed in parameters should be posted to the server");
is_deeply($result, { contactId => $contact_id }, "result response was decoded from JSON");

# maximal set of params
$expected_data{firstName} = "Tester";
$expected_data{lastName} = "McTesterson";
$expected_data{email} = 'tester@test.com';
$expected_data{companyName} = "We Test Everything";
$expected_data{country} = "UK";

$called{POST} = 0;

$result = $tm->addContact(%expected_data, phone => $test_tel, lists => \@list);
cmp_ok($called{POST}, '==', 1, "addContact should have made a POST request");
cmp_ok($captured_resource, 'eq', "/contacts", "addTemplate should POST to /contacts");
is_deeply(JSON::decode_json($captured_data), \%expected_data, "data passed in parameters should be posted to the server");
is_deeply($result, { contactId => $contact_id }, "result response was decoded from JSON");

# 
# addContact missing/invalid params
#
eval {
    $called{POST} = 0;
    $tm->addContact(lists => \@list);
    fail("should have thrown exception for missing phone number");
};
cmp_ok($called{POST}, '==', 0, "addContact should not have made a POST request");
like($@, qr/Contact phone and at least one list should be specified/, "expected exception message not found");

eval {
    $called{POST} = 0;
    $tm->addContact(phone => $test_tel);
    fail("should have thrown exception for missing lists param");
};
cmp_ok($called{POST}, '==', 0, "addContact should not have made a POST request");
like($@, qr/Contact phone and at least one list should be specified/, "expected exception message not found");

eval {
    $called{POST} = 0;
    $tm->addContact(phone => "phone#", lists => \@list);
    fail("should have thrown exception for non-numeric phone param");
};
cmp_ok($called{POST}, '==', 0, "addContact should not have made a POST request");
like($@, qr/Contact phone and at least one list should be specified/, "expected exception message not found");

eval {
    $called{POST} = 0;
    $tm->addContact(phone => $test_tel, lists => "1,2");
    fail("should have thrown exception for non-array lists param");
};
cmp_ok($called{POST}, '==', 0, "addContact should not have made a POST request");
like($@, qr/Contact phone and at least one list should be specified/, "expected exception message not found");

# 
# addContact server error response
#
$injected_json = JSON::encode_json({ message => "test error" });
$injected_code = 500;

eval {
    $called{POST} = 0;
    $tm->addContact(phone => $test_tel, lists => \@list);
    fail("should have thrown an exception when the server returns an error code");
};
cmp_ok($called{POST}, '==', 1, "should have made a POST request to the server");
like($@, qr/test error/, "expected exception message was not found");

# 
# updateContact success tests
#
$injected_json = JSON::encode_json({ contactId => $contact_id });
$injected_code = 201;

%expected_data = %contact_keys;
$expected_data{phone} = $test_tel;
$expected_data{lists} = join(",", @list);

# minimal set of params
my $result = $tm->updateContact(id => $contact_id, phone => $test_tel, lists => \@list);
cmp_ok($called{PUT}, '==', 1, "updateContact should have made a PUT request");
cmp_ok($captured_resource, 'eq', "/contacts/$contact_id", "addTemplate should PUT to /contacts");
is_deeply(JSON::decode_json($captured_data), \%expected_data, "data passed in parameters should be PUT to the server");
is_deeply($result, { contactId => $contact_id }, "result response was decoded from JSON");

# maximal set of params
$expected_data{firstName} = "Tester";
$expected_data{lastName} = "McTesterson";
$expected_data{email} = 'tester@test.com';
$expected_data{companyName} = "We Test Everything";
$expected_data{country} = "UK";

$called{PUT} = 0;

$result = $tm->updateContact(id => $contact_id, %expected_data, phone => $test_tel, lists => \@list);
cmp_ok($called{PUT}, '==', 1, "updateContact should have made a PUT request");
cmp_ok($captured_resource, 'eq', "/contacts/$contact_id", "addTemplate should PUT to /contacts");
is_deeply(JSON::decode_json($captured_data), \%expected_data, "data passed in parameters should be PUTed to the server");
is_deeply($result, { contactId => $contact_id }, "result response was decoded from JSON");

# 
# updateContact missing/invalid params
#
eval {
    $called{PUT} = 0;
    $tm->updateContact(phone => $test_tel, lists => \@list);
    fail("should have thrown exception for missing id");
};
cmp_ok($called{PUT}, '==', 0, "updateContact should not have made a PUT request");
like($@, qr/Contact ID, phone and at least one list should be specified/, "expected exception message not found");

eval {
    $called{PUT} = 0;
    $tm->updateContact(id => "three", phone => $test_tel, lists => \@list);
    fail("should have thrown exception non-numeric id");
};
cmp_ok($called{PUT}, '==', 0, "updateContact should not have made a PUT request");
like($@, qr/Contact ID, phone and at least one list should be specified/, "expected exception message not found");

eval {
    $called{POST} = 0;
    $tm->updateContact(id => $contact_id, lists => \@list);
    fail("should have thrown exception for missing phone number");
};
cmp_ok($called{POST}, '==', 0, "updateContact should not have made a POST request");
like($@, qr/Contact ID, phone and at least one list should be specified/, "expected exception message not found");

eval {
    $called{POST} = 0;
    $tm->updateContact(id => $contact_id, phone => $test_tel);
    fail("should have thrown exception for missing lists param");
};
cmp_ok($called{POST}, '==', 0, "updateContact should not have made a POST request");
like($@, qr/Contact ID, phone and at least one list should be specified/, "expected exception message not found");

eval {
    $called{POST} = 0;
    $tm->updateContact(id => $contact_id, phone => "phone#", lists => \@list);
    fail("should have thrown exception for non-numeric phone param");
};
cmp_ok($called{POST}, '==', 0, "updateContact should not have made a POST request");
like($@, qr/Contact ID, phone and at least one list should be specified/, "expected exception message not found");

eval {
    $called{POST} = 0;
    $tm->updateContact(id => $contact_id, phone => $test_tel, lists => "1,2");
    fail("should have thrown exception for non-array lists param");
};
cmp_ok($called{POST}, '==', 0, "updateContact should not have made a POST request");
like($@, qr/Contact ID, phone and at least one list should be specified/, "expected exception message not found");

# 
# updateContact server error response
#
$injected_json = JSON::encode_json({ message => "test error" });
$injected_code = 500;

eval {
    $called{PUT} = 0;
    $tm->updateContact(id => $contact_id, phone => $test_tel, lists => \@list);
    fail("should have thrown an exception when the server returns an error code");
};
cmp_ok($called{PUT}, '==', 1, "should have made a PUT request to the server");
like($@, qr/test error/, "expected exception message was not found");

done_testing();
