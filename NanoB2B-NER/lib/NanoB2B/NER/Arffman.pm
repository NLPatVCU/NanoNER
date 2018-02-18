#!/usr/bin/perl
# NanoB2B-NER::NER::Arffman
#
# Creates ARFF files from annotated files
# Version 1.9
#
# Program by Milk

package NanoB2B::NER::Arffman;

use NanoB2B::UniversalRoutines;
use MetaMap::DataStructures;
use File::Path qw(make_path);			#makes sub directories	
use List::MoreUtils qw(uniq);

use Data::Dumper;

use strict;
use warnings;

#option variables
my $debug = 1;
my $program_dir = "";
my $fileIndex = 0;
my $stopwords_file;
my $prefix = 3;
my $suffix = 3;
my $bucketsNum = 10;
my $fileBuckets = 0;
my $is_cui = 0;
my $sparse_matrix = 0;
my $wcs = "";

#datastructure object
my %params = ();
my $dataStructures = MetaMap::DataStructures->new(\%params); 

#universal subroutines object
my %uniParams = ();
my $uniSub;

#other general global variables
my @allBuckets;
my %fileHash;
my %metamapHash;
my %featHash;
my %orthoHash;
my @features;
my $selfId = "_self";
my $entId = "_e";
my $morphID = "_m";

my $stopRegex;

####      A HERO IS BORN     ####

# construction method to create a new Arffman object
# input  :         $directory      <-- the name of the directory for the files
#		   $name 	   <-- name of the file to examine
#		   $features       <-- the list of features to use [e.g. "ortho morph text pos cui sem"]
#		   $bucketsNum     <-- the number of buckets to use for k-fold cross validation
#		   \$debug         <-- run the program with debug print statements
#		   \$prefix        <-- the number of letters to look at the beginning of each word
#		   \$suffix        <-- the number of letters to look at the end of each word
#		   \$index         <-- the index to start metamapping from in the set of files
#		   \$no_stopwords  <-- exclude examining stop words [imported from the stop word list]
# output :         $self           <-- an instance of the Arffman object
sub new {
    #grab class and parameters
    my $self = {};
    my $class = shift;
    return undef if(ref $class);
    my $params = shift;

    #reset all arrays and hashes
    @allBuckets = ();
    %fileHash = ();
    %metamapHash = ();
    %featHash = ();
    %orthoHash = ();
    @features = ();
    
    #bless this object - hallelujah
    bless $self, $class;
    $self->_init($params);
    @allBuckets = (1..$bucketsNum);
    
    #retrieve parameters for universal-routines
    $uniParams{'debug'} = $debug;
    $uniSub = NanoB2B::UniversalRoutines->new(\%uniParams);
    
    #return the object
    return $self;
}

#  method to initialize the NanoB2B::NER::Arffman object.
#  input : $parameters <- reference to a hash
#  output: 
sub _init {
    my $self = shift;
    my $params = shift;

    $params = {} if(!defined $params);

    #  get some of the parameters
    my $diroption = $params->{'directory'};
    my $ftsoption = $params->{'features'};
    my $bucketsNumoption = $params->{'bucketsNum'};
    my $fileBucketsoption = $params->{'fileBuckets'};
    my $debugoption = $params->{'debug'};
    my $prefixoption = $params->{'prefix'};
    my $suffixoption = $params->{'suffix'};
    my $indexoption = $params->{'index'};
    my $stopwordoption = $params->{'stopwords'};
    my $iscuioption = $params->{'is_cui'};
    my $sparsematrixoption = $params->{'sparse_matrix'};
    my $wcsoption = $params->{'wcs'};
    
    #set the global variables
    if(defined $debugoption){$debug = $debugoption;}
    if(defined $diroption){$program_dir = $diroption;}
    if(defined $indexoption){$fileIndex = $indexoption;}
    if(defined $stopwordoption){$stopwords_file = $stopwordoption;}
    if(defined $iscuioption){$is_cui = $iscuioption;}
    if(defined $sparsematrixoption){$sparse_matrix = $sparsematrixoption;}
    if(defined $prefixoption){$prefix = $prefixoption;}
    if(defined $suffixoption){$suffix = $suffixoption;}
    if(defined $wcsoption){$wcs = $wcsoption;}
    if(defined $bucketsNumoption){$bucketsNum = $bucketsNumoption;}
    if(defined $fileBucketsoption){$fileBuckets = $fileBucketsoption;}
    if(defined $ftsoption){@features = split(' ', $ftsoption);}
}


