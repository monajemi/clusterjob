package CJ::Get;
# This is part of Clusterjob that handles GET option
# Copyright 2015 Hatef Monajemi (monajemi@stanford.edu)

use strict;
use warnings;
use CJ;
use CJ::CJVars;
use Data::Dumper;




sub gather_results{
    my ($pid, $pattern, $dir_name, $verbose) = @_;
    
    
    if ( (!defined($pattern)) ||  (!defined($dir_name)) ){
        &CJ::err("Pattern and dir_name must be provided for gather with parrun packages, eg, 'clusterjob gather *.mat MATFILES' ");
    }

    
    
    
    my $info;
    if( (!defined $pid) || ($pid eq "") ){
        #read last_instance.info;
        $info = &CJ::retrieve_package_info();
        $pid        = $info->{'pid'};
    }else{
        if( &CJ::is_valid_pid($pid) ){
            # read info from $run_history_file
            $info = &CJ::retrieve_package_info($pid);
            
            if (!defined($info)){
                CJ::err("No such job found in the database");
            }
            
        }else{
            &CJ::err("incorrect usage: nothing to show");
        }
        
        
        
    }

    
    my $machine    = $info->{'machine'};
    my $account    = $info->{'account'};
    my $remote_path= $info->{'remote_path'};
    my $runflag    = $info->{'runflag'};
    my $bqs        = $info->{'bqs'};
    my $job_id     = $info->{'job_id'};
    my $program    = $info->{'program'};
    
    
    
    # Check Connection;
    &CJ::CheckConnection($machine);

    
    
    # gather IS ONLY FOR PARRUN
    if(! $runflag =~ m/^par*/){
        CJ::err("GATHER must be called for a 'parrun' package. Please use GET instead.");
    }

    
    

    # Get current remote directory from .ssh_config
    # user might wanna rename, copy to anothet place,
    # etc. We consider the latest one , and if the
    # saved remote is different, we issue a warning
    # for the user.
    #print "$machine\n";
    my $ssh             = &CJ::host($machine);
    my $remotePrefix    = $ssh->{remote_repo};
    
    my @program_name    = split /\./,$program;
    my  $lastone = pop @program_name;
    my $program_name   =   join "\_",@program_name;
    my $current_remote_path = "$remotePrefix/$program_name/$info->{'pid'}";
    
    #print("$remote_path");
    if($current_remote_path ne $remote_path){
        &CJ::warning("the .ssh_config remote directory and the history remote are not the same. CJ is choosing:\n     $account:${current_remote_path}.");
        $remote_path = $current_remote_path;
    }
    
    
    
# Find number of jobs to be gathered
my @job_ids = split(',', $job_id);
my $num_res = 1+$#job_ids;
    
# header for bqs's
my $HEADER = &CJ::bash_header($bqs);
my $bash_remote_path  = $remote_path;
$bash_remote_path =~ s/~/\$HOME/;
my $gather_bash_script=<<GATHER;
    $HEADER
    
    TARGET_DIR=$remote_path/$dir_name
    rm -rf \$TARGET_DIR
    mkdir \$TARGET_DIR
        
    for COUNTER in \$(seq $num_res);do
      cd $remote_path/\$COUNTER
        NUMFILES=\$(ls -C1 $pattern | wc -l | tr -d ' ' );
        echo "Gathering -> \$COUNTER: [\$NUMFILES] ";
        for file in \$(ls -C1 $pattern );do
            if [ ! -f \$TARGET_DIR/\$file ];then
                cp \$file \$TARGET_DIR
    #echo "      :\$file";
            else
            echo "Files are not distinct. Use REDUCE instead of GATEHR"; exit 1;
            fi
        done
    done
        
GATHER
        
    my $gather_name = "cj_gather.sh";
    my $gather_bash_path = "/tmp/$gather_name";
    &CJ::writeFile($gather_bash_path,$gather_bash_script);
    
    my $cmd = "scp $gather_bash_path $account:$remote_path/";
    
    &CJ::my_system($cmd,$verbose);
    
    
    &CJ::message("Gathering $pattern in $dir_name...");
    $cmd = "ssh $account 'cd $remote_path; bash -l $gather_name 2> cj_gather.stderr'";
    &CJ::my_system($cmd,1);
    
    
    # Get the feedback
    $cmd = "scp  $account:$remote_path/cj_gather.stderr /tmp/";
    &CJ::my_system($cmd,$verbose);
    
    my $short_pid = substr($info->{'pid'},0,8);
    if ( -z "/tmp/cj_gather.stderr" ){
    &CJ::message("Gathering results done! Please use \"CJ get $short_pid \" to get your results.");
    }else{
    my $error = `cat "/tmp/cj_gather.stderr"`;
    &CJ::err("$error");
    }
    
}








