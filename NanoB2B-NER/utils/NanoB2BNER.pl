#!/usr/local/bin/perl

=head1 NAME

NanoB2BNER.pl - This program provides an example of using the 
    ner methods in NanoB2B::NER

=head1 SYNOPSIS

This program provides an example of using the ner methods in 
NanoB2B::NER

=head1 USAGE

Usage: NanoB2BNER.pl [OPTIONS]

=head1 OPTIONS

Optional command line arguements

=head2 Options (* = required):

=head3 --help

Displays a brief summary of program options.

=head3 *--dir

The name of the directory that contain the files

=head3 *--features STR

Get the list of features you want to use for the set
Ex. "ortho morph text pos cui sem"

=head3 --debug

Sets the debug flag on for testing

=head3 --process STR

Decide how to run NNER (by method or by file)
Ex/ "file" = each method processes the file before going to the next
Ex/ "method" = each file is run the the method before going to the next method

=head3 --index NUM

Starts the program at a certain index number in a directory

=head3 --file STR

Defines the file source of a single article

=head3 --sort

Option to sort the directory files by size

=head3 --import_meta

Runs the program with the pre-made meta data

=head3 --stopwords

Eliminates stop words from vectors in the ARFF files

=head3 --buckets NUM

The number of buckets for the k-fold cross validation

=head3 --prefix NUM

Sets the prefix character amount for morph features

=head3 --suffix NUM

Sets the suffix character amount for morph features

=head3 --weka_type STR

Sets the type of weka algorithm to use on the data

=head3 --weka_size STR

Sets the maximum memory value to run weka with

=head1 SYSTEM REQUIREMENTS

=over

=item * Perl (version 5.8.5 or better) - http://www.perl.org

=back

=head1 CONTACT US
   
  If you have any trouble installing and using NanoB2B-NER, 
  please contact us: 

      Megan Charity : charityml at vcu.edu

=head1 AUTHOR

 Megan Charity, Virginia Commonwealth University 
 Bridget T. McInnes, Virginia Commonwealth University 

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
this program; if not, write to:

 The Free Software Foundation, Inc.,
 59 Temple Place - Suite 330,
 Boston, MA  02111-1307, USA.

=cut

####################		IMPORTS  		###################

use Getopt::Long;		 # options 
use Getopt::Long qw(GetOptions); #shorten option length
use NanoB2B::NER;

################# 			OPTIONS        	 #####################

eval(GetOptions("help", "dir=s", "features=s", "debug", "process=s", "file=s", "sort", "import_meta", "stopwords=s", "is_cui", "sparse_matrix", "prefix=i", "suffix=i", "index=i", "wcs=s", "weka_type=s", "weka_size=s", "buckets=i", "file_buckets", "mm_arg=s", "model")) or die ("Check your options!\n");

my %params = ();
my $process = "";

#   if help is defined, print out help
if( defined $opt_help ) {
    $opt_help = 1;
    &showHelp;
    exit;
}

#required parameters
if(defined $opt_dir){	#get the name of the directory to look in
	$params{'dir'} = $opt_dir;
	print "---Opening directory: \"$opt_dir\"---\n";
}
else {
    "The --dir option is required to be defined.\n";
    &showHelp;
    exit;
}
if(defined $opt_features){ #grab the features you want to use
	$params{'features'} = $opt_features;
}
else {
    "The --feature option is required to be defined.\n";
    &showHelp;
    exit;
}

#########################################################
#optional parameters
#########################################################

#have the debug print statements
if(defined $opt_debug){	
	$params{'debug'} = 1;
	print("---DEBUG MODE---\n")							
}

if(defined $opt_process){
	$process = $opt_process;
}else{
	$process = "file";
}

