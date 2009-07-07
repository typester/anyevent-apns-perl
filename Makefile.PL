use inc::Module::Install;
name 'AnyEvent-APNS';
all_from 'lib/AnyEvent/APNS.pm';

requires 'AnyEvent'    => '4.80';
requires 'Net::SSLeay' => '1.33';

test_requires 'Test::More';
use_test_base;
auto_include;
WriteAll;
