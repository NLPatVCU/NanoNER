#!/usr/bin/perl
# NanoB2B::NER
# (Last Updated $Id: NER.pm,v 0.09 2018/01/18 16:33:33 charityml Exp $)
#
# Perl module that turns labeled text lines into 
# ARFF files based on specified features
# that are extracted using MetaMap
# and runs through WEKA to average the results
#
# Copyright (c) 2017
#
# Megan Charity, Virginia Commonwealth University 
# charityml at vcu.edu 
#
# Bridget T. McInnes, Virginia Commonwealth University 
# btmcinnes at vcu.edu 
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to 
#
# The Free Software Foundation, Inc., 
# 59 Temple Place - Suite 330, 
# Boston, MA  02111-1307, USA.


=head1 NAME

    NanoB2B::NER - turns labeled text lines into ARFF files based on 
    specified features that are extracted using MetaMap and runs 
    through WEKA to average the results

=head1 DESCRIPTION

    This package turns labeled text lines into ARFF files based on 
    specified features that are extracted using MetaMap and runs 
    through WEKA to average the results

    For more information please see the NanoB2B::NER.pm documentation.

=head1 SYNOPSIS

    add synopsis

=head1 ABSTRACT

    There is a critical need to automatically extract and synthesize knowledge and
    trends in nanotechnology research from an exponentially increasing body of
    literature. Engineered nanomaterials (ENMs), such as nanomedicines, are
    continuously being discovered and Natural Language Processing approaches can
    semi‐automate the cataloging of ENMs and their unique physico‐chemical
    properties; automatically aggregate studies on their exposure and hazards; 
and link the physicochemical properties to the measured effects. 
    The goal of this project is to develop a nanomedicine entity extraction system 
    to automatically identify nanomedicine physico-characteristics, 
    exposure and biological effects.

=head1 INSTALL

    To install the module, run the following magic commands:

    perl Makefile.PL
    make
    make test
    make install

    This will install the module in the standard location. You will, most
    probably, require root privileges to install in standard system
    directories. To install in a non-standard directory, specify a prefix
    during the 'perl Makefile.PL' stage as:

    perl Makefile.PL PREFIX=/home/milk

    It is possible to modify other parameters during installation. The
    details of these can be found in the ExtUtils::MakeMaker
    documentation. However, it is highly recommended not messing around
    with other parameters, unless you know what you're doing.

=head1 FUNCTION DESCRIPTIONS
=cut

package NanoB2B::NER;

use 5.006;
use strict;
use warnings FATAL => 'all';

use NanoB2B::UniversalRoutines;
use NanoB2B::NER::Metaman;
use NanoB2B::NER::Arffman;
use NanoB2B::NER::Arffman2;
use NanoB2B::NER::Wekaman;
use NanoB2B::NER::Avgman;
use NanoB2B::NER::Modelman;
use NanoB2B::NER::Bucketman;

#the instances of the modules (named 'boy' because they are expendable and constantly changing - like Robin, BOY Wonder to BatMAN)
my $uniSub;
my $metaboy;
my $arffboy;
my $wekaboy;
my $avgboy;
my $modelboy;
my $bucketboy;

our $VERSION = '1.01';

#option variables
my $debug = 0;

#for wcs
my $wcs_found = 1;

=head1 NAME

    NanoB2B-NNER-PM::NER - The main file that runs all of the processes for NER

=head1 DESCRIPTION

    This package turns nanoparticle texts into ARFF
    files and WEKA accuracy files based on the nanoparticle characteristics
    found from pre-annotated articles

=head1 VERSION

    Version 1.01

=head1 INITIALIZING THE MODULE

    To create an instance of the ner module, using default values
    for all configuration options:

    use NanoB2B::NER;
    my %params =  ();
    $params{'dir'} = "my_directory";
    $params{'features'} = "ortho morph text pos cui sem";

    my $nner = new NanoB2B::NER(\%params);

=cut


# -------------------- Class methods start here --------------------

#  method to create a new NanpB2B-NNER-PM::NER object
#  output: $self <- an NER object
sub new {

    #grab class and parameters
    my $self = {};
    my $class = shift;

    return undef if(ref $class);

    my $params = shift;

    #bless this object - amen
    bless $self, $class;
    $self->_init($params);

    #retrieve parameters for universal-routines
    my %uniParams = ();
    $uniParams{'debug'} = $debug;
    $uniSub = NanoB2B::UniversalRoutines->new(\%uniParams);

    #return the object
    return $self;
}