#######		ARFFMAN AND THE METHODS OF MADNESS		#####
# opens a single file and runs it through the process of creating buckets
# extracting tokens and concepts, and creating arff files based on the features given
# input  : $file <-- the name of the file to make into arff files
# output : a set of arff files
sub arff_file{
    my $self = shift;
    my $file = shift;
    
    #define and reset temp var
    my $indexer = 0;
    %fileHash = ();
    %metamapHash = ();
    %featHash = ();
    %orthoHash = ();
    
    #get the name of the file
    my @n = split '/', $file;
    my $l = @n;
    my $filename = $n[$l - 1];
    $filename = lc($filename);
    
    my $FILE;
    open ($FILE, "$program_dir/$file") || die ("what is this '$program_dir/$filename' you speak of?\n$!");
    my @fileLines = <$FILE>;
    my @orthoLines = @fileLines;
    foreach my $l(@fileLines){
	$l = lc($l);
    }
    $uniSub->printColorDebug("on_red", "$filename");
    #$uniSub->printColorDebug("on_cyan", "*** $wcs ***");
    
    #get the total num of lines
    my $totalLines = 0;
    $totalLines = @fileLines;
    $uniSub->printColorDebug("red", "Lines: $totalLines\n");
    
    #clean it up for two separate sets
    my @tagSet = retagSet($filename, \@fileLines);
    my @cleanLines = untagSet($filename, \@fileLines);
    
    #get the orthographic based lines
    #my @orthoLines = <FILE>;
    @orthoLines = retagSetOrtho($file, \@orthoLines);
    
    #$uniSub->printColorDebug("red", "TAG SET: ");
    #$uniSub->printArr(", ", \@tagSet);
    
    #######     ASSIGN THE VALUES TO HASHTABLES O KEEP TRACK OF THEM    #######
    
    #put all the lines in a file hash
    $uniSub->printColorDebug("blue", "*Putting all the file lines into a hashtable....\n");
    $indexer = 0;
    foreach my $line (@tagSet){
	$fileHash{$indexer} = $line;
	$indexer++;
    }
    
    #put the orthographic lines in a hash
    $indexer = 0;
    foreach my $line (@orthoLines){
	#$uniSub->printColorDebug("red", "$line\n");
	$orthoHash{$indexer} = $line;
	$indexer++;
    }
    
    #import the hashtables from saved data
    importMetaData($filename);
    
    #tokenize all the lines --> tokenhash
    $uniSub->printColorDebug("blue", "*Tokenizing the lines into a hashtable....\n");
    $indexer = 0;
    my $totalTokens = 0;
    my $totalConcepts = 0;
    foreach my $line (@cleanLines){
	#$| = 1;
	#$uniSub->printColorDebug("bright_blue", "Line - $indexer/$totalLines");
	$uniSub->printColorDebug("bright_blue", "\r" . "\t\tLine - $indexer/$totalLines");

	print STDERR "LINE: $indexer/$totalLines\n"; 
	#acquire the necessary variables
	my $special_ID = "1.ti.1";
	print STDERR "specialID: $special_ID\n"; 
	my $meta = $metamapHash{$indexer};
	print STDERR "META : $meta\n"; 
	$uniSub->printColorDebug("bright_blue", "** creating citations\n");
	#create citation first
	$dataStructures->createFromTextWithId($meta, $special_ID);
	my $citation = $dataStructures->getCitationWithId($special_ID);

	$uniSub->printColorDebug("green", "** getting ordered tokens\n");
	#get tokens
	my @tokens = @{$citation->getOrderedTokens()};
	my $tnum = @tokens;
	$totalTokens += $tnum;

	$uniSub->printColorDebug("green", "** getting ordered concepts\n");
	#get concepts
	my @concepts = @{$citation->getOrderedConcepts()};
	my $cnum = @concepts;
	$totalConcepts += $cnum;
	
	#grab EVERYTHING

	$uniSub->printColorDebug("green", "** looping thruogh tokens\n");	
	#get tokens first
	foreach my $token (@tokens){
	    #print Dumper($token);
	    #print "token ";
	    #get text and pos
	    my $super_text = lc($token->{text});
	    
	    foreach my $text (split(" ", $super_text)){	#split just in case its a compound word
		#check if already there
		if($featHash{$text}){
		    next;
		}
		
		my $pos = $token->{posTag};
		$featHash{$text}->{pos} = $pos;
	    }
	}

	$uniSub->printColorDebug("green", "** looping thruogh concepts\n");	
	#get concepts second
	foreach my $cc (@concepts){
	    foreach my $concept (@{$cc}[0]){		#two levels for some strange reason
		#print "token ";
		my $super_text = lc($concept->{text});
		for my $text (split(" ", $super_text)){	#split just in case its a compound word
		    #grab original hash
		    my $hash_ref = $featHash{$text};
		    if (!$hash_ref || $hash_ref->{cui} || $hash_ref->{sem}){
			next;
		    }
		    
		    #get sem and cuis v_1
		    #$hash_ref->{cui} = $concept->{cui};
		    #$hash_ref->{sem} = $concept->{semanticTypes};
		    
		    #print "$text --> ";
		    #$uniSub->printArr(", ", \@sem);
		    
		    #get sem and cuis v_2
		    if($hash_ref->{cui}){
			$hash_ref->{cui} = ($hash_ref->{cui} . $concept->{cui});
		    }else{
			$hash_ref->{cui} = $concept->{cui};
		    }
		    
		    if($hash_ref->{sem}){
			$hash_ref->{sem} = ($hash_ref->{sem} . $concept->{semanticTypes});
		    }else{
			$hash_ref->{sem} = $concept->{semanticTypes};
		    }
		    
		    
		    exit; 		    
		}
	    }
	}
	
	#increment to the next set
	$indexer++;
    }
    
    #clean up everything
    foreach my $key(keys %featHash){
	my $hash_ref = $featHash{$key};
	my %hash = %$hash_ref;
	if($hash{cui}){
	    $hash{cui} = join(',', uniq(split(',', $hash{cui})));
	}
	if($hash{sem}){
	    $hash{sem} = join(',', uniq(split(',', $hash{sem})));
	}
    }
    
    #print it back
    print("\n");
    #hash_debug();
    
    $uniSub->printColorDebug("red", "TOKENS: $totalTokens\n");
    $uniSub->printColorDebug("red", "CONCEPTS: $totalConcepts\n");
    
    exit;
    
    
    #######           BUCKET SORTING - TRAIN AND TEST DATA            #######
    
    #sort the lines to buckets
    my %buckets = ();
    if($bucketsNum > 1){
	$uniSub->printColorDebug("blue", "*Making buckets....\n");
	%buckets = sort2Buckets($totalLines, $bucketsNum);
    }else{
	push(@{$buckets{1}}, (0..($totalLines-1)));
    }
    
    #$uniSub->printArr(" ", $buckets{1});
    
    
    $uniSub->printColorDebug("blue", "*Making train and test files....\n");
    
    process_file($filename, \%buckets);
    
    $uniSub->printDebug("\n");
    
}

#print out the contents of the feature hash
sub hash_debug{
    foreach my $key (sort keys %featHash){
	my $text = $key;
	my $hash_ref = $featHash{$key};
	my %hash = %$hash_ref;
	
	my $pos = "";
	my $cui = "";
	my $sem = "";
	
	if($hash{pos}){
	    $pos = $hash{pos};
	}
	if($hash{cui}){
	    $cui = join(',', @{$hash{cui}});
	}
	if($hash{sem}){
	    $sem = join(',', @{$hash{sem}});
	}
	
	print "$text - $pos - $cui - $sem\n";
    }
}


######################              LINE MANIPULATION               #####################

######    RETAGS THE LINE    ######

# turns the tagged entity words into special words with <> for the context words
# input  : $input <-- the line to retag
#	 : $id    <-- the id within the tag to look for
# output : (.arff files)
sub retag{
    my $input = shift;
    my $id = shift;
    
    $id = lc($id);
    my $line = lc($input);
    
    #get rid of any tags
    my @words = split (" ", $line);
    my @newSet = ();
    my $charact = 0;
    foreach my $word (@words){
	#if word is currently in the annotation
	if($charact){
	    if($word =~/<end>/){		#reached the end
		$charact = 0;
	    }else{						#continue adding extension to the annotation set
		my $charWord = "$word"."$entId"; 
		push @newSet, $charWord;
	    }
	}else{
	    if($word =~/<start:[a-z0-9]+>/){
		$charact = 1;
	    }else{									#continue as normal
		push @newSet, $word;
	    }
	}
    }
    
    #clean up the new line
    my $new_line = join " ", @newSet;
    $new_line =~s/\b$entId\b//g;
    $new_line = $uniSub->cleanWords($new_line);
    return $new_line;
}

