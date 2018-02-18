#!/bin/perl

use List::Util qw(max);
use File::Path qw(make_path);			#makes sub directories	
use Term::ANSIColor;					#color coding the output
use strict;
use warnings;
use POSIX;

my $fileDir;
my $features;
my $buckets;
my @bucketList;
my $wekaType;

my $padding = 2;
my $super_pad = 6;
my %matrix_data = ();
my $cols = 4;
#grid_format("party time", [2, 323, 1352352, 7]);

main();

sub main{
	#get the inputs
	print "Directory: ";
	chomp($fileDir = <STDIN>);
	print "Weka Type: ";
	chomp($wekaType = <STDIN>);
	print "Features [abbreviation]: ";
	chomp($features = <STDIN>);
	print "Buckets: ";
	chomp($buckets = <STDIN>);
	@bucketList = (1..$buckets);

	#open the directory	 
	opendir (DIR, $fileDir) or die $!;							
	my @tags = grep { $_ ne '.' and $_ ne '..' and substr($_, 0, 1) ne '_'} readdir DIR;	#get each file from the directory

	#open new file	
	my $filepath = "$fileDir" . "_weka-matrix_SUPER";		
	my $WEKA_MATRIX;
	open ($WEKA_MATRIX, ">", "$filepath") || die ("Aw man! $!");

	print $WEKA_MATRIX "CONFUSION MATRIX - $fileDir - $features - average $buckets buckets\n";
	print $WEKA_MATRIX "==============================================================================\n\n";

	#ner the files
	my $totalTags = @tags;
	for(my $a = 0; $a < $totalTags; $a++){
		my $b = $a+1;
		my $tag = $tags[$a];
		printColor("bold blue", "FILE #$b / $totalTags -- $tag");
		gridMaker2($tag, $WEKA_MATRIX);
		printColor("bold blue", "..........FINISHED!\n");
	}
	super_grid_format($WEKA_MATRIX);
}

#create a new sparse matrix arff file
sub gridMaker2{
	my $file = shift;
	my $MAT_FILE = shift;

	#get the name of the file
	my @n = split '/', $file;
	my $l = @n;
	my $filename = $n[$l - 1];
	$filename = lc($filename);

	#iterate through each arff file based on feature, type, and bucket #
	my @avg_set = ();
	foreach my $bucket(@bucketList){
		#import the lines
		my $name = "$fileDir/_WEKAS/$wekaType/$filename" . "_WEKA_DATA/_$features/$filename" . "_accuracy_$bucket";
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
		for(my $v=0;$v<4;$v++){
			$avg_set[$v] += $matrixVals[$v];
		}

		close($FILE);
	}

	#average it
	for(my $v=0;$v<4;$v++){
		#$avg_set[$v] /= 10;
		$avg_set[$v] = int($avg_set[$v]);
	}
	$matrix_data{$filename} = [@avg_set];
}

