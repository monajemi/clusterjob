package CJ::Get;
# This is part of Clusterjob that handles GET option
# Copyright 2015 Hatef Monajemi (monajemi@stanford.edu)

use strict;
use warnings;
use CJ;


sub make_parrun_check_script{
my ($info,$res_filename) = @_;
my $machine    = $info->{'machine'};
my $package    = $info->{'package'};
my $account    = $info->{'account'};
my $remote_path = $info->{'remote_path'};
my $runflag    = $info->{'runflag'};
my $bqs        = $info->{'bqs'};
my $job_id     = $info->{'job_id'};
my $program    = $info->{'program'};





#find the number of folders with results in it
my @job_ids = split(',', $job_id);
my $num_res = 1+$#job_ids;

# header for bqs's
my $HEADER = &CJ::bash_header($bqs);
# check which jobs are done.
my $bash_remote_path  = $remote_path;
$bash_remote_path =~ s/~/\$HOME/;
my $check_runs=<<TEXT;
$HEADER

if [ ! -f "$bash_remote_path/run_list.txt" ];then
touch $bash_remote_path/done_list.txt
touch $bash_remote_path/run_list.txt

for COUNTER in `seq $num_res`;do
    if [ -f "$bash_remote_path/\$COUNTER/$res_filename" ];then
echo -e "\$COUNTER\\t" >> "$bash_remote_path/done_list.txt"
    else
        echo -e "\$COUNTER\\t" >> "$bash_remote_path/run_list.txt"
        fi
        done
        else
            
            for line in \$(cat $bash_remote_path/run_list.txt);do
                COUNTER=`grep -o "[0-9]*" <<< \$line`
                if [ -f "$bash_remote_path/\$COUNTER/$res_filename" ];then
echo -e "\$COUNTER\\t" >> "$bash_remote_path/done_list.txt"
sed  '/\^\$COUNTER\$/d' "$bash_remote_path/run_list.txt" > "$bash_remote_path/run_list.txt"
fi
done
fi

TEXT

    
    return  $check_runs;
    
    
}




1;