sub reduce_results{
	my ($pids,$res_filename,$verbose, $text_header_lines, $force_tag) = @_;
	
    my $yesno = undef; # wether they need to reduce with qsub (for big reduction) or not;
    
	if(! @$pids){
	    # just the last instance		
        my $info       = &CJ::retrieve_package_info();
        my $pid           = $info->{'pid'};
		CJ::message("$pid");
        
		reduce_one_pid($pid,$res_filename,$verbose, $text_header_lines,$force_tag,$yesno);
	}else{
  	  	# here $pids is a reference to an array
        foreach my $pid (@$pids){
			CJ::message("$pid");
           	$yesno = reduce_one_pid($pid,$res_filename,$verbose, $text_header_lines,$force_tag,$yesno);
           
        }
	}
	
    
    
    
}


###########################
sub reduce_one_pid{
###########################
    my ($pid,$res_filename,$verbose, $text_header_lines,$force_tag,$yesno) = @_;
    
    
    my $info;
    if( (!defined $pid) || ($pid eq "") ){
        #read last_instance.info;
        $info = &CJ::retrieve_package_info();
        $pid           = $info->{'pid'};

    }else{
        if( &CJ::is_valid_pid($pid) ){
            # read info from $run_history_file
            $info = &CJ::retrieve_package_info($pid);
            
            if (!defined($info)){
                CJ::err("No such job found in the database");
            }
            
        }else{
            &CJ::err("incorrect usage: nothing to show");
        }
        
        
        
    }

    
    my $machine       = $info->{'machine'};
    my $account       = $info->{'account'};
    my $remote_path   = $info->{'remote_path'};
    my $runflag       = $info->{'runflag'};
    my $bqs           = $info->{'bqs'};
    my $job_id        = $info->{'job_id'};
    my $program       = $info->{'program'};
   
    
    
    # Check Connection;
    &CJ::CheckConnection($machine);
 
    
    
    # REDUCE IS ONLY FOR PARRUN
    if(! $runflag =~ m/^par*/){
      CJ::err("REDUCE must be called for a 'parrun' package. Please use GET instead.");
    }

    # Check that job has been actually submitted.
    my @job_ids = split(',', $job_id);
    my $num_res = 1+$#job_ids;
    my $short_pid = &CJ::short_pid($pid);
    
    if ( $num_res < 1 ){
    CJ::message(" Nothing to reduce. no job id found. try 'cj rerun $short_pid' to resubmit this PID.");
        exit 0;
    }
    
    
    
    
    
    # Get current remote directory from .ssh_config
    # user might wanna rename, copy to another place,
    # etc. We consider the latest one , and if the
    # saved remote is different, we issue a warning
    # for the user.
    #print "$machine\n";
    my $ssh             = &CJ::host($machine);
    my $remotePrefix    = $ssh->{remote_repo};
    
    my @program_name    = split /\./,$program;
    my  $lastone = pop @program_name;
    my $program_name   =   join "\_",@program_name;
    my $current_remote_path = "$remotePrefix/$program_name/$info->{pid}";
    
    #print("$remote_path");
    if($current_remote_path ne $remote_path){
        &CJ::warning("the .ssh_config remote directory and the history remote are not the same. CJ is choosing:\n     $account:${current_remote_path}.");
        $remote_path = $current_remote_path;
    }
    
    
    
    
    if (!defined($res_filename)){
        &CJ::err("The result filename must be provided for Reduce with parrun packages, eg, 'clusterjob reduce Results.mat' ");
    }
    
    
    
    # clear everything if force
    if($force_tag == 1){
        ### You need to delete all the previous files generated by reduce in PID top directory.
        my $cmd = "ssh $account 'rm -f $remote_path/$res_filename $remote_path/*.cjr'";
        &CJ::my_system($cmd,$verbose);
    }
    

    
    
    my $check_runs = &CJ::Get::make_parrun_check_script($info,$res_filename);
    my $check_name = "check_complete.sh";
    my $check_path = "/tmp/$check_name";
    &CJ::writeFile($check_path,$check_runs);
    
    &CJ::message("Checking progress of runs...");
    my $cmd = "rsync $check_path $account:$remote_path/;ssh $account 'source ~/.bashrc;cd $remote_path; bash $check_name'";
    &CJ::my_system($cmd,$verbose);
    # Run a script to gather all files of the same name.
    my $completed_filename = "completed_list.cjr";
    my $remaining_filename = "remaining_list.cjr";
    
    my $ext = lc(&CJ::getExtension($res_filename));
    #print "$res_filename\n";
    
    my $collect_bash_script;
    if( $ext =~ m/mat/){
        $collect_bash_script = &CJ::Get::make_MAT_collect_script($res_filename, $completed_filename,$bqs,$ssh);
    }elsif ($ext =~ m/txt|csv/){
        $collect_bash_script = &CJ::Get::make_TEXT_collect_script($res_filename,$remaining_filename,$completed_filename,$bqs, $text_header_lines);
    }else{
        &CJ::err("File extension not recognized");
    }
    
    
    #print "$collect_bash_script";
    
    
    my $CJ_reduce_matlab = "$src_dir/CJ/CJ_reduce.m";
    my $collect_name = "cj_collect.sh";
    my $collect_bash_path = "/tmp/$collect_name";
    &CJ::writeFile($collect_bash_path,$collect_bash_script);
   
    $cmd = "scp $collect_bash_path $CJ_reduce_matlab $account:$remote_path/";
    &CJ::my_system($cmd,$verbose);
	
    &CJ::message("Reducing $res_filename");
    if($bqs eq "SLURM"){
		
        
        if(not defined($yesno) ){
            CJ::message("Do you want to submit the reduce script to the queue via srun? (recommneded for big jobs) Y/N?");
            $yesno =  <STDIN>; chomp($yesno);
        }
    
        
        if(lc($yesno) eq "y" or lc($yesno) eq "yes"){
	        &CJ::message("Reducing results...");
	        my $cmd = "ssh $account 'cd $remote_path; srun bash -l $collect_name'";
	        #my $cmd = "ssh $account 'cd $remote_path; qsub $collect_name'";
		    &CJ::my_system($cmd,1);
		    &CJ::message("Reducing results done! Use \"CJ get $short_pid \" to get your results.");
		
	    }elsif(lc($yesno) eq "n" or lc($yesno) eq "no"){
	        my $cmd = "ssh $account 'cd $remote_path; bash -l $collect_name'";
		    &CJ::my_system($cmd,1);
		    &CJ::message("Reducing results done! Use \"CJ get $short_pid \" to get your results.");
	    }else{
	        &CJ::message("Reduce Canceled!");
	        exit 0;
	    }	
    }else{
            my $cmd = "ssh $account 'cd $remote_path; bash -l $collect_name'";
            &CJ::my_system($cmd,1);
            &CJ::message("Reducing results done! Please use \"CJ get $short_pid \" to get your results.");
 
    }

return $yesno;

}