#output for the values
sub super_grid_format{
	my $file_out = shift;

	#assign number indexes
	my %super_values = ();
	my @super_labels = ();
	my $index = 0;
	foreach my $ner (sort keys %matrix_data){
		push(@super_labels, $ner);
		my @arr = @{$matrix_data{$ner}};
		$super_values{$index} = [@arr];	
		$index++;
	}

	#print out 3 at a time
	my $keyCt = keys %matrix_data;
	for(my $n = 0; $n < ($cols*int($keyCt / $cols)); $n+=$cols){
		my @num_set = ($n...($n+($cols-1)));

	#####print the box parts######
		#label part of the box
		for(my $w=0;$w<$cols;$w++){
			my $label = $super_labels[$num_set[$w]];
			my $num = $num_set[$w];
			print "$num\n";
			my @values = @{$super_values{$num}};

			#get max space of box
			my $maxDig = countDigits(max(@values));
			my $space = $maxDig + 2*($padding);


			print $file_out " " x ($padding + 1 + ($maxDig/2));
			print $file_out "no";
			print $file_out " " x ((($space - ($padding + 1 + ($maxDig/2))) + ($padding + ($maxDig/2) - 1)));
			print $file_out "yes";
			print $file_out " " x ($padding);
			print $file_out " " x ($super_pad);
		}
		print $file_out "\n";
		#top border
		for(my $w=0;$w<$cols;$w++){
			my $label = $super_labels[$num_set[$w]];
			my $num = $num_set[$w];
			my @values = @{$super_values{$num}};
			
			#get max space of box
			my $maxDig = countDigits(max(@values));
			my $space = $maxDig + 2*($padding);

			#print out
			print $file_out "+";
			print $file_out "-" x $space;
			print $file_out "-";
			print $file_out "-" x $space;
			print $file_out "+";
			print $file_out " " x $super_pad;
		}
		print $file_out "\n";
		#first layer of the set
		for(my $w=0;$w<$cols;$w++){
			my $label = $super_labels[$num_set[$w]];
			my $num = $num_set[$w];
			my @values = @{$super_values{$num}};
			
			#get max space of box
			my $maxDig = countDigits(max(@values));
			my $space = $maxDig + 2*($padding);

			#print out
			foreach my $n (@values[0..1]){
				print $file_out "|";
				print $file_out " " x $padding;
				print $file_out " " x (($maxDig - countDigits($n))/2);
				print $file_out $n;
				print $file_out " " x (($maxDig - (countDigits($n))+1)/2);
				print $file_out " " x $padding;
			}
			print $file_out "|";
			print $file_out " " x $super_pad;
		}
		print $file_out "\n";
		#middle bar border
		for(my $w=0;$w<$cols;$w++){
			my $label = $super_labels[$num_set[$w]];
			my $num = $num_set[$w];
			my @values = @{$super_values{$num}};
			
			#get max space of box
			my $maxDig = countDigits(max(@values));
			my $space = $maxDig + 2*($padding);

			#print out
			print $file_out "|";
			print $file_out "-" x $space;
			print $file_out "+";
			print $file_out "-" x $space;
			print $file_out "|";
			print $file_out " " x $super_pad;
		}
		print $file_out "\n";
		#last layer
		for(my $w=0;$w<$cols;$w++){
			my $label = $super_labels[$num_set[$w]];
			my $num = $num_set[$w];
			my @values = @{$super_values{$num}};
			
			#get max space of box
			my $maxDig = countDigits(max(@values));
			my $space = $maxDig + 2*($padding);

			#print out
			foreach my $n (@values[2..3]){
				print $file_out "|";
				print $file_out " " x $padding;
				print $file_out " " x (($maxDig - countDigits($n))/2);
				print $file_out $n;
				print $file_out " " x (($maxDig - (countDigits($n))+1)/2);
				print $file_out " " x $padding;
			}
			print $file_out "|";
			print $file_out " " x $super_pad;
		}
		print $file_out "\n";
		#bottom
		for(my $w=0;$w<$cols;$w++){
			my $label = $super_labels[$num_set[$w]];
			my $num = $num_set[$w];
			my @values = @{$super_values{$num}};
			
			#get max space of box
			my $maxDig = countDigits(max(@values));
			my $space = $maxDig + 2*($padding);

			#print out
			print $file_out "+";
			print $file_out "-" x $space;
			print $file_out "-";
			print $file_out "-" x $space;
			print $file_out "+";
			print $file_out " " x $super_pad;
		}
		print $file_out "\n";

		#labels underneath
		for(my $w=0;$w<$cols;$w++){
			my $label = $super_labels[$num_set[$w]];
			my $num = $num_set[$w];
			my @values = @{$super_values{$num}};
			
			#get max space of box
			my $maxDig = countDigits(max(@values));
			my $space = $maxDig + 2*($padding);

			#print out
			print $file_out " " x ($space - ((length($label))/2));
			print $file_out $label;
			print $file_out " " x (((2*$space)+4) - (($space - ((length($label))/2)) + length($label)));
			print $file_out " " x $super_pad;
		}
		print $file_out "\n\n\n";
	}

	#get the stragglers
	if(($cols*int($keyCt / $cols)) != $keyCt){
		my @num_set = (($cols*int($keyCt / $cols))..($keyCt-1));
	printArr(", ", \@num_set);
	print "$keyCt\n";

	#####print the box parts######
		#label part of the box
		for(my $w=0;$w<($keyCt % $cols);$w++){
			my $label = $super_labels[$num_set[$w]];
			my $num = $num_set[$w];
			my @values = @{$super_values{$num}};

			#get max space of box
			my $maxDig = countDigits(max(@values));
			my $space = $maxDig + 2*($padding);


			print $file_out " " x ($padding + 1 + ($maxDig/2));
			print $file_out "no";
			print $file_out " " x ((($space - ($padding + 1 + ($maxDig/2))) + ($padding + ($maxDig/2) - 1)));
			print $file_out "yes";
			print $file_out " " x ($padding);
			print $file_out " " x ($super_pad);
		}
		print $file_out "\n";
		#top border
		for(my $w=0;$w<($keyCt % $cols);$w++){
			my $label = $super_labels[$num_set[$w]];
			my $num = $num_set[$w];
			my @values = @{$super_values{$num}};
			
			#get max space of box
			my $maxDig = countDigits(max(@values));
			my $space = $maxDig + 2*($padding);

			#print out
			print $file_out "+";
			print $file_out "-" x $space;
			print $file_out "-";
			print $file_out "-" x $space;
			print $file_out "+";
			print $file_out " " x $super_pad;
		}
		print $file_out "\n";
		#first layer of the set
		for(my $w=0;$w<($keyCt % $cols);$w++){
			my $label = $super_labels[$num_set[$w]];
			my $num = $num_set[$w];
			my @values = @{$super_values{$num}};
			
			#get max space of box
			my $maxDig = countDigits(max(@values));
			my $space = $maxDig + 2*($padding);

			#print out
			foreach my $n (@values[0..1]){
				print $file_out "|";
				print $file_out " " x $padding;
				print $file_out " " x (($maxDig - countDigits($n))/2);
				print $file_out $n;
				print $file_out " " x (($maxDig - (countDigits($n))+1)/2);
				print $file_out " " x $padding;
			}
			print $file_out "|";
			print $file_out " " x $super_pad;
		}
		print $file_out "\n";
		#middle bar border
		for(my $w=0;$w<($keyCt % $cols);$w++){
			my $label = $super_labels[$num_set[$w]];
			my $num = $num_set[$w];
			my @values = @{$super_values{$num}};
			
			#get max space of box
			my $maxDig = countDigits(max(@values));
			my $space = $maxDig + 2*($padding);

			#print out
			print $file_out "|";
			print $file_out "-" x $space;
			print $file_out "+";
			print $file_out "-" x $space;
			print $file_out "|";
			print $file_out " " x $super_pad;
		}
		print $file_out "\n";
		#last layer
		for(my $w=0;$w<($keyCt % $cols);$w++){
			my $label = $super_labels[$num_set[$w]];
			my $num = $num_set[$w];
			my @values = @{$super_values{$num}};
			
			#get max space of box
			my $maxDig = countDigits(max(@values));
			my $space = $maxDig + 2*($padding);

			#print out
			foreach my $n (@values[2..3]){
				print $file_out "|";
				print $file_out " " x $padding;
				print $file_out " " x (($maxDig - countDigits($n))/2);
				print $file_out $n;
				print $file_out " " x (($maxDig - (countDigits($n))+1)/2);
				print $file_out " " x $padding;
			}
			print $file_out "|";
			print $file_out " " x $super_pad;
		}
		print $file_out "\n";
		#bottom
		for(my $w=0;$w<($keyCt % $cols);$w++){
			my $label = $super_labels[$num_set[$w]];
			my $num = $num_set[$w];
			my @values = @{$super_values{$num}};
			
			#get max space of box
			my $maxDig = countDigits(max(@values));
			my $space = $maxDig + 2*($padding);

			#print out
			print $file_out "+";
			print $file_out "-" x $space;
			print $file_out "-";
			print $file_out "-" x $space;
			print $file_out "+";
			print $file_out " " x $super_pad;
		}
		print $file_out "\n";

		#labels underneath
		for(my $w=0;$w<($keyCt % $cols);$w++){
			my $label = $super_labels[$num_set[$w]];
			my $num = $num_set[$w];
			my @values = @{$super_values{$num}};
			
			#get max space of box
			my $maxDig = countDigits(max(@values));
			my $space = $maxDig + 2*($padding);

			#print out
			print $file_out " " x ($space - ((length($label))/2));
			print $file_out $label;
			print $file_out " " x (((2*$space)+4) - (($space - ((length($label))/2)) + length($label)));
			print $file_out " " x $super_pad;
		}
		print $file_out "\n\n\n";
	}
	
	
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