#  method to initialize the NanoB2B::NER::Arffman object.
#  input : $parameters <- reference to a hash
#  output: (module variables to use in other parameters)
sub _init {
    my $self = shift;
    my $params = shift;

    $params = {} if(!defined $params);

    #get the parameters
    my $opt_dir 	     = $params->{'dir'};
    my $opt_file 	     = $params->{'file'};
    my $opt_sortbysize 	     = $params->{'sortBySize'};
    my $opt_index 	     = $params->{'index'};
    my $opt_debug 	     = $params->{'debug'};
    my $opt_importmeta 	     = $params->{'import_meta'};
    my $opt_features 	     = $params->{'features'};
    my $opt_buckets 	     = $params->{'buckets'};
    my $opt_file_buckets 	 = $params->{'file_buckets'};
    my $opt_stopwords 	     = $params->{'stopwords'};
    my $opt_is_cui 	     = $params->{'is_cui'};
    my $opt_sparse           = $params->{'sparse_matrix'};
    my $opt_prefix           = $params->{'prefix'};
    my $opt_suffix           = $params->{'suffix'};
    my $opt_wcs	             = $params->{'wcs'};
    my $opt_wekatype	     = $params->{'weka_type'};
    my $opt_wekasize	     = $params->{'weka_size'};
    my $opt_metamaparguments = $params->{'metamap_arguments'};
    my $opt_model	     = $params->{'model'};


    #set the global variables

    #required variables
    #if using the entire directory
    if(defined $opt_dir){
	$self->{program_dir} = $opt_dir;
    }else{
	print STDERR ("***ERROR: DIRECTORY NOT DEFINED!!***\n");
	exit(-1);
    }
    #grab the features you want to use
    if(defined $opt_features){	
	$self->{features} = $opt_features;
    }else{
	print STDERR ("***ERROR: FEATURE SET NOT DEFINED!!***\n");
	exit(-1);
    }
    

    #not required variables
    #if using one file
    if(defined $opt_file){  
	$self->{program_file} = $opt_file;
    }

    #run the programs with debug mode on
    if(defined $opt_debug){
	$self->{debug} = $opt_debug;
	$debug	       = $opt_debug;
    }else{
	$debug	= 0; 
    }
    
    #exclude stop words from arff vectors
    if(defined $opt_stopwords){
	$self->{stopwords} = $opt_stopwords;
    }

    #if a word doesn't have a cui - don't make a vector
    if(defined $opt_is_cui){									
	$self->{is_cui} = $opt_is_cui;
    }else{
	$self->{is_cui}	= 0;
    }

    #decide to turn vector's into sparse format
    if(defined $opt_sparse){
	$self->{sparse_matrix} = $opt_sparse;
    }else{
	$self->{sparse_matrix} = 0;
    }

    #decide to import metamap or not
    if(defined $opt_importmeta){							
	$self->{import_meta} = $opt_importmeta;	
    }else{
	$self->{import_meta} = 0;
    }

    #get the word prefix character count
    if(defined $opt_prefix){									
	$self->{prefix}	= $opt_prefix;
    }else{
	$self->{prefix} = 3;
    }
    #get the word suffix character count
    if(defined $opt_suffix){									
	$self->{suffix}	= $opt_suffix;
    }else{
	$self->{suffix}	= 3;
    }

    #check if to do worst-case-scenario backup -- TODO: add more detail on this
    if(defined $opt_wcs){										
	$self->{wcs} = $opt_wcs;
	$wcs_found   = 0;
    }

    #get the type of weka algorithm to run
    if(defined $opt_wekatype){									
	$self->{weka_type} = $opt_wekatype;
    }else{
	$self->{weka_type} = "weka.classifiers.bayes.NaiveBayes";
    }

    #set the memory allocation size for weka to run
    if(defined $opt_wekasize){
	$self->{weka_size} = $opt_wekasize;
    }else{
	$self->{weka_size} = "-Xmx2G";
    }
    
    #set the number of buckets to run for k-fold cross validation
    if(defined $opt_buckets){									
	$self->{bucketsNum} = $opt_buckets; 
    }else{
	$self->{bucketsNum} = 10;
    }
    
    #determine whether to split the lines into buckets or the files
    if(defined $opt_file_buckets){									
	$self->{fileBuckets} = $opt_file_buckets; 
    }else{
	$self->{fileBuckets} = 0;
    }

    #start at a certain file given an index
    if(defined $opt_index){										
	$self->{fileIndex} = $opt_index;
    }else{
	$self->{fileIndex} = 1;
    }	

    #start at a certain file given an index
    if(defined $opt_sortbysize){								
	$self->{sortSize} = $opt_sortbysize;
    }else{
	$self->{sortSize} = 0;
    }
    
    #run metamap with specific arguments
    if(defined $opt_metamaparguments){							
	$self->{metamap_arguments} = $opt_metamaparguments;
    } else {
	$self->{metamap_arguments} = "-q";
    }

    #  TODO: add description
    if(defined $opt_model){
	$self->{model} = $opt_model;
    }else{
	$self->{model} = 0;
    }

    #error handling?
    if(defined $opt_file and $self->{fileIndex} > 1){
	print STDERR ("***ERROR: Cannot have an index value for a single file!***\n");
	exit;
    }

    #check for out of bounds index
    opendir (my $DIR, $self->{program_dir}) or die $!;
    my @files = grep { $_ ne '.' and $_ ne '..' and 
			   substr($_, 0, 1) ne '_'} readdir $DIR;
    my $totFiles = @files;
    if($self->{fileIndex} > $totFiles){
	print STDERR ("***ERROR: Index cannot be greater than the number of files in the directory!***\n");
	exit;
    }

}




