package CJ::Matlab;
# This is part of Clusterjob that handles the collection
# of Matlab results
# Copyright 2015 Hatef Monajemi (monajemi@stanford.edu) 

use strict;
use warnings;
use CJ;








sub read_matlab_index_set
{
    my ($forline, $TOP) = @_;
    
    chomp($forline);
    $forline = &CJ::Matlab::uncomment_matlab_line($forline);   # uncomment the line so you dont deal with comments. easier parsing;
    
    
    # split at equal sign.
    my @myarray    = split(/\s*=\s*/,$forline);
    my @tag     = split(/\s/,$myarray[0]);
    my $idx_tag = $tag[-1];
    
    
    
    
    my $range;
    # The right of equal sign
    my $right  = $myarray[1];
    
    # see if the forline contains :
    if($right =~ /.*\:.*/){
        
        my @rightarray = split( /\s*:\s*/, $right, 2 );
        
        my $low =$rightarray[0];
        if(! &CJ::isnumeric($low) ){
            &CJ::err("The lower limit of for MUST be numeric for this version of clusterjob\n");
        }
        
        
        
        # exit on unallowed structure
        if ($rightarray[1] =~ /.*:.*/){
            &CJ::err("Sorry!...structure 'for i=1:1:3' is not allowed in clusterjob. Try rewriting your script using 'for i = 1:3' structure\n");
        }
        
        
        
        if($rightarray[1] =~ /\s*length\(\s*(.+?)\s*\)/){
            
            #CASE i = 1:length(var);
            # find the variable;
            my ($var) = $rightarray[1] =~ /\s*length\(\s*(.+?)\s*\)/;
            my $this_line = &CJ::grep_var_line($var,$TOP);
            
            
            #extract the range
            my @this_array    = split(/\s*=\s*/,$this_line);
            
            my $numbers;
            if($this_array[1] =~ /\[\s*(.+?)\s*\]/){
                ($numbers) = $this_array[1] =~ /\[\s*(.+?)\s*\]/;
            }else{
                # FUTURE_REV_ADD
                &CJ::err("MATLAB structure '$this_line ' not currently supported for parrun.");
            }
            
            
            
            my @vals = split(/,|;/,$numbers);
            
            my $high = 1+$#vals;
            my @range = ($low..$high);
            $range = join(',',@range);
            
        }elsif($rightarray[1] =~ /\s*(\D+).*/) {
            print "$rightarray[1]"."\n";
            # CASE i = 1:L
            # find the variable;
            my($var) = $rightarray[1] =~ /\s*(\D+).*/;
            my $this_line = &CJ::grep_var_line($var,$TOP);
            
            #extract the range
            my @this_array    = split(/\s*=\s*/,$this_line);
            my ($high) = $this_array[1] =~ /\[?\s*(\d+)\s*\]?/;
            my @range = ($low..$high);
            $range = join(',',@range);
            
        }elsif($rightarray[1] =~ /.*(\d+).*/){
            # CASE i = 1:10
            my ($high) = $rightarray[1] =~ /\s*(\d+).*/;
            my @range = ($low..$high);
            $range = join(',',@range);
            
        }else{
            &CJ::err("strcuture of for loop not recognized by clusterjob. try rewriting your for loop using 'i = 1:10' structure");
            
        }
        
        
    }
    
    return ($idx_tag, $range);
}








sub uncomment_matlab_line{
    my ($line) = @_;
    $line =~ s/^(?:(?!\').)*\K\%(.*)//;
    return $line;
}









sub make_MAT_collect_script
{
my ($res_filename, $done_filename, $bqs) = @_;
    
my $collect_filename = "collect_list.txt";
    
my $matlab_collect_script=<<MATLAB;
\% READ done_list.txt and FIND The counters that need
\% to be read
done_list = load('$done_filename');

if(~isempty(done_list))


\%determine the structre of the output
if(exist('$res_filename', 'file'))
    \% CJ has been called before
    res = load('$res_filename');
    start = 1;
else
    \% Fisrt time CJ is being called
    res = load([num2str(done_list(1)),'/$res_filename']);
    start = 2;
    
    
    \% delete the line from done_filename and add it to collected.
    fid = fopen('$done_filename', 'r') ;              \% Open source file.
    fgetl(fid) ;                                      \% Read/discard line.
    buffer = fread(fid, Inf) ;                        \% Read rest of the file.
    fclose(fid);
    delete('$done_filename');                         \% delete the file
    fid = fopen('$done_filename', 'w')  ;             \% Open destination file.
    fwrite(fid, buffer) ;                             \% Save to file.
    fclose(fid) ;
    
    if(~exist('$collect_filename','file'));
    fid = fopen('$collect_filename', 'a+');
    fprintf ( fid, '%d\\n', done_list(1) );
    fclose(fid);
    end
    
    percent_done = 1/length(done_list) * 100;
    fprintf('\\n SubPackage %d Collected (%3.2f%%)', done_list(1), percent_done );

    
end

flds = fields(res);


for idx = start:length(done_list)
    count  = done_list(idx);
    newres = load([num2str(count),'/$res_filename']);
    
    for i = 1:length(flds)  \% for all variables
        res.(flds{i}) =  CJ_reduce( res.(flds{i}) ,  newres.(flds{i}) );
    end

\% save after each packgae
save('$res_filename','-struct', 'res');
percent_done = idx/length(done_list) * 100;
    
\% delete the line from done_filename and add it to collected.
fid = fopen('$done_filename', 'r') ;              \% Open source file.
fgetl(fid) ;                                      \% Read/discard line.
buffer = fread(fid, Inf) ;                        \% Read rest of the file.
fclose(fid);
delete('$done_filename');                         \% delete the file
fid = fopen('$done_filename', 'w')  ;             \% Open destination file.
fwrite(fid, buffer) ;                             \% Save to file.
fclose(fid) ;

if(~exist('$collect_filename','file'));
    error('   CJerr::File $collect_filename is missing. CJ stands in AWE!');
end

fid = fopen('$collect_filename', 'a+');
fprintf ( fid, '%d\\n', count );
fclose(fid);
    
fprintf('\\n SubPackage %d Collected (%3.2f%%)', count, percent_done );
end

   

end

MATLAB




my $HEADER= &CJ::bash_header($bqs);

my $script;
if($bqs eq "SGE"){
$script=<<BASH;
$HEADER
echo starting collection
echo FILE_NAME $res_filename


module load MATLAB-R2014a;
matlab -nosplash -nodisplay <<HERE

$matlab_collect_script

quit;
HERE

echo ending colection;
echo "done"
BASH
}elsif($bqs eq "SLURM"){
$script= <<BASH;
$HEADER
echo starting collection
echo FILE_NAME $res_filename

module load matlab;
matlab -nosplash -nodisplay <<HERE

$matlab_collect_script

quit;
HERE

echo ending colection;
echo "done"
BASH

}

    
    return $script;
}




1;