# turns the tagged entity words in the entire file into special words with <> for the context words
# input  : $name   <-- the name of the file to use as the id tag
#	 : @lines  <-- the set of lines to retag
# output : @tagSet <-- set of retagged lines
sub retagSet{
    my $name = shift;
    my $lines_ref = shift;
    my @lines = @$lines_ref;
    
    my @tagSet = ();
    foreach my $line (@lines){
	#retag the line
	chomp($line);
	my $tag_line = retag($line, $name);
	
	#add it to the set
	push @tagSet, $tag_line;
    }
    return @tagSet;
}

#returns clean line with no tags or retaggings
# input  : $line <-- the line to untag
# 	     : $id   <-- the id label to look for
# output : $input <-- untagged input line
sub untag{
    my $line = shift;
    my $id = shift;
    
    #remove <start:___> and <end>
    my $input = lc($line);
    $id = lc($id);
    $input =~ s/<start:[a-z0-9]+>//g;
    $input =~ s/<end>//g;
    $input = $uniSub->cleanWords($input);
    return $input;
}
#returns a clean set of lines
# input  : $filename   <-- the name of the file for use in the id tag
#	 : @lines      <-- the set of lines to untag
# output : @clean_set  <-- untagged set of lines
sub untagSet{
    my $filename = shift;
    my $lines_ref = shift;
    my @lines = @$lines_ref;
    
    my @clean_set = ();
    #run untagger on each line
    foreach my $line(@lines){
	my $cl = untag($line, $filename);
	push @clean_set, $cl;
    }
    return @clean_set;
}


#import metamap hashtable data
# input  : $name  <-- the name of the file to import from
# output : (hashmap of metamap lines in $name file)
sub importMetaData{
    my $name = shift;
    
    #create a directory to save hashtable data
    my $META;
    my $subdir = "_METAMAPS";
    open($META, "<", ("$program_dir/$subdir/" . $name . "_meta")) || die ("Metamap file for " . $name . " not found! Check the _METAMAP folder in the file directory\n$!");
    
    
    #import metamap data from the file
    my @metaLines = <$META>;
    my $metaCombo = join("", @metaLines);
    my @newMetaLines = split("\n\n", $metaCombo);
    my $t = @newMetaLines;
    $uniSub->printColorDebug("red", "META LINES: $t\n");
    my $key = 0;
    #assign each metamap line to a hash indexer
    foreach my $mm (@newMetaLines){
	$metamapHash{$key} = $mm;
	$key++;
    }
    close $META;
}

#####     FOR THE ORTHO SET     #####

#turns the tagged entity words into special words with <> for the context words
# input  : $input    <-- the line to retag 
# output : $new_line <-- the retagged line
sub retagOrtho{
    my $filename = shift;
    my $input = shift;
    my $line = $input;
    
    #get rid of any tags
    my @words = split (" ", $line);
    my @newSet = ();
    my $charact = 0;
    foreach my $word (@words){
	if($charact){					#currently annotating
	    if($word =~/<END>/){			#stop annotation set
		$charact = 0;
	    }else{
		my $charWord = "$word"."$entId"; 	#add extension to annotation word
		push @newSet, $charWord;
	    }
	}else{
	    if($word =~/<START:[a-zA-Z0-9]+>/){
		$charact = 1;
	    }else{										#continue as normal
		push @newSet, $word;
	    }
	}
    }
    
    #clean up the new line
    my $new_line = join " ", @newSet;
    $new_line =~s/\s$entId\b//g;
    $new_line = noASCIIOrtho($new_line);
    return $new_line;
}
#turns the tagged entity words in the entire file into special words with <> for the context words
# input  : @lines  <-- the set of lines to retag
# output : @tagSet <-- the retagged line
sub retagSetOrtho{
    my $file = shift;
    my $lines_ref = shift;
    my @lines = @$lines_ref;
    
    my @n = split '/', $file;
    my $l = @n;
    my $filename = $n[$l - 1];
    
    my @tagSet = ();
    foreach my $line (@lines){
	#retag the line
	chomp($line);
	my $tag_line = retagOrtho($filename, $line);
	
	#add it to the set
	push @tagSet, $tag_line;
    }
    return @tagSet;
}

#cleans the line without getting rid of tags
# input  : $line     <-- line to clean up
# output : $new_in   <-- the cleaned line
sub noASCIIOrtho{
    my $line = shift;
    
    my $new_in = $line;
    $new_in =~ s/[^[:ascii:]]//g;		#remove any words that do not contain ASCII characters
    return $new_in
}


#######################      TOKENS AND CONCEPT MANIPULATION       #######################   
#gets rid of any special tokens
# input  : $text      <-- the token text to fix
# output : $tokenText <-- a cleaned up token
sub cleanToken{
    my $text = shift;
    
    my $tokenText = $text;
    
    #fix "# . #" tokens, fix "__ \' __" tokens, remove any non word based characters
    $tokenText =~s/\s\.\s/\./og;
    $tokenText =~s/\s\\\'\s//og;
    $tokenText =~s/[^a-zA-Z0-9]//og;
    
    return $tokenText;
}

#retrieves the feature for a single word
# input  : $word     	<-- the word to extract the features from
#	 : $type        <-- what type of feature to extract [e.g. "pos", "sem", "cui"]
# output : if "pos"	<-- a scalar part-of-speech value
#	 : else		<-- an array of semantic or cui values (a single text value can have more than one of these)
sub getFeature{
    my $orig_word = shift;
    my $type = shift;
    
    #clean up thw word
    my $word = lc($orig_word);
    $word =~s/[^a-zA-Z0-9\s]//;
    
    if(!$featHash{$word}){
	return "";
    }
    
    my $hash_ref = $featHash{$word};
    my %hash = %$hash_ref;
    
    if($hash{$type}){
	return $hash{$type};
    }
    return "";
}

