#!/usr/bin/env perl

# Install/Uninstall a  directory holding some pm files somewhere at your Perl @INC
#
#        Install:    setup.pl --install   --module=SomeDirectory
#        Uninstall:  setup.pl --uninstall --module=SomeDirectory
#
# to do
# Generate (and remove) html help files using the Perl utility  pod2html
#
# George Mpouras
# Our galaxy/our solar system/Earth/Europe/Athens
# 4 Feb 2011

use Getopt::Long;
use strict;
use warnings;
our $VERSION = '1.0.0';

my ($module, $install, $uninstall, $v, $help)=(0,undef,undef,0,0);
Getopt::Long::GetOptions(
'module=s'  => \$module   ,
'install!'  => \$install  ,
'uninstall!'=> \$uninstall,
'version!'  => \$v  ,
"help!"     => \$help     ) || die "Oups ! could not grab arguments.\n";

die "You can not use install and uninstall option at the same time.\nTry --help for some help.\n" if $install && $uninstall;
die "You are using Module setup version $VERSION\n" if $v;
if ($help) {
print STDOUT<<stop_printing;
Setup version $VERSION

Install
    setup.pl --install   --module=FastDB
Uninstall
    setup.pl --uninstall --module=FastDB

stop_printing
exit 2
}

die "You have not define any module name.\nTry --help for some help.\n" if ! $module;

#   From the full path of a node, returns the 4 items:
#
#   0) Upper directory
#   1) node
#   2) node without the extension
#   3) node's extension only
#
#   Foe example:     ((Path_analyzer('c:\windows\readme.txt'))[1])
#
sub Path_analyzer ($)
{
my ($dir, $file, $body, $ext) = shift;
$dir =~s/\\/\//g; $dir =~s/(\s|\/)*$//;
($dir,$file) = $dir =~/^(.*?)([^\/]+)$/;
$dir =~s/(\s|\/)*$//;
$dir=~/^\s*$/ ? ( $dir = '.' ):();
if (-1 == rindex $file,'.') { $body=$file; $ext=undef } else { $body = substr $file,0,(rindex $file,'.'); $ext = substr($file,(rindex $file,'.')+1)}
$dir, $file, $body, $ext
}


my %source;
my ($dir_source) = Path_analyzer($module);
opendir  DIR, $dir_source or die "Could not list directory \"$dir_source\"\n";
foreach (grep /^$module/, readdir DIR) { $source{$_} = -d "$dir_source/$_" ? ('dir'):('file') }
closedir DIR;
die "Could not found any files related with module \"$module\"\n" if 0 == scalar keys %source;



goto install   if $install;
goto uninstall if $uninstall;


install:;
########################################################################################################
use File::Copy;

$_=[[],[]];
foreach my $dir (sort {length($a) <=> length($b)} grep ! /^\.+$/, @INC) {
$dir =~s/\\/\//g; $dir =~s/(\s|\/)*$//;
# we give priority to /site/ ... directories because they are not affected from syste, updates and patches
$dir=~/(?i)\/site/ ? ( push @{$_->[0]}, $dir ):( push @{$_->[1]}, $dir ) }
my $dir_target = ((@{$_->[0]},@{$_->[1]}))[0];

foreach (sort keys %source)
{
	if	('file' eq $source{$_})
	{
	print STDOUT "Installing file \"$dir_source/$_\" to \"$dir_target/$_\"\n";
	File::Copy::copy("$dir_source/$_","$dir_target/$_") or die "Could not copy file \"$dir_source/$_\" to \"$dir_target/$_\" because \"$^E\"\n";
	}
	elsif	('dir' eq $source{$_})
	{
	print STDOUT "Installing directory \"$dir_source/$_\" to \"$dir_target/$_\"\n";
		
		if ( $^O =~/(?i)MSWin/ )
		{		
		(my $win_src = "$dir_source/$_")=~s/\//\\/g;
		(my $win_trg = "$dir_target/$_")=~s/\//\\/g;
		if (-f $win_trg) {print STDOUT "Error. A file exists with the same name as module \"$win_trg\"\n"; exit 4}
		system("xcopy /Q /E /H /R /Y /I \"$win_src\" \"$win_trg\" 1> nul 2> nul");
		}
		else
		{
		unless (0 == system("/bin/cp -f -a \"$dir_source/$_\" \"$dir_target/\"")) {die "Could not copy \"$dir_source/$_\" directory to \"$dir_target\" because \"$^E\"\n" }		
		}
	}
}

print STDOUT "Module installed successfuly\n";
exit 0;
uninstall:;
########################################################################################################

foreach my $dir_target (grep ! /^\.+$/, @INC)
{
	foreach (keys %source)
	{
		if	('file' eq $source{$_})
		{
			if (-f "$dir_target/$_")
			{
			print STDOUT "Removing file \"$dir_target/$_\"\n";
			unlink("$dir_target/$_") || die "Could not delete file \"$dir_target/$_\" because \"$^E\"\n"
			}
		}
		elsif	('dir' eq $source{$_})
		{
			if (-d "$dir_target/$_")
			{
			print STDOUT "Removing directory \"$dir_target/$_\"\n";
			
				if ( $^O =~/(?i)MSWin/ )
				{				
				($_ = "$dir_target/$_")=~s/\//\\/g;
				unless (0 == system("rd /Q /S \"$_\"")) {die "Could not remove directory tree \"$_\" because \"$^E\"\n" }
				}
				else
				{
				unless (0 == system("/bin/rm -rf \"$dir_target/$_\"")) {die "Could not remove directory tree \"$dir_target/$_\" because \"$^E\"\n" }
				}			
			}
		}
	}
}

print STDOUT "Module uninstalled successfuly\n";
exit 0;