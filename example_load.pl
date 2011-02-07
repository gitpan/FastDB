#!/usr/bin/perl
#
# Example of FastDB::Load . Extra virtual fields you can optional use:
#
#	EXTRA_DAY          01  - 31
#	EXTRA_DAY_NAME     Sun - Sat
#	EXTRA_MONTH_NAME   Jan - Dec
#	EXTRA_MONTH        01  - 12
#	EXTRA_YEAR         1453
#	EXTRA_HOUR         00  - 23
#	EXTRA_MINUTE       00  - 59
#	EXTRA_SECOND       00  - 59
#	EXTRA_TIMESTAMP    20101201123957  ( YYYYMMDDhhmmss )

use FastDB::Load;

my $load = Load->new(

'Name'                     => 'Export cargo'                                           ,
'Data store location'      => '/work/FastDB test/db'                                   ,
'Field separator string'   => ','                                                      ,
'Original field names'     => [ 'COLOR', 'HEIGHT', 'WEIGHT', 'TYPE', 'ID', 'COUNTRY' ] ,
'Indexed fields'           => [ 'WEIGHT' , 'EXTRA_YEAR' ]                              ,
'Extra virtual fields'     => [ 'EXTRA_TIMESTAMP', 'EXTRA_YEAR', 'EXTRA_DAY_NAME' ]    ,
'Transform'                => [
                              'COLOR'   => 'my $a = lc DATA; $a'  ,
                              'TYPE'    => 'uc DATA;'             ,
                              'ID'      =>  '"<id>DATA</id>"'     ,
                              'COUNTRY' => 'uc DATA'              ,
                              ]
);

$load->load( 'Green' , 10, 1500, 'mech22', 'A100', 'New Zeland'   );
$load->load( 'Brown' , 10, 1500, 'mech22', 'A100', 'India'        );
$load->load( 'Green' , 11, 3500, 'mech23', 'B100', 'Australia'    );
$load->load( 'Yellow',  7, 2500, 'mech21', 'C100', 'South Africa' );
$load->load( 'Red'   , 14, 2500, 'mech21', 'D001', 'U.S. Montana' );
$load->load( 'Red'   , 17, 5500, 'mech32', 'D101', 'U.S. Montana' );
$load->load( 'White' , 21,  700, 'snow02', 'E002', 'North Pole'   );
$load->load( 'White' , 21,  700, 'snow02', 'E002', 'South Pole'   );


# Optional write some short information about your load
#	$load->Write_statistics_at_the_end();
#	$load->Write_statistics_at_the_end( $SomeFile );
#	$load->Write_statistics_at_the_end( "$load->{'Data store location'}/$load->{'Name'}.log" );

$load->Write_statistics_at_the_end();