######################      BUCKETS - TRAIN AND TEST ARFF FILES     #####################


#sorts the keys from the hashmaps into buckets so that certain values can be accessed
# input  : $keyAmt     	    <-- the number of lines or "keys" to divvy up into the buckets
#	 : $bucketNum       <-- how many buckets to use
# output : %bucketList		<-- the set of buckets with keys in them
sub sort2Buckets{
    my $keyAmt = shift;
    my $bucketNum = shift;

	#create sets 	
    my @keySet = (0..$keyAmt - 1); #set of keys
    my %bucketList = ();	   #all of the buckets

    #add some buckets to the bucket list
    for(my $a = 1; $a <= $bucketNum; $a++){
	$bucketList{$a} = [];
    }
    
    #sort the lines into buckets
    my $bucketId = 1;
    foreach my $key (@keySet){
	push (@{$bucketList{$bucketId}}, $key);	#add the line to the bucket
	
	#reset the id if at the max value
	if($bucketId == $bucketNum){
	    $bucketId = 1;
	}else{
	    $bucketId++;
	}
    }
    
    #return the list of buckets
    return %bucketList;
}

######################               ARFF STUFF              #####################
# makes arff files for ortho, morpho, text, pos, cui, and sem attributes
#
# Processes the file by retrieving attributes, making vectors, and splitting into buckets
# (formally known as 'zhu li!! Do the thing!!'')
# input  : $name     	    <-- the name of the file
#	 : %bucketList      <-- the set of buckets with keys in them
# output : (n arff files; n = # of buckets x (train and test) x # of features being used)
sub process_file{
    my $name = shift;
    my $bucketList_ref = shift;
    my %buckets = %$bucketList_ref;
    
    #grab the attributes
    my %attrSets = ();
    $uniSub->printColorDebug("bold green", "Retrieving attributes...\n");
    foreach my $item(@features){
	$uniSub->printColorDebug("bright_green", "\t$item attr\n");
	my %setOfAttr = grabAttr($name, $item, \%buckets);
	$attrSets{$item} = \%setOfAttr;						#gets both the vector and arff based attributes
    }
    
    #contain the stop words regular expressions if the parameter was defined
    if(defined $stopwords_file){
	$stopRegex = stop($stopwords_file);
    }
    
    #let's make some vectors!
    $uniSub->printColorDebug("bold yellow", "Making Vectors...\n-------------------\n");
    my @curFeatSet = ();
    my $abbrev = "";
    
    #run based on wcs
    my $wcs_bucket;
    my $wcs_feature;
    my $wcs_found = 0;
    if($wcs){
	my @wcs_parts = split("-", $wcs);
	$wcs_feature = $wcs_parts[1];
	$wcs_bucket = $wcs_parts[0];
    }
    
    #iteratively add on the features [e.g. o, om, omt, omtp, omtpc, omtpcs]
    foreach my $feature (@features){
	$uniSub->printColorDebug("yellow", "** $feature ** \n");
	push(@curFeatSet, $feature);
	$abbrev .= substr($feature, 0, 1);		#add to abbreviations for the name
	
	#$uniSub->printColorDebug("on_red", "$wcs - $wcs_found - $abbrev vs. $wcs_feature");
	if(($wcs) && (!$wcs_found) && ($abbrev ne $wcs_feature)){
	    print("**SKIP** \n");
	    next;
	}
	
	#go through each bucket
	foreach my $bucket (sort keys %buckets){
	    #if wcs parameter defined - skip these buckets until the specified bucket and feature is reached
	    if(($wcs) && (!$wcs_found) && ($bucket != $wcs_bucket)){
		print("\t**SKIP**\n");
		next;
	    }else{
		$wcs_found = 1;
	    }
	    
	    #make train-test bucket indexes
	    my @range = ();
	    if($bucketsNum > 1){
		@range = $uniSub->bully($bucketsNum, $bucket);
	    }else{
		@range = (1);
	    }
	    
	    $uniSub->printColorDebug("on_green", "BUCKET #$bucket");
	    #retrieve the vector attributes to use
	    my %vecAttrSet = ();
	    foreach my $curItem(@curFeatSet){
		if($curItem eq "ortho"){
		    $vecAttrSet{$curItem} = ();
		}else{
		    #get outer layer (tpcs)
		    my $a_ref = $attrSets{$curItem};
		    my %a = %$a_ref;
		    
		    #get inner layer (vector)
		    my $b_ref = $a{vector};
		    my %b = %$b_ref;
		    
		    #foreach my $key (sort keys %b){print "$key\n";}
		    
		    #finally get the bucket layer (1..$bucketNum) based on range
		    my $c_ref = $b{$bucket};
		    my @c = @$c_ref;
		    $vecAttrSet{$curItem} = \@c;
		}
	    }
	    
	    ### TRAIN ###
	    $uniSub->printColorDebug("bold blue", "\ttraining...\n");
	    #retrieve the lines to use
	    my @lineSetTrain = ();
	    my @bucketSetTrain = ();
	    foreach my $num (@range){push(@bucketSetTrain, @{$buckets{$num}});}
	    foreach my $key (@bucketSetTrain){push(@lineSetTrain, $orthoHash{$key});}
	    
	    #make the vector
	    my @vectorSetTrain = vectorMaker(\@lineSetTrain, \@curFeatSet, \%vecAttrSet);
	    $uniSub->printDebug("\n");
	    
	    ### TEST ###
	    my @vectorSetTest = ();
	    if($bucketsNum > 1){		#skip this if only 1 bucket being used (train bucket)
		$uniSub->printColorDebug("bold magenta", "\ttesting...\n");
		#retrieve the lines to use
		my @lineSetTest = ();
		my @bucketSetTest = ();
		push(@bucketSetTest, @{$buckets{$bucket}});
		foreach my $key (@bucketSetTest){push(@lineSetTest, $orthoHash{$key});}
		
		#make the vector
		@vectorSetTest = vectorMaker(\@lineSetTest, \@curFeatSet, \%vecAttrSet);
		$uniSub->printDebug("\n");
	    }
	    
	    
	    ### ARFF ###
	    #retrieve the arff attributes to use
	    my @arffAttrSet = ();
	    foreach my $curItem(@curFeatSet){
		if($curItem eq "ortho"){
		    #get outer layer (ortho)
		    my $a_ref = $attrSets{$curItem};
		    my %a = %$a_ref;
		    #get the values from ortho
		    push(@arffAttrSet, @{$a{arff}});
		}else{
		    #get outer layer (mtpcs)
		    my $a_ref = $attrSets{$curItem};
		    my %a = %$a_ref;
		    
		    #get inner layer (arff)
		    my $b_ref = $a{arff};
		    my %b = %$b_ref;
		    
		    #finally get the bucket layer (1..$bucketNum) based on range
		    my $c_ref = $b{$bucket};
		    my @c = @$c_ref;
		    push(@arffAttrSet, @c);
		}
	    }
	    
	    #create the arff files for the test and train features
	    $uniSub->printColorDebug("bright_yellow", "\tmaking arff files...\n");
	    $uniSub->printColorDebug("bright_red", "\t\tARFF TRAIN\n");
	    createARFF($name, $bucket, $abbrev, "train", \@arffAttrSet, \@vectorSetTrain);
	    if($bucketsNum > 1){
		$uniSub->printColorDebug("bright_red", "\t\tARFF TEST\n");
		createARFF($name, $bucket, $abbrev, "test", \@arffAttrSet, \@vectorSetTest);
	    }
	    
	}
    }
}


