use inc::Module::Install;
name 'AnyEvent-APNS';
all_from 'lib/AnyEvent/APNS.pm';

requires 'Any::Moose';
requires 'AnyEvent'    => '4.80';
requires 'Net::SSLeay' => '1.33';
requires 'JSON::Any';

test_requires 'Test::More';
test_requires 'Test::TCP';

use_test_base;
author_tests('xt');

auto_include;
WriteAll;
