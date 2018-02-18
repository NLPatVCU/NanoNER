#!/bin/perl

use List::Util qw(max);
use File::Path qw(make_path);			#makes sub directories	
use Term::ANSIColor;					#color coding the output
use strict;
use warnings;


my $fileDir;
my $features;
my $buckets;
my @bucketList;
my $wekaType;

my $padding = 2;
#grid_format("party time", [2, 323, 1352352, 7]);

main();

sub main{
	#get the inputs
	print "Directory: ";
	chomp($fileDir = <STDIN>);
	print "Weka Type: ";
	chomp($wekaType = <STDIN>);
	print "Index or File: ";
	chomp(my $fileIndex = <STDIN>);
	print "Features [abbreviation]: ";
	chomp($features = <STDIN>);
	print "Buckets: ";
	chomp($buckets = <STDIN>);
	@bucketList = (1..$buckets);

	#open the directory	 
	opendir (DIR, $fileDir) or die $!;							
	my @tags = grep { $_ ne '.' and $_ ne '..' and substr($_, 0, 1) ne '_'} readdir DIR;	#get each file from the directory

	#ner the files
	my $totalTags = @tags;
	if($fileIndex =~/\b[0-9]+\b/){		#is a number
		for(my $a = $fileIndex; $a < $totalTags; $a++){
			my $b = $a+1;
			my $tag = $tags[$a];
			printColor("bold blue", "FILE #$b / $totalTags -- $tag");
			gridMaker($tag);
			printColor("bold blue", "..........FINISHED!\n");
		}
	}else{
		gridMaker($fileIndex);
	}
}

#create a new sparse matrix arff file
sub gridMaker{
	my $file = shift;

	#get the name of the file
	my @n = split '/', $file;
	my $l = @n;
	my $filename = $n[$l - 1];
	$filename = lc($filename);

	#open new file
	my $direct = ("$fileDir/_WEKAS/$wekaType/$filename" . "_WEKA_DATA");		
	make_path($direct);		
	my $filepath = "$direct/$filename" . "_weka-matrix";		
	my $WEKA_MATRIX;
	open ($WEKA_MATRIX, ">", "$filepath") || die ("Aw man! $!");

	print $WEKA_MATRIX "CONFUSION MATRIX - $filename\n=========================\n\n";

	#iterate through each arff file based on feature, type, and bucket #
	my $abbrev = "_";
	for(my $ab=0;$ab<length($features);$ab++){
		$abbrev .= substr($features, $ab, 1);
		my %matrix_data = ();
		foreach my $bucket(@bucketList){
			#import the lines
			my $name = "$fileDir/_WEKAS/$wekaType/$filename" . "_WEKA_DATA/$abbrev/$filename" . "_accuracy_$bucket";
			open (my $FILE, $name) || die ("Cannot find $name\n");
			
			#get lines
			my @lines = <$FILE>;
			foreach my $line(@lines){chomp($line)};
			my $len = @lines;

			if($len == 0){
				printColor("red", "NOTHING FOUND FOR $filename!\n");
				next;
				#return %featAvg;
			}

			#get the rest of the array
			my $keyword = "=== Error on test data ===";
			my $index = getIndexofLine($keyword, \@lines);
			my @result = @lines[$index..$len];

			#grab the only stuff you need
			my $len2 = @result;
			my $confusionWord = "=== Confusion Matrix ===";
			my $confusionIndex = getIndexofLine($confusionWord, \@result);
			my @result2 = @result[$confusionIndex..$len2-2];

			#printArr("\n", \@result2);

			#split it uuup
			my $firstRow = $result2[3];
			my $secRow = $result2[4];
			my @topVal = (split " ", $firstRow)[0..1];
			my @botVal = (split " ", $secRow)[0..1];
			my @matrixVals = (@topVal, @botVal);

			#add to the rest
			$matrix_data{$bucket} = \@matrixVals;

			close($FILE);
		}
		print $WEKA_MATRIX "\n\n$abbrev\n-------------------------\n";
		foreach my $set(sort {$a<=>$b} keys %matrix_data){
			my $mat_name = "$filename" . "$abbrev" . "_$set";
			grid_format($mat_name, $matrix_data{$set}, $WEKA_MATRIX);
		}
		%matrix_data = ();
	}
	close $WEKA_MATRIX;
}





#puts a file name and its contents into a grid format
sub grid_format{
	my $name = shift;
	my $values_ref = shift;
	my $file_out = shift;
	my @values = @$values_ref;

	#get max space of box
	my $maxDig = countDigits(max(@values));
	my $space = $maxDig + 2*($padding);

	#### boxes are fun ####

	print $file_out " " x ($padding + 1 + ($maxDig/2));
	print $file_out "no";
	print $file_out " " x ((($space - ($padding + 1 + ($maxDig/2))) + ($padding + ($maxDig/2) - 1)));
	print $file_out "yes\n";

	#top
	print $file_out "+";
	print $file_out "-" x $space;
	print $file_out "-";
	print $file_out "-" x $space;
	print $file_out "+\n";

	#first layer
	foreach my $n (@values[0..1]){
		print $file_out "|";
		print $file_out " " x $padding;
		print $file_out " " x (($maxDig - countDigits($n))/2);
		print $file_out $n;
		print $file_out " " x (($maxDig - (countDigits($n))+1)/2);
		print $file_out " " x $padding;
	}
	print $file_out "|\n";

	#middle bar
	print $file_out "|";
	print $file_out "-" x $space;
	print $file_out "+";
	print $file_out "-" x $space;
	print $file_out "|  $name\n";

	#last layer
	foreach my $n (@values[2..3]){
		print $file_out "|";
		print $file_out " " x $padding;
		print $file_out " " x (($maxDig - countDigits($n))/2);
		print $file_out $n;
		print $file_out " " x (($maxDig - (countDigits($n))+1)/2);
		print $file_out " " x $padding;
	}
	print $file_out "|\n";
	
	#bottom
	print $file_out "+";
	print $file_out "-" x $space;
	print $file_out "-";
	print $file_out "-" x $space;
	print $file_out "+\n\n";

}

#count the digits in a number
sub countDigits{
	my $num = shift;
	my @chars = split("", $num);
	my $l = @chars;
	return $l;
}

#gets the line's index
# input  : $keyword <-- the regex to use to search for the specific line
#		   @lines   <-- the set of lines to look through
# output : $a  		<-- return the index of the line based on the regex; returns -1 if not found
sub getIndexofLine{
	my $keyword = shift;
	my $lines_ref = shift;
	my @lines = @$lines_ref;

	my $len = @lines;
	for(my $a = 0; $a < $len; $a++){
		my $line = $lines[$a];
		if ($line =~ /($keyword)/){
			return $a;
		}
	}	
	return -1;
}

#prints input with color
# input  : $color 	<-- color to print the text in
#		   $text    <-- the text to print
# output : --
sub printColor{
	my $color = shift;
	my $text = shift;

	if($color =~ /on_\w+/){print color($color), "$text", color("reset"), "\n";}
	else{print color($color), "$text", color("reset");}
}

#shows an array
# input  : $delim 	 <-- string to separate the elememts by
#		   @array    <-- the array to print
# output : string    <-- returns the array elements in a string format separated by the delimiter
sub printArr{
	my $delim = shift;
	my $parr_ref = shift;
	my @parr = @$parr_ref;

	my $combo = join ($delim, @parr);
	print "$combo\n";
}