#if using one file
if(defined $opt_file){ 
    $params{'file'} = $opt_file;
    if(! (-e "$opt_dir/$opt_file")){
	print "$opt_file DNE";
    }else{
	print "---Opening file: \"$opt_file\"---\n";
    }
}
#sort the directory to access the files by smallest first
if(defined $opt_sort){
    $params{'sortBySize'} = $opt_sort;
    print("---SORTING DIRECTORY FILES BY SIZE---\n");
}
#set the number of buckets to run
if(defined $opt_buckets){
    $params{'buckets'} = $opt_buckets;
}		
#whether to do the file_bucket method or not
if(defined $opt_file_buckets){
    $params{'file_buckets'} = 1;
    print("---USING FILE BUCKETS METHOD---\n");
    $process = "buckets";
}else{
    $params{'file_buckets'} = 0;
}
#start at a certain file given an index
if(defined $opt_index){	
    $params{'index'} = $opt_index;
}

if(defined $opt_stopwords){
    $params{'stopwords'} = $opt_stopwords;
    print("---ELIMINATING STOP WORDS w/ $opt_stopwords file---\n");	 
}

if(defined $opt_is_cui){
    $params{'is_cui'} = 1;
    print("---EXCLUDING VECTORS FOR WORDS WITHOUT CUIS---\n");
}else{
    $params{'is_cui'} = 0;
}

if(defined $opt_sparse_matrix){
    $params{'sparse_matrix'} = 1;
    print("---USING SPARSE MATRIX GENERATION---\n");
}else{
    $params{'sparse_matrix'} = 0;
}
#grab metamap file instead of make them
if(defined $opt_import_meta){
    $params{'import_meta'} = 1;
    print("---Importing MetaMap Data---\n"); 
}else{
    $params{'import_meta'} = 0;
    print("---Creating MetaMap Data---\n");
}
#get the word prefix character count
if(defined $opt_prefix){ 
    $params{'prefix'} = $opt_prefix;
}
#get the word suffix character count
if(defined $opt_suffix){ 
    $params{'suffix'} = $opt_suffix;
}

if(defined $opt_wcs){
    $params{'wcs'} = $opt_wcs;
    print("---RUNNING WORSE CASE SCENARIO: $opt_wcs---\n");
}

if(defined $opt_weka_type){
    $params{'weka_type'} = $opt_weka_type;
    #average the weka accuracies
    print("---RUNNING $weka_type WEKA---\n"); 
}

if(defined $opt_weka_size){
    $params{'weka_size'} = $opt_weka_size;
    #average the weka accuracies
    print("---MAXIMUM WEKA MEMORY = $opt_weka_size---\n");
}	
if(defined $opt_metamap_arguments){
    $params{'mm_arg'} = $opt_metamap_arguments;
}
else{
    $params{'mm_arg'} = "-q";
}

if(defined $opt_model){
    $params{'model'} = 1;
    print("---MAKING MODELS WITH ARFF TRAIN DATA--\n");
}else{
    $params{'model'} = 0;
}


if(defined $opt_file_buckets and defined $opt_file){
    print("***ERROR: CANNOT RUN FILE BUCKETS ON JUST ONE FILE!***\n");
    print("***         ONE OR THE OTHER MUST BE USED          ***\n");
    exit;
}

