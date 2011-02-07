#!/usr/bin/perl
#
# Insertion of a csv file to FastDB indexed database
# c:\perl64\bin\perl.exe db_load.pl
# 
# Set tab to 8 spaces to have a beautiful view of this file.
# This version is more updated than "db_load_MultipleConfiguration.pl" . Even if the MultipleConfiguration
# code is more advanced, it is very rare its functionality to be usefull at real world projects. 
#
# Extra dynamic fields you can use at loading time
#
#   EXTRA_YEAR, EXTRA_MONTH, EXTRA_MONTH_NAME, EXTRA_DAY, EXTRA_DAY_NAME, EXTRA_HOUR, EXTRA_MINUTE, EXTRA_SECOND, EXTRA_TIMESTAMP
#
# George Mpouras
# Europe/Athens, gravitalsun@hotmail.com, 1 Feb 2011

require 5.10.0;
use feature qw/switch/;
use Getopt::Long;

my $VERSION = '1.5.0';
my %option  = ();
my $saytime = sub{local @{$_} = localtime(time); $_->[5]+=1900; sprintf '%02d-%s-%04d %02d:%02d:%02d', $_->[3], (qw/Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec/)[$_->[4]], @{$_}[5,2,1,0]};

&New;

#use Data::Dumper; $Data::Dumper::Deparse=1; print STDOUT Data::Dumper::Dumper(\%option); exit;
# Examine the entries of field_index
for (my $i=$#{$option{'field_index'}} ; $i>=0 ; $i--)
{
	# Check if the field_index item is valid
	unless ( ( $option{'field_index'}->[$i] ~~ @{$option{'field_original'}} ) || ( $option{'field_index'}->[$i] ~~ @{$option{'field_extra'}} ) )
	{
	die "At database \"$option{'Name'}\", field \"$option{'field_index'}->[$i]\" you want to index is not defined at \"Original field names\" or \"Extra virtual fields\"\n"
	}

	# Remove it, if exists inside the  field_remove
	if ( $option{'field_index'}->[$i] ~~ @{$option{'field_remove'}} )
	{
	splice @{$option{'field_index'}}, $i, 1;
	}
}

# Define the  field_noindex  list. We are using  de-duplication technology to not include any indexed fields at field_noindex list
foreach ( @{$option{'field_original'}} , @{$option{'field_extra'}} )
{
next if $_ ~~ @{$option{'field_index'}};
next if $_ ~~ @{$option{'field_remove'}};
push @{$option{'field_noindex'}} , $_;
}


# Define the hash ref    $option{'field_reverse'}   . We are using the power of hash slice   @hash{@array}=list  to accomplish this task  
@{$_} = ( @{$option{'field_original'}} , @{$option{'field_extra'}} );
@{$option{'field_reverse'}}{@{$_}} = ( 0 .. $#{$_} );
-2  == ( $#{$option{'field_index'}} + $#{$option{'field_noindex'}} ) && die "At schema \"$option{'Name'}\" you have not define any index or data column indsite the configuration file\n";


# Write schema information at first loading, or check the data schema on next loadings
unless ( -f "$option{'dir_data'}/$option{'Name'}.schema" )
{
open  FILE, '>:raw', "$option{'dir_data'}/$option{'Name'}.schema" or die "Could not create schema file \"$option{'dir_data'}/$option{'Name'}.schema\" because \"$^E\"\n";
print FILE  'name          : '. $option{'Name'}."\x0A";
print FILE  'dir_data      : '. "$option{'dir_data'}/$option{'Name'}\x0A";
print FILE  'separator     : '. $option{'separator'}	."\x0A";
print FILE  'field_index   : '. join($option{'separator'}, @{$option{'field_index'}}) ."\x0A";
print FILE  'field_noindex : '. join($option{'separator'}, @{$option{'field_noindex'}} );
close FILE 
}
else
{
my %check_schema;
open    FILE, '<', "$option{'dir_data'}/$option{'Name'}.schema" or die "Could not retrieve schema information from file \"$option{'dir_data'}/$option{'Name'}.schema\" because \"$^E\"\n";
while (<FILE>) { /^\s*(?<Key>[^:]+?)\s*:\s*(?<Value>.*?)\s*$/ or next ; $check_schema{$+{Key}} = $+{Value}}
close   FILE;
$check_schema{'name'}      eq $option{'Name'}				or die "Your current database name \"$check_schema{'name'}\" is different from the one you are tring to load \"$option{'Name'}\"\n";
$check_schema{'separator'} eq $option{'separator'}			or die "Schema error. \"$option{'Name'}\" property \"separator\" has value \"$check_schema{'separator'}\" while you current load configuration is set to \"$option{'separator'}\"\n";
$check_schema{'dir_data'}  eq "$option{'dir_data'}/$option{'Name'}"	or die "Schema error. \"$option{'Name'}\" property \"dir_data\"  has value \"$check_schema{'dir_data'}\"  while you current load configuration is set to \"$option{'dir_data'}/$option{'Name'}\"\n";

	unless ( 2 + $#{[split ',',$check_schema{'field_index'}]} + $#{[split ',',$check_schema{'field_noindex'}]} == (1+$#{$option{'field_original'}}) + (1+$#{$option{'field_extra'}}) - (1+$#{$option{'field_remove'}}) )
	{
	die "Schema error. \"$option{'Name'}\" has ". (2 + $#{[split ',',$check_schema{'field_index'}]} + $#{[split ',',$check_schema{'field_noindex'}]}) . " fields while you are trying to load ". ((1+$#{$option{'field_original'}}) + (1+$#{$option{'field_extra'}}) - (1+$#{$option{'field_remove'}})) ."\n"
	}

	unless ( $#{[split ',',$check_schema{'field_index'}]} == $#{$option{'field_index'}} )
	{
	die "Schema error. \"$option{'Name'}\" has ". (1+$#{[split ',',$check_schema{'field_index'}]}) . " indexed fields while you current load configuration has ". (1+$#{$option{'field_index'}}) ."\n"
	}
}

# @{$option{'field_original'}}		All the fields of the input file
# $option{'field_index'}		Fields we want to index
# $option{'field_noindex'}		Fields we want to simple store their data 
# $option{'field_reverse'}		Field index
#
# Write some metadata. At future, more functionality could be added here
my      $lines = 0;
open	FILE, '>>:raw', "$option{'dir_data'}/$option{'Name'}.metadata" or die "Could not create metadata file \"$option{'dir_data'}/$option{'Name'}.metadata\" because \"$^E\"\n";
print	FILE  'Start loading : '. $saytime->()."\x0A";
close	FILE;
open	INPUT_FILE, '<', $option{'Input data file'} or die "$^E\n";


while (<INPUT_FILE>)
{
tr/\x0D\x0A//d;
my @col = split /\s*$option{'separator'}\s*/, $_, -1;  # mind the unicode bom header tr/\xEF\xBB\xBF//d;
unless ( $#{$option{'field_original'}} == $#col ) { warn "Skip line $. not ".(1+$#{$option{'field_original'}})." fields: $_\n"; next }
push( @col, Calculate_extra_field($option{'field_extra'}) ) unless -1 == $#{$option{'field_extra'}};
++$lines;
	
	# Apply field transformations
	foreach (keys %{$option{'Transform'}})
	{
	$col[$option{'field_reverse'}->{$_}] = $option{'Transform'}->{$_}->( $col[$option{'field_reverse'}->{$_}] )
	}

# Create the upper schema directories
$_ = join '/',  "$option{'dir_data'}/$option{'Name'}",  map { $col[$option{'field_reverse'}->{$_}] } @{$option{'field_index'}};
CreateDir($_) || die "Could not create directory \"$_\" because \"$^E\"\n";

# Write the rest data to the data file
next if $#{$option{'field_noindex'}} == -1;
open  FILE, '>>:raw', join('/', $_, 'data');
select((select(FILE),$|=1)[0]);
print FILE  join($option{'separator'}, map{ $col[$option{'field_reverse'}->{$_}] } @{$option{'field_noindex'}}) ."\x0A";
close FILE
}




close INPUT_FILE;
open  FILE,'>>:raw', "$option{'dir_data'}/$option{'Name'}.metadata" or die "Could not update metadata file \"$option{'dir_data'}/$option{'Name'}.metadata\" because \"$^E\"\n";
print FILE 'End   loading : '.$saytime->()."\x0A";
print FILE "Loaded rows   : $lines\x0A";
print FILE ('-' x37)."\x0A";
close FILE;
exit 0;

			################
			#              #
			# Sub routines #
			#              #
			################


#   Create nested directory and all the upper path that may missing.
#   returns the directory on success, or undef on error
sub CreateDir
{
(my $dir     = shift) =~s/[\\\/]*$//;
my ($i, @CH) = (0, split /[\\\/]/, $dir, -1);						# split dir
for($i=$#CH; $i>=0; $i--) { last if -d join '/', @CH[0..$i] }				# find the last existing directory
if (($i == -1) && ($^O eq 'linux')) { splice @CH, 0, 2, "/$CH[1]" if $CH[0] eq undef }	# If it is linux , we should not try to create the / directory
for (my $j=++$i; $j<=$#CH; $j++) { mkdir(join '/', @CH[0..$j]) || return undef}		# start creating until the last existing
$dir
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
	default			{ die "The extra virtual field \"$field\" have not been implemented yet\n" } }
	}
@R
}



#   Grab user input
sub New
{
Getopt::Long::GetOptions(	
'config=s'	=> \my $file_config,
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

Show version: db_load.pl --version  (or -v --ver   etc ...)
Help screen : db_load.pl --help     (or -h --help  etc ...)
Load data   : db_load.pl [--config \$file_configFile]
Examples
	db_load.pl -v
	db_load.pl
	db_load.pl --config /etc/load.cfg

--input is optional.  It is the path of your input data file you
want to load at the database. If it is missing, program search for
a file called  data.csv  at the same directory it resides.

--config is optional. It is the path of the loading configuration
file. If it is missing, program search for a file called
db_load.conf  at the same directory it resides.

This program works as it is to all operating systems without any
change. Just copy it at you machine and execute it !

This program is GoodWare. That means if you like it and use it, you
have to do some good deeds.\n
George Bouras (gravitalsun\@hotmail.com)
Greece/Athens
stop_helping
exit 3 }


($_=$0) =~s/[^\\\/]*$//; s/\\/\//g; s/\/*$//; $_ = '.' if $_ eq '';
$file_config //= "$_/db_load.conf";
open FILE, "<$file_config" or die "Could not read the configuration file \"$file_config\" . Use --help switch for some help.\n";
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
				if ( ($section eq 'Transform')  &&  ( /^\s*(.+?)\s*-->\s*(.+?)\s*$/ ) )
				{
				my ($fn,$fv) = ($1,$2);

					# Ignore useless filters line * .*  =~/.*/
					unless ( ( $fv eq '*' ) || ( $fv eq '.*' ) || ( $fv eq '.*' ) || ( $fv =~ /\s*\=\~\s*.\^?\.\*\$?./ ) )
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

$option{'field_reverse'} = {};
$option{'field_noindex'} = [];			
$option{'dir_data'}      = $option{'Data store location'};					delete $option{'Data store location'};
$option{'separator'}     = $option{'Field separator string'};					delete $option{'Field separator string'};
$option{'field_original'}= [ split /(?:\s*,\s*|\s+)/ , $option{'Original field names'}    ];	delete $option{'Original field names'};
$option{'field_index'}   = [ split /(?:\s*,\s*|\s+)/ , $option{'Indexed fields'}          ];	delete $option{'Indexed fields'};
$option{'field_extra'}   = [ split /(?:\s*,\s*|\s+)/ , $option{'Extra virtual fields'}	  ];	delete $option{'Extra virtual fields'};
$option{'field_remove'}  = [ split /(?:\s*,\s*|\s+)/ , $option{'Do not load these fields'}];	delete $option{'Do not load these fields'};

-f $option{'Input data file'} || die "Your input data file \"$option{'Input data file'}\" does not exist. Use --help for some help.\n";
$option{'dir_data'}=~s/\\/\//gs;
$option{'dir_data'}=~s/\/*$//gs;
CreateDir($option{'dir_data'}) || die "Could not create the data directory \"$option{'dir_data'}\"\n";

	# check the Transform fields
	foreach (keys %{$option{'Transform'}})
	{
	if ( $_ ~~ @{$option{'field_remove'}} ) { delete $option{'Transform'}->{$_}; next }
	unless ( ( $_ ~~ @{$option{'field_original'}} ) || ( $_ ~~ @{$option{'field_extra'}} ) ) { die "At database \"$option{'Name'}\", field \"$_\" you want to transform using the code \"$option{'Transform'}->{$_}\" is not defined at properties \"Original field names\" or \"Extra virtual fields\" : ".join(', ',(@{$option{'field_original'}},@{$option{'field_extra'}}))."\n" }	
	(my $code = $option{'Transform'}->{$_}) =~s/\bdata\b/\$field/g;
	$code = "sub {my \$field = \$_[0]; $code }";
	$code = eval $code or die "Bad filter $_ code:   $option{'Transform'}->{$_}\n";
	$option{'Transform'}->{$_} = $code
	}



}
