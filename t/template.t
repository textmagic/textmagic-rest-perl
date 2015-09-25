use strict;
use warnings;

use JSON;
use Net::SMS::TextmagicRest;
use REST::Client;
use Test::MockModule;
use Test::More;

# 
# This file contains tests addTemplate and updateTemple. The methods
# getTemplate, getTemplates, and deleteTemplate are all tested in crud.t
#

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

my $tm = Net::SMS::TextmagicRest->new(username => "testuser", token => "testtoken");

# 
# addTemplate success case
#
my $template_id = 1234;
my $template_name = "testTemplate";
my $template_body = "template body text";
$injected_json = JSON::encode_json({ templateId => $template_id });
$injected_code = 201;

my $result = $tm->addTemplate(name => $template_name, body => $template_body);
cmp_ok($called{POST}, '==', 1, "addTemplate should have made a POST request");
cmp_ok($captured_resource, 'eq', "/templates", "addTemplate should PUT to /templates");
is_deeply(JSON::decode_json($captured_data), { name => $template_name, body => $template_body }, "data passed in parameters should be posted to the server");
is_deeply($result, { templateId => $template_id }, "result response was decoded from JSON");

# 
# addTemplate missing parameters
#
eval {
    $called{POST} = 0;
    $tm->addTemplate(body => $template_body);
    fail("should have thrown an exception when no name is given");
};
cmp_ok($called{POST}, '==', 0, "should not have made a POST request to the server");
like($@, qr/Template text and body should be specified/, "expected exception message was not found");

eval {
    $called{POST} = 0;
    $tm->addTemplate(name => $template_name);
    fail("should have thrown an exception when no body is given");
};
cmp_ok($called{POST}, '==', 0, "should not have made a POST request to the server");
like($@, qr/Template text and body should be specified/, "expected exception message was not found");

# 
# addTemplate server error code
#
$injected_json = JSON::encode_json({ message => "test error" });
$injected_code = 500;

eval {
    $called{POST} = 0;
    $tm->addTemplate(name => $template_name, body => $template_body);
    fail("should have thrown an exception when the server returns an error code");
};
cmp_ok($called{POST}, '==', 1, "should have made a POST request to the server");
like($@, qr/test error/, "expected exception message was not found");

#
# updateTemplate success case
#
$injected_json = JSON::encode_json({ success => "ok" });
$injected_code = 201;

$result = $tm->updateTemplate(id => $template_id, name => $template_name, body => $template_body);
cmp_ok($called{PUT}, '==', 1, "updateTemplate should have made a PUT request");
cmp_ok($captured_resource, 'eq', "/templates/$template_id", "addTemplate should PUT to /templates");
is_deeply(JSON::decode_json($captured_data), { "template[name]" => $template_name, "template[body]" => $template_body }, "data passed in parameters should be posted to the server");
is_deeply($result, { success => "ok" }, "result response was decoded from JSON");

# 
# updateTemplate missing/invalid parameters
#
eval {
    $called{PUT} = 0;
    $tm->updateTemplate(name => $template_id, body => $template_body);
    fail("should have thrown an exception when no id is given");
};
cmp_ok($called{PUT}, '==', 0, "should not have made a PUT request to the server");
like($@, qr/Template id, text and body should be specified/, "expected exception message was not found");

eval {
    $called{PUT} = 0;
    $tm->updateTemplate(id => "foo", name => $template_name, body => $template_body);
    fail("should have thrown an exception when id is not numeric");
};
cmp_ok($called{PUT}, '==', 0, "should not have made a PUT request to the server");
like($@, qr/should be numeric/, "expected exception message was not found");

eval {
    $called{PUT} = 0;
    $tm->updateTemplate(id => $template_id, body => $template_body);
    fail("should have thrown an exception when no name is given");
};
cmp_ok($called{PUT}, '==', 0, "should not have made a PUT request to the server");
like($@, qr/Template id, text and body should be specified/, "expected exception message was not found");

eval {
    $called{PUT} = 0;
    $tm->updateTemplate(id => $template_id, name => $template_name);
    fail("should have thrown an exception when no body is given");
};
cmp_ok($called{PUT}, '==', 0, "should not have made a PUT request to the server");
like($@, qr/Template id, text and body should be specified/, "expected exception message was not found");

# 
# updateTemplate server error response
#
$injected_json = JSON::encode_json({ message => "test error" });
$injected_code = 500;

eval {
    $called{PUT} = 0;
    $tm->updateTemplate(id => $template_id, name => $template_name, body => $template_body);
    fail("should have thrown an exception when the server returns an error code");
};
cmp_ok($called{PUT}, '==', 1, "should have made a PUT request to the server");
like($@, qr/test error/, "expected exception message was not found");

done_testing();
