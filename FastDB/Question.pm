# Perform queries to FastDB indexed database.
# Set tab to 8 spaces
#
# George Bouras
# Europe/Athens, gravitalsun@hotmail.com

BEGIN {
package Question;
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
my $class = ref shift || __PACKAGE__;
my $self  = 	{
		__OBJECT_METHODS =>
			{
			new				=> 'Create a new Question object',
			clone				=> 'Clone (copy) an existing object to an other new object.',
			question			=> 'Query FastDB database',
			DESTROY				=> 'Forcefully terminate the object instance. Have in mind that normally the object will auti destroyed at the end of your program automatically',
			AUTOLOAD			=> 'Trap calls to not implemented class methods',
			__NOT_AN_OBJECT			=> 'Internal method. Complain when a method is not called like am object',
			__SEARCH_FOR_DATA_RECURSIVE	=> 'Internal method. Searching the FastDB for data much the Filters',
			__EXAMINE_DATA			=> 'Internal method. For every found row applies filters and conditions',
			__SHOUT_THE_ANSWER		=> 'Internal method. Do something with the found data'
			}
		};

# Create more proprties from the external schema file $_[0]
local $_ = undef;
-f $_[0] || croak "Your schema file \"$_[0]\" does not exist. Please check the file name argument while calling the new method.\n";
open    FILE, '<', $_[0] or croak "Could not read schema file \"$_[0]\" because \"$^E\"\n";
while (<FILE>) { next if /^\s*(\;|\#)/; if ( /^\s*([^:]+?)\s*:\s*(.+?)\s*$/ ) {$self->{$1} = $2} }
close   FILE;
$self->{'dir_data_depth'} = $self->{'dir_data'}=~tr/\//\//;
$self->{'field_index'}	  = [ split /\s*\|\s*/ , $self->{'field_index'}];
$self->{'field_all'}	  = [ @{$self->{'field_index'}}, split /\s*\|\s*/, $self->{'field_noindex'} ];
delete $self->{'field_noindex'}; # we do not need it any more

# To examine the $self data structure so far
# use Data::Dumper; $Data::Dumper::Deparse=1; print STDOUT Data::Dumper::Dumper($self); exit;

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

  This is an auto generated message from method: $method_me

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

print STDERR "\n  Oups, big problem !\n\n  Could not access method \"$method\" in class \"$class\".\n";

	if ( ref $self )
	{
	print STDERR "\n  Existing methds are :\n\n";
	map { print STDERR  "  $_". (' 'x (25 - length $_)) ." : $self->{__OBJECT_METHODS}{$_}\n" } sort {lc($a) cmp lc($b)} grep /^[^_]{2}.*?[^_]{2}$/, sort { $a cmp $b } keys %{$self->{__OBJECT_METHODS}}
	}

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
return	undef
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



#   Load passed list to the database
#
sub question
{
my $self  = shift;
my $class = ref $self or __NOT_AN_OBJECT((caller 0)[3],$self,@_);
local $_;

for (my $i = 0; $i <= $#_; $i += 2) { $self->{$_[$i]} = $_[$i+1] }

croak "Error. At Results hash key inside the array reference you have defined ann odd number of items\n" unless 0 == ((1+$#{$self->{'Results'}}) % 2);
$self->{'Results'} = {@{$self->{'Results'}}}; # Transform Results array to hash

	# Clear Conditions
	foreach ( @{$self->{'Conditions'}} )
	{
	s/(\s|\;)*$//;
	s/\s+/ /g;
	s/\( /(/g;
	s/ \)/)/g;
	tr/(/(/ == tr/)/)/ || croak "Number of left/right parentheses do not match at condition \"$_\"\n"
	}

	# Clear Filters
	$_ = $self->{'Filters'}; $self->{'Filters'} = {};
	croak "Error. At Filters hash key inside the array reference you have defined ann odd number of items\n" unless 0 == ((1 + $#{$_}) % 2);
	for (my $i = 0; $i <= $#{$_}; $i += 2)
	{
	my ($fn,$fv)=($_->[$i],$_->[$i+1]);
	next if ( ( $fv eq '*' ) || ( $fv eq '.*' ) || ( $fv eq '.*' ) || ( $fv =~ /\s*\=\~\s*.\^?\.\*\$?./ ) );
	$fn ~~ @{$self->{'field_all'}} or croak "Filter \"$fn\" ( $fv ) is not one of the existing fields: ".  join("$self->{'separator'} ",@{$self->{'field_all'}})."\n";
	
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

		# Now we must check if the filter is simple like:   data eq "something"     or     data == 153
		if ( $fv =~/^data eq '(.+?)'$/ )
		{
		$self->{'Filters'}->{$fn} = { 'simple' => $1 }
		}
		else
		{
		(my $code = $fv) =~s/\bdata\b/\$_[0]/g;
		# We are using the following method :			$code = '( $_[0] > 100 ) and ( $_[0] < 400 )';
		#							$code = "sub { ($code) ?(return 1):(return 0)}";
		#							$code = eval $code or die "oups, bad perl code\n";   print $code->(200);		
		$code = "sub { ($code) ? ( return 1 ):( return 0 ) }";
		$code = eval $code or croak "Bad filter $_ code:   $self->{'Filters'}->{$_}\n";
		$self->{'Filters'}->{$fn} = { 'code' => $code }; 
		}
	} 

$self->{'Conditions'}					//= [];
$self->{'field_prepared'}				= [];
$self->{'field_return'}					= $self->{'Fields to return'}; return [] if -1 == $#{$self->{'field_return'}};
$self->{'Results'}->{'Print to standard output'}	= $self->{'Results'}->{'Print to standard output'} =~/(?i)y/ ?(1):(0);
$self->{'Results'}->{'Print to standard error'}		= $self->{'Results'}->{'Print to standard error'}  =~/(?i)y/ ?(1):(0);
$self->{'Results'}->{'Print to file'}			= $self->{'Results'}->{'Print to file'}	           =~/(?i)y/ ?(1):(0);
$self->{'Results'}->{'Return an array of arrays'}	= $self->{'Results'}->{'Return an array of arrays'}=~/(?i)y/ ?(1):(0);
delete $self->{'Fields to return'}; # we don't need it any more
$self->{'Found data'} = [] if $self->{'Results'}->{'Return an array of arrays'};

	if ( $self->{'Results'}->{'Pass to external Perl module'} =~/(?i)y/ )
	{
	eval "use $self->{'Results'}->{'Perl module name'}";
	unless ($@ eq '') { croak "Perl module \"$self->{'Results'}->{'Perl module name'}\" does not exist.\n" }
	$self->{'Results'}->{'Pass to external Perl module'} = "$self->{'Results'}->{'Perl module name'}::$self->{'Results'}->{'Function of the Perl module'}($self->{'Results'}->{'Code of how to pass data at function'})"
	}
	else
	{
	$self->{'Results'}->{'Pass to external Perl module'} = 0
	}


	# Open the output file if needed
	if ( $self->{'Results'}->{'Print to file'} )
	{
	(my $dir = $self->{'Results'}->{'File name'})=~s/\\/\//g;
	$dir =~/[^\/]*$/;
	$dir = ${^PREMATCH};
	$dir =~s/\/*$//;
	unless ( -d $dir ) { my ($i, @CH) = (0, split /\//, $dir, -1);
	for($i=$#CH; $i>=0; $i--) { last if -d join '/', @CH[0..$i] }
	if (($i == -1) && ($^O eq 'linux')) { splice @CH, 0, 2, "/$CH[1]" if $CH[0] eq undef }
	for (my $j=++$i; $j<=$#CH; $j++) { mkdir join '/', @CH[0..$j] } }
	open $self->{OUTPUT_FILE}, '>:raw', $self->{'Results'}->{'File name'} or croak "Could not create the output file \"$self->{'Results'}->{'File name'}\" because \"$^E\"\n"
	}

# Check if fields of 'field_return' exis as field in 'field_all'
foreach (@{$self->{'field_return'}}) { $_ ~~ @{$self->{'field_all'}} or croak "Field to return \"$_\" is not one of the existing fields: ". join("$self->{'separator'} ",@{$self->{'field_all'}})."\n" }

	# 'field_prepared' is an array with all the returned fields and their filters
	#  0       1            2               3
	#  name    index:1,0    returned:1,0    filter:undef,code

	for (my $i=0; $i<= $#{$self->{'field_all'}}; $i++)
	{
	$self->{'field_prepared'}->[$i][0] = $self->{'field_all'}->[$i];						# name             column 0
	$self->{'field_prepared'}->[$i][1] = $self->{'field_all'}->[$i] ~~ @{$self->{'field_index'}}  ? (1):(0);	# If it is indexed column 1
	$self->{'field_prepared'}->[$i][2] = $self->{'field_all'}->[$i] ~~ @{$self->{'field_return'}} ? (1):(0);	# If user want it  column 2
	$self->{'field_prepared'}->[$i][3] = $self->{'Filters'}->{$self->{'field_all'}->[$i]} || { 'null' => 0 };	# Filter           column 3. If there is no filter we this to a pseudo hash
	}

delete $self->{'Filters'}; # we don't need any more 'Filters' (All usefull info is at 'field_prepared')

	# From the field_prepared we should delete all the last fields where user does not want them, AND they have no filters
	for (my $i=$#{$self->{'field_prepared'}}; $i>=0; $i--)
	{
	( $self->{'field_prepared'}->[$i][2] == 0 ) && ( exists $self->{'field_prepared'}->[$i][3]->{'null'} ) ? ( splice @{$self->{'field_prepared'}}, $i, 1 ):( last )
	}

# Examine the table 'field_prepared'
# use Data::Dumper; $Data::Dumper::Indent=0; $Data::Dumper::Deparse=1; foreach (@{$self->{'field_prepared'}}) {print "$_->[0], $_->[1], $_->[2], ".Dumper($_->[3])."\n" } exit;

# Now we must change the array 'field_return' to change the columns names to column offsets
#  COLOR , WEIGHT , HEIGHT  ->  12 0 3

$_=[];
my %temp=(); # name -> position

	for (my $i=0; $i<=$#{$self->{'field_prepared'}}; $i++)
	{
		if ( $self->{'field_prepared'}->[$i][2] )
		{
		$temp{ $self->{'field_prepared'}->[$i][0] } = $i
		}
	}

	for (my $i=0; $i<=$#{$self->{'field_return'}}; $i++)
	{
	push @{$_}, $temp{$self->{'field_return'}->[$i]}
	}

undef %temp;
$self->{'field_return'} = $_;

# To examine the $self data structure so far
#use Data::Dumper; $Data::Dumper::Deparse=1; print STDOUT Data::Dumper::Dumper($self); exit;
#
# If there are not any indexes we will not dig (that means the first item of field_prepared is not indexed)

	if ( -1 == $#{$self->{'field_index'}} )
	{
	$self->__EXAMINE_DATA( $self->{'dir_data'}, -1)
	}
	else
	{
	$self->__SEARCH_FOR_DATA_RECURSIVE( $self->{'dir_data'} )
	}

close  $self->{OUTPUT_FILE} if $self->{'Results'}->{'Print to file'};

$self->{'Results'}->{'Return an array of arrays'} ? ( $self->{'Found data'} ) : ( [] )
}



#   What to do the found data
sub __SHOUT_THE_ANSWER
{
my $self  = shift;
my $class = ref $self or __NOT_AN_OBJECT((caller 0)[3],$self,@_);
local $_  = join($self->{'separator'}, @_);

print STDOUT			"$_\n"		if $self->{'Results'}->{'Print to standard output'};
print STDERR			"$_\n"		if $self->{'Results'}->{'Print to standard error'};
print {$self->{OUTPUT_FILE}}	"$_\x0A"	if $self->{'Results'}->{'Print to file'};
push @{$self->{'Found data'}}, \@_ 		if $self->{'Results'}->{'Return an array of arrays'};

	if ( $self->{'Results'}->{'Pass to external Perl module'} )
	{
	eval $self->{'Results'}->{'Pass to external Perl module'};
	$@ && {croak "Error while feeding function $self->{'Results'}->{'Perl module name'} --> $self->{'Results'}->{'Function of the Perl module'} the found data \"$_\" because $@\n" }
	}
}



sub __SEARCH_FOR_DATA_RECURSIVE
{
my $self  = shift;
my $class = ref $self or __NOT_AN_OBJECT((caller 0)[3],$self,@_);
my $dir   = shift;
my $level = $dir =~tr/\//\// - $self->{'dir_data_depth'};

	if ( exists $self->{'field_prepared'}->[$level]->[3]->{'simple'} )
	{
		if ( -d "$dir/$self->{field_prepared}->[$level]->[3]->{simple}" )
		{		
			if (( exists $self->{'field_prepared'}->[1+$level] ) && ( $self->{'field_prepared'}->[1+$level]->[1] ))
			{			
			$self->__SEARCH_FOR_DATA_RECURSIVE("$dir/$self->{field_prepared}->[$level]->[3]->{simple}")
			}
			else
			{
			$self->__EXAMINE_DATA("$dir/$self->{field_prepared}->[$level]->[3]->{simple}", $level)
			}
		}
	return
	}

opendir my $DIR, $dir or croak "Could not read column's \"$self->{'field_prepared'}->[$level-1][0]\" directory \"$dir\"\n";
	while (my $node = readdir $DIR )
	{
	next if $node eq '.' or $node eq '..';
	if ( exists $self->{'field_prepared'}->[$level]->[3]->{'code'} ) { next unless $self->{'field_prepared'}->[$level]->[3]->{'code'}->($node) }

		if (( exists $self->{'field_prepared'}->[1+$level] ) && ( $self->{'field_prepared'}->[1+$level]->[1] ))
		{	
		$self->__SEARCH_FOR_DATA_RECURSIVE("$dir/$node")
		}
		else
		{
		$self->__EXAMINE_DATA("$dir/$node", $level)
		}
	}
closedir $DIR
}






sub __EXAMINE_DATA
{
my $self  = shift;
my $class = ref $self or __NOT_AN_OBJECT((caller 0)[3],$self,@_);
my ($path, $level) = @_;

	# it is not neccassery to open the data file if       $level == $#{$self->{'field_prepared'}}
	# because all wanted fields are at directory names !
	if ( $level == $#{$self->{'field_prepared'}} )
	{
	$path =~s/^$self->{'dir_data'}\///;
	my @FLD = split '/', $path, -1;

		if ( -1 == $#{$self->{'Conditions'}} )
		{
		$self->__SHOUT_THE_ANSWER( @FLD[@{$self->{'field_return'}}] )
		}
		else
		{
		my $pass=1;
		my %field_value; # $field_value{field} => value
		@field_value{@{$self->{field_all}}} = @FLD; 

			foreach my $Condition (@{$self->{'Conditions'}})
			{
			( $_ = $Condition ) =~s/\b(.+?)\b/ exists $field_value{$^N} ? ( "'$field_value{$^N}'" ):( $^N ) /ge;
			$pass = eval $_;
			unless ($@ eq '') {croak "Syntax error at condition:  $Condition\n"}
			last unless $pass			
			}

		$self->__SHOUT_THE_ANSWER( @FLD[@{$self->{'field_return'}}] ) if $pass
		}
	return
	}

# Lets open the data file to search its data
open FILE, '<', "$path/data" or croak "Could not read data file \"$path/data\"\n";

	while (<FILE>)
	{
	chop; # we are sure of the final x0A character no matter if it is linux, mac or windowz so we don't use the slower chomp
	my $pass = 1;
	my @FLD  = split $self->{'separator'}, $_, -1;
		
		# Now we must apply filters to the rest fields. If one fails then all line's fields are skipped
		for (my ($i, $j) = (1+$level, 1+$level); $i <= $#{$self->{'field_prepared'}}; $i++)
		{
			unless ( exists $self->{'field_prepared'}->[$i]->[3]->{'null'} )
			{
				if ( exists $self->{'field_prepared'}->[$i]->[3]->{'simple'} )
				{
				unless ( $self->{'field_prepared'}->[$i]->[3]->{'simple'} eq $FLD[$i-$j] )	{$pass=0; last}
				}
				else
				{
				unless ( $self->{'field_prepared'}->[$i]->[3]->{'code'}->($FLD[$i-$j]) )	{$pass=0; last}
				}
			}
		}

	next unless $pass;
	$path =~s/^$self->{'dir_data'}\/?//;
	unshift @FLD, split('/', $path, -1);
	
		if ( -1 == $#{$self->{'Conditions'}} )
		{
		$self->__SHOUT_THE_ANSWER( @FLD[@{$self->{'field_return'}}] )
		}
		else
		{
		my %field_value; # $field_value{field} => value
		@field_value{@{$self->{field_all}}} = @FLD; 

			foreach my $Condition (@{$self->{'Conditions'}})
			{
			( $_ = $Condition ) =~s/\b(.+?)\b/ exists $field_value{$^N} ? ( "'$field_value{$^N}'" ):( $^N ) /ge;
			$pass = eval $_;
			unless ($@ eq '') {croak "Syntax error at condition:  $Condition\n"}
			last unless $pass			
			}
		
		$self->__SHOUT_THE_ANSWER( @FLD[@{$self->{'field_return'}}] ) if $pass
		}
	}

close FILE
}



#<EMD OF MODULE>
}1;
__END__


=head1 NAME

FastDB::Question - Ask questions to FastDB database and get back the answers

=head1 SYNOPSIS

	use FastDB::Question;
	
	my $obj    = Load->new( $SchemaFile );
	my $answer = $qry->question( %hash );

	foreach my $row (@{$answer}) { print "Columns : @{$row}\n" }

=head1 EXAMPLE

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
	                      '((COLOR eq "blue") or (COLOR eq "red")) and (COUNTRY eq "France")'
	                      ],
	'Results'          =>
	                      [
	                      'Return an array of arrays'             => 'Yes'           ,
	                      'Print to standard output'              => 'No '           ,
	                      'Print to standard error'               => 'no'            ,
	                      'Print to file'                         => 'Yes'           ,
	                      'File name'                             => '/tmp/OUTPUT.TXT',
	                      'Pass to external Perl module'          => 'Yes'           ,
	                      'Perl module name'                      => 'MIME::Base64'  ,
	                      'Function of the Perl module'           => 'encode_base64' ,
	                      'Code of how to pass data at function'  => 'join ",", @_'  ,
	                      ]
	);

	print "No data or 'Return an array of arrays' is set to No\n" if 0 == scalar @{$answer};
	foreach my $row (@{$answer}) {
	print "columns : @{$row}\n"
	}

=head1 DESCRIPTION

Ask questions to FastDB and to something with the found data. It is designed to provide unparallel speed. With correct indexes and questions you can get your data back much faster than other big database vendors.
You have two methods to select your data. Filters and Conditions. Filters are always faster than conditions. Conditions are applied to all columns, while every Filter is applied only to the column it is assigned to. It is also fast if you combine both Filters and Conditions. Good practice is to index the columns you are usually applying Filters.

Do not use conditions if you can do the same selection with Filters only.

You have several options of what to do the found data. For example you can pass them to another external perl module, or you can write them to file. All options except  'Return an array of arrays' are real time. That means they do something with the data the moment they found before the question finish. 
The answer can be several Terabytes with billions of lines, and the Perl process will not consume more memory than a simple “hello world”.
This cannot be done if 'Return an array of arrays' is set to ‘yes’ because at this case all data must be kept in memory , so do not set it for huge amount of returned data.

=head1 Functions

=over 4

=item my $qry = Question->new( $SchemaFile );

Creates a new FastDB::Question object. its only argument is database schema file.
The schema file is a unique file for every database, and it is created at first data load, inside data directory. Its name is "$DatabaseName.schema" 

=item   $qry->question( %hash )

Queries the database and do something with returned data. The %hash should have the keys


B<I<Fields to return>>

It is an array reference, of the columns you want to select. The column names are case sensitive. You can define as many columns you want, for example

[ 'TYPE', 'WEIGHT', 'COUNTRY', 'COLOR' ],

B<I<Filters>>

An array reference containing pairs of Columns and its assigned generic Perl code. They used for narrowing data selection.

You can have multiple Filters. Every Filter is assigned only to its column. At Perl code you can not write column names.
The Filter's order is not important. Every Filter is simple Perl code. Every filter can have multipe code lines separated by the ;
The last returned value of your code is examined if it is TRUE or FALSE.
The special string DATA is replaced with column values. For example:

	'Filters' =>
	[
	'YEAR'   =>  'DATA == 2009'                       ,
	'MONTH'  =>  'DATA eq "12"'                       ,
	'DAY'    =>  'DATA eq "01"'                       ,
	'HOUR'   => '(DATA ge "07" ) and (DATA le "07")'  ,
	'MINUTE' => '(DATA ge "57" ) and (DATA le "57")'  ,
	'SECOND' => '(DATA ge "48" ) and (DATA le "48")'  ,
	'COL8'   =>  'DATA =~/^49/'
	],

Filters work faster if their columns are indexed. Indexed columns are defined at first data load using the package FastDB::Load

B<I<Conditions>>

An array reference containing pieces of Perl code. They used for narrowing data selection.
Inside the Perl code you write any column you want , and its name is replaced by its value. Every condition can
have multipe code lines separated by the ;    The last returned value of your code is examined if it is TRUE or FALSE.  For example

	'Conditions' =>
                      [
                      '(WEIGHT >= 1500) and TYPE=~/2/'      ,
                      '((COLOR eq "green") or (COLOR eq "red")) and (COUNTRY eq "New Zeland")'
                      ], 

Conditions are slower than Filters and you must avoid them if you can have the same selection using only Filters.
But as you can use all columns you can built more complex expressions than Filters. You can have multiple Conditions.

B<I<Results>>

An array reference containing (as hash) settings and their values concerning how the results of the question should evaluated.
There setting are

	'Return an array of arrays'  =>  'Yes' or 'no'
	
		If it is yes then the found data are returned as an array of arrays.
		All found data are kept is system memory and returned all together when the question
		is finished. Be careful with this option when the estimated size of returned data are many gigabytes.
		A sampe code to dispatch the answer is
		
		foreach my $row (@{$answer}) { print "Columns: @{$row}\n" } 
	
	'Print to standard output'  =>  'Yes' or 'no'
	
		If it is yes then the found data are printed at standard output (usually the screen)
		at the moment they found while the question is still working. Does not consume system memory no matter how much the found data are.
	
	'Print to standard error'  =>  'Yes' or 'no'

		If it is yes then the found data are printed at standard error at the moment they found while the question is still working. Does not consume system memory no matter how much the found data are.

	'Print to file'  =>  'Yes' or 'no'
		
		If it is yes then the found data are printed at the specified file at the moment they found while the question is still working. Does not consume system memory no matter how much the found data are.
	
	'File name'  =>  $SomeFile
	
		The file name to print the found data. It does not have any effect if option 'Print to file' is set to No
	
	'Pass to external Perl module'  =>  'Yes' or 'no'
	
		If it is yes then the found data are passed to the external Perl module at the moment they found while the question is still working. Does not consume system memory no matter how much the found data are.
		The module's function is called for every found row. The passed data are the values of the columns defined at 'Fields to return'
	
	'Perl module name'  =>  $Module
	
		The Perl module to pass the found data. It does not have any effect if option 'Pass to external Perl module' is set to No
	
	'Function of the Perl module'  =>  $Module::$Function
	
		The function of the external Perl module to pass the found data. It does not have any effect if option 'Pass to external Perl module' is set to No
	
	'Code of how to pass data at function'  =>  perl code passing @_
	
		Here you can take control of how your row columns values will passes at function. You can use a sipmle '@_' to pass them as list;  'join ",", @_'  to pass the as one string or whatever else fits your needs.
		
here is a sample 'Results' key
	
'Results' =>   
[ 
'Return an array of arrays'             => 'No'            ,
'Print to standard output'              => 'No'            ,
'Print to standard error'               => 'no'            ,
'Print to file'                         => 'Yes'           ,
'File name'                             => './answer.txt'  ,
'Pass to external Perl module'          => 'No '           ,
'Perl module name'                      => 'MIME::Base64'  ,
'Function of the Perl module'           => 'encode_base64' ,
'Code of how to pass data at function'  => 'join ",", @_' 
]


=back

=head1 NOTES

Some usefull basic operators you can use for 'Filters' and 'Conditions' (there are much more)

	eq                string equal
	ne                string not equal
	==                number equal
	!=                number not equal
	>                 number greater
	<                 number less
	>=                number greater or equal 
	<=                number less    or equal
	gt                string greater
	lt                string less
	ge                string greater or equal 
	le                string less    or equal 
	uc                upper case
	lc                lower case
	=~/something/     like      case sensitive
	=~/something/i    iike   no case sensitive

=head1 INSTALL

Because this module is implemented with pure Perl it is enough to copy FastDB directory somewhere at your @INC
or where your script is. For your convenient you can use the following commands to install/uninstall the module

	Install:     setup_module.pl u-install   --module=FastDB

	Uninstall:   setup_module.pl u-uninstall --module=FastDB

=head1 AUTHORS

Author:
gravitalsun@hotmail.com (George Mpouras)

=head1 COPYRIGHT

Copyright (c) 2011, George Mpouras, gravitalsun@hotmail.com All rights reserved.

This program is free software; you may redistribute it and/or
modify it under the same terms as Perl itself.

=cut