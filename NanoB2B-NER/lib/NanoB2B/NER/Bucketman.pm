#!/usr/bin/perl
# NanoB2B-NER::NER::Bucketman
#
# Creates new buckets from grouping FDA labels
# Version 1.0
#
# Program by Milk

package NanoB2B::NER::Bucketman;

use NanoB2B::UniversalRoutines;
use File::Path qw(make_path);			#makes sub directories	
use strict;
use warnings;
use List::Util qw(shuffle);

####          GLOBAL VARIABLES           ####

#option variables
my $program_dir;
my $buckets = 10;
my $debug = 0;

#universal subroutines object
my %uniParams = ();
my $uniSub;



sub new {
	#grab class and parameters
    my $self = {};
    my $class = shift;
    return undef if(ref $class);
    my $params = shift;

    #bless this object
    bless $self, $class;
    $self->_init($params);

    #retrieve parameters for universal-routines
    $uniParams{'debug'} = $debug;
	$uniSub = NanoB2B::UniversalRoutines->new(\%uniParams);

	#return the object
    return $self;
}
#  method to initialize the NanoB2B::NER::Wekaman object.
#  input : $parameters <- reference to a hash
#  output: 
sub _init {
    my $self = shift;
    my $params = shift;

    $params = {} if(!defined $params);

    #  get some of the parameters
    my $diroption = $params->{'directory'};
	my $bucketsNumoption = $params->{'bucketsNum'};
    my $debugoption = $params->{'debug'};

    #set the global variables
    if(defined $debugoption){$debug = $debugoption;}
    if(defined $diroption){$program_dir = $diroption;}
    if(defined $bucketsNumoption){$buckets = $bucketsNumoption;}
}

#make some pseudo-files
sub sudowoodo{
	my $self = shift;

	#open the directory	 
    opendir (my $DIR, $program_dir) or die "Can't find your $program_dir directory thingy or whatever";			

    #get each file from the directory
	my @files  = grep { $_ ne '.' and $_ ne '..' 
				and substr($_, 0, 1) ne '_'} 
	readdir $DIR;

	#randomize the buckets
	# it will be in the form
	# (bucket #) - (file names)
	my %pseudoBuckets = ();
	my $totFiles = @files;
	my @randFiles = shuffle @files;

	for(my $b = 0;$b < $totFiles;$b++){
		push(@{$pseudoBuckets{$b % $buckets}}, $randFiles[$b]);
	}


	#now let's make some brand spanking new files
	make_path("$program_dir/_PSEUDO_FILES");
	foreach my $buck(keys %pseudoBuckets){
		my $b2 = $buck+1;
		#make a new file
		my $BUCKETFILE;
		if($b2 < 10){
			open($BUCKETFILE, ">", ("$program_dir/_PSEUDO_FILES/file_0$b2"))
		}else{
			open($BUCKETFILE, ">", ("$program_dir/_PSEUDO_FILES/file_$b2"))
		}

		#write in from the old files
		my @set = @{$pseudoBuckets{$buck}};
		foreach my $file(@set){
			$uniSub->printColorDebug("yellow", "WRITING FILE: $file to file_" . ($b2 < 10 ? "0$b2\n" : "$b2\n"));
			open(my $OLD_FILE, "<", ("$program_dir/$file"));
			my @lines = <$OLD_FILE>;
			foreach my $line(@lines){$uniSub->print2File($BUCKETFILE, $line);}
			close $OLD_FILE;
		}
		close $BUCKETFILE;
	}

}



1;