#########################			THE MEATY STUFF			##########################

=head3 nerByFile

  description:

    Runs the files specified in the parameters program_dir metamaps all the
    files, arffs all the files, wekas all the files, and averages all the files
    
    This NER method doesn't move on to the next file until all the methods 
    have been used

  input:

    None

  output:

    Metamap files, ARFF file sets, Weka file sets, and Averaged Accuracy files

  example:

    use NanoB2B::NER;
    my %params  = ();
    $params{'dir'} = "my_directory";
    $params{'features'} = "ortho morph text pos cui sem";

    my $nner = new NanoB2B::NER(\%params);
    $nner->nerByFile();

=cut

sub nerByFile{
    my $self = shift; 

    #open the directory	 
    opendir (my $DIR, $self->{program_dir}) or die  $!;							
    
    #if not doing a single file
    if(!defined $self->{program_file}){
	#get each file from the directory
	my @files  = grep { $_ ne '.' and $_ ne '..' 
				and substr($_, 0, 1) ne '_'} 
	readdir $DIR;	
	
	#sort by size?
	if($self->{sortSize}){
	    @files = sortBySize($self, \@files);
	}
	
	#ner the files individually
	my $totalTags = @files;
	for(my $a = $self->{fileIndex}; $a <= $totalTags; $a++){
	    $uniSub->printColorDebug("on_blue", "FILE #$a / $totalTags");
	    my $tag = $files[$a - 1];
	    
	    #metamap the files if needed
	    if(!$self->{import_meta}){
		$uniSub->printColorDebug("bold cyan", "---  METAMAP  ---\n");
		my %paramsm		      = ();
		$paramsm{'directory'}	      = $self->{program_dir};
		$paramsm{'index'}	      = $self->{index};
		$paramsm{'metamap_arguments'} = $self->{metamap_arguments};
		$paramsm{'debug'}	      = $debug;
		$metaboy		      = NanoB2B::NER::Metaman->new(\%paramsm);
		$metaboy->meta_file($tag);
	    }

	    #arff the file
	    $uniSub->printColorDebug("bold magenta", "---    ARFF    ---\n");
	    #define arffboy with the parameters
	    my %paramsr			      = ();
	    $paramsr{'directory'}	      = $self->{program_dir};
	    $paramsr{'features'}	      = $self->{features};
	    $paramsr{'bucketsNum'}	      = $self->{bucketsNum};
	    $paramsr{'fileBuckets'}       = $self->{fileBuckets};
	    $paramsr{'debug'}		      = $debug;
	    $paramsr{'prefix'}		      = $self->{prefix};
	    $paramsr{'suffix'}		      = $self->{suffix};
	    $paramsr{'index'}		      = $self->{index};
	    $paramsr{'stopwords'}	      = $self->{stopwords};
	    $paramsr{'is_cui'}		      = $self->{is_cui};
	    $paramsr{'sparse_matrix'}	      = $self->{sparse_matrix};
	    if(!$wcs_found){
		$paramsr{'wcs'} = $self->{wcs};
		$wcs_found = 1;
	    }

	    if($self->{fileBuckets}){
		    $arffboy = NanoB2B::NER::Arffman->new(\%paramsr);	
		    $arffboy->arff_file($tag);
		}

	    if($self->{buckets}){
	    	#weka the file
		    $uniSub->printColorDebug("bold yellow", "---    WEKA    ---\n");
		    
		    #define wekaboy with the parameters
		    my %paramsw = ();
		    $paramsw{'directory'} = $self->{program_dir};
		    $paramsw{'type'} = $self->{weka_type};
		    $paramsw{'weka_size'} = $self->{weka_size};
		    $paramsw{'features'} = $self->{features};
		    $paramsw{'buckets'} = $self->{bucketsNum};
		    $paramsw{'debug'} = $debug;
		    $wekaboy = NanoB2B::NER::Wekaman->new(\%paramsw);
		    $wekaboy->weka_file($tag);
		    
		    #model the file
		    if($self->{model}){
			$uniSub->printColorDebug("bold red", "---  MODEL  ---\n");
			my %paramsmo = ();
			$paramsmo{'directory'} = $self->{program_dir};
			$paramsmo{'type'} = $self->{weka_type};
			$paramsmo{'weka_size'} = $self->{weka_size};
			$paramsmo{'features'} = $self->{features};
			$paramsmo{'buckets'} = $self->{bucketsNum};
			$paramsmo{'debug'} = $debug;
			$modelboy = NanoB2B::NER::Modelman->new(\%paramsmo);
			$modelboy->make_model_file($tag);
		    }
		    
		    #average the file
		    $uniSub->printColorDebug("bold green", "---    AVG    ---\n");
		    #define avgboy with the parameters
		    my %paramsa = ();
		    $paramsa{'directory'} = $self->{program_dir};
		    my @a = split(/\./, $self->{weka_type});
		    $paramsa{'weka_dir'} = $a[$#a];
		    $paramsa{'features'} = $self->{features};
		    $paramsa{'buckets'} = $self->{bucketsNum};
		    $paramsa{'debug'} = $debug;
		    $avgboy = NanoB2B::NER::Avgman->new(\%paramsa);	
		    $avgboy->avg_file($tag);		
	    }else{
	    	$uniSub->printColorDebug("on_yellow", "NOT ENOUGH BUCKETS TO RUN WEKA OR AVERAGE");
	    }
	    
	    
	    
	    $uniSub->printColorDebug("on_blue", "##         FINISHED #$a - $tag!        ##");
	}
    }else{
	my $tag = $self->{program_file};
	$uniSub->printColorDebug("on_blue", "FILE #$tag");
	
	#metamap the files if needed
	if(!$self->{import_meta}){
	    $uniSub->printColorDebug("bold cyan", "---  METAMAP  ---\n");
	    my %paramsm = ();
	    $paramsm{'directory'} = $self->{program_dir};
	    $paramsm{'index'} = $self->{index};
	    $paramsm{'metamap_arguments'} = $self->{metamap_arguments};
	    $paramsm{'debug'} = $debug;
	    $metaboy = NanoB2B::NER::Metaman->new(\%paramsm);
	    $metaboy->meta_file($tag);
	}
	
	#arff the file
	$uniSub->printColorDebug("bold magenta", "---    ARFF    ---\n");
	#define arffboy with the parameters
	my %paramsr = ();
	$paramsr{'directory'} = $self->{program_dir};
	$paramsr{'features'} = $self->{features};
	$paramsr{'bucketsNum'} = $self->{bucketsNum};
	$paramsr{'debug'} = $debug;
	$paramsr{'prefix'} = $self->{prefix};
	$paramsr{'suffix'} = $self->{suffix};
	$paramsr{'index'} = $self->{index};
	$paramsr{'stopwords'} = $self->{stopwords};
	$paramsr{'is_cui'} = $self->{is_cui};
	$paramsr{'sparse_matrix'} = $self->{sparse_matrix};
	if(!$wcs_found){
	    $paramsr{'wcs'} = $self->{wcs};
	    $wcs_found = 1;
	}
	$arffboy = NanoB2B::NER::Arffman->new(\%paramsr);	
	$arffboy->arff_file($tag);
	
	if($self->{buckets}){
		#weka the file
		$uniSub->printColorDebug("bold yellow", "---    WEKA    ---\n");
		#define wekaboy with the parameters
		my %paramsw = ();
		$paramsw{'directory'} = $self->{program_dir};
		$paramsw{'type'} = $self->{weka_type};
		$paramsw{'weka_size'} = $self->{weka_size};
		$paramsw{'features'} = $self->{features};
		$paramsw{'buckets'} = $self->{bucketsNum};
		$paramsw{'debug'} = $debug;
		$wekaboy = NanoB2B::NER::Wekaman->new(\%paramsw);
		$wekaboy->weka_file($tag);
		
		#model the file
		if($self->{model}){
		    $uniSub->printColorDebug("bold red", "---  MODEL  ---\n");
		    my %paramsmo = ();
		    $paramsmo{'directory'} = $self->{program_dir};
		    $paramsmo{'type'} = $self->{weka_type};
		    $paramsmo{'weka_size'} = $self->{weka_size};
		    $paramsmo{'features'} = $self->{features};
		    $paramsmo{'buckets'} = $self->{bucketsNum};
		    $paramsmo{'debug'} = $debug;
		    $modelboy = NanoB2B::NER::Modelman->new(\%paramsmo);
		    $modelboy->make_model_file($tag);
		}
		
		#average the file
		$uniSub->printColorDebug("bold green", "---    AVG    ---\n");
		#define avgboy with the parameters
		my %paramsa = ();
		$paramsa{'directory'} = $self->{program_dir};
		my @a = split(/\./, $self->{weka_type});
		$paramsa{'weka_dir'} = $a[$#a];
		$paramsa{'features'} = $self->{features};
		$paramsa{'buckets'} = $self->{bucketsNum};
		$paramsa{'debug'} = $debug;
		$avgboy = NanoB2B::NER::Avgman->new(\%paramsa);	
		$avgboy->avg_file($tag);		
	}else{
		$uniSub->printColorDebug("on_yellow", "NOT ENOUGH BUCKETS TO RUN WEKA OR AVERAGE");
	}

	
	
	$uniSub->printColorDebug("on_blue", "##         FINISHED #$tag!        ##");
    }					
    
}


=head3 nerByMethod
    
description:

    Runs the files specified in the parameters program_dir metamaps all the 
    files, arffs all the files, wekas all the files, and averages all the files 
  
    This NER method doesn't move on to the next method until all the files 
    have been processed

input:

 None

output:

    Metamap files, ARFF file sets, Weka file sets, and Averaged Accuracy files
    
example:

  use NanoB2B::NER;
  my %params =  ();
  $params{'dir'} = "my_directory";
  $params{'features'} = "ortho morph text pos cui sem";

  my $nner = new NanoB2B::NER(\%params);
  $nner->nerByMethod();

=cut

sub nerByMethod{
    my $self = shift;

    #meta the files if needed
    if(!$self->{import_meta}){
	$self->metaSet();
    }
    
    #arff the files
    $self->arffSet();
    
    if($self->{bucketsNum} > 1){
    	#weka the files
	    $self->wekaSet();
	    
	    if($self->{model}){
		$self->modelSet();
	    }
	    
	    #average the files
	    $self->avgSet();
	}else{
		$uniSub->printColorDebug("on_yellow", "NOT ENOUGH BUCKETS TO RUN WEKA OR AVERAGE");
	}

	$uniSub->printColorDebug("on_cyan", "FINITO!");
    
}

=head3 nerByBuckets

  description:

    Runs the files specified in the parameters program_dir metamaps all the
    files, arffs all the files, wekas all the files, and averages all the files
    
    This NER method doesn't move on to the next file until all the methods 
    have been used

  input:

    None

  output:

    Metamap files, ARFF file sets, Weka file sets, and Averaged Accuracy files

  example:

    use NanoB2B::NER;
    my %params  = ();
    $params{'dir'} = "my_directory";
    $params{'features'} = "ortho morph text pos cui sem";

    my $nner = new NanoB2B::NER(\%params);
    $nner->nerByFile();

=cut

sub nerByBuckets{
    my $self = shift; 

    #setup the pseudo files
    if(!$self->{import_meta}){
    	$self->winter_soldier();
    }else{
    	#reroute the directory to the pseudo buckets directory 
		$self->{program_dir} = $self->{program_dir} . "/_PSEUDO_FILES";
    }
	
    #open the directory	 
    opendir (my $DIR, $self->{program_dir}) or die  $!;							
    
	#get each file from the directory
	my @files  = grep { $_ ne '.' and $_ ne '..' 
				and substr($_, 0, 1) ne '_'} 
	readdir $DIR;	
	
	#sort by size?
	if($self->{sortSize}){
	    @files = sortBySize($self, \@files);
	}
	
	#see if metamap is needed for datastructures
	my $feats_ref = $self->{features};
	my @feats = split(/ /, $feats_ref);
	my $needMeta = 0;
	if($uniSub->inArr("pos", \@feats) || $uniSub->inArr("cui", \@feats) || $uniSub->inArr("sem", \@feats)){
		$needMeta = 1;
	}


	#ner the files individually
	my $totalTags = @files;
	for(my $a = $self->{fileIndex}; $a <= $totalTags; $a++){
	    $uniSub->printColorDebug("on_blue", "FILE #$a / $totalTags");
	    my $tag = $files[$a - 1];
	    
	    #metamap the files if needed
	    if(!$self->{import_meta} && $needMeta){
		$uniSub->printColorDebug("bold cyan", "---  METAMAP  ---\n");
		my %paramsm		      = ();
		$paramsm{'directory'}	      = $self->{program_dir};
		$paramsm{'index'}	      = $self->{index};
		$paramsm{'metamap_arguments'} = $self->{metamap_arguments};
		$paramsm{'debug'}	      = $debug;
		$metaboy		      = NanoB2B::NER::Metaman->new(\%paramsm);
		$metaboy->meta_file($tag);
	    }
	}
	#arff2 the set
	$uniSub->printColorDebug("bold magenta", "---    ARFF 2    ---\n");
	#define arffboy with the parameters
	my %paramsr			      = ();
	$paramsr{'directory'}	      = $self->{program_dir};
	$paramsr{'features'}	      = $self->{features};
	$paramsr{'bucketsNum'}	      = $self->{bucketsNum};
	$paramsr{'fileBuckets'}       = $self->{fileBuckets};
	$paramsr{'debug'}		      = $debug;
	$paramsr{'prefix'}		      = $self->{prefix};
	$paramsr{'suffix'}		      = $self->{suffix};
	$paramsr{'index'}		      = $self->{index};
	$paramsr{'stopwords'}	      = $self->{stopwords};
	$paramsr{'is_cui'}		      = $self->{is_cui};
	$paramsr{'sparse_matrix'}	      = $self->{sparse_matrix};
	if(!$wcs_found){
		$paramsr{'wcs'} = $self->{wcs};
		$wcs_found = 1;
	}

	$arffboy = NanoB2B::NER::Arffman2->new(\%paramsr);	
	$arffboy->arff_file_buckets();

	for(my $a = $self->{fileIndex}; $a <= $totalTags; $a++){
	    $uniSub->printColorDebug("on_blue", "FILE #$a / $totalTags");
	    my $tag = $files[$a - 1];
		#weka the file
		    $uniSub->printColorDebug("bold yellow", "---    WEKA    ---\n");
		    my @thing = split('_', $tag);
		    my $bucketID = $thing[1] + 0;
		    
		    #define wekaboy with the parameters
		    my %paramsw = ();
		    $paramsw{'directory'} = $self->{program_dir};
		    $paramsw{'type'} = $self->{weka_type};
		    $paramsw{'weka_size'} = $self->{weka_size};
		    $paramsw{'features'} = $self->{features};
		    $paramsw{'buckets'} = $self->{bucketsNum};
		    $paramsw{'debug'} = $debug;
		    $wekaboy = NanoB2B::NER::Wekaman->new(\%paramsw);
		    $wekaboy->weka_file_buckets($tag, $bucketID);
		    
		    #model the file
		    if($self->{model}){
			$uniSub->printColorDebug("bold red", "---  MODEL  ---\n");
			my %paramsmo = ();
			$paramsmo{'directory'} = $self->{program_dir};
			$paramsmo{'type'} = $self->{weka_type};
			$paramsmo{'weka_size'} = $self->{weka_size};
			$paramsmo{'features'} = $self->{features};
			$paramsmo{'buckets'} = $self->{bucketsNum};
			$paramsmo{'debug'} = $debug;
			$modelboy = NanoB2B::NER::Modelman->new(\%paramsmo);
			$modelboy->make_model_file($tag);
		    }
		    
		    #average the file
		    $uniSub->printColorDebug("bold green", "---    AVG    ---\n");
		    #define avgboy with the parameters
		    my %paramsa = ();
		    $paramsa{'directory'} = $self->{program_dir};
		    my @a = split(/\./, $self->{weka_type});
		    $paramsa{'weka_dir'} = $a[$#a];
		    $paramsa{'features'} = $self->{features};
		    $paramsa{'buckets'} = $self->{bucketsNum};
		    $paramsa{'debug'} = $debug;
		    $avgboy = NanoB2B::NER::Avgman->new(\%paramsa);	
		    #$avgboy->avg_file_buckets($tag);		

		    sleep(1);
    }

	$uniSub->printColorDebug("on_blue", "##         FINISHED!        ##");
    				
    
}

=head3 winter_soldier

description:

  splits the files into buckets and reroutes the directory to use

input:

 None

output:

    New concatenated files under the _PSEUDO_FILES directory 
    sorted based on randomized buckets

example:

  use NanoB2B::NER;
  my %params =  ();
  $params{'directory'} = "my_directory";
  $params{'features'} = "ortho morph text pos cui sem";
  $params{'bucketsNum'} = 5;
  $params{'debug'} = 1;

  my $nner = new NanoB2B::NER(\%params);
  $nner->winter_soldier();

=cut
#
sub winter_soldier{
	my $self = shift;

	$uniSub->printColorDebug("bright_red", "---  FILE BUCKETS  ---\n");
	#make pseudo files from the Bucketman module
	my %paramsb = ();
	$paramsb{'directory'} = $self->{program_dir};
	$paramsb{'bucketsNum'} = $self->{bucketsNum};
	$paramsb{'debug'} = $self->{debug};
	$bucketboy = NanoB2B::NER::Bucketman->new(\%paramsb);
	$bucketboy->sudowoodo();

	#reroute the directory to the pseudo buckets directory 
	$self->{program_dir} = $self->{program_dir} . "/_PSEUDO_FILES";
}

=head3 metaSet

description:

  Runs a set of files through metamap

input:

 None

output:

    Metamap files for every file found in the directory specified in 
    the constructor parameters

example:

  use NanoB2B::NER;
  my %params =  ();
  $params{'dir'} = "my_directory";
  $params{'features'} = "ortho morph text pos cui sem";

  my $nner = new NanoB2B::NER(\%params);
  $nner->metaSet();

=cut
sub metaSet{
    my $self = shift;
    
    print "\tDIR: " .  $self->{'program_dir'} . "\n";
    
    #open the directory	 
    opendir (my $DIR, $self->{program_dir}) or die $!;
    
    my @tags = grep { $_ ne '.' and $_ ne '..' and substr($_, 0, 1) ne '_'} 
    readdir $DIR;	#get each file from the directory
    
    my $totalTags = @tags;
    
    #if only file
    if($self->{program_file}){
	$totalTags = 1;
    }
    
    #sort by size?
    if($self->{sortSize}){
	@tags = sortBySize($self, \@tags);
    }
    
    #if only one file reduce it to the one
    if(defined $self->{program_file}){
	@tags = ($self->{program_file});
    }
    
    #define metaboy with the parameters
    my %params = ();
    $params{'directory'} = $self->{program_dir};
    $params{'index'} = $self->{index};
    $params{'metamap_arguments'} = $self->{metamap_arguments};
    $params{'debug'} = $debug;
    $metaboy = NanoB2B::NER::Metaman->new(\%params);
    
    #run set through metamap
    for(my $a = $self->{fileIndex}; $a <= $totalTags; $a++){
	$uniSub->printColorDebug("bold cyan", "META FILE #$a / $totalTags\n");
	my $tag = $tags[$a - 1];
	$metaboy->meta_file($tag);
	$uniSub->printColorDebug("bold cyan", "##         FINISHED METAMAP #$a - $tag!        ##\n");
    }
}

=head3 arffSet

description:

    Turns a set of files into ARFF files based on the features specificied 
    in the constructor parameters

input:

 None

output:

    ARFF file sets for every file found in the directory specified in the 
    constructor parameters

example:

  use NanoB2B::NER;
  my %params =  ();
  $params{'dir'} = "my_directory";
  $params{'features'} = "ortho morph text pos cui sem";

  my $nner = new NanoB2B::NER(\%params);
  $nner->arffSet();

=cut
sub arffSet{
    my $self = shift;
    
    #open the directory	 
    opendir (my $DIR, $self->{program_dir}) or die $!;							
    my @tags = grep { $_ ne '.' and $_ ne '..' and substr($_, 0, 1) ne '_'} readdir $DIR;	#get each file from the directory
    my $totalTags = @tags;
    
    #if only one file
    if($self->{program_file}){
	$totalTags = 1;
    }
    
    #sort by size?
    if($self->{sortSize}){
	@tags = sortBySize($self, \@tags);
    }
    
    #if only one file reduce it to the one
    if(defined $self->{program_file}){
	@tags = ($self->{program_file});
    }
    
    #define arffboy with the parameters
    my %params = ();
    $params{'directory'} = $self->{'program_dir'};
    $params{'features'} = $self->{'features'};
    $params{'bucketsNum'} = $self->{'bucketsNum'};
    $params{'fileBuckets'} = $self->{'fileBuckets'};
    $params{'debug'} = $debug;
    $params{'prefix'} = $self->{'prefix'};
    $params{'suffix'} = $self->{'suffix'};
    $params{'index'} = $self->{'index'};
    $params{'stopwords'} = $self->{'stopwords'};
    $params{'is_cui'} = $self->{'is_cui'};
    $params{'sparse_matrix'} = $self->{'sparse_matrix'};
    $params{'wcs'} = $self->{'wcs'};
    $arffboy = NanoB2B::NER::Arffman->new(\%params);			
    
    for(my $a = $self->{fileIndex}; $a <= $totalTags; $a++){
	$uniSub->printColorDebug("bold magenta", "ARFF FILE #$a / $totalTags\n");
	my $tag = $tags[$a - 1];
	if($wcs_found){
	    $params{'wcs'} = "";
	    $arffboy = NanoB2B::NER::Arffman->new(\%params);
	}else{
	    $wcs_found = 1;
	}
	$arffboy->arff_file($tag);
	$uniSub->printColorDebug("bold magenta", "##         FINISHED ARFF #$a - $tag!        ##\n");
    }
}

=head3 wekaSet

description:

  Runs a set of ARFF files through WEKA

input:

 None

output:

    WEKA files for every file found in the directory specified in the 
    constructor parameters

example:

  use NanoB2B::NER;
  my %params =  ();
  $params{'dir'} = "my_directory";
  $params{'features'} = "ortho morph text pos cui sem";

  my $nner = new NanoB2B::NER(\%params);
  $nner->wekaSet();

=cut
sub wekaSet{
    my $self = shift;
    
    #open the directory	 
    opendir (my $DIR, $self->{program_dir}) or die $!;							
    my @tags = grep { $_ ne '.' and $_ ne '..' and substr($_, 0, 1) ne '_'} readdir $DIR;	#get each file from the directory
    my $totalTags = @tags;
    
    #if only one file
    if($self->{program_file}){
	$totalTags = 1;
    }
    
    #sort by size?
    if($self->{sortSize}){
	@tags = sortBySize($self, \@tags);
    }
    
    #if only one file reduce it to the one
    if(defined $self->{program_file}){
	@tags = ($self->{program_file});
    }
    
    #define wekaboy with the parameters
    my %params = ();
    $params{'directory'} = $self->{program_dir};
    $params{'type'} = $self->{weka_type};
    $params{'weka_size'} = $self->{weka_size};
    $params{'features'} = $self->{features};
    $params{'buckets'} = $self->{bucketsNum};
    $params{'fileBuckets'} = $self->{'fileBuckets'};
    $params{'debug'} = $debug;
    $wekaboy = NanoB2B::NER::Wekaman->new(\%params);			
    
    for(my $a = $self->{fileIndex}; $a <= $totalTags; $a++){
	$uniSub->printColorDebug("bold yellow", "##         WEKA FILE #$a / $totalTags         ##\n");
	my $tag = $tags[$a - 1];
	$wekaboy->weka_file($tag);
	$uniSub->printColorDebug("bold yellow", "##         FINISHED WEKA #$a - $tag!        ##\n");
	sleep(1);
    }
}

=head3 modelSet

description:

    Creates WEKA models from the training ARFF files

input:

 None

output:

    WEKA model files for every file with training ARFF files

example:

  use NanoB2B::NER;
  my %params =  ();
  $params{'dir'} = "my_directory";
  $params{'features'} = "ortho morph text pos cui sem";

  my $nner = new NanoB2B::NER(\%params);
  $nner->modelSet();

=cut
sub modelSet{
    my $self = shift;
    
    #open the directory	 
    opendir (my $DIR, $self->{program_dir}) or die $!;							
    my @tags = grep { $_ ne '.' and $_ ne '..' and substr($_, 0, 1) ne '_'} readdir $DIR;	#get each file from the directory
    my $totalTags = @tags;
    
    #if only one file
    if($self->{program_file}){
	$totalTags = 1;
    }
    
    #sort by size?
    if($self->{sortSize}){
	@tags = sortBySize($self, \@tags);
    }
    
    #if only one file reduce it to the one
    if(defined $self->{program_file}){
	@tags = ($self->{program_file});
    }
    
    #define wekaboy with the parameters
    my %params = ();
    $params{'directory'} = $self->{program_dir};
    $params{'type'} = $self->{weka_type};
    $params{'weka_size'} = $self->{weka_size};
    $params{'features'} = $self->{features};
    $params{'buckets'} = $self->{bucketsNum};
    $params{'fileBuckets'} = $self->{'fileBuckets'};
    $params{'debug'} = $debug;
    $modelboy = NanoB2B::NER::Modelman->new(\%params);			
    
    for(my $a = $self->{fileIndex}; $a <= $totalTags; $a++){
	$uniSub->printColorDebug("bold red", "##         MODEL FILE #$a / $totalTags         ##\n");
	my $tag = $tags[$a - 1];
	$modelboy->make_model_file($tag);
	$uniSub->printColorDebug("bold red", "##         FINISHED MODEL #$a - $tag!        ##\n");
	sleep(1);
    }
}


=head3 avgSet

description:

    Averages together a set of WEKA files

input:

    None

output:

    Average accuracy files for every file found in the directory 
    specified in the constructor parameters

example:

  use NanoB2B::NER;
  my %params =  ();
  $params{'dir'} = "my_directory";
  $params{'features'} = "ortho morph text pos cui sem";

  my $nner = new NanoB2B::NER(\%params);
  $nner->avgSet();

=cut
sub avgSet{
    my $self = shift;
    
    #open the directory
    opendir (my $DIR, $self->{program_dir}) or die $!;							
    my @tags = grep { $_ ne '.' and $_ ne '..' and substr($_, 0, 1) ne '_'} readdir $DIR;	#get each file from the directory
    my $totalTags = @tags;
    
    #if only one file
    if($self->{program_file}){
	$totalTags = 1;
    }
    
    #sort by size?
    if($self->{sortSize}){
	@tags = sortBySize($self, \@tags);
    }
    
    #if only one file reduce it to the one
    if(defined $self->{program_file}){
	@tags = ($self->{program_file});
    }
    
    #define avgboy with the parameters
    my %params = ();
    $params{'directory'} = $self->{program_dir};
    my @a = split(/\./, $self->{weka_type});
    $params{'weka_dir'} = $a[$#a];
    $params{'features'} = $self->{features};
    $params{'buckets'} = $self->{bucketsNum};
    $params{'fileBuckets'} = $self->{'fileBuckets'};
    $params{'debug'} = $debug;
    $avgboy = NanoB2B::NER::Avgman->new(\%params);			
    
    for(my $a = $self->{fileIndex}; $a <= $totalTags; $a++){
	$uniSub->printColorDebug("bold green", "AVG FILE #$a / $totalTags\n");
	my $tag = $tags[$a - 1];
	$avgboy->avg_file($tag);
	$uniSub->printColorDebug("bold green", "##         FINISHED AVERAGING #$a - $tag!        ##\n");
    }
}

#  TODO: add comment on what this function does
sub isArr{
    my $self = shift;
    my $arr_ref = shift;
    my @arr = @$arr_ref;
    
    print "yay\n";
    
}

#  TODO: reformat comment to match above
#sorts a directory by the file size
# input  : @files  <-- get the list of files in the folder
# output : @newset <-- the set of files ordered by size from smallest to largest
sub sortBySize{
    my $self = shift;
    my $files_ref = shift;
    my @files = @$files_ref;
    
    my %hash = ();
    my @newSet = ();
    
    my $dir = $self->{program_dir};
    
    #create hashmap -- TODO : revise by overloading the sort mechanism 
    foreach my $file (@files){
	my $s = -s "$dir/$file";
	$hash{$s} = $file;
    }
    
    #add sorted sizes to array
    foreach my $key (sort { $a <=> $b } keys %hash){
	my $name = $hash{$key};
	#printColorDebug("cyan", "$name - $key\n");
	push @newSet, $name;
    }
    
    return @newSet;
}

1;

=head1 SEE ALSO

=head1 AUTHOR

Megan Charity <charityml@vcu.edu>
Bridget T McInnes <btmcinnes@vcu.edu> 

=head1 COPYRIGHT

 Copyright (c) 2017
 Megan Charity, Virginia Commonwealth University 
 charityml at vcu.edu 

 Bridget T. McInnes, Virginia Commonwealth University 
 btmcinnes at vcu.edu 

This program is free software; you can redistribute it and/or modify it under
the terms of the GNU General Public License as published by the Free Software
Foundation; either version 2 of the License, or (at your option) any later
version.

This program is distributed in the hope that it will be useful, but WITHOUT
ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with
this program; if not, write to 

 The Free Software Foundation, Inc.,
 59 Temple Place - Suite 330,
 Boston, MA  02111-1307, USA.

=cut