#create the arff file
# input  : $name     	    <-- the name of the file
#	 : $bucket   	    <-- the index of the bucket you're testing [e.g. bucket #1]
#        : $abbrev          <-- the abbreviation label for the set of features
#        : $type            <-- train or test ARFF?
#        : @attrARFFSet     <-- the set of attributes exclusively for printing to the arff file
#	 : @vecSec          <-- the set of vectors created
# output : (an arff file)
sub createARFF{
    my $name = shift;
    my $bucket = shift;
    my $abbrev = shift;
    my $type = shift;
    my $attr_ref = shift;
    my $vec_ref = shift;
    
    my $typeDir = "_$type";
    my $ARFF;
    #print to files
    $uniSub->printColorDebug("bold cyan", "\t\tcreating $name/$abbrev - BUCKET #$bucket $type ARFF...\n");
    if($program_dir ne ""){
	my $subdir = "_ARFF";
	my $arffdir = $name . "_ARFF";
	my $featdir = "_$abbrev";
	make_path("$program_dir/$subdir/$arffdir/$featdir/$typeDir");
	open($ARFF, ">", ("$program_dir/$subdir/$arffdir/$featdir/$typeDir/" . $name . "_$type-" . $bucket .".arff")) || die ("Cannot write ARFF file to the directory! Check permissions!\n$!");
    }else{
	my $arffdir = $name . "_ARFF";
	my $featdir = "_$abbrev";
	make_path("$arffdir/$featdir/$typeDir");
	open($ARFF, ">", ("$arffdir/$featdir/$typeDir/" . $name . "_$type-" . $bucket .".arff")) || die ("Cannot write ARFF file to the directory! Check permissions!\n$!");
    }
    
    #get the attr and vector set
    my @attrARFFSet = @$attr_ref;
    my @vecSet = @$vec_ref;
    
    #get format for the file
    my $relation = "\@RELATION $name";	
    my @printAttr = makeAttrData(\@attrARFFSet);	
    my $entity = "\@ATTRIBUTE Entity {No, Yes}";	#set if the entity word or not
    my $data = "\@DATA";
    
    #print everything to the file
    $uniSub->printDebug("\t\tprinting to file...\n");
    $uniSub->print2File($ARFF, $relation);
    foreach my $a(@printAttr){$uniSub->print2File($ARFF, $a);}
    $uniSub->print2File($ARFF, $entity);
    $uniSub->print2File($ARFF, $data);
    foreach my $d(@vecSet){$uniSub->print2File($ARFF, $d);}
    close $ARFF;
}

######################               VECTOR THINGIES              #####################


#makes vectors from a set
# input  : @txtLineSet 		<-- the retagged text lines to make vectors out of
#	 : @featureList		<-- the list of features to make the vectors out of [e.g. (ortho, morph, text)]
#	 : @attrs  		<-- the attributes to use to make the vectors
# output : @setVectors		<-- the vectors for each word in all of the lines
sub vectorMaker{
	my $set_ref = shift;
	my $feat_ref = shift;
	my $attrib_ref = shift;
	my @txtLineSet = @$set_ref;
	my @featureList = @$feat_ref;
	my %attrs = %$attrib_ref;

	my @setVectors = ();
	#go through each line of the set
	my $setLen = @txtLineSet;

	for(my $l = 0; $l < $setLen; $l++){
		my $line = $txtLineSet[$l];
		#$uniSub->printColorDebug("on_red", $line);
		my @words = split(' ', $line);
		#$uniSub->printArr(", ", \@words);
		#print "\n";
		my $wordLen = @words;

		#go through each word
		for(my $a = 0; $a < $wordLen; $a++){

			$| = 1;

			my $wordOrig = $words[$a];	
			#make the words for comparison
			my $word = $words[$a];
			my $prevWord = "";
			my $nextWord = "";

			#show progress
			my $l2 = $l + 1; 
			my $a2 = $a + 1;
			$uniSub->printDebug("\r" . "\t\tLine - $l2/$setLen ------ Word - $a2/$wordLen  ----  ");
			
			#cut-off a word in the display if it is too long 
			#(longer than 8 characters)
			my $smlword = substr($word, 0, 8);
			if(length($word) > 8){
				$smlword .= "...";
			}
			
			#distinguish entity words from normal words
			if($word =~/$entId/o){
				$uniSub->printColorDebug("red", "$smlword!                ");
			}else{
				$uniSub->printDebug("$smlword!                    ")
			}

			my @word_cuis = getFeature($word, "cui");
			my $ncui = $word_cuis[0];
			#$uniSub->printColorDebug("red", "\n\t\t$word - $ncui\n");

			#check if it's a stopword
			if(($stopwords_file and $word=~/$stopRegex/o) || ($is_cui and $word_cuis[0] eq "")){
				#$uniSub->printColorDebug("on_red", "\t$word\tSKIP!");
				if(!($word =~/[a-zA-Z0-9]+$entId/)){
					next;
				}
			}

			#if a weird character word - skip
			if((length($word) eq 1) and ($word =~/[^a-zA-Z0-9]/)){
				next;
			}

			#get the word before and after the current word
			if($a > 0){$prevWord = $words[$a - 1];}
			if($a < ($wordLen - 1)){$nextWord = $words[$a + 1];}

			

			#get rid of tag if necessary
			$prevWord =~s/$entId//og;
			$nextWord =~s/$entId//og;
			$word =~s/$entId//og;

			my $vec = "";
			#use each set of attributes
			foreach my $item(@featureList){
				my $addVec = "";
				if($item eq "ortho"){$addVec = orthoVec($word);}
				elsif($item eq "morph"){$addVec = morphVec($word, \@{$attrs{"morph"}});}
				elsif($item eq "text"){$addVec = textVec($word, $prevWord, $nextWord, \@{$attrs{"text"}});}
				elsif($item eq "pos"){$addVec = posVec($word, $prevWord, $nextWord, \@{$attrs{"pos"}});}
				elsif($item eq "cui"){$addVec = cuiVec($word, $prevWord, $nextWord, \@{$attrs{"cui"}});}
				elsif($item eq "sem"){$addVec = semVec($word, $prevWord, $nextWord, \@{$attrs{"sem"}});}
				

				$vec .= $addVec;

			}

			#convert binary to sparse if specified
			if($sparse_matrix){
				$vec = convert2Sparse($vec);
				#$uniSub->printColorDebug("red", "$vec\n");
			}

			#check if the word is an entity or not
			#$uniSub->printColorDebug("red", "\n$wordOrig\n");
			$vec .= (($wordOrig =~/\b[\S]+($entId)\b/) ? "Yes " : "No ");

			#close it if using sparse matrix
			if($sparse_matrix){
				$vec .= "}";
			}

			#finally add the word back and add the entire vector to the set
			$vec .= "\%$word";
			if($word ne ""){
				push(@setVectors, $vec);
			}
		}
	}

	return @setVectors;
}

