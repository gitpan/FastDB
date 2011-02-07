#!/usr/bin/perl
#
# Insertion of a csv file to a file based indexed database
# c:\perl64\bin\perl.exe db_load_MultipleConfiguration.pl
#
# This version supports multiple configuration schemas and can load data
# to multiple databases.
#
# Extra dynamic fields you can use at loading time
#
#   EXTRA_YEAR, EXTRA_MONTH, EXTRA_DAY, EXTRA_HOUR, EXTRA_MINUTE, EXTRA_SECOND, EXTRA_TIMESTAMP
#
# George Bouras
# Europe/Athens, gravitalsun@hotmail.com

use strict;
use feature qw/switch/;
use Getopt::Long;

my $VERSION = '3.0.2';
my @Schemas;

&Parse_user_arguments_and_return_the_schemas;

my $saytime = sub{local @{$_} = localtime(time); $_->[5]+=1900; sprintf '%02d-%s-%04d %02d:%02d:%02d', $_->[3], (qw/Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec/)[$_->[4]], @{$_}[5,2,1,0]};


# Analyze and re-create the @Schemas. View its structure with the following line
# use Data::Dumper; print STDOUT Data::Dumper::Dumper(\@Schemas); exit;
foreach my $schema (@Schemas)
{
$schema->{'loaded lines'}=0;
$schema->{'dir_data'}=~s/\\/\//gs;
$schema->{'dir_data'}=~s/\/*$//gs;
CreateDir($schema->{'dir_data'}) || die "Could not create the data directory \"$schema->{'dir_data'}\"\n";

	# check the vadility of lower case fields
	foreach ( @{$schema->{'field_case_lower'}} ) {
	unless ( ( $_ ~~ @{$schema->{'field_all'}} ) || ( $_ ~~ $schema->{'field_extra'} ) ) { die "At schema \"$schema->{'name'}\" the field \"$_\" you want to make lower case is not defined at \"Standard input file fields\" or at \"Extra virtual fields\"\n" }
	$_ ~~ @{$schema->{'field_case_upper'}} && die "At schema  \"$schema->{'name'}\" you can not define field \"$_\" at \"field_case_upper\" because it is already defined at \"field_case_lower\"\n" }

	# check the vadility of upper case fields
	foreach ( @{$schema->{'field_case_upper'}} ) {
	unless ( ( $_ ~~ @{$schema->{'field_all'}} ) || ( $_ ~~ $schema->{'field_extra'} ) ) { die "At schema \"$schema->{'name'}\" the field \"$_\" you want to make upper case is not defined at \"Standard input file fields\" or at \"Extra virtual fields\"\n" } }

	# Examine the entries of field_index_yes
	for (my $i=$#{$schema->{'field_index_yes'}} ; $i>=0 ; $i--)
	{
		# Check if the field_index_yes item is valid
		unless ( ( $schema->{'field_index_yes'}->[$i] ~~ @{$schema->{'field_all'}} ) || ( $schema->{'field_index_yes'}->[$i] ~~ $schema->{'field_extra'} ) )
		{
		die "At schema \"$schema->{'name'}\" the field \"$schema->{'field_index_yes'}->[$i]\" you want to index is not defined at \"Standard input file fields\" or at \"Extra virtual fields\"\n"
		}
	
		# Remove it, if exists inside the  field_remove
		if ( $schema->{'field_index_yes'}->[$i] ~~ @{$schema->{'field_remove'}} )
		{
		splice @{$schema->{'field_index_yes'}}, $i, 1;
		}
	}

	# Define the  field_index_no  items. We are using  de-duplication login to not include at the data any index fields
	foreach ( @{$schema->{'field_all'}} , @{$schema->{'field_extra'}} )
	{
	next if $_ ~~ @{$schema->{'field_index_yes'}};
	next if $_ ~~ @{$schema->{'field_remove'}};
	push @{$schema->{'field_index_no'}} , $_;
	}

# Define the hash ref    $schema->{'field_reverse'}   . We are using the power of hash slice   @hash{@array}=list  to accomplish this task  
@{$_} = ( @{$schema->{'field_all'}} , @{$schema->{'field_extra'}} );
@{$schema->{'field_reverse'}}{@{$_}} = ( 0 .. $#{$_} );
-2  == ( $#{$schema->{'field_index_yes'}} + $#{$schema->{'field_index_no'}} ) && die "At schema \"$schema->{'name'}\" you have not define any index or data column indsite the configuration file\n";

	# Write schema information at first loading, or check the data schema on next loadings
	unless ( -f "$schema->{'dir_data'}/$schema->{'name'}.schema" )
	{
	open  FILE, '>:raw', "$schema->{'dir_data'}/$schema->{'name'}.schema" or die "Could not create schema file \"$schema->{'dir_data'}/$schema->{'name'}.schema\" because \"$^E\"\n";
	print FILE  'name        : '. $schema->{'name'}		."\x0A";
	print FILE  'dir_data    : '. "$schema->{'dir_data'}/$schema->{'name'}"	."\x0A";
	print FILE  'separator   : '. $schema->{'separator'}	."\x0A";
	$_=[]; my $i=0; foreach my $f ( @{$schema->{'field_index_yes'}} , @{$schema->{'field_index_no'}} ) { push @{$_}, "$f,".$i++ }
	print FILE  'field_all   : '. join(',',@{$_})		."\x0A";
	print FILE  'field_index : '. join($schema->{'separator'}, @{$schema->{'field_index_yes'}});
	close FILE 
	}
	else
	{
	my %check_schema;
	open    FILE, '<', "$schema->{'dir_data'}/$schema->{'name'}.schema" or die "Could not retrieve schema information from file \"$schema->{'dir_data'}/$schema->{'name'}.schema\" because \"$^E\"\n";
	while (<FILE>) { /^\s*(?<Key>[^:]+?)\s*:\s*(?<Value>.*?)\s*$/ or next ; $check_schema{$+{Key}} = $+{Value}}
	close   FILE;

		unless ( (scalar split(',',$check_schema{'field_all'})/2) == scalar(@{$schema->{'field_all'}}) - scalar(@{$schema->{'field_remove'}}) + scalar(@{$schema->{'field_extra'}}) )
		{
		die "Schema error. \"$schema->{'name'}\" has ". (scalar split(',',$check_schema{'field_all'})/2). " while you want to load ".  ( scalar(@{$schema->{'field_all'}}) - scalar(@{$schema->{'field_remove'}}) + scalar(@{$schema->{'field_extra'}}) ) ."\n"
		}

		unless ( (scalar split ',', $check_schema{'field_index'}) == scalar(@{$schema->{'field_index_yes'}}) )
		{
		die "Schema error. \"$schema->{'name'}\" has ". (scalar split ',', $check_schema{'field_index'}) . " indexed fields while you current load configuration has ". scalar(@{$schema->{'field_index_yes'}}) ."\n"
		}
	
		foreach ('name', 'dir_data', 'separator')
		{
		$check_schema{$_} eq $schema->{$_} or die "Schema error. \"$schema->{'name'}\" property \"$_\" has value \"$check_schema{$_}\" while you current load configuration is set to \"$schema->{$_}\"\n"
		}
	}


# @{$schema->{'field_all'}}		All the fields of the input file
# $schema->{'field_index_yes'}		Fields we want to index
# $schema->{'field_index_no'}		Fields we want to simple store their data 
# $schema->{'field_reverse'}		Field index
#
# Write some metadata. At future, more functionality could be added here
open  FILE, '>>:raw', "$schema->{'dir_data'}/$schema->{'name'}.metadata" or die "Could not create metadata file \"$schema->{'dir_data'}/$schema->{'name'}.metadata\" because \"$^E\"\n";
print FILE  'Start loading    : '. $saytime->()."\x0A";
close FILE;
open  INPUT_FILE, '<', $schema->{'input_data'} or die "$^E\n";

	while  (<INPUT_FILE>)
	{
	tr/\x0D\x0A//d;
	my @col = split /\s*$schema->{'separator'}\s*/, $_, -1;  # mind the unicode bom header tr/\xEF\xBB\xBF//d;
	unless ( $#{$schema->{'field_all'}} == $#col ) { die "Skip line not ".(1+$#{$schema->{'field_all'}})." fields at line $. = $_\n"; next }

	push( @col, Calculate_extra_field($schema->{'field_extra'}) ) unless -1 == $#{$schema->{'field_extra'}};
	++$schema->{'lines'};

	# Make lower/upper case fields as defined
	unless ( -1 == $#{$schema->{'field_case_lower'}} ) { foreach (@{$schema->{'field_case_lower'}}) { $col[$schema->{'field_reverse'}->{$_}] = lc $col[$schema->{'field_reverse'}->{$_}] } }
	unless ( -1 == $#{$schema->{'field_case_upper'}} ) { foreach (@{$schema->{'field_case_upper'}}) { $col[$schema->{'field_reverse'}->{$_}] = uc $col[$schema->{'field_reverse'}->{$_}] } }

	# Create the upper schema directories
	$_ = join '/',  "$schema->{'dir_data'}/$schema->{'name'}",  map { $col[$schema->{'field_reverse'}->{$_}] } @{$schema->{'field_index_yes'}};
	CreateDir($_) || die "Could not create directory \"$_\" because \"$^E\"\n";

	# Write the rest data to the data file
	next if $#{$schema->{'field_index_no'}} == -1;
	open  FILE, '>>:raw', join('/', $_, 'data');
	select((select(FILE),$|=1)[0]);
	print FILE  join($schema->{'separator'}, map{ $col[$schema->{'field_reverse'}->{$_}] } @{$schema->{'field_index_no'}}) ."\x0A";
	close FILE
	}

close INPUT_FILE;
open  FILE,'>>:raw', "$schema->{'dir_data'}/$schema->{'name'}.metadata" or die "Could not update metadata file \"$schema->{'dir_data'}/$schema->{'name'}.metadata\" because \"$^E\"\n";
print FILE 'End   loading    : '.$saytime->()		."\x0A";
print FILE 'Loaded "lines"   : '.$schema->{'lines'}	."\x0A";
print FILE ('-' x39)					."\x0A";
close FILE
}



exit 0;





			################
			#              #
			# Sub routines #
			#              #
			################


#   Create nested directory and all the upper path that may missing.
#   returns the directory on success, or undef on error
sub CreateDir ($)
{
(my $dir     = shift) =~s/[\\\/]*$//;
my ($i, @CH) = (0, split /[\\\/]/, $dir, -1);						# split dir
for($i=$#CH; $i>=0; $i--) { last if -d join '/', @CH[0..$i] }				# find the last existing directory
if (($i == -1) && ($^O eq 'linux')) { splice @CH, 0, 2, "/$CH[1]" if $CH[0] eq undef }	# If it is linux , we should not try to create the / directory
for (my $j=++$i; $j<=$#CH; $j++) { mkdir(join '/', @CH[0..$j]) || return undef}		# start creating until the last existing
$dir
}


#   Calculate and return all the passed as array reference extra fields
#   The implemented extra fields are :
#
#   EXTRA_YEAR, EXTRA_MONTH, EXTRA_DAY, EXTRA_HOUR, EXTRA_MINUTE, EXTRA_SECOND, EXTRA_TIMESTAMP
#
sub Calculate_extra_field
{
my @Result;
my @Time = localtime time;
$Time[0] = sprintf "%02d",   $Time[0];
$Time[1] = sprintf "%02d",   $Time[1];
$Time[2] = sprintf "%02d",   $Time[2];
$Time[3] = sprintf "%02d",   $Time[3];
$Time[4] = sprintf "%02d", ++$Time[4];
$Time[5]+= 1900;

	foreach my $field (@{$_[0]})
	{
	given ($field) {
	when ('EXTRA_TIMESTAMP'){ push @Result, join('',@Time[5,4,3,2,1,0]) }
	when ('EXTRA_DAY')	{ push @Result, $Time[3] }
	when ('EXTRA_MONTH')	{ push @Result, $Time[4] }
	when ('EXTRA_YEAR')	{ push @Result, $Time[5] }
	when ('EXTRA_HOUR')	{ push @Result, $Time[2] }
	when ('EXTRA_MINUTE')	{ push @Result, $Time[1] }
	when ('EXTRA_SECOND')	{ push @Result, $Time[0] }
	default			{ die  "The extra virtual field \"$field\" have not been implemented yet\n" } }
	}

@Result
}



#   Grab user input
sub Parse_user_arguments_and_return_the_schemas
{
Getopt::Long::GetOptions(	
'config=s'	=> \my $config,
'version!'	=> \my $version,
"help|?!"	=> \my $help) || die "Syntax error. Use --help switch for more help.\n"; 

if ($version) {
print STDERR<<stop_versioning;
Disk file database version $VERSION\n
This program is GoodWare. That means if you
like it and use it, you have to do some good deeds.\n
George Bouras (gravitalsun\@hotmail.com)
Greece/Athens
stop_versioning
exit 4 }

if ($help) {
print STDERR<<stop_helping;
Disk file database version $VERSION . Syntax:

Show version: db_load_MultipleConfiguration.pl --version  (or -v --ver   etc ...)
Help screen : db_load_MultipleConfiguration.pl --help     (or -h --help  etc ...)
Load data   : db_load_MultipleConfiguration.pl [--config \$ConfigFile]
Examples
	db_load_MultipleConfiguration.pl -v
	db_load_MultipleConfiguration.pl
	db_load_MultipleConfiguration.pl --config /etc/load.cfg

--input is optional.  It is the path of your input data file you
want to load at the database. If it is missing, program search for
a file called  data.csv  at the same directory it resides.

--config is optional. It is the path of the loading configuration
file. If it is missing, program search for a file called
db_load_MultipleConfiguration.conf  at the same directory it resides.

This program works as it is to all operating systems without any
change. Just copy it at you machine and execute it !

This program is GoodWare. That means if you like it and use it, you
have to do some good deeds.\n
George Bouras (gravitalsun\@hotmail.com)
Greece/Athens
stop_helping
exit 3 }

($_=$0) =~s/[^\\\/]*$//; s/\\/\//g; s/\/*$//; $_ = '.' if $_ eq undef;
   $config     //= "$_/db_load_MultipleConfiguration.conf";

open( FILE, '<', $config) || die "Could not read the configuration file \"$config\" . Use --help switch for some help.\n";
my ($section, %option);
	while (<FILE>)
	{
	next if /^\s*(\;|\#)/;
	
		if (/^\s*\[\s*(.+?)\s*\]\s*$/)
		{
		exists $option{$^N} && die "The schema \"$^N\" is duplicated at your configuration file \"$config\" . Specify a different uniq name and try again.\n";
		$section = $^N;
		next
		}
	
	if ( /^\s*([^=]+?)\s*=\s*(.+?)\s*$/ ) { defined $section ? ( $option{$section}->{$1} = $2 ):( $option{$1} = $2 ) }
	}
close FILE;

	foreach my $name (keys %option)
	{
	next unless 'HASH' eq ref $option{$name};
	next if $option{$name}->{'Disable this database'} =~/(?i)y/;
	-f $option{$name}->{'Input data file'} || die "Your input data file \"$option{$name}->{'Input data file'}\" does not exist. Use --help for some help.\n";
	push @Schemas, {
	'name'			=> $name,
	'field_reverse'		=> {},
	'field_index_no'	=> [],			
	'dir_data'		=> $option{$name}->{'Data store location'},
	'separator'		=> $option{$name}->{'Field separator string'},
	'input_data'		=> $option{$name}->{'Input data file'},
	'field_all'		=> [ split /(?:\s*,\s*|\s+)/ , $option{$name}->{'Original field names'}     ],
	'field_index_yes'	=> [ split /(?:\s*,\s*|\s+)/ , $option{$name}->{'Fields with indexes'}      ],
	'field_extra'		=> [ split /(?:\s*,\s*|\s+)/ , $option{$name}->{'Extra virtual fields'}     ],
	'field_remove'		=> [ split /(?:\s*,\s*|\s+)/ , $option{$name}->{'Do not load these fields'} ],
	'field_case_lower'	=> [ split /(?:\s*,\s*|\s+)/ , $option{$name}->{'Fields to make lower case'}],
	'field_case_upper'	=> [ split /(?:\s*,\s*|\s+)/ , $option{$name}->{'Fields to make upper case'}]}
	}

-1 == $#Schemas	&& die "You need at least one active schema. Please specify it at \"$config\" configuration file.\n";
# use Data::Dumper; print Data::Dumper::Dumper(\@Schemas); exit; # view @Schemas
}