#==========================================================
#            CLUSTERJOB GET
#       ex.  clusterjob get Results.txt
#       ex.  clusterjob get 2015JAN07_213759  Results.mat
#==========================================================





sub get_results{
    my ($pid,$subfolder,$verbose) = @_;
   

    
    my $info;
    if( (!defined $pid) || ($pid eq "") ){
        #read last_instance.info;
        $info = &CJ::retrieve_package_info();
        $pid           = $info->{'pid'};
    }else{
        if( &CJ::is_valid_pid($pid) ){
            # read info from $run_history_file
            $info = &CJ::retrieve_package_info($pid);
            
            if (!defined($info)){
                CJ::err("No such job found in the database");
            }
            
        }else{
            &CJ::err("incorrect usage: nothing to show");
        }
        
        
        
    }
    
    
    my $machine       = $info->{'machine'};
    my $account       = $info->{'account'};
    my $local_path    = $info->{'local_path'};
    my $remote_path   = $info->{'remote_path'};
    my $runflag       = $info->{'runflag'};
    my $bqs           = $info->{'bqs'};
    my $job_id        = $info->{'job_id'};
    my $program       = $info->{'program'};
    
    
    # Check Connection;
    &CJ::CheckConnection($machine);


    
    # Get current remote directory from .ssh_config
    # user might wanna rename, copy to anothet place,
    # etc. We consider the latest one , and if the
    # save remote is different, we issue a warning
    # for the user.
    &CJ::message("Getting results from '$machine'");

    #print "\n";
    my $ssh             = &CJ::host($machine);
    my $remotePrefix    = $ssh->{remote_repo};
    
    my @program_name    = split /\./,$program;
    my  $lastone = pop @program_name;
    my $program_name   =   join "\_",@program_name;
    my $current_remote_path = "$remotePrefix/$program_name/$info->{pid}";
    
    #print("$remote_path");
    if($current_remote_path ne $remote_path){
        &CJ::warning("the .ssh_config remote directory and the history remote are not the same. CJ is choosing:\n     $account:${current_remote_path}.");
        $remote_path = $current_remote_path;
    }
    
    
    
    
    # Give a message that REDUCE must be called before
    # Get for parrun. Sometimes, people wont want to reduce
    # in which case a GET does the job. For instance, each
    # parrallel folder might contain a *.vtu file for a certain
    # time, and you certainly dont want to reduce that
    
    if($runflag =~ m/^par.*/){
        &CJ::message("Run REDUCE before GET for reducing parrun packages");
    }
    
    mkdir "$get_tmp_dir" unless (-d "$get_tmp_dir");
    mkdir "$get_tmp_dir/$info->{pid}" unless (-d "$get_tmp_dir/$info->{pid}");
    
	# remove the trailing backslash by user if any
	if($subfolder){
			$subfolder =~ s/\/*$//;
	}else{
	  	$subfolder="";
	}
    my $cmd = "rsync -arvz  $account:${remote_path}/$subfolder $get_tmp_dir/$info->{pid}";
    &CJ::my_system($cmd,$verbose);
    
    
    # build a CJ confirmation file
    my $confirm_path = "$get_tmp_dir/$info->{pid}";
    &CJ::build_cj_confirmation($info->{pid}, $confirm_path);

    &CJ::message("Please see your last results in $get_tmp_dir/$info->{pid}");
    
    
    exit 0;
}





sub make_parrun_check_script{
    
my ($info,$res_filename) = @_;
my $machine     = $info->{'machine'};
my $pid         = $info->{'pid'};
my $account     = $info->{'account'};
my $remote_path = $info->{'remote_path'};
my $runflag     = $info->{'runflag'};
my $bqs         = $info->{'bqs'};
my $job_id      = $info->{'job_id'};
my $program     = $info->{'program'};

my $collect_filename    = "collect_list.cjr";
my $alljob_filename     = "job_list.cjr";
my $remaining_filename  = "remaining_list.cjr";
my $completed_filename  = "completed_list.cjr";
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

if [ ! -f "$bash_remote_path/$collect_filename" ];then
#build a file of jobs
seq $num_res > $bash_remote_path/$alljob_filename
cp   $bash_remote_path/$alljob_filename  $bash_remote_path/$remaining_filename
else
grep -Fxvf $bash_remote_path/$collect_filename $bash_remote_path/$alljob_filename  >  $bash_remote_path/$remaining_filename;
fi

    
if [ -f "$bash_remote_path/$completed_filename" ];then
    rm $bash_remote_path/$completed_filename
fi
    
    
touch $completed_filename
for line in \$(cat $bash_remote_path/$remaining_filename);do
COUNTER=`grep -o "[0-9]*" <<< \$line`
if [ -f "$bash_remote_path/\$COUNTER/$res_filename" ];then
echo -e "\$COUNTER\\t" >> "$bash_remote_path/$completed_filename"
fi
done
    
    
TEXT

    ### IMPROVE THIS LATER: COMPLETED JOBS MUST BE CHECK BY STATUS OF THE JOB NOT BY THE PRESENCE OF THE RESULTS.
    ### RESULTS FILE MIGHT BE EXTENDING OVER TIME.
    return  $check_runs;
}








sub make_TEXT_collect_script
{
    my ($res_filename, $remaining_filename, $completed_filename, $bqs, $text_header_lines) = @_;
    
    my $collect_filename = "collect_list.cjr";
    
    my $num_header_lines;
    if(defined($text_header_lines)){
        $num_header_lines = $text_header_lines;
    }else{
        $num_header_lines = 0;
    }
        
    
    
# header for bqs's
my $HEADER = &CJ::bash_header($bqs);
    
my $text_collect_script=<<BASH;
$HEADER
#READ remaining_list.cjr and FIND The counters that need
#to be collected
    
if [ ! -s $completed_filename ]; then
    
    if [ ! -s  $remaining_filename ]; then
     echo "CJ::Reduce:: All results completed and collected. ";
    else
    # check if collect is complete
    # if yes, then echo results collect fully
    echo "     CJ::Reduce:: Nothing to collect. Possible reasons are: Invalid filename, No new completed job.";
    fi
    
else
  
    TOTAL=\$(wc -l < "$completed_filename");
    
    # determine whether reduce has been run before
    if [ ! -f "$res_filename" ];then
      # It is the first time reduce is being called.
      # Read the result of the first package
    
      firstline=\$(head -n 1 $completed_filename)
      COUNTER=`grep -o "[0-9]*" <<< \$firstline`

      touch $res_filename;
      cat "\$COUNTER/$res_filename" > "$res_filename";
    
        # Pop the first line of remaining_list and add it to collect_list
    #  sed -i '1d' $completed_filename
        if [ ! -f $collect_filename ];then
            echo \$COUNTER > $collect_filename;
        else
          echo "CJ::Reduce:: CJ in AWE. $collect_filename exists but CJ thinks its the first time reduce is called" 1>&2
          exit 1
        fi
    PROGRESS=1;
    percent_done=\$(awk "BEGIN {printf \\"%.2f\\",100*\${PROGRESS}/\${TOTAL}}")
    printf "\\n SubPackage %d Collected (%3.2f%%)" \$COUNTER \$percent_done

    else
    PROGRESS=0;
    fi

    
    for LINE in \$(tail -n +\$((\$PROGRESS+1)) $completed_filename);do


        PROGRESS=\$((\$PROGRESS+1))
        # Reduce results
        COUNTER=`grep -o "[0-9]*" <<< \$LINE`


        # Remove header-lines!
        startline=\$(($num_header_lines+1));
        sed -n "\$startline,\\\$p" < "\$COUNTER/$res_filename" >> "$res_filename";  #simply append

        # Pop the first line of remaining_list and append it to collect_list
        #sed -i '1d' $completed_filename
        if [ -f $collect_filename ];then
        echo \$COUNTER >> $collect_filename
        else
        echo "CJ::Reduce:: CJ in AWE. $collect_filename does not exists when CJ expects it." 1>&2
        exit 1
        fi

        percent_done=\$(awk "BEGIN {printf \\"%.2f\\",100*\${PROGRESS}/\${TOTAL}}")
        printf "\\n SubPackage %d Collected (%3.2f%%)" \$COUNTER \$percent_done

    done
    printf "\\n"
    
fi
    
    
BASH
  
    
    
    

    
    return $text_collect_script;
    
    
    
}










#############################
sub make_MAT_collect_script{
#############################
    
my ($res_filename, $completed_filename, $bqs, $ssh) = @_;

my $collect_filename = "collect_list.cjr";

my $matlab_collect_script=<<MATLAB;
\% READ completed_list.cjr and FIND The counters that need
\% to be collected
completed_list = load('$completed_filename');

if(~isempty(completed_list))

\%determine the structre of the output
if(exist('$res_filename', 'file'))
\% CJ has been called before
res = load('$res_filename');
start = 1;
else
\% Fisrt time CJ is being called
res = load([num2str(completed_list(1)),'/$res_filename']);
start = 2;


\% delete the line from remaining_filename and add it to collected.
\%fid = fopen('$completed_filename', 'r') ;               \% Open source file.
\%fgetl(fid) ;                                            \% Read/discard line.
\%buffer = fread(fid, Inf) ;                              \% Read rest of the file.
\%fclose(fid);
\%delete('$completed_filename');                         \% delete the file
\%fid = fopen('$completed_filename', 'w')  ;             \% Open destination file.
\%fwrite(fid, buffer) ;                                  \% Save to file.
\%fclose(fid) ;

if(~exist('$collect_filename','file'));
fid = fopen('$collect_filename', 'a+');
fprintf ( fid, '%d\\n', completed_list(1) );
fclose(fid);
end

percent_done = 1/length(completed_list) * 100;
fprintf('\\n SubPackage %d Collected (%3.2f%%)', completed_list(1), percent_done );


end

flds = fields(res);

for idx = start:length(completed_list)
count  = completed_list(idx);
newres = load([num2str(count),'/$res_filename']);

for i = 1:length(flds)  \% for all variables
res.(flds{i}) =  CJ_reduce( res.(flds{i}) ,  newres.(flds{i}) );
end

\% save after each packgae
save('$res_filename','-struct', 'res');
percent_done = idx/length(completed_list) * 100;

\% delete the line from remaining_filename and add it to collected.
\%fid = fopen('$completed_filename', 'r') ;              \% Open source file.
\%fgetl(fid) ;                                           \% Read/discard line.
\%buffer = fread(fid, Inf) ;                             \% Read rest of the file.
\%fclose(fid);
\%delete('$completed_filename');                         \% delete the file
\%fid = fopen('$completed_filename', 'w')  ;             \% Open destination file.
\%fwrite(fid, buffer) ;                                  \% Save to file.
\%fclose(fid) ;

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




my $script = &CJ::bash_header($bqs);
    
$script .=<<BASH;
echo starting collection
echo FILE_NAME $res_filename
    
module load <MATLAB_MODULE>
unset _JAVA_OPTIONS
matlab -nosplash -nodisplay <<HERE
$matlab_collect_script
quit;
HERE
    
echo ending colection;
echo "done"
BASH

$script =~ s|<MATLAB_MODULE>|$ssh->{mat}|;
    
return $script;
}




1;
