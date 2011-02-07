# Delete data that match the specified criteria from FastDB database.
# Set tab to 8 spaces.
#
# George Bouras
# Europe/Athens, gravitalsun@hotmail.com

BEGIN {
package Delete;
require 5.10.0;
our	$VERSION = '2.0.2';
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
__OBJECT_METHODS		=> {
new				=> 'Create a brand new object',
delete				=> 'Delete data from FastDB database',
clone				=> 'Clone (copy) an existing object to an other new object.',
DESTROY				=> 'Forcefully terminate the object instance. Have in mind that normally the object will automatic destroyed at the end of your program automatically',
AUTOLOAD			=> 'Trap calls to not implemented class methods',
__NOT_AN_OBJECT			=> 'Internal package method to complain when a method is not called like am object',
__SEARCH_FOR_DATA_RECURSIVE	=> 'Internal method. Searching the FastDB for data much the Filters',
__EXAMINE_DATA			=> 'Internal method. For every found row applies filters' } };

local $_;
croak "Odd number of arguments while calling Delete::new function. Is it really a hash ?\n" unless 0 == ((1+$#_) % 2);
for (my $i = 0; $i <= $#_; $i += 2) { $self->{$_[$i]} = $_[$i+1] }

-f $self->{'Schema file'} || croak "Your schema file \"$self->{'Schema file'}\" does not exist. Please check the file name argument while calling the new method.\n";
open    FILE, '<', $self->{'Schema file'} or croak "Could not read schema file \"$self->{'Schema file'}\" because \"$^E\"\n";
while (<FILE>) { next if /^\s*(\;|\#)/; if ( /^\s*([^:]+?)\s*:\s*(.+?)\s*$/ ) {$self->{$1} = $2} }
close   FILE;

$self->{'dir_data_depth'}			= $self->{'dir_data'}=~tr/\//\//;
$self->{'field_index'}				= [ split /\s*\|\s*/, $self->{'field_index'}];
$self->{'field_all'}				= [ @{$self->{'field_index'}}, split /\s*\|\s*/, $self->{'field_noindex'} ];
$self->{'Allow deletion with no filters'}	= $self->{'Allow deletion with no filters'}   =~/(?i)Y/ ? (1):(0);
$self->{'Show activity at standard output'}	= $self->{'Show activity at standard output'} =~/(?i)Y/ ? (1):(0);

delete $self->{'field_noindex'}; # we do not need it any more
delete $self->{'Schema file'}; 	 # we do not need it any more

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



#   Start deleting files and directories to the root of the passed directory
#   until two or more files or directories found
#
sub __DELETE_DIRECTORIE_TREES_UNTIL_MULTIPLE_NODES_FOUND
{
my $self  = shift;
my $class = ref $self or __NOT_AN_OBJECT((caller 0)[3],$self,@_);

my @Chop = -d $_[0] ? (split /\//, $_[0]):(return undef);

	for (my $i = $#Chop - 1; $i >= 0; $i--)
	{
	my $dir = join '/', @Chop[0..$i];
	my $j   = 0;
	opendir DIRECTORY, $dir or croak "Could not list directory \"$dir\"\n";
	while (readdir DIRECTORY) { if ($j == 3) {$j=0; last}; $j++ }
	closedir DIRECTORY;
	
		unless ($j)
		{
		$dir = join '/', @Chop[0 .. ++$i];
		print STDOUT "Removing directory tree \"$dir\"\n" if $self->{'Show activity at standard output'};
		$^O  =~/(?i)MSWin/ ? (`RD /S /Q "$dir" 1> nul 2> nul`):(`rm -rf "$dir" 1> /dev/null 2> /dev/null`);
		-d $dir ? ( croak "Could not remove directory tree \"$dir\" because \"$^E\"\n" ):( return $dir )
		}
	}
undef
}



#   Delete all data from database that match user Filters
#
sub delete
{
my $self  = shift;
my $class = ref $self or __NOT_AN_OBJECT((caller 0)[3],$self,@_);

croak "Odd number of arguments while calling Delete::delete function. Is it really a hash ?\n" unless 0 == ((1+$#_) % 2);
local $_;
$self->{'Filters'} = {};

	# Clear, correct and make hash the 'Transform'
	for (my $i = 0; $i <= $#_; $i += 2)
	{
	my ($fn,$fv)=($_[$i],$_[$i+1]);
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
		#							$code = eval $code or die "oups, bad perl code\n"; print $code->(200);
		$code = "sub { ($code) ? (return 1):(return 0) }";
		$code = eval $code or croak "Bad filter $fn code:   $self->{'Filters'}->{$fv}\n";
		$self->{'Filters'}->{$fn} = { 'code' => $code } 
		}	
	}

	if ( (0 == scalar keys %{$self->{'Filters'}}) && ($self->{'Allow deletion with no filters'} == 0) )
	{
	print STDOUT "You have not define any filter, so all your database \"$self->{'name'}\" data would get deleted, but this will not happen because you have set property 'Allow deletion with no filters' to No . If this is not the desired behaviour set it to yes";
	return 0
	}


	# Define the   field_prepared   array of arrays
	# This is an array with all the filters
	#  0       1            2
	#  name    index:1,0    filter:undef,code    
	$self->{'field_prepared'} = [];
	for (my $i=0; $i<= $#{$self->{'field_all'}}; $i++)
	{
	$self->{'field_prepared'}->[$i][0] = $self->{'field_all'}->[$i];						# name             column 0
	$self->{'field_prepared'}->[$i][1] = $self->{'field_all'}->[$i] ~~ @{$self->{'field_index'}}  ? (1):(0);	# If it is indexed column 1
	$self->{'field_prepared'}->[$i][2] = $self->{'Filters'}->{$self->{'field_all'}->[$i]} || { 'null' => 0 };	# Filter           column 2. If there is no filter we this to a pseudo hash
	}

	# From the field_prepared we should delete all the last fields that have no filters
	for (my $i=$#{$self->{'field_prepared'}}; $i>=0; $i--)
	{
	exists $self->{'field_prepared'}->[$i][2]->{'null'} ? ( splice @{$self->{'field_prepared'}}, $i, 1 ):( last )
	}

#use Data::Dumper; $Data::Dumper::Deparse=0; foreach (@{$self->{'field_prepared'}}) { print "name = $_->[0] , index = $_->[1] , filter = ". Dumper($_->[2]) ."\n" } exit;
delete $self->{'Filters'}; # we do not need it any more
open   $self->{JUNK}, '>:raw', "$self->{'dir_data'}.junk" or croak "Could not create temporary file \"$self->{'dir_data'}.junk\"\n";

	if (( -1 == $#{$self->{'field_index'}} ) || ( -1 == $#{$self->{'field_prepared'}} ))
	{	
	$self->__EXAMINE_DATA($self->{'dir_data'}, -1)
	}
	else
	{	
	$self->__SEARCH_FOR_DATA_RECURSIVE($self->{'dir_data'})
	}

close $self->{JUNK};
unless ( -z "$self->{'dir_data'}.junk" ) {
open	FILE, '<', "$self->{'dir_data'}.junk" or croak "Could not read temporary file \"$self->{'dir_data'}.junk\"\n";
while (<FILE>) { chop $_; $self->__DELETE_DIRECTORIE_TREES_UNTIL_MULTIPLE_NODES_FOUND($_) }
close	FILE }
if (-1 == $#{$self->{'field_prepared'}} ) { mkdir $self->{'dir_data'} or croak "Could not create directory \"$self->{'dir_data'}\"\n" unless -d $self->{'dir_data'} }
unlink("$self->{'dir_data'}.junk") ? ( return 1 ):( croak "Could not delete file \"$self->{'dir_data'}.junk\"\n" );
}



sub __SEARCH_FOR_DATA_RECURSIVE
{
my $self  = shift;
my $class = ref $self or __NOT_AN_OBJECT((caller 0)[3],$self,@_);
my $dir   = shift;
my $level = $dir =~tr/\//\// - $self->{'dir_data_depth'};

	if ( ( $#{$self->{'field_prepared'}} >= $level ) && ( exists $self->{'field_prepared'}->[$level]->[2]->{'simple'} ) )
	{
		if ( -d "$dir/$self->{'field_prepared'}->[$level]->[2]->{'simple'}" )
		{		
			if (( exists $self->{'field_prepared'}->[1+$level] ) && ( $self->{'field_prepared'}->[1+$level]->[1] ))
			{			
			$self->__SEARCH_FOR_DATA_RECURSIVE("$dir/$self->{'field_prepared'}->[$level]->[2]->{'simple'}")
			}
			else
			{
			$self->__EXAMINE_DATA("$dir/$self->{'field_prepared'}->[$level]->[2]->{'simple'}", $level)
			}
		}
	return
	}

opendir my $DIR, $dir or croak "Could not read column's \"$self->{'field_prepared'}->[$level-1][0]\" directory \"$dir\"\n";

	while (my $node = readdir $DIR )
	{
	next if $node eq '.' or $node eq '..';
	if ( ( $#{$self->{'field_prepared'}} >= $level ) && ( exists $self->{'field_prepared'}->[$level]->[2]->{'code'} ) ) { next unless $self->{'field_prepared'}->[$level]->[2]->{'code'}->($node) }
		
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
	# because all Filters have been applied to directory names
	if ( $level >= $#{$self->{'field_prepared'}} )
	{
	print {$self->{JUNK}} "$path\x0A"
	}
	else
	{	
	my $Deletions = 0;
	open FILE, '<',     "$path/data"	or croak "Could not read data file \"$path/data\" because \"$^E\"\n";
	open BUSY, '>:raw', "$path/data.busy"	or croak "Could not create temporary data file \"$path/data.busy\" because \"$^E\"\n";
	
		while (<FILE>)
		{
		chop; # we are sure of the final x0A character no matter if it is linux, mac or windowz so we don't use the slower chomp
		my $pass = 1;
		my @FLD  = split $self->{'separator'}, $_, -1;
		
			# Now we must apply filters to the rest fields. If one fails then all line's fields are skipped
			for (my ($i, $j) = (1+$level, 1+$level); $i <= $#{$self->{'field_prepared'}}; $i++)
			{
				unless ( exists $self->{'field_prepared'}->[$i]->[2]->{'null'} )
				{
					if ( exists $self->{'field_prepared'}->[$i]->[2]->{'simple'} )
					{
					unless ( $self->{'field_prepared'}->[$i]->[2]->{'simple'} eq $FLD[$i-$j] )	{$pass=0; last}
					}
					else
					{
					unless ( $self->{'field_prepared'}->[$i]->[2]->{'code'}->($FLD[$i-$j]) )	{$pass=0; last}
					}
				}

			$Deletions++
			}

		next if $pass;		
		print BUSY "$_\x0A"
		}
	
	close FILE;
	close BUSY;
	
		if ( -z "$path/data.busy" )
		{
		print STDOUT		"File full emptied \"$path/data\"\n" if $self->{'Show activity at standard output'};
		print {$self->{JUNK}}	"$path\x0A"
		}
		else
		{
			if ( $Deletions > 0 )
			{
			print STDOUT "$Deletions records deleted from \"$path/data\"\n" if $self->{'Show activity at standard output'};
			unlink("$path/data") || croak "Could not delete file \"$path/data\" because \"$^E\"\n";
			rename "$path/data.busy", "$path/data"
			}
			else
			{
			unlink("$path/data.busy") || croak "Could not delete file \"$path/data.busy\" because \"$^E\"\n"
			}
		}	
	}
}



#<EMD OF MODULE>
}1;
__END__


=head1 NAME

FastDB::Delete - Delete selected data from FastDB database

=head1 SYNOPSIS

	use FastDB::Delete;

	my $obj = Delete->new(
	'Schema file'                      => $SchemaFile,
	'Allow deletion with no filters'   => yes|no     ,
	'Show activity at standard output' => yes|no     );

	$obj->delete( col1 => 'Perl code1' , col2 => 'Perl code2', ... );

=head1 EXAMPLE

	my $obj = Delete->new(
	'Schema file'                      => '/work/FastDB test/db/Export cargo.schema',
	'Allow deletion with no filters'   => 'No',
	'Show activity at standard output' => 'yes'  );

	$obj->delete(
	'WEIGHT'     => '(DATA > 2000) and (DATA <= 100000) and ( DATA % 2 == 0)' ,
	'EXTRA_YEAR' => 'DATA == 2011' );

=head1 DESCRIPTION

Delete selected data from FastDB databases. You can select data for deletion
using Filters. Only rows that all their column Filters are true can be deleted. 

You can have multiple Filters. Every Filter is assigned only to one column.
The Filter's order is not important. Every Filter is simple Perl code. The
last returned value of your code is examined if it is TRUE or FALSE.
The special string DATA is replaced with column values.

=head1 Functions

=over 4

=item my $obj = Delete->new( %hash );

Creates a new FastDB::Delete object. %hash must have the keys

B<I<Schema file>>

This is where your schema File is. The schema file is a unique file
for every database, and it is created at first data load, inside data directory. Its name is "$DatabaseName.schema"

B<I<Allow deletion with no filters>>

Yes or No. If it is No, you are not allowed to delete data if you do not specify any Filters. If it yes and you
do not define any Filters, then all your database data will be deleted.

B<I<Show activity at standard output>>

Yes or No. If it is yes it displays at standard output short information of its activity.

=item $load->delete( %Filters );

delete deletes the data. Accepts a hash with columns as keys and generic Perl code as values.
Every filter evaluate only the data of its column. That means at Perl code you can not
write column names . The special string DATA is replaced with current column value.

=back

=head1 NOTES

This module is written with pure perl, so it can run on all operating systems. It is
designed to work as fast your disk and operating system is.

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