#help screen
sub showHelp{
	print("                     NanoB2B-NER -- Version 2.0                     \n");
	print("                   ==============================                   \n");
	print("\n");
	print("######          THIS PROGRAM TURNS NANOPARTICLE TEXTS         ######\n");
	print("######         INTO ARFF FILES AND WEKA ACCURACY FILES        ######\n");
	print("######        BASED ON THE NANOPARTICLE CHARACTERISTICS       ######\n");
	print("######          FOUND FROM THE PRE-ANNOTATED ARTICLES         ######\n");
	print("\n");
	print("\n");
	print("--help             Opens this help screen\n");
	print("\n");
	print("*** REQUIRED PARAMETERS ***\n");
	print("--dir DIR          Defines the directory of a set of articles\n");
	print("--features STR[s]  Get the list of features you want to use for the set\n");
	print("                        -->   \"ortho morph text pos cui sem\"\n");
	print("\n");
	print("*** PROCESS PARAMETERS ***\n"); # TODO: add defaults
	print("--debug            Runs the program with debugging print statements\n\n");
	print("--process STR      Decide how to run NNER (by method or by file)\n");
	print("                   --> \"file\"=each method processes the file\n");
    print("                   --> \"method\"=each file is run in the method\n");
	print("                   --> \"buckets\"=pseduo files are made and runs off buckets\n");
	print("                   --> \"meta\", \"arff\", \"weka\", or \"avg\"=run on set\n\n");
    print("--buckets NUM      The number of buckets for the k-fold cross validation\n\n");
	print("--file_buckets     Buckets the files instead of the lines\n\n");
	print("--index NUM        Starts the program at a certain index number in a directory\n\n");
	print("--file FILE        Defines the file source of a single article\n\n");
	print("--sort             Option to sort the directory files by size\n\n");
	print("--import_meta      Runs the program with the pre-made meta data\n\n");
	print("--mm_arg STR       Runs MetaMap with specified arguments\n\n");
	print("--wcs STR          Worst-case-scenario -- start from a set bucket and feature set\n");
	print("                   --> FORMAT: '(bucket #)-(feature abbreviation)\n\n");
	
	print("*** FEATURE SELECTION  PARAMETERS ***\n");
	print("--stopwords FILE   Remove stop words from vectors in the ARFF\n\n");
	print("--is_cui           Creates a vector for a word only if has a UMLS CUI\n\n");
	print("--sparse_matrix    Generates the vectors as a sparse matrix\n\n");
       	
	print("--prefix NUM       Sets the prefix character amount for morph features\n\n");
	print("--suffix NUM       Sets the suffix character amount for morph features\n\n");
	
	print("*** WEKA PARAMETERS ***\n");
	print("--weka_type STR    Sets the type of weka algorithm to use on the data\n\n");
	print("--weka_size STR    Sets the maximum memory value to run weka with\n");
	print("                   --> (ex. -Xmx2G, -Xmx6G, -Xmx64G)\n\n");
	print("--model            Create models in WEKA using the train files\n\n");
	
	print("*** EXAMPLE COMMAND ***\n");
	print("perl NanoB2BNER.pl --dir my_directory --features=\"ortho morph text pos cui sem\" --debug --process=\"file\" --buckets=5 --import --index=18 --weka_type weka.classifiers.functions.SMO --weka_size=\"-Xmx6G\" --wcs=\"5-omt\"\n\n");
}


#  function to output minimal usage notes
sub minimalUsageNotes {
    
    print "Usage: NanoB2BNER.pl --dir DIRECTORYNAME --features FEATURESET [OPTIONS]\n\n";
    &askHelp();
    exit;
}

#  function to output the version number
sub showVersion {
    print '$Id: NanoB2BNER.pl,v 1.00 2017/02/22 13:47:05 btmcinnes Exp $';
    print "\nCopyright (c) 2017, Megan Charity & Bridget McInnes\n";
}

#  function to output "ask for help" message when user's goofed
sub askHelp {
    print STDERR "Type MetaMapDataStructures.pl --help for help.\n";
}
    

#########################		test code 		######################

my $nner = NanoB2B::NER->new(\%params);
if($process eq "file"){
    $nner->nerByFile();
}elsif($process eq "method"){
    $nner->nerByMethod();
}elsif($process eq "meta"){
    $nner->metaSet();
}elsif($process eq "arff"){
    $nner->arffSet();
}elsif($process eq "weka"){
    $nner->wekaSet();
}elsif($process eq "model"){
    $nner->modelSet();
}elsif($process eq "avg"){
    $nner->avgSet();
}elsif($process eq "buckeroo"){
    $nner->winter_soldier();
}elsif($process eq "buckets"){
    $nner->nerByBuckets();
}else{
    print("***ERROR: INVALID PROCESS METHOD FOR NNER!***\n");
    exit;
}
