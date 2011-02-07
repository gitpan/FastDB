#!/usr/bin/perl
#
# Example of FastDB::Delete . Set tab to 8 spaces.

use FastDB::Delete;

# Be careful ! if 'Allow deletion with no filters' is 'Yes' and you
# do not specify any Filtes , all your database data will get deleted

my $obj = Delete->new(
'Schema file'                      => '/work/FastDB test/db/Export cargo.schema',
'Allow deletion with no filters'   => 'No',
'Show activity at standard output' => 'yes'
);


# The order of 'Filters' is not important.

$obj->delete(
'WEIGHT'     => '(DATA > 2000) and (DATA <= 100000) and ( DATA % 2 == 0)' ,
'EXTRA_YEAR' => 'DATA == 2011' );