#makes the orthographic based part of the vector
# input  : $word     	    <-- the word to analyze
# output : $strVec			<-- the orthographic vector string
sub orthoVec{
	my $word = shift;

	##  CHECKS  ##
	my $strVec = "";
	my $addon = "";

	#check if first letter capital
	$addon = ($word =~ /\b([A-Z])\w+\b/o ? 1 : 0);
	$strVec .= "$addon, ";

	#check if a single letter word
	$addon = (length($word) == 1 ? 1 : 0);
	$strVec .= "$addon, ";

	#check if all capital letters
	$addon = ($word =~ /\b[A-Z]+\b/o ? 1 : 0);
	$strVec .= "$addon, ";

	#check if contains a digit
	$addon = ($word =~ /[0-9]+/o ? 1 : 0);
	$strVec .= "$addon, ";

	#check if all digits
	$addon = ($word =~ /\b[0-9]+\b/o ? 1 : 0);
	$strVec .= "$addon, ";

	#check if contains a hyphen
	$addon = ($word =~ /-/o ? 1 : 0);
	$strVec .= "$addon, ";

	#check if contains punctuation
	$addon = ($word =~ /[^a-zA-Z0-9\s]/o ? 1 : 0);
	$strVec .= "$addon, ";

	return $strVec;
}

#makes the morphological based part of the vector
# input  : $word     	    <-- the word to analyze
#		 : @attrs 			<-- the set of morphological attributes to use
# output : $strVec			<-- the morphological vector string
sub morphVec{
	my $word = shift;
	my $attrs_ref = shift;
	my @attrs = @$attrs_ref;

	my $strVec = "";

	#grab the first # characters and the last # characters
	my $preWord = substr($word, 0, $prefix);
	my $sufWord = substr($word, -$suffix);

	#compare and build a binary vector
	foreach my $a (@attrs){
		if($a eq $preWord){
			$strVec .= "1, ";
		}elsif($a eq $sufWord){
			$strVec .= "1, ";
		}else{
			$strVec .= "0, ";
		}
	}

	return $strVec;

}

#makes the text based part of the vector
# input  : $w     	    	<-- the word to analyze
#        : $pw     	    	<-- the previous word
#        : $nw     	    	<-- the next word
#		 : @attrbts 		<-- the set of text attributes to use
# output : $strVec			<-- the text vector string
sub textVec{
	my $w = shift;
	my $pw = shift;
	my $nw = shift;
	my $at_ref = shift;
	my @attrbts = @$at_ref;

	my $strVec = "";

	#clean the words
	$w = $uniSub->cleanWords($w);
	$pw = $uniSub->cleanWords($pw);
	$nw = $uniSub->cleanWords($nw);

	#check if the word is the attribute or the words adjacent it are the attribute
	foreach my $a(@attrbts){
		
		my $pair = "";
		$pair .= ($w eq $a ? "1, " : "0, ");	
		$pair .= (($pw eq $a or $nw eq $a) ? "1, " : "0, ");
		$strVec .= $pair;
	}

	return $strVec;
}

#makes the part of speech based part of the vector
# input  : $w     	    	<-- the word to analyze
#        : $pw     	    	<-- the previous word
#        : $nw     	    	<-- the next word
#		 : @attrbts 		<-- the set of pos attributes to use
# output : $strVec			<-- the pos vector string
sub posVec{
	my $w = shift;
	my $pw = shift;
	my $nw = shift;
	my $at_ref = shift;
	my @attrbts = @$at_ref;

	#clean the words
	$w = $uniSub->cleanWords($w);
	$pw = $uniSub->cleanWords($pw);
	$nw = $uniSub->cleanWords($nw);

	#alter the words to make them pos types
	$w = getFeature($w, "pos");
	$pw = getFeature($pw, "pos");
	$nw = getFeature($nw, "pos");

	my $strVec = "";

	#check if the word is the attribute or the words adjacent it are the attribute
	foreach my $a(@attrbts){
		my $pair = "";
		$pair .= ($w eq $a ? "1, " : "0, ");		
		$pair .= (($pw eq $a or $nw eq $a) ? "1, " : "0, ");
		$strVec .= $pair;
	}

	return $strVec;
}

