#!/usr/bin/perl
#
# Ask the file based indexed database to return specific data
#
#    c:\perl\bin\perl.exe db_question.pl
#    c:\perl\bin\perl.exe db_question.pl --config some_question
#    c:\perl\bin\perl.exe db_question.pl --version
#    c:\perl\bin\perl.exe db_question.pl --help
#
# If no arguments specified program searches for a configuration file 
# called db_question.conf  inside its directory
#
# George Mpouras
# Europe/Athens, gravitalsun@hotmail.com, 1 Feb 2011

require 5.10.0;
use feature qw/switch/;

my  $VERSION = '1.5.0';
our %option  = ();

&New;

#use Data::Dumper; print STDOUT Data::Dumper::Dumper(\%option); exit;
#
# Define the   field_prepared   array of arrays
# This is an array with all the returned fields and their filters
#  0       1            2               3
#  name    index:1,0    returned:1,0    filter:undef,code    

for (my $i=0; $i<= $#{$option{'field_all'}}; $i++)
{
$option{'field_prepared'}->[$i][0] = $option{'field_all'}->[$i];						# name             column 0
$option{'field_prepared'}->[$i][1] = $option{'field_all'}->[$i] ~~ @{$option{'field_index'}}  ? (1):(0);	# If it is indexed column 1
$option{'field_prepared'}->[$i][2] = $option{'field_all'}->[$i] ~~ @{$option{'field_return'}} ? (1):(0);	# If user want it  column 2
$option{'field_prepared'}->[$i][3] = $option{'Filters'}->{$option{'field_all'}->[$i]} || { 'null' => 0 };	# Filter           column 3. If there is no filter we this to a pseudo hash
}

delete $option{'Filters'}; # we don't need any more 'Filters' (All usefull info is at 'field_prepared')

# From the field_prepared we should delete all the last fields where user does not want them, AND they have no filters
for (my $i=$#{$option{'field_prepared'}}; $i>=0; $i--) {
( $option{'field_prepared'}->[$i][2] == 0 ) && ( exists $option{'field_prepared'}->[$i][3]->{'null'} ) ? ( splice @{$option{'field_prepared'}}, $i, 1 ):( last ) }

#use Data::Dumper; $Data::Dumper::Indent=0; $Data::Dumper::Deparse=1; foreach (@{$option{'field_prepared'}}) {print "$_->[0], $_->[1], $_->[2], ".Dumper($_->[3])."\n" } exit;

# Change the 'field_return' array from column names to offsets
my %temp = (); # name -> position
my $_    = [];

for (my $i=0; $i<=$#{$option{'field_prepared'}}; $i++)
{
	if ( $option{'field_prepared'}->[$i][2] )
	{
	$temp{ $option{'field_prepared'}->[$i][0] } = $i
	}
}

for (my $i=0; $i<=$#{$option{'field_return'}}; $i++)
{
push @{$_}, $temp{$option{'field_return'}->[$i]}
}
undef %temp;
$option{'field_return'} = $_;



# If there are not any indexes we will not dig ( the first item of field_prepared is not indexed )
-1 == $#{$option{'field_index'}} ? ( ExamineData( $option{'dir_data'}, -1) ):( Search_for_data_recursive( $option{'dir_data'} ) );

close OUTPUT_FILE if $option{'Results - print to an output file'};
exit 0;




sub Search_for_data_recursive
{
my $dir   = shift;
my $level = $dir =~tr/\//\// - $option{'dir_data_depth'};

	if ( exists $option{'field_prepared'}->[$level]->[3]->{'simple'} )
	{
		if ( -d "$dir/$option{field_prepared}->[$level]->[3]->{simple}" )
		{		
			if (( exists $option{'field_prepared'}->[1+$level] ) && ( $option{'field_prepared'}->[1+$level]->[1] ))
			{			
			Search_for_data_recursive("$dir/$option{field_prepared}->[$level]->[3]->{simple}")
			}
			else
			{
			ExamineData("$dir/$option{field_prepared}->[$level]->[3]->{simple}", $level)
			}
		}
	return
	}

opendir my $DIR, $dir or die "Could not read column's \"$option{'field_prepared'}->[$level-1][0]\" directory \"$dir\"\n";
	while (my $node = readdir $DIR )
	{
	next if $node eq '.' or $node eq '..';
	if ( exists $option{'field_prepared'}->[$level]->[3]->{'code'} ) { next unless $option{'field_prepared'}->[$level]->[3]->{'code'}->($node) }			
	
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
	if ( $level == $#{$option{'field_prepared'}} )
	{
	$path =~s/^$option{'dir_data'}\///;
	my @FLD = split '/', $path, -1;

		if ( -1 == $#{$option{'Conditions'}} )
		{
		Shout_the_answer( @FLD[@{$option{'field_return'}}] )
		}
		else
		{
		my $pass=1;
		my %field_value; # $field_value{field} => value
		@field_value{@{$option{field_all}}} = @FLD; 

			foreach my $Condition (@{$option{'Conditions'}})
			{
			( $_ = $Condition ) =~s/\b(.+?)\b/ exists $field_value{$^N} ? ( "'$field_value{$^N}'" ):( $^N ) /ge;
			$pass = eval $_;
			unless ($@ eq '') {die "Syntax error at condition:  $Condition\n"}
			last unless $pass			
			}

		Shout_the_answer( @FLD[@{$option{'field_return'}}] ) if $pass
		}
	return
	}

# Lets open the data file to search its data
open FILE, '<', "$path/data" or die "Could not read data file \"$path/data\"\n";

	while (<FILE>)
	{
	chop; # we are sure of the final x0A character no matter if it is linux, mac or windowz so we don't use the slower chomp
	my $pass = 1;
	my @FLD  = split $option{'separator'}, $_, -1;
		
		# Now we must apply filters to the rest fields. If one fails then all line's fields are skipped
		for (my ($i, $j) = (1+$level, 1+$level); $i <= $#{$option{'field_prepared'}}; $i++)
		{
			unless ( exists $option{'field_prepared'}->[$i]->[3]->{'null'} )
			{
				if ( exists $option{'field_prepared'}->[$i]->[3]->{'simple'} )
				{
				unless ( $option{'field_prepared'}->[$i]->[3]->{'simple'} eq $FLD[$i-$j] )	{$pass=0; last}
				}
				else
				{
				unless ( $option{'field_prepared'}->[$i]->[3]->{'code'}->($FLD[$i-$j]) )	{$pass=0; last}
				}
			}
		}

	next unless $pass;
	$path =~s/^$option{'dir_data'}\/?//;
	unshift @FLD, split('/', $path, -1);
	
		if ( -1 == $#{$option{'Conditions'}} )
		{
		Shout_the_answer( @FLD[@{$option{'field_return'}}] )
		}
		else
		{
		my %field_value; # $field_value{field} => value
		@field_value{@{$option{field_all}}} = @FLD; 

			foreach my $Condition (@{$option{'Conditions'}})
			{
			( $_ = $Condition ) =~s/\b(.+?)\b/ exists $field_value{$^N} ? ( "'$field_value{$^N}'" ):( $^N ) /ge;
			$pass = eval $_;
			unless ($@ eq '') {die "Syntax error at condition:  $Condition\n"}
			last unless $pass			
			}
		
		Shout_the_answer( @FLD[@{$option{'field_return'}}] ) if $pass
		}
	}

close FILE
}




			##############################
			#                            #
			# Not so imnportant routines #
			#                            #
			##############################




sub Shout_the_answer
{
$_ = join($option{'separator'}, @_);
print STDOUT      "$_\n"	if $option{'Results - print to standard output'};
print STDERR      "$_\n"	if $option{'Results - print to standard error'};
print OUTPUT_FILE "$_\x0A"	if $option{'Results - print to an output file'};

	if ( $option{'Results - Pass to external Perl module'} )
	{
	eval $option{'Results - Pass to external Perl module'};
	$@ && {die "Error while feeding function $option{'Results - Perl module name'} --> $option{'Results - Function of the Perl module'} the found data \"$_\" because $@\n" }
	}
}



#   Grab user input
sub New
{
my $file_question = $ARGV[0];
$file_question //= '';

given ($file_question)
{
when		( /(-v|\/v)/i ) {
print STDERR<<stop_printing;
Query FastDB for information version $VERSION\n
This program is GoodWare. That means if you
like it and use it, you have to do some good deeds.\n
George Bouras (gravitalsun\@hotmail.com)
Greece/Athens
stop_printing
exit 4}


when		( /(-h|\/h)/i ) {
print STDERR<<stop_printing;
Query SimpleDB for information version $VERSION . Syntax:
Show version
        db_question.pl --version  (or -v --ver   etc ...)
This help screen
        db_question.pl --help     (or -h --help  etc ...)
Query using a specific question file
        db_question.pl [SomeQuestionFile]
Examples
	db_question.pl      (searches for the ./db_question.conf)
	db_question.pl -v
	db_question.pl ~/servers

Question file is optional. If you do not specify it, program
search for a file called  db_question.conf at its directory.

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
$file_question = "$_/db_question.conf" if $file_question eq '';
-f $file_question || die "Your question file \"$file_question\" does not exist. Use --help for some help.\n";
open(FILE, '<', $file_question) || die "Could not read the question file \"$file_question\"\n";
my $section;

	while (<FILE>)
	{
	next if /^\s*(\;|\#)/;
	next if /^\s*$/;
		
		if (/^\s*\[\s*(.+?)\s*\]\s*$/)
		{
		exists $option{$^N} && die "The key \"$^N\" is duplicated at your configuration file \"$file_question\" . Specify a different uniq name and try again.\n";
		$section = $^N;
		next
		}
		else
		{
			if ( defined $section )
			{
				if	( $section eq 'Conditions' )
				{
				s/^(.*?)$/$1/; s/(\s|\;)*$//; s/\s+/ /g; s/\( /(/g; s/ \)/\)/g;
				tr/(/(/ == tr/)/)/ || die "Number of left/right parentheses do not match at condition \"$_\"\n";
				push @{$option{$section}}, $_
				}
				elsif	( ($section eq 'Filters')  &&  ( /^\s*(.+?)\s*-->\s*(.+?)\s*$/ ) )
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
-f $option{'Schema file'} || die "Your schema file \"$option{'Schema file'}\" does not exist. Please check the option \"Schema file\" of your question file \"$file_question\"\n";
open    FILE, '<', $option{'Schema file'} or die "Could not read schema file \"$option{'Schema file'}\" because \"$^E\"\n";
while (<FILE>) { next if /^\s*(\;|\#)/; if ( /^\s*([^:]+?)\s*:\s*(.+?)\s*$/ ) {$option{$1} = $2} }
close   FILE;
$option{'Conditions'}				//= [];
$option{'field_prepared'}			= [];
$option{'field_index'}				= [ split /(?:\s*$option{'separator'}\s*|\s+)/ , $option{'field_index'}];
$option{'field_return'}				= [ split /(?:\s*$option{'separator'}\s*|\s+)/ , $option{'Fields to return'}]; exit 0 if -1 == $#{$option{'field_return'}}; delete $option{'Fields to return'};
$option{'field_all'}				= [ @{$option{'field_index'}}, split /(?:\s*$option{'separator'}\s*|\s+)/, $option{'field_noindex'} ];
$option{'dir_data_depth'}			= $option{'dir_data'}=~tr/\//\//;
$option{'Results - print to standard output'}	= $option{'Results - print to standard output'} =~/(?i)y/ ?(1):(0);
$option{'Results - print to standard error'}	= $option{'Results - print to standard error'}  =~/(?i)y/ ?(1):(0);
$option{'Results - print to an output file'}	= $option{'Results - print to an output file'}  =~/(?i)y/ ?(1):(0);

	if ( $option{'Results - Pass to external Perl module'} =~/(?i)y/ )
	{
	eval "use $option{'Results - Perl module name'}";
	unless ($@ eq '') { die "Perl module \"$option{'Results - Perl module name'}\" does not exist.\n" }
	$option{'Results - Pass to external Perl module'} = "$option{'Results - Perl module name'}::$option{'Results - Function of the Perl module'}($option{'Results - Code of how to pass data at function'})"
	}
	else
	{
	$option{'Results - Pass to external Perl module'} = 0
	}

	if ( $option{'Results - print to an output file'} )
	{
	(my $dir = $option{'Results - output filename'})=~s/\\/\//g;
	$dir =~/[^\/]*$/;
	$dir = ${^PREMATCH};
	$dir =~s/\/*$//;
	unless ( -d $dir ) { my ($i, @CH) = (0, split /\//, $dir, -1);
	for($i=$#CH; $i>=0; $i--) { last if -d join '/', @CH[0..$i] }
	if (($i == -1) && ($^O eq 'linux')) { splice @CH, 0, 2, "/$CH[1]" if $CH[0] eq undef }
	for (my $j=++$i; $j<=$#CH; $j++) { mkdir join '/', @CH[0..$j] } }
	open OUTPUT_FILE, '>:raw', $option{'Results - output filename'} or die "Could not create the output file \"$option{'Results - output filename'}\" because \"$^E\"\n"
	}

delete $option{'field_noindex'};

# Check if 'field_return' exist as field in  field_all
foreach (@{$option{'field_return'}}) { $_ ~~ @{$option{'field_all'}} or die "Field to return \"$_\" is not one of the existing fields: ". join("$option{'separator'} ",@{$option{'field_all'}})."\n" }

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
		#							$code = eval $code or die "oups, bad perl code\n";   print $code->(200);		
		$code = "sub { ($code) ? ( return 1 ):( return 0 ) }";
		$code = eval $code or die "Bad filter $_ code:   $option{'Filters'}->{$_}\n";
		$option{'Filters'}->{$_} = { 'code' => $code }; 
		}
	}
}