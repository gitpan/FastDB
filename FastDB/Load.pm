	# Load data to FastDB indexed database.
# Extra dynamic fields you can use at loading time
#
#   EXTRA_YEAR, EXTRA_MONTH, EXTRA_DAY, EXTRA_HOUR, EXTRA_MINUTE, EXTRA_SECOND, EXTRA_TIMESTAMP
#
# Set tab to 8 spaces
#
# George Bouras
# Europe/Athens, gravitalsun@hotmail.com

BEGIN {
package Load;
require 5.10.0;
our	$VERSION = '2.0.1';
our     @ISA     = ();
use	feature 'switch';
use	strict;
use	warnings;
use	Carp;

#   Create and initialize a new FastDB::Load object
#
sub new
{
my $class	=  ref shift || __PACKAGE__;
my $self	=  {
lines		=> 0,
__OBJECT_METHODS=> {
new		=> 'Create a brand new object',
clone		=> 'Clone (copy) an existing object to an other new object.',
DESTROY		=> 'Forcefully terminate the object instance. Have in mind that normally the object will auti destroyed at the end of your program automatically',
AUTOLOAD	=> 'Trap calls to not implemented class methods',
__NOT_AN_OBJECT	=> 'Internal package method to complain when a method is not called like am object',
load		=> 'Load passed data (as list) to FastDB database' } };

# grab pashed hash keys and values
for (my $i = 0; $i <= $#_; $i += 2) { $self->{$_[$i]} = $_[$i+1] }

$self->{'field_reverse'}	= {};
$self->{'field_noindex'}	= [];			
$self->{'separator'}		= $self->{'Field separator string'};	delete $self->{'Field separator string'};
$self->{'field_index'}		= $self->{'Indexed fields'};		delete $self->{'Indexed fields'};
$self->{'Data store location'}	=~s/\\/\//gs;
$self->{'Data store location'}	=~s/\/*$//gs;

	local $_ = $self->{'Transform'}; $self->{'Transform'} = {};
	croak "Error. At Transform hash key inside the array reference you have defined ann odd number of items\n" unless 0 == ((1 + $#{$_}) % 2);

	# Clear, correct and make hash the 'Transform'
	for (my $i = 0; $i <= $#{$_}; $i += 2)
	{
	my ($fn,$fv)=($_->[$i],$_->[$i+1]);
	next if ( ( $fv eq '*' ) || ( $fv eq '.*' ) || ( $fv eq '.*' ) || ( $fv =~ /\s*\=\~\s*.\^?\.\*\$?./ ) );
	
	$fv =~s/(?i)\bdata\b/data/g;		# se DaTA to data
	$fv =~s/\s*(.*?)\s*/$1/;		# remove suffix and prefix spaces
	$fv=~s/DATA\s*=!/data!=/ig;		# Correct the =! to !=
	$fv=~s/DATA\s*=>/data>=/ig;		# Correct the => to >=
	$fv=~s/DATA\s*=</data<=/ig;		# Correct the =< to <=
	$fv=~s/DATA\s*=([^=~!])/data==$1/ig;	# Correct the =  to ==
	$fv=~s/^eq\s+/eq /;			# Clear the not needed spaces
	$fv=~s/^==\s+/== /;					
	$fv=~s/^>=\s+/>= /;
	$fv=~s/^<=\s+/<= /;
	$fv=~s/^=~\s+/=~/;
	$fv=~s/;*$//;

		if ( $fv =~/^data\s*(==|eq)\s*(.*)$/ )
		{
		my $exp = $2;
		$exp =~s/^"(.+?)"$/$1/;
		$exp =~s/^'(.+?)'$/$1/;
		$fv = "data eq '$exp'"
		}

	unless ( ( $fn ~~ @{$self->{'Original field names'}} ) || ( $fn ~~ @{$self->{'Extra virtual fields'}} ) ) { croak "At database \"$self->{'Name'}\", field \"$fn\" you want to transform using the code \"$fv\" is not defined at properties \"Original field names\" or \"Extra virtual fields\" : ".join(', ',(@{$self->{'Original field names'}},@{$self->{'Extra virtual fields'}}))."\n" }
	(my $code = $fv) =~s/\bdata\b/\$field/g;
	$code = "sub {my \$field = \$_[0]; $code }";
	$code = eval $code or croak "Bad filter $_ code: $self->{'Transform'}->{$_}\n";
	$self->{'Transform'}->{$fn} = $code
	}

CreateDir($self->{'Data store location'}) || croak "Could not create the data directory \"$self->{'Data store location'}\"\n";

	# Examine the entries of field_index
	for (my $i=$#{$self->{'field_index'}} ; $i>=0 ; $i--)
	{
		# Check if the field_index item is valid
		unless ( ( $self->{'field_index'}->[$i] ~~ @{$self->{'Original field names'}} ) || ( $self->{'field_index'}->[$i] ~~ @{$self->{'Extra virtual fields'}} ) )
		{
		croak "At database \"$self->{'Name'}\", field \"$self->{'field_index'}->[$i]\" you want to index is not defined at \"Original field names\" or \"Extra virtual fields\"\n"
		}
	}

	# Define the  field_noindex  list. We are using  de-duplication technology to not include any indexed fields at field_noindex list
	foreach ( @{$self->{'Original field names'}} , @{$self->{'Extra virtual fields'}} )
	{
	next if $_ ~~ @{$self->{'field_index'}};
	croak "Your column \"$_\" contains a | which not allowed at column names\n" if $_=~/\|/;
	push @{$self->{'field_noindex'}} , $_;
	}

# Define the hash ref    $self->{'field_reverse'}   . We are using the power of hash slice   @hash{@array}=list  to accomplish this task  
@{$_} = ( @{$self->{'Original field names'}} , @{$self->{'Extra virtual fields'}} );
@{$self->{'field_reverse'}}{@{$_}} = ( 0 .. $#{$_} );
-2  == ( $#{$self->{'field_index'}} + $#{$self->{'field_noindex'}} ) && croak "At schema \"$self->{'Name'}\" you have not define any index or data column indsite the configuration file\n";

	# Write schema information at first loading, or check the data schema on next loadings
	unless ( -f "$self->{'Data store location'}/$self->{'Name'}.schema" )
	{
	open  FILE,'>:raw', "$self->{'Data store location'}/$self->{'Name'}.schema" or croak "Could not create schema file \"$self->{'Data store location'}/$self->{'Name'}.schema\" because \"$^E\"\n";
	print FILE "name          : $self->{'Name'}\x0A";
	print FILE "dir_data      : $self->{'Data store location'}/$self->{'Name'}\x0A";
	print FILE "separator     : $self->{'separator'}\x0A";
	print FILE 'field_index   : '. join('|', @{$self->{'field_index'}}) ."\x0A";
	print FILE 'field_noindex : '. join('|', @{$self->{'field_noindex'}} );
	close FILE 
	}
	else
	{
	my %check_schema;
	open    FILE, '<', "$self->{'Data store location'}/$self->{'Name'}.schema" or croak "Could not retrieve schema information from file \"$self->{'Data store location'}/$self->{'Name'}.schema\" because \"$^E\"\n";
	while (<FILE>) { /^\s*(?<Key>[^:]+?)\s*:\s*(?<Value>.*?)\s*$/ or next; $check_schema{$+{Key}} = $+{Value} }
	close   FILE;
	$check_schema{'name'}      eq $self->{'Name'}					or croak "Your current database name \"$check_schema{'name'}\" is different from the one you are tring to load \"$self->{'Name'}\"\n";
	$check_schema{'separator'} eq $self->{'separator'}				or croak "Schema error. \"$self->{'Name'}\" property \"separator\" has value \"$check_schema{'separator'}\" while you current load configuration is set to \"$self->{'separator'}\"\n";
	$check_schema{'dir_data'}  eq "$self->{'Data store location'}/$self->{'Name'}"	or croak "Schema error. \"$self->{'Name'}\" property \"Data store location\"  has value \"$check_schema{'dir_data'}\"  while you current load configuration is set to \"$self->{'Data store location'}/$self->{'Name'}\"\n";

		unless ( $#{[split /\s*\|\s*/,$check_schema{'field_index'}]} + $#{[split /\s*\|\s*/,$check_schema{'field_noindex'}]} == $#{$self->{'Original field names'}} + $#{$self->{'Extra virtual fields'}} )
		{
		croak "Schema error. \"$self->{'Name'}\" has ". (2 + $#{[split /\s*\|\s*/,$check_schema{'field_index'}]} + $#{[split /\s*\|\s*/,$check_schema{'field_noindex'}]}) . " fields while you are trying to load ". (2 + $#{$self->{'Original field names'}} + $#{$self->{'Extra virtual fields'}} ) ."\n"
		}

		unless ( $#{[split /\s*\|\s*/,$check_schema{'field_index'}]} == $#{$self->{'field_index'}} )
		{
		croak "Schema error. \"$self->{'Name'}\" has ". (1+$#{[split /\s*\|\s*/,$check_schema{'field_index'}]}) . " indexed fields while you current load configuration has ". (1+$#{$self->{'field_index'}}) ."\n"
		}
	}

# @{$self->{'Original field names'}}		All the fields of the input file
# $self->{'field_index'}		Fields we want to index
# $self->{'field_noindex'}		Fields we want to simple store their data 
# $self->{'field_reverse'}		Field index
#
#use Data::Dumper; $Data::Dumper::Deparse=1; print STDOUT Data::Dumper::Dumper($self); exit;
bless ($self,$class);

return $self
}



sub __NOT_AN_OBJECT
{
(my $method_no  = shift) =~s/.*://;
my  $method_me  = (caller 0)[3];
my  $class      = __PACKAGE__;
my  $argument	=  join ', ', @_;
my  $self       = new();
my  $user       = $^O =~/(?i)win/ ? ( "\u$ENV{USERNAME}" ):( "\u$ENV{LOGNAME}" );

print STDERR<<STOP_PRINTING;

  Hello $user,

  Method \"$method_no\" of package \"$class\"
  did not called with object oriented way. 
  Change your code similar to the following lines
  and try again.
  
        use $class;
        my  \$object = $class->new( ... );
            \$object->$method_no("$argument");

  This is an auto generated message from method:
  $method_me

STOP_PRINTING
exit 1;
}


#   This is triggered when user trying to use a non existing method
#
sub AUTOLOAD
{
my  $self   = shift;
my  $class  = ref $self || __PACKAGE__;
(my $method = eval "\$$class\::AUTOLOAD") =~s/.*://;

print STDERR "\n  Oups, big problem !\n\n  Could not access method \"$method\" in class \"$class\".\n  Existing methds are :\n\n";
map { print STDERR  "  $_". (' 'x (25 - length $_)) ." : $self->{__OBJECT_METHODS}{$_}\n" } sort {lc($a) cmp lc($b)} grep /^[^_]{2}.*?[^_]{2}$/, sort { $a cmp $b } keys %{$self->{__OBJECT_METHODS}};
print STDERR "\n  Method AUTOLOAD of class \"$class\" terminate your program\n";
exit 0
}



sub DESTROY
{
my	$self 	= shift;
my	$class  = ref $self || __PACKAGE__;
(my	$method	= (caller 0)[3]) =~s/.*://;
ref	$self	|| croak "Method \"$method\" of class \"$class\" did not called as object like   \$object->$method(Arg1, Arg2, ...);   Correct your code and try again.\n";
undef %{$self};
undef   $self;
return  undef;
}



# Create a new object method to an already existing
#
sub clone
{
my  $self  = shift;
my  $class = ref $self || __PACKAGE__;

	
	if ( ref $self )
	{
	my $clone = {};
	foreach ( keys %{$self} ) { $clone->{$_} = $self->{$_} }
	for (my $i=0; $i<=$#_; $i += 2) { $clone->{$_[$i]} = $_[$i+1] }
	return bless($clone,$class);
	}
	
	# Alternative way of calling the new
	else
	{			
	$self = $class->new( @_ );
	return bless($self, $class);
	}
}



#   Create nested directory and all the upper path that may missing.
#   returns the directory on success, or undef on error
#
sub CreateDir
{
my ($i, @CH) = (0, split /\//, $_[0], -1);
for($i=$#CH; $i>=0; $i--) { last if -d join '/', @CH[0..$i] }				# find the last existing directory
if (($i == -1) && ($^O eq 'linux')) { splice @CH, 0, 2, "/$CH[1]" if $CH[0] eq undef }	# If it is linux , we should not try to create the / directory
for (my $j=++$i; $j<=$#CH; $j++) { mkdir(join '/', @CH[0..$j]) || return undef}		# start creating directories until the last existing
$_[0]
}



#   Calculate and return extra fields The implemented extra fields are:
#
#	EXTRA_TIMESTAMP
#	EXTRA_YEAR
#	EXTRA_MONTH
#	EXTRA_MONTH_NAME
#	EXTRA_DAY
#	EXTRA_DAY_NAME
#	EXTRA_HOUR
#	EXTRA_MINUTE
#	EXTRA_SECOND
#
sub Calculate_extra_field
{
my @Time = localtime time;
my @R;
	foreach my $field (@{$_[0]})
	{
	given ($field) {
	when('EXTRA_YEAR')	{ push @R, (1900+$Time[5]) }
	when('EXTRA_TIMESTAMP')	{ push @R, sprintf "%04d%02d%02d%02d%02d%02d", (1900+$Time[5]),(1+$Time[4]),@Time[3,2,1,0] }
	when('EXTRA_MONTH_NAME'){ push @R, (qw/Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec/)[$Time[4]] }
	when('EXTRA_MONTH')	{ push @R, sprintf "%02d",(1+$Time[4]) }
	when('EXTRA_DAY')	{ push @R, sprintf "%02d", $Time[3] }
	when('EXTRA_DAY_NAME')	{ my ($d,$m,$y)=($Time[3],1+$Time[4],1900+$Time[5]); $m < 3 && $y--; push @R, {0,'Sun',1,'Mon',2,'Tue',3,'Wed',4,'Thu',5,'Fri',6,'Sat'}->{($d + ((qw/0 3 2 5 0 3 5 1 4 6 2 4/)[$m-1]) +$y+(int($y/4))-(int($y/100))+(int($y/400)))%7} }
	when('EXTRA_HOUR')	{ push @R, sprintf "%02d", $Time[2] }
	when('EXTRA_MINUTE')	{ push @R, sprintf "%02d", $Time[1] }
	when('EXTRA_SECOND')	{ push @R, sprintf "%02d", $Time[0] }
	default			{ croak "The extra virtual field \"$field\" have not been implemented yet\n" } }
	}
@R
}



#   Write some metadata. At future, more functionality could be added here
#   This should be user`s last call, when all data have been loaded.
#   The usage of this function is optional.
#
sub Write_statistics_at_the_end
{
my $self	= shift;
my $class	= ref $self or __NOT_AN_OBJECT((caller 0)[3],$self,@_);
my $logfile	= exists $_[0] ? ( $_[0] ):( "$self->{'Data store location'}/$self->{'Name'}.log" );
my $saytime	= sub { local $_=[]; @{$_} = localtime($_[0]); $_->[5]+=1900; sprintf '%02d-%s-%04d %02d:%02d:%02d', $_->[3], (qw/Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec/)[$_->[4]], @{$_}[5,2,1,0] };		# Return date and time as DD-mmm-YYYY hh:mm:ss  ( 31-Dec-2012 23:59:59 )

open  FILE, '>>:raw', $logfile or croak "Could not create metadata file \"$logfile\" because \"$^E\"\n";
print FILE  "Start loading : ". $saytime->($^T)  ."\x0A";
print FILE  "End   loading : ". $saytime->(time) ."\x0A";
print FILE  "Loaded rows   : ". $self->{'lines'} ."\x0A";
print FILE ('-' x37)."\x0A";
close FILE
}



#   Load passed list to the database
#
sub load
{
my $self  = shift;
my $class = ref $self or __NOT_AN_OBJECT((caller 0)[3],$self,@_);

local $_;
my @col = @_;
unless ( $#{$self->{'Original field names'}} == $#col ) { warn "Skip line not ".(1+$#{$self->{'Original field names'}})." fields at line $. = $_\n"; next }
push( @col, Calculate_extra_field($self->{'Extra virtual fields'}) ) unless -1 == $#{$self->{'Extra virtual fields'}};
++$self->{'lines'};

	# Apply field transformations
	foreach (keys %{$self->{'Transform'}})
	{
	$col[$self->{'field_reverse'}->{$_}] = $self->{'Transform'}->{$_}->( $col[$self->{'field_reverse'}->{$_}] )
	}

# Create the upper schema directories
$_ = "$self->{'Data store location'}/$self->{'Name'}/". join('/', map { $col[$self->{'field_reverse'}->{$_}] } @{$self->{'field_index'}});
CreateDir($_) || croak "Could not create directory \"$_\" because \"$^E\"\n";

# Write the rest data to the data file
return if -1 == $#{$self->{'field_noindex'}};
open  FILE, '>>:raw', join('/', $_, 'data');
print FILE join($self->{'separator'}, map{ $col[$self->{'field_reverse'}->{$_}] } @{$self->{'field_noindex'}}) ."\x0A";
close FILE
}





#<EMD OF MODULE>
}1;
__END__



=head1 NAME

FastDB::Load - Load data to FastDB database

=head1 SYNOPSIS

	use FastDB::Load;

	my $obj = Load->new(
	'Name'                     => 'Database name',
	'Data store location'      => 'Directory to store the data',
	'Field separator string'   => '|'  ,
	'Original field names'     => [ Columns         ],
	'Indexed fields'           => [ Indexed columns ],
	'Extra virtual fields'     => [ Extra   columns ],
	'Transform'                => [
	                              'Some column 1' => 'my $a = lc DATA; $a = reverse $a; return $a;',
	                              'Some column 2' => 'lc DATA'                ,
	                              'Some column 3' => 'uc DATA;'               ,
	                              ]
	);

	$load->load( 'a1' , 'a2', 'a3', ...  );
	$load->load( 'b1' , 'b2', 'c3', ...  );
	...
	$obj->Write_statistics_at_the_end();

=head1 EXAMPLE

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

=head1 DESCRIPTION

FastDB is a file based database. It is using directories to store the indexed
columns. Also there is implemented deduplication to avoid storing the same data
where it is possible. Your database and its schema will be created at first
data load. After the first data load it is not possible to add or remove columns.

It is written at Pure perl, so it can run on all operating systems. It is
designed to give answers as fast your disk and operating system is.

This module load your data to a FastDB database. At loading time you can
edit your data of every column using generic Perl code defined at the
property 'Transform'. Its column should have its own code. You can have
transform to one or more columns. The special string DATA (or data) is
replaced with the currect column value, at loading time
'Transform' is optional, do not use it if you do not want.

At the end of loading it is suggested to call the optional function 'Write_statistics_at_the_end'  to write some short info to a file.


=head1 Functions

=over 4

=item my $load = Load->new( %hash );

Creates a new FastDB::Load object. %hash must have the keys

B<I<Data store location>>

The root directory that will hold your data

B<I<Name>>

The name of your database. This will also become a subdirectory of the B<I<Data store location>>

B<I<Field separator string>>

This is used internal to separated columns from each other. Can be more than one characters. You must select a string that there is no case to be found at your data

B<I<Extra virtual fields>>

At loading time you can optional load the following fields that do not exists at your data . Their values
calculated at loading time. The values may change if your load continue for long time.
The name of these fields and some sample values are

	EXTRA_DAY          01  - 31
	EXTRA_DAY_NAME     Sun - Sat
	EXTRA_MONTH_NAME   Jan - Dec
	EXTRA_MONTH        01  - 12
	EXTRA_YEAR         2012
	EXTRA_HOUR         00  - 23
	EXTRA_MINUTE       00  - 59
	EXTRA_SECOND       00  - 59
	EXTRA_TIMESTAMP    20121201123957  ( YYYYMMDDhhmmss )

B<I<Original field names>>

An array reference of your column names. Do not include here again the B<I<Extra virtual fields>>
The case is important. Field names must not contain the character |

B<I<Indexed fields>>

An array reference of the columns you want to index. You define any any original or extra field.
Do not define more than you really need. These will become subdirectories.

B<I<Transform>>

An array reference with the data transformations . You can use this, to transfrom your data at loading time.
You define the column name and some Perl code. Perl code is applied over column data, and FastDB is storing
its returned value. The special string DATA is replaced at loading time with the current value.
Every Transformation is applied only to its column. You can not use column names inside the Perl code.
The order of 'Transform' is not important. Its syntax is

	'SOME COLUMN 1' => 'Perl code do something with the "DATA"',
	'SOME COLUMN 2' => 'ucfirst DATA',
	'SOME COLUMN 3' => 'my $var = DATA ; blah blah blah ; $var',
	and so on

=item $load->load( col1, col2, ... );

A list of data you want to store as a row. The fields order should be the same as the column names at B<I<Original field names>>

normally you will put this inside a loop that read and split lines from a file, socket or whatever.


=item $load->Write_statistics_at_the_end( [SomefFile] );

Optional method. Writes to a file how many rows loaded and long it took. It takes as optional argument the file
to write this info to. If you do not specify an file it will use the string
"$load->{'Data store location'}/$load->{'Name'}.log"

	$load->Write_statistics_at_the_end();
	$load->Write_statistics_at_the_end( $SomeFile );
	$load->Write_statistics_at_the_end( "$load->{'Data store location'}/$load->{'Name'}.log" );

=back

=head1 NOTES

There is a case to have problem at microsoft windows when you have multiple
indexes with long values because of the 255 characters NTFS max
path limitation.

It is recommented to use a linux partition (or a mounted file)
formatted with btrfs file system ( ext4 is also good but not as fast as btrfs). Ext3, Fat16 are not recommended.

=head1 INSTALL

Because this module is implemented with pure Perl it is enough to copy FastDB directory somewhere at your @INC
or where your script is. For your convenient you can use the following commands to install/uninstall the module

	Install:     setup_module.pl –-install   --module=FastDB

	Uninstall:   setup_module.pl –-uninstall --module=FastDB

=head1 AUTHORS

Author:
gravitalsun@hotmail.com (George Mpouras)

=head1 COPYRIGHT

Copyright (c) 2011, George Mpouras, gravitalsun@hotmail.com All rights reserved.

This program is free software; you may redistribute it and/or
modify it under the same terms as Perl itself.

=cut
