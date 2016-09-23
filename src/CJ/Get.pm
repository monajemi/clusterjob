package CJ::Get;
# This is part of Clusterjob that handles GET option
# Copyright 2015 Hatef Monajemi (monajemi@stanford.edu)

use strict;
use warnings;
use CJ;
use CJ::CJVars;




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
    $cmd = "ssh $account 'cd $remote_path; bash -l $gather_name 2> cj_gather.out'";
    &CJ::my_system($cmd,1);
    
    
    # Get the feedback
    $cmd = "scp  $account:$remote_path/cj_gather.out /tmp/";
    &CJ::my_system($cmd,$verbose);
    
    my $short_pid = substr($info->{'pid'},0,8);
    if ( ! -s "/tmp/cj_gather.out" ){
    &CJ::message("Gathering results done! Please use \"CJ get $short_pid \" to get your results.");
    }else{
    my $error = `cat "/tmp/cj_gather.out"`;
    &CJ::err("$error");
    }
    
}










sub reduce_results{
    my ($pid,$res_filename,$verbose, $text_header_lines) = @_;
    
    
    
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
   
  # REDUCE IS ONLY FOR PARRUN
  if(! $runflag =~ m/^par*/){
      CJ::err("REDUCE must be called for a 'parrun' package. Please use GET instead.");
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
    my $current_remote_path = "$remotePrefix/$program_name/$info->{pid}";
    
    #print("$remote_path");
    if($current_remote_path ne $remote_path){
        &CJ::warning("the .ssh_config remote directory and the history remote are not the same. CJ is choosing:\n     $account:${current_remote_path}.");
        $remote_path = $current_remote_path;
    }
    
    
    
    
    if (!defined($res_filename)){
        &CJ::err("The result filename must be provided for Reduce with parrun packages, eg, 'clusterjob reduce Results.mat' ");
    }
    
    my $check_runs = &CJ::Get::make_parrun_check_script($info,$res_filename);
    my $check_name = "check_complete.sh";
    my $check_path = "/tmp/$check_name";
    &CJ::writeFile($check_path,$check_runs);
    
    &CJ::message("Checking progress of runs...");
    my $cmd = "rsync $check_path $account:$remote_path/;ssh $account 'source ~/.bashrc;cd $remote_path; bash $check_name'";
    &CJ::my_system($cmd,$verbose);
    # Run a script to gather all files of the same name.
    my $completed_filename = "completed_list.txt";
    my $remaining_filename = "remaining_list.txt";
    
    my $ext = lc(getExtension($res_filename));
    
    
    my $collect_bash_script;
    if( $ext =~ m/mat/){
        $collect_bash_script = &CJ::Matlab::make_MAT_collect_script($res_filename, $completed_filename,$bqs);
        
    }elsif ($ext =~ m/txt|csv/){
        $collect_bash_script = &CJ::Get::make_TEXT_collect_script($res_filename, $remaining_filename,$completed_filename,$bqs, $text_header_lines);
    }else{
        &CJ::err("File extension not recognized");
    }
    
    
    #print "$collect_bash_script";
   
    
    my $CJ_reduce_matlab = "$install_dir/CJ/CJ_reduce.m";
    my $collect_name = "cj_collect.sh";
    my $collect_bash_path = "/tmp/$collect_name";
    &CJ::writeFile($collect_bash_path,$collect_bash_script);
   
    $cmd = "scp $collect_bash_path $CJ_reduce_matlab $account:$remote_path/";
    &CJ::my_system($cmd,$verbose);
   
    
	
	
   
	
	
    my $short_pid=substr($info->{'pid'},0,8);
	
    &CJ::message("Reducing results...");
    if($bqs eq "SLURM"){
		
		
	    CJ::message("Do you want to submit the reduce script to the queue via srun?(recommneded for big jobs) Y/N?");
	    my $input =  <STDIN>; chomp($input);
	    if(lc($input) eq "y" or lc($input) eq "yes"){
	        &CJ::message("Reducing results...");
	        my $cmd = "ssh $account 'cd $remote_path; srun bash -l $collect_name'";
	        #my $cmd = "ssh $account 'cd $remote_path; qsub $collect_name'";
		    &CJ::my_system($cmd,1);
		    &CJ::message("Reducing results done! Please use \"CJ get $short_pid \" to get your results.");
		
	    }elsif(lc($input) eq "n" or lc($input) eq "no"){
	        my $cmd = "ssh $account 'cd $remote_path; bash -l $collect_name'";
		    &CJ::my_system($cmd,1);
		    &CJ::message("Reducing results done! Please use \"CJ get $short_pid \" to get your results.");
	    }else{
	        &CJ::message("Reduce Canceled!");
	        exit 0;
	    }	
    }else{
    my $cmd = "ssh $account 'cd $remote_path; bash -l $collect_name'";
    &CJ::my_system($cmd,1);
    &CJ::message("Reducing results done! Please use \"CJ get $short_pid \" to get your results.");
    }
   
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











sub getExtension{
    my ($filename) = @_;
    #print "$filename\n";
    
    my ($ext) = $filename =~ /\.([^.]+)$/;
    return $ext;
}














sub make_parrun_check_script{
    
my ($info,$res_filename) = @_;
my $machine    = $info->{'machine'};
my $pid        = $info->{'pid'};
my $account    = $info->{'account'};
my $remote_path = $info->{'remote_path'};
my $runflag    = $info->{'runflag'};
my $bqs        = $info->{'bqs'};
my $job_id     = $info->{'job_id'};
my $program    = $info->{'program'};

my $collect_filename = "collect_list.txt";
my $alljob_filename  = "job_list.txt";
my $remaining_filename = "remaining_list.txt";
my $completed_filename = "completed_list.txt";
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

    
    return  $check_runs;
    
    
}








sub make_TEXT_collect_script
{
    my ($res_filename, $remaining_filename, $completed_filename, $bqs, $text_header_lines) = @_;
    
    
    
    
    my $collect_filename = "collect_list.txt";
    
    
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
#READ remaining_list.txt and FIND The counters that need
#to be read
if [ ! -s  $completed_filename ]; then
    
    if [ ! -s  $remaining_filename ]; then
     echo "CJ::Reduce:: All results completed and collected. ";
    else
    # check if collect is complete
    # if yes, then echo results collect fully
    echo "     CJ::Reduce:: Nothing to collect. Possible reasons are: Invalid filename, No new completed job.";
    fi
    
else
  
    TOTAL=\$(wc -l < "$completed_filename");
    
    # determine wether reduce has been run before
    
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
        sed -n "\$startline,\\\$p" < "\$COUNTER/$res_filename" >> "$res_filename";  #simply append (no header modification yet)

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










1;