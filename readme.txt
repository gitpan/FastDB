FastDB is a pure Perl file based databased. It is using
directories to hold the values of indexed columns.

The implementation of FastDB is based on three modules:

	FastDB::Load.pm
	FastDB::Question.pm
	FastDB::Delete.pm

Data insertion using the ( FastDB::Load ) is not very fast,
but the queries when you have indexed the correct columns
and have applied the right Filters is very fast. Faster of some
other big players : )

FastDB is working as is to ALL operating systems with Perl 5.1 or greater.

Read install.txt for installation instructions.
I hope you like it, any suggestions/contributins are wellcome.

George Mpouras (gravitalsun@hotmail.com)
5 Feb 2011
Athens, Greece