#makes the cui based part of the vector
# input  : $w     	    	<-- the word to analyze
#        : $pw     	    	<-- the previous word
#        : $nw     	    	<-- the next word
#		 : @attrbts 		<-- the set of cui attributes to use
# output : $strVec			<-- the cui vector string
sub cuiVec{
	my $w = shift;
	my $pw = shift;
	my $nw = shift;
	my $at_ref = shift;
	my @attrbts = @$at_ref;

	#clean the words
	$w = $uniSub->cleanWords($w);
	$pw = $uniSub->cleanWords($pw);
	$nw = $uniSub->cleanWords($nw);

	#alter the words to make them cui types
	my @wArr = getFeature($w, "cui");
	my @pwArr = getFeature($pw, "cui");
	my @nwArr = getFeature($nw, "cui");

	my $strVec = "";
	#check if the word is the attribute or the words adjacent it are the attribute
	foreach my $a(@attrbts){
		my $pair = "";
		$pair .= ($uniSub->inArr($a, \@wArr) ? "1, " : "0, ");		
		$pair .= (($uniSub->inArr($a, \@pwArr) or $uniSub->inArr($a, \@nwArr)) ? "1, " : "0, ");
		$strVec .= $pair;
	}

	return $strVec;
}

#makes the semantic based part of the vector
# input  : $w     	    	<-- the word to analyze
#        : $pw     	    	<-- the previous word
#        : $nw     	    	<-- the next word
#		 : @attrbts 		<-- the set of sem attributes to use
# output : $strVec			<-- the sem vector string
sub semVec{
	my $w = shift;
	my $pw = shift;
	my $nw = shift;
	my $at_ref = shift;
	my @attrbts = @$at_ref;

	#clean the words
	$w = $uniSub->cleanWords($w);
	$pw = $uniSub->cleanWords($pw);
	$nw = $uniSub->cleanWords($nw);

	#alter the words to make them sem types
	my @wArr = getFeature($w, "sem");
	my @pwArr = getFeature($pw, "sem");
	my @nwArr = getFeature($nw, "sem");

	my $strVec = "";

	#check if the word is the attribute or the words adjacent it are the attribute
	foreach my $a(@attrbts){
		#remove "sem" label
		$a = lc($a);

		my $pair = "";
		$pair .= ($uniSub->inArr($a, \@wArr) ? "1, " : "0, ");		
		$pair .= (($uniSub->inArr($a, \@pwArr) or $uniSub->inArr($a, \@nwArr)) ? "1, " : "0, ");
		$strVec .= $pair;
	}
	return $strVec;
}

#converts a binary vector to a sparse vector
sub convert2Sparse{
	my $bin_vec = shift;
	my @vals = split(", ", $bin_vec);
	my $numVals = @vals;

	my $sparse_vec = "{";
	for(my $c=0;$c<$numVals;$c++){
		my $curVal = $vals[$c];

		#if a non-zero value is found at the index - add it to the final
		if(($curVal eq "1")){
			$sparse_vec .= "$c $curVal, ";
			#$uniSub->printColorDebug("red", "$c $curVal, ");
		}
	}
	$sparse_vec .= "$numVals, ";

	return $sparse_vec;
}


######################               ATTRIBUTE BASED METHODS              #####################

#gets the attributes based on the item
# input  : $feature     	<-- the feature type [e.g. ortho, morph, text]
#		 : %buckets 		<-- the bucket key set
# output : %vecARFFattr		<-- the vector set of attributes and arff set of attributes
sub grabAttr{
	my $name = shift;
	my $feature = shift;
	my $buckets_ref = shift;
	my %buckets = %$buckets_ref;

	my %vecARFFattr = ();
	#no importing of attributes is needed for ortho since they all check the same features
	if($feature eq "ortho"){
		my @vecSet = ();
		my @arffSet = ("first_letter_capital", 		#output for the ARFF file
						"single_character",
						"all_capital",
						"has_digit",
						"all_digit",
						"has_hyphen",
						"has_punctuation");
		$vecARFFattr{vector} = \@vecSet;
		$vecARFFattr{arff} = \@arffSet;
		return %vecARFFattr;
	}
	#the morphological attributes look at the prefix and suffix of a word not the adjacencies
	elsif($feature eq "morph"){	
		my %bucketAttr = ();
		my %bucketAttrARFF = ();

		#get the attributes for each bucket
		foreach my $testBucket (@allBuckets){
			my @range = ();
			if($bucketsNum > 1){
				@range = $uniSub->bully($bucketsNum, $testBucket);
			}else{
				@range = (1);
			}
			$uniSub->printDebug("\t\t$name BUCKET #$testBucket/$feature MORPHO attributes...\n");
			
			#get attributes [ unique and deluxe ]
			my @attr = getMorphoAttributes(\@range, \%buckets);
			@attr = uniq(@attr);						#make unique forms
			$bucketAttr{$testBucket} = \@attr;

			my @attrARFF = @attr;
			foreach my $a(@attrARFF){$a .= $morphID;}
			$bucketAttrARFF{$testBucket} = \@attrARFF;
		}

		#add to overall
		$vecARFFattr{vector} = \%bucketAttr;
		$vecARFFattr{arff} = \%bucketAttrARFF;

		return %vecARFFattr;
	}
	#text, part-of-speech, semantics, cui attributes
	else{
		my %bucketAttr = ();
		my %bucketAttrARFF = ();

		#get the attributes for each bucket
		foreach my $testBucket (@allBuckets){
			my @range = ();
			if($bucketsNum > 1){
				@range = $uniSub->bully($bucketsNum, $testBucket);
			}else{
				@range = (1);
			}
			$uniSub->printDebug("\t\t$name BUCKET #$testBucket/$feature attributes...\n");
			
			#get attributes [ unique and deluxe ]
			my @attr = getRangeAttributes($feature, \@range, \%buckets);
			$bucketAttr{$testBucket} = \@attr;

			my @attrARFF = getAttrDelux($feature, \@attr);
			$bucketAttrARFF{$testBucket} = \@attrARFF;
		}

		#add to overall
		$vecARFFattr{vector} = \%bucketAttr;
		$vecARFFattr{arff} = \%bucketAttrARFF;

		return %vecARFFattr;
	}
}

