#!/usr/bin/perl
#
# Delete data from the database
#
#    c:\perl\bin\perl.exe db_delete.pl
#    c:\perl\bin\perl.exe db_delete.pl --config file
#    c:\perl\bin\perl.exe db_delete.pl --version
#    c:\perl\bin\perl.exe db_delete.pl --help
#
# If no arguments specified program searches for a configuration file 
# called db_delete.conf  inside its directory
#
# George Mpouras
# Europe/Athens, gravitalsun@hotmail.com, 2 Feb 2011

require 5.10.0;
use feature qw/switch/;

my  $VERSION = '1.5.0';
our %option  = ();

&New;

#use Data::Dumper; print STDOUT Data::Dumper::Dumper(\%option); exit;
# Define the   field_prepared   array of arrays
# This is an array with all the filters
#  0       1            2
#  name    index:1,0    filter:undef,code    

for (my $i=0; $i<= $#{$option{'field_all'}}; $i++)
{
$option{'field_prepared'}->[$i][0] = $option{'field_all'}->[$i];						# name             column 0
$option{'field_prepared'}->[$i][1] = $option{'field_all'}->[$i] ~~ @{$option{'field_index'}}  ? (1):(0);	# If it is indexed column 1
$option{'field_prepared'}->[$i][2] = $option{'Filters'}->{$option{'field_all'}->[$i]} || { 'null' => 0 };	# Filter           column 2. If there is no filter we this to a pseudo hash
}
# From the field_prepared we should delete all the last fields that have no filters
for (my $i=$#{$option{'field_prepared'}}; $i>=0; $i--) {
exists $option{'field_prepared'}->[$i][2]->{'null'} ? ( splice @{$option{'field_prepared'}}, $i, 1 ):( last ) }

#use Data::Dumper; foreach (@{$option{'field_prepared'}}) { print "name = $_->[0] , index = $_->[1] , filter = ".Dumper($_->[2]) ."\n"} exit;

open JUNK, '>:raw', "$option{'dir_data'}.junk" or die "Could not create temporary file \"$option{'dir_data'}.junk\"\n";

	if (( -1 == $#{$option{'field_index'}} ) || ( -1 == $#{$option{'field_prepared'}} ))
	{	
	ExamineData($option{'dir_data'}, -1)
	}
	else
	{	
	Search_for_data_recursive($option{'dir_data'})
	}

close	JUNK;
unless ( -z "$option{'dir_data'}.junk" ) {
open	JUNK, '<', "$option{'dir_data'}.junk" or die "Could not read temporary file \"$option{'dir_data'}.junk\"\n";
while (<JUNK>) { chop $_; Delete_directorie_trees_until_multiple_nodes_found($_) }
close	JUNK }
if (0 == scalar keys %{$option{'Filters'}}) { mkdir $option{'dir_data'} or die "Could not create directory \"$option{'dir_data'}\"\n" unless -d $option{'dir_data'} }
unlink("$option{'dir_data'}.junk") ? ( exit 0 ):( die "Could not delete file \"$option{'dir_data'}.junk\"\n" );


		#################
		#               #
		#  Subroutines  #
		#               #
		#################


sub Search_for_data_recursive
{
my $dir   = shift;
my $level = $dir =~tr/\//\// - $option{'dir_data_depth'};

	if ( ( $#{$option{'field_prepared'}} >= $level ) && ( exists $option{'field_prepared'}->[$level]->[2]->{'simple'} ) )
	{
		if ( -d "$dir/$option{field_prepared}->[$level]->[2]->{simple}" )
		{		
			if (( exists $option{'field_prepared'}->[1+$level] ) && ( $option{'field_prepared'}->[1+$level]->[1] ))
			{			
			Search_for_data_recursive("$dir/$option{field_prepared}->[$level]->[2]->{simple}")
			}
			else
			{
			ExamineData("$dir/$option{field_prepared}->[$level]->[2]->{simple}", $level)
			}
		}
	return
	}

opendir my $DIR, $dir or die "Could not read column's \"$option{'field_prepared'}->[$level-1][0]\" directory \"$dir\"\n";

	while (my $node = readdir $DIR )
	{
	next if $node eq '.' or $node eq '..';
	if ( ( $#{$option{'field_prepared'}} >= $level ) && ( exists $option{'field_prepared'}->[$level]->[2]->{'code'} ) ) { next unless $option{'field_prepared'}->[$level]->[2]->{'code'}->($node) }
		
		if (( exists $option{'field_prepared'}->[1+$level] ) && ( $option{'field_prepared'}->[1+$level]->[1] ))
		{		
		Search_for_data_recursive("$dir/$node")
		}
		else
		{		
		ExamineData("$dir/$node", $level)
		}
	}

closedir $DIR
}






sub ExamineData
{
my ($path, $level) = @_;

	# it is not neccassery to open the data file if       $level == $#{$option{'field_prepared'}}
	# because all wanted fields are at directory names !
	if ( $level >= $#{$option{'field_prepared'}} )
	{
	print JUNK "$path\x0A"
	}
	else
	{	
	my $Deletions = 0;
	open FILE, '<',     "$path/data"	or die "Could not read data file \"$path/data\" because \"$^E\"\n";
	open BUSY, '>:raw', "$path/data.busy"	or die "Could not create temporary data file \"$path/data.busy\" because \"$^E\"\n";
	
		while (<FILE>)
		{
		chop; # we are sure of the final x0A character no matter if it is linux, mac or windowz so we don't use the slower chomp
		my $pass = 1;
		my @FLD  = split $option{'separator'}, $_, -1;
		
			# Now we must apply filters to the rest fields. If one fails then all line's fields are skipped
			for (my ($i, $j) = (1+$level, 1+$level); $i <= $#{$option{'field_prepared'}}; $i++)
			{
				unless ( exists $option{'field_prepared'}->[$i]->[2]->{'null'} )
				{
					if ( exists $option{'field_prepared'}->[$i]->[2]->{'simple'} )
					{
					unless ( $option{'field_prepared'}->[$i]->[2]->{'simple'} eq $FLD[$i-$j] )	{$pass=0; last}
					}
					else
					{
					unless ( $option{'field_prepared'}->[$i]->[2]->{'code'}->($FLD[$i-$j]) )	{$pass=0; last}
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
		print STDOUT "File full emptied \"$path/data\"\n";
		print JUNK   "$path\x0A"
		}
		else
		{
			if ( $Deletions > 0 )
			{
			print STDOUT "$Deletions records deleted from \"$path/data\"\n";
			unlink("$path/data") || die "Could not delete file \"$path/data\" because \"$^E\"\n";
			rename "$path/data.busy", "$path/data"
			}
			else
			{
			unlink("$path/data.busy") || die "Could not delete file \"$path/data.busy\" because \"$^E\"\n"
			}
		}	
	}
}






sub Delete_directorie_trees_until_multiple_nodes_found
{
my @Chop = -d $_[0] ? (split /\//, $_[0]):(return undef);

	for (my $i = $#Chop - 1; $i >= 0; $i--)
	{
	my $dir = join '/', @Chop[0..$i];
	my $j   = 0;
	opendir DIRECTORY, $dir or die "Could not list directory \"$dir\"\n";
	while (readdir DIRECTORY) { if ($j == 3) {$j=0; last}; $j++ }
	closedir DIRECTORY;
	
		unless ($j)
		{
		$dir = join '/', @Chop[0 .. ++$i];
		print STDOUT "Removing directory tree \"$dir\"\n";
		$^O  =~/(?i)MSWin/ ? (`RD /S /Q "$dir" 1> nul 2> nul`):(`rm -rf "$dir" 1> /dev/null 2> /dev/null`);
		-d $dir ? ( die "Could not remove directory tree \"$dir\" because \"$^E\"\n" ):( return $dir )
		}
	}
undef
}




sub New
{
my $file_config = $ARGV[0];
$file_config //= '';

given ($file_config)
{
when		( /(-v|\/v)/i ) {
print STDERR<<stop_printing;
Delete data from SimpleDB version $VERSION\n
This program is GoodWare. That means if you
like it and use it, you have to do some good deeds.\n
George Bouras (gravitalsun\@hotmail.com)
Greece/Athens
stop_printing
exit 4}


when		( /(-h|\/h)/i ) {
print STDERR<<stop_printing;
Delete data from SimpleDB version $VERSION . Syntax:
Show version
        db_delete.pl --version  (or -v --ver   etc ...)
This help screen
        db_delete.pl --help     (or -h --help  etc ...)
Use a specific configuration file
        db_delete.pl [ConfigFile]
Examples
	db_delete.pl      (searches for the ./db_delete.conf)
	db_delete.pl -v
	db_delete.pl ~/servers

The config file is optional. If you do not specify it, program
searches for a file called  db_delete.conf  at its directory.

This program works as it is to all operating systems without any
change. Just copy it at you machine and execute it !

This program is GoodWare. That means if you like it and use it, you
have to do some good deeds.\n
George Bouras (gravitalsun\@hotmail.com)
Greece/Athens
stop_printing
exit 3 }
}

($_=$0) =~s/[^\\\/]*$//; s/\\/\//g; s/\/*$//; $_ = '.' if $_ eq '';
$file_config = "$_/db_delete.conf" if $file_config eq '';
-f $file_config || die "Your configuration file \"$file_config\" does not exist. Use --help for some help.\n";
open(FILE, '<', $file_config) || die "Could not read the question file \"$file_config\"\n";
my $section;

	while (<FILE>)
	{
	next if /^\s*(\;|\#)/;

		if (/^\s*\[\s*(.+?)\s*\]\s*$/)
		{
		exists $option{$^N} && die "The key \"$^N\" is duplicated at your configuration file \"$file_config\" . Specify a different uniq name and try again.\n";
		$section = $^N;
		next
		}
		else
		{
			if ( defined $section )
			{
				if ( ($section eq 'Filters')  &&  ( /^\s*(.+?)\s*-->\s*(.+?)\s*$/ ) )
				{
				my ($fn,$fv) = ($1,$2);

					# Ignore useless filters line * .*  =~/.*/
					unless ( ( $fv eq '*' ) || ( $fv eq '.*' ) || ( $fv =~ /\s*\=\~\s*.\^?\.\*\$?./ ) )
					{
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

					$option{$section}->{$fn} = $fv
					}				
				}
			}
			elsif ( /^\s*([^=]+?)\s*=\s*(.+?)\s*$/ )
			{
			$option{$1} = $2
			}
		}
	} 

close FILE;
-f $option{'Schema file'} || die "Your schema file \"$option{'Schema file'}\" does not exist. Please check the option \"Schema file\" of your question file \"$file_config\"\n";
open    FILE, '<', $option{'Schema file'} or die "Could not read schema file \"$option{'Schema file'}\" because \"$^E\"\n";
while (<FILE>) { next if /^\s*(\;|\#)/; if ( /^\s*([^:]+?)\s*:\s*(.+?)\s*$/ ) {$option{$1} = $2} }
close   FILE;
$option{'field_index'}		= [ split /(?:\s*$option{'separator'}\s*|\s+)/ , $option{'field_index'}];
$option{'field_all'}		= [ @{$option{'field_index'}}, split /(?:\s*$option{'separator'}\s*|\s+)/, $option{'field_noindex'} ];
$option{'dir_data_depth'}	= $option{'dir_data'}=~tr/\//\//;
$option{'field_prepared'}	= [];
delete $option{'field_noindex'};

	if ( (0 == scalar keys %{$option{'Filters'}}) && ($option{'Show warnings'} =~/(?i)y/) )
	{
	print STDOUT "You have not define any filter, so all data from the\ndatabase \"$option{'name'}\" will be deleted.\nAre you sure you want to continue ? [Yes|No] : ";
	unless ( getc =~/(?i)y/ ) { print STDOUT "Deletion aborted.\n"; exit 0 }
	}

	# Lets parse filters
	foreach (keys %{$option{'Filters'}})
	{
	$_ ~~ @{$option{'field_all'}} or die "Filter \"$_\" ( $option{'Filters'}->{$_} ) is not one of the existing fields: ".  join("$option{'separator'} ",@{$option{'field_all'}})."\n";

		# First we must check if the filter is simple like:   data eq "something"     or     data == 153
		if ( $option{'Filters'}->{$_} =~/^data eq '(.+?)'$/ )
		{
		$option{'Filters'}->{$_} = { 'simple' => $1 }
		}
		else
		{		
		(my $code = $option{'Filters'}->{$_}) =~s/\bdata\b/\$_[0]/g;
		# We are using the following method :			$code = '( $_[0] > 100 ) and ( $_[0] < 400 )';
		#							$code = "sub { ($code) ?(return 1):(return 0)}";
		#							$code = eval $code or die "oups, bad perl code\n"; print $code->(200);
		$code = "sub { ($code) ? (return 1):(return 0) }";
		$code = eval $code or die "Bad filter $_ code:   $option{'Filters'}->{$_}\n";
		$option{'Filters'}->{$_} = { 'code' => $code } 
		}	
	}
}