package CJ::Matlab;
# This is part of Clusterjob that handles the collection
# of Matlab results
# Copyright 2015 Hatef Monajemi (monajemi@stanford.edu) 

use strict;
use warnings;
use CJ;



sub make_collect_script
{
my ($res_filename, $done_filename, $bqs) = @_;
    

    
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
end

flds = fields(res);


for idx = start:length(done_list)
    count  = done_list(idx);
    newres = load([num2str(count),'/$res_filename']);
    
    for i = 1:length(flds)  \% for all variables
      res.(flds{i}) =  CJ_reduce( res.(flds{i}) ,  newres.(flds{i}) )
    end

end

save('$res_filename','-struct', 'res')

delete('$done_filename');
fclose(fopen('$done_filename', 'w'));

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