#returns the attribute values of a range of buckets
# input  : $type     	    <-- the feature type [e.g. ortho, morph, text]
#		 : @bucketRange     <-- the range of the buckets to use [e.g.(1-8,10) out of 10 buckets; use "$uniSub->bully" subroutine in UniversalRoutines.pm]
#		 : %buckets 		<-- the bucket key set
# output : @attributes		<-- the set of attributes for the specific type and range
sub getRangeAttributes{
	my $type = shift;
	my $bucketRange_ref = shift;
	my $buckets_ref = shift;
	my @bucketRange = @$bucketRange_ref;
	my %buckets = %$buckets_ref;

	#collect all the necessary keys
	my @keyRing = ();
	foreach my $bucket (sort { $a <=> $b } keys %buckets){
		if($uniSub->inArr($bucket, \@bucketRange)){
			my @keys = @{$buckets{$bucket}};
			push @keyRing, @keys;
		}
	}

	#get the lines
	my @bucketLines = ();
	foreach my $key (@keyRing){
		push(@bucketLines, $fileHash{$key});
	}

	#gather the attributes based on the words in the lines
	my @attributes = ();
	foreach my $line (@bucketLines){	#in each line
		foreach my $o_word (split(' ', $line)){		#each word
			my $word = $o_word;
			$word =~s/$entId//;							#remove the annotation marker
			$word =~s/<START:[a-zA-Z0-9]+>//;			#remove the <START:___> tag
			$word =~s/<END>//;							#remove the <END> tag
			$word =~s/[\:\.\-]//;						#remove any : . - characters

			#if word is empty - skip
			if($word eq ""){
				next;
			}

			#if only looking for text attributes - use the actual word
			if($type eq "text"){
				push(@attributes, $word);
				next;
			}

			#skip if dne
			if(!$featHash{$word}){
				next;
			}
			#grab attributes if it does
			my $hash_ref = $featHash{$word};
			my %hash = %$hash_ref;

			if($hash{$type}){
				push(@attributes, split(',', $hash{$type}));
			}
		}
	}

	@attributes = uniq(@attributes);
	#$uniSub->printArr(",", \@attributes);
	return @attributes;

}

#makes the arff version attributes - makes a copy of each attribute but with "_self" at the end
# input  : $f     			<-- the feature type (used for special features like POS and morph)
#		 : @attrs 		    <-- the attributes to ready for arff output
# output : @attrDelux		<-- the delux-arff attribute set
sub getAttrDelux{
	my $f = shift;
	my $attr_ref = shift;
	my @attr = @$attr_ref;

	#add the _self copy
	my @attrDelux = ();
	foreach my $word (@attr){
		#check if certain type of feature
		if($f eq "pos"){
			$word = ($word . "_POS");
		}
		elsif($f eq "ortho"){
			$word = ($word . "_o");
		}
		elsif($f eq "morph"){
			$word = ($word . "_m");
		}
        elsif($f eq "text"){
			$word = ($word . "_t");
		}
        elsif($f eq "cui"){
			$word = ($word . "_c");
		}
        elsif($f eq "sem"){
			$word = ($word . "_s");
		}
		$word =~s/$entId//g;

		#add the copy and then the original
		my $copy = "$word" . "$selfId";
		if(!$uniSub->inArr($word, \@attrDelux)){
			push (@attrDelux, $copy);
			push(@attrDelux, $word);
		}
	}
	return @attrDelux;
}

#looks at the prefix # and suffix # and returns a substring of each word found in the bucket text set
# input  : @bucketRange     <-- the range of the buckets to use [e.g.(1-8,10) out of 10 buckets; use "$uniSub->bully" subroutine in UniversalRoutines.pm]
#		 : %buckets 		<-- the bucket key set
# output : @attributes		<-- the morphological attribute set
sub getMorphoAttributes{
	my $bucketRange_ref = shift;
	my $buckets_ref = shift;
	my @bucketRange = @$bucketRange_ref;
	my %buckets = %$buckets_ref;

	#collect all the necessary keys
	my @keyRing = ();
	foreach my $bucket (sort { $a <=> $b } keys %buckets){
		if($uniSub->inArr($bucket, \@bucketRange)){
			my @keys = @{$buckets{$bucket}};
			push @keyRing, @keys;
		}
	}

	my @bucketLines = ();
	#get the lines for each associated key
	foreach my $key (@keyRing){
		my $line = $fileHash{$key};
		push @bucketLines, $line;
	}

	#get each word from each line
	my @wordSet = ();
	foreach my $line (@bucketLines){
		my @words = split(" ", $line);
		push(@wordSet, @words);
	}

	#get the prefix and suffix from each word
	my @attributes = ();
	foreach my $word (@wordSet){
		$word =~s/$entId//g;
		push(@attributes, substr($word, 0, $prefix));									#add the word's prefix
		push(@attributes, substr($word, -$suffix));		#add the word's suffix
	}

	#my $a = @attributes;
	#$uniSub->printColorDebug("red", "$type ATTR: #$a\n");
	#printArr("\n", @attributes);

	return @attributes;
}

#formats attributes for the ARFF file
# input  : @set    		    <-- the attribute set
# output : @attributes  	<-- the arff formatted attributes
sub makeAttrData{
	my $set_ref = shift;
	my @set = @$set_ref;

	my @attributes = ();
	foreach my $attr (@set){
		push (@attributes, "\@ATTRIBUTE $attr NUMERIC");
	}

	return @attributes;
}

##new stoplist function - by Dr. McInnes
#generates a regex expression searching for the stop list words
sub stop { 
 
    my $stopfile = shift; 

    my $stop_regex = "";
    my $stop_mode = "AND";

    open ( STP, $stopfile ) ||
        die ("Couldn't open the stoplist file $stopfile\n$!");
    
    while ( <STP> ) {
	chomp; 
	
	if(/\@stop.mode\s*=\s*(\w+)\s*$/) {
	   $stop_mode=$1;
	   if(!($stop_mode=~/^(AND|and|OR|or)$/)) {
		print STDERR "Requested Stop Mode $1 is not supported.\n";
		exit;
	   }
	   next;
	} 
	
	# accepting Perl Regexs from Stopfile
	s/^\s+//;
	s/\s+$//;
	
	#handling a blank lines
	if(/^\s*$/) { next; }
	
	#check if a valid Perl Regex
        if(!(/^\//)) {
	   print STDERR "Stop token regular expression <$_> should start with '/'\n";
	   exit;
        }
        if(!(/\/$/)) {
	   print STDERR "Stop token regular expression <$_> should end with '/'\n";
	   exit;
        }

        #remove the / s from beginning and end
        s/^\///;
        s/\/$//;
        
	#form a single big regex
        $stop_regex.="(".$_.")|";
    }

    if(length($stop_regex)<=0) {
	print STDERR "No valid Perl Regular Experssion found in Stop file $stopfile";
	exit;
    }
    
    chop $stop_regex;
    
    # making AND a default stop mode
    if(!defined $stop_mode) {
	$stop_mode="AND";
    }
    
    close STP;
    
    return $stop_regex; 
}

1;
