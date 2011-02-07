#!/usr/bin/perl
# Example of FastDB::Question
#
# Please do not use 'Conditions' if you can do the same thing with 'Filters'
# because 'Filters' are much faster. ( 'Conditions' always search all the data )
# It is ok to combine 'Filters' and 'Conditions'

use FastDB::Question;

my $qry    = Question->new( '/work/FastDB test/db/Export cargo.schema' );
my $answer = $qry->question(

'Fields to return' => [ 'TYPE', 'WEIGHT', 'COUNTRY', 'COLOR' ],
'Filters'          =>
                      [
                      'WEIGHT' => '( DATA > 800 ) and ( DATA < 8000 )'  ,
                      'COLOR'  => 'dATA =~/(green|brown|red)/i'         ,
                      ],
'Conditions'       =>
                      [
                      '(WEIGHT >= 1500) and TYPE=~/2/',
                      '((COLOR eq "green") or (COLOR eq "red")) and (COUNTRY eq "U.S. MONTANA")'
                      ],
'Results'          =>
                      [
                      'Return an array of arrays'             => 'Yes'           ,
                      'Print to standard output'              => 'No '           ,
                      'Print to standard error'               => 'no'            ,
                      'Print to file'                         => 'Yes'           ,
                      'File name'                             => '/work/FastDB test/OUTPUT.TXT',
                      'Pass to external Perl module'          => 'Yes'           ,
                      'Perl module name'                      => 'MIME::Base64'  ,
                      'Function of the Perl module'           => 'encode_base64' ,
                      'Code of how to pass data at function'  => 'join ",", @_'  , # or @_, or whatever Perl code you want
                      ]
);


print "No data found or 'Return an array of arrays' is set to No\n" if 0 == scalar @{$answer};

foreach my $row (@{$answer})
{
print "@{$row}\n"
}

