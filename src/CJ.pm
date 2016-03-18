package CJ;
# This is part of Clusterjob (CJ)
# Copyright 2015 Hatef Monajemi (monajemi@stanford.edu)
use strict;
use warnings;
use CJ::CJVars;
use Term::ReadLine;
use Time::Local;
use JSON::PP;
use Data::Dumper;
use feature 'say';


sub version_info{
my $version_script="\n\n          This is Clusterjob (CJ) verion 1.1.0";
$version_script .=  "\n          Copyright (c) 2015 Hatef Monajemi (monajemi\@stanford.edu)";
$version_script .="\n          CJ may be copied only under the terms and conditions of";
$version_script .=  "\n          the GNU General Public License, which may be found in the CJ";
$version_script .=  "\n          source code. For more info please visit";
$version_script .=  "\n          https://github.com/monajemi/clusterjob";
    return $version_script ;
}






sub rerun
{
    my ($pid,$counter,$mem,$runtime,$qsub_extra,$verbose) = @_;
   
   
    my $info;
    if( (!defined $pid) || ($pid eq "") ){
        #read last_instance.info;
        $info = &CJ::retrieve_package_info();
        $pid = $info->{'pid'};
        
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
    
    
    my $short_pid = substr($pid,0,8);
    if($info->{'clean'}){
        CJ::message("Can't rerun. Package $short_pid has been cleaned on $info->{'clean'}->{'date'}->{datestr}.");
        exit 0;
    }

    
    my $account     = $info->{'account'};
    my $remote_path = $info->{'remote_path'};
    my $runflag = $info->{'runflag'};
    my $program = $info->{'program'};
    my $job_id = $info->{'job_id'};
    my $bqs = $info->{'bqs'};

    #my $programName = &CJ::remove_extention($program);
    
    my @job_ids = split(',',$job_id);

	if(! @$counter){
	   $counter = [1..($#job_ids+1)];  
	}
    
    my $date = &CJ::date();
    my $master_script;
    if ($#job_ids eq 0) { # if there is only one job
        #run
        $master_script =  &CJ::make_master_script($master_script,$runflag,$program,$date,$pid,$bqs,$mem,$runtime,$remote_path,$qsub_extra);
    }else{
        #parrun
        if(@$counter){
            foreach my $count (@$counter){
                $master_script =  &CJ::make_master_script($master_script,$runflag,$program,$date,$pid,$bqs,$mem,$runtime,$remote_path,$qsub_extra,$count);
            }
        }else{
            # Package is parrun, run the whole again!
            foreach my $i (0..$#job_ids){
               $master_script =  &CJ::make_master_script($master_script,$runflag,$program,$date,$pid,$bqs,$mem,$runtime,$remote_path,$qsub_extra,$i);
            }
        }
    }


    

#===================================
# write out developed rerun master script
#===================================
my $local_master_path="/tmp/rerun_master.sh";
&CJ::writeFile($local_master_path, $master_script);

    
#==============================================
# Send master script over to the server, run it
#==============================================

&CJ::message("Sending rerun script over to $account");
my $cmd = "rsync -arvz  $local_master_path ${account}:$remote_path/";
&CJ::my_system($cmd,$verbose);
    
    
    &CJ::message("Submitting job(s)");
    $cmd = "ssh $account 'source ~/.bashrc;cd $remote_path; bash -l rerun_master.sh > $remote_path/rerun_qsub.info; sleep 2'";
    &CJ::my_system($cmd,$verbose);
    
    
    
    # bring the log file
    my $qsubfilepath="$remote_path/rerun_qsub.info";
    $cmd = "rsync -avz $account:$qsubfilepath  $install_dir/.info/";
    &CJ::my_system($cmd,$verbose);

    
    
    my $rerun_qsub_info_file = "$install_dir/.info/"."rerun_qsub.info";
    my $rerun_job_ids = &CJ::read_qsub($rerun_qsub_info_file); # array ref
    #my $rerun_job_id = join(',', @{$rerun_job_ids});

   

#=======================================
# write changes to the run_history file
#=======================================
  # - replace the old job_id's by the new one
    
    if($#job_ids eq 0){
           $job_id =~ s/$job_ids[0]/$rerun_job_ids->[0]/g;
        &CJ::message("job-id: $rerun_job_ids->[0]");

    }else{
        &CJ::message("job-id: $rerun_job_ids->[0]-$rerun_job_ids->[-1]");
        foreach my $i (0..$#{$counter}){
            my $this = $counter->[$i] - 1;
           $job_id =~ s/$job_ids[$this]/$rerun_job_ids->[$i]/g;
        }
    }

    
# - Keep track of the old id in the rerun section
 my @runinfo;
    if($#job_ids eq 0){
        $runinfo[0] = "($job_ids[0])";
    }else{
        foreach my $i (0..$#{$counter}){
        $runinfo[$i] = "$counter->[$i]"."($job_ids[$i])";
        }
    }
    
my $runinfo    = join(',', @runinfo);
my $this_rerun = "$date -> $runinfo";


my $type = "Rerun";
my $change = {new_job_id => $job_id,
              date       => $date, 
			  old_job_id => $runinfo};
&CJ::add_change_to_run_history($pid, $change, $type);

exit 0;
}




















# This is the CJ confirmation included in the
# reproducible package
sub build_cj_confirmation{
    my ($pid, $path) = @_;
    
    my $info = retrieve_package_info($pid);
    my $program = $info->{'program'};
    
    my $version_script = &CJ::version_info() ;
    
    $Data::Dumper::Sortkeys = 1;
    $Data::Dumper::Terse = 1;
    my $dumper_info = Dumper($info);
    

my $confirmation_script =<<CONFIRM;
$version_script
------------------------------------------------------------
This reproducible package is generated by Clusterjob (CJ).
To reproduce the results, please rerun
                "reproduce_$program"
    
job discription:
    
PID         = $info->{'pid'}
DATE        = $info->{'date'}->{'datestr'}
AUTHOR      = $info->{'user'}
PROGRAM     = $info->{'program'}
ACCOUNT     = $info->{'account'}
RUNFLAG     = $info->{'runflag'}
REMOTE_PATH = $info->{'remote_path'}
    
          $info->{message}

...
    
$dumper_info
    
    
------------------------------------------------------------
CONFIRM

CJ::writeFile("$path/CJ_CONFIRMATION.TXT", $confirmation_script);
my $cmd = "chmod +x $path/CJ_CONFIRMATION.TXT";
&CJ::my_system($cmd,0);




}

# ======
# Build master script
sub make_master_script{
    my($master_script,$runflag,$program,$date,$pid,$bqs,$mem, $runtime, $remote_sep_Dir,$qsub_extra,$counter) = @_;
    
    
    
if( (!defined($master_script)) ||  ($master_script eq "")){
my $docstring=<<DOCSTRING;
# EXPERIMENT $program
# COPYRIGHT 2014:
# Hatef Monajemi (monajemi AT stanford DOT edu)
# DATE : $date->{datestr}
DOCSTRING

my $HEADER = &CJ::bash_header($bqs);
$master_script=$HEADER;
$master_script.="$docstring";
}




    my $programName = &CJ::remove_extention($program);


    if(!($runflag =~ /^par.*/) ){
        
        
        $master_script .= "mkdir ${remote_sep_Dir}"."/logs" . "\n" ;
        $master_script .= "mkdir ${remote_sep_Dir}"."/scripts" . "\n" ;
    
        my $tagstr="CJ_$pid\_$programName";
        if($bqs eq "SGE"){
            
        $master_script.= "qsub -S /bin/bash -w e -l h_vmem=$mem -l h_rt=$runtime $qsub_extra -N $tagstr -o ${remote_sep_Dir}/logs/${tagstr}.stdout -e ${remote_sep_Dir}/logs/${tagstr}.stderr ${remote_sep_Dir}/bashMain.sh \n";
        }elsif($bqs eq "SLURM"){
            
            $master_script.="sbatch --mem=$mem --time=$runtime $qsub_extra -J $tagstr -o ${remote_sep_Dir}/logs/${tagstr}.stdout -e ${remote_sep_Dir}/logs/${tagstr}.stderr ${remote_sep_Dir}/bashMain.sh \n"
            
        }else{
            &CJ::err("unknown BQS")
        }

    
    
    }elsif(defined($counter)){
    
    
    
        # Add QSUB to MASTER SCRIPT
        $master_script .= "mkdir ${remote_sep_Dir}/$counter". "/logs"    . "\n" ;
        $master_script .= "mkdir ${remote_sep_Dir}/$counter". "/scripts" . "\n" ;
        
        
        my $tagstr="CJ_$pid\_$counter\_$programName";
        if($bqs eq "SGE"){
            $master_script.= "qsub -S /bin/bash -w e -l h_vmem=$mem  -l h_rt=$runtime $qsub_extra -N $tagstr -o ${remote_sep_Dir}/$counter/logs/${tagstr}.stdout -e ${remote_sep_Dir}/$counter/logs/${tagstr}.stderr ${remote_sep_Dir}/$counter/bashMain.sh \n";
        }elsif($bqs eq "SLURM"){
            
            $master_script.="sbatch --mem=$mem --time=$runtime $qsub_extra -J $tagstr -o ${remote_sep_Dir}/$counter/logs/${tagstr}.stdout -e ${remote_sep_Dir}/$counter/logs/${tagstr}.stderr ${remote_sep_Dir}/$counter/bashMain.sh \n"
            
        }else{
            &CJ::err("unknown BQS");
        }
        
        
    }else{
            &CJ::err("counter is not defined");
    }
    
    
    
}





#=================================================================
#            CLUSTERJOB SAVE (ONLY SAVES THE OUTPUT OF 'GET')
#  ex.  clusterjob save pid
#  ex.  clusterjob save pid ~/Downloads/myDIR
#=================================================================



sub save_results{
    
    my ($pid,$save_dir,$verbose) = @_;
    

    
    if(! &CJ::is_valid_pid($pid)){
        &CJ::err("Please enter a valid package name");
    }
    
    my $info  = &CJ::retrieve_package_info($pid);
    
    
    my $save_path;
    if( !defined($save_dir)){
        # Read the deafult save directory
        $save_path= $info->{'save_path'};
        &CJ::message("Saving results in ${save_path}");
    }else{
        $save_path = "$save_dir/$info->{pid}";
    }
    
    
    
    
    if(! -d "$get_tmp_dir/$info->{'pid'}"){
        &CJ::warning("You must run 'get' before 'save'!");
        exit 0 ;
    }
    
    
    if(-d "$save_path"){
        # Ask if it needs to be overwritten
        
        CJ::message("Directory $save_path already exists. What to do: [S]ync, [O]verwrite,[C]ancel?");
        my $input =  <STDIN>; chomp($input);
        if(lc($input) eq "o" or lc($input) eq "overwrite"){
            
            my $cmd = "rm -rf $save_path/*";
            &CJ::my_system($cmd,$verbose);
            
            $cmd = "rsync -arz  $get_tmp_dir/$info->{'pid'}/ $save_path/";
            &CJ::my_system($cmd,$verbose);
            
        }elsif(lc($input) eq "s" or lc($input) eq "sync"){
            
            my $cmd = "rsync -arz  $get_tmp_dir/$info->{'pid'}/ $save_path/";
            &CJ::my_system($cmd,$verbose);
        }else{
            &CJ::message("Nothing Saved!");
            exit 0;
        }
        
        
    }else{
        
        # Create directories
        my $cmd = "mkdir -p $save_path";
        &CJ::my_system($cmd,$verbose) ;
        
        $cmd = "rsync -arz  $get_tmp_dir/$info->{'pid'}/ $save_path";
        &CJ::my_system($cmd,$verbose);
        
        
    }
    
    
    my $date = &CJ::date();
    # Find the last number
    my $lastnum=`grep "." $history_file | tail -1  | awk \'{print \$1}\' `;
    my $hist_date = (split('\s', $date->{datestr}))[0];
    my $flag = "save";
    my $history = sprintf("%-15u%-15s%-21s%-10s",$lastnum+1, $hist_date,substr($pid,0,8), $flag);
    # ADD THIS SAVE TO HISTRY
    &CJ::add_to_history($history);

    exit 0;
}



sub show_cmd_history{
    my ($argin) = @_;

    if( (!defined $argin) || ($argin eq "") ){
        $argin= 50;
    }
    
        
    if($argin =~ m/^\-?\d*$/){
        
        $argin =~ s/\D//g;   #remove any non-digit
        my $info=`tail -n  $argin $cmd_history_file`;chomp($info);
        print "$info \n";
       
    }elsif($argin =~ m/^\-?all$/){
        my $info=`cat $cmd_history_file`;chomp($info);
        print "$info \n";
    }else{
        &CJ::err("Incorrect usage: nothing to show");
    }
    
    
    
    
    exit 0;


}



sub show_history{
    my ($history_argin) = @_;
    
    
    if( (!defined $history_argin) || ($history_argin eq "") ){
        $history_argin= "all";
    }
    
   if($history_argin =~ m/^\-?\d*$/){
        
        $history_argin =~ s/\D//g;   #remove any non-digit
        my $info=`tail -n  $history_argin $history_file`;chomp($info);
        print "$info \n";
        
    }elsif($history_argin =~ m/^\-?all$/){
        my $info=`cat $history_file`;chomp($info);
        print "$info \n";
    }else{
        &CJ::err("Incorrect usage: nothing to show");
    }
    
    exit 0;
    
}




sub show_log{
    my ($log_argin, $log_tag, $log_script) = @_;

    my $num_show = undef;
    
    if( (! defined $log_argin) || ($log_argin eq "") ) {
        $num_show = 10;
        $log_argin = "";
    }elsif( $log_argin =~ m/^\-?all$/ ){
        $num_show= `cat $history_file | wc -l`; chomp($num_show); $num_show=~s/^\s+|\s+$//;
    }elsif( $log_argin =~ m/^\-?\d*$/ ){
        $log_argin =~ s/\D//g;     #remove any non-digit
        $num_show = $log_argin;
    }elsif(&CJ::is_valid_pid($log_argin)){
        
        if(defined(&CJ::read_record($log_argin))){
            &CJ::print_detailed_log($log_argin);
           
        }else{
            &CJ::err("No such job found in CJ database");
        }
        
        exit 0;
        
    }else{
        &CJ::err("Incorrect usage: nothing to show");
    }
    
   
    
        my $pidList=`cat $history_file | awk \'{print \$3}\' `;
     
        
        my @pidList = $pidList =~ m/\b([0-9a-f]{8,40})\b/g;
        my @unique_pids = do { my %seen; grep { !$seen{$_}++ } @pidList};
        #say Dumper(@unique_pids);
        
        
        
        my  @to_show_idx;
        
        if(!defined($log_script)){
            #my $min = ($num_show-1, $#unique_pids)[$num_show-1 > $#unique_pids];
            #foreach my $i (0..$min){
            my $counter = 0;
            while( ($counter <= $#unique_pids) & ($#to_show_idx < $num_show-1 )  ){
                        my $info =  &CJ::retrieve_package_info($unique_pids[$#unique_pids-$counter]);

                        if( $log_tag eq "showclean" ){
                            push @to_show_idx, $counter;
                        }else{
                            # only alive
                            push @to_show_idx, $counter if( ! $info->{clean} );
                        }
                $counter = $counter +1;
            }
        }else{
            foreach my $i (0..$#unique_pids){
                my $info =  &CJ::retrieve_package_info($unique_pids[$#unique_pids-$i]);
                if( $log_tag eq "showclean" ){
                push @to_show_idx, $i if( $info->{program} =~ m/$log_script/);
                }else{
                push @to_show_idx, $i if( ($info->{program} =~ m/$log_script/) & (! $info->{clean}) );
                }
                    
            }
        }
            
        
    #say Dumper(@to_show_idx);
    
        
        foreach my $i (reverse @to_show_idx){
        
        my $info =  &CJ::retrieve_package_info($unique_pids[$#unique_pids-$i]);

        print "\n";
        print "\033[32mpid $info->{pid}\033[0m\n";
        print "date: $info->{date}->{datestr}\n";
        print "user: $info->{user}\n";
        #            print "local_host: $info->{local_host} ($info->{local_ip})\n";
        print "remote: $info->{account}\n";
        print "script: $info->{program}\n";
        #print "remote_path: $info->{remote_path}\n";
        print "initial_flag: $info->{runflag}\n";
        print "reruned: ",1+$#{$info->{rerun}} . " times \n" if($info->{rerun}) ;
        print "cleaned: $info->{clean}->{date}->{datestr}\n" if($info->{clean}) ;
        print "\n";
        print ' ' x 10; print "$info->{message}\n";
        print "\n";
        }
    
  
        
    
    
    
    
    
    exit 0;


}




sub  print_detailed_log{
    my ($pid) = @_;

my $record = read_record($pid);
my $info = decode_json $record;

$Data::Dumper::Sortkeys = 1;
$Data::Dumper::Terse = 1;
print "\n\033[32mpid $info->{pid}\033[0m\n";
print Dumper($info);
    
}
    
    
    
sub clean
{
    my ($pid, $verbose) = @_;
    
    
    
    
    
    my $account;
    my $local_path;
    my $remote_path;
    my $job_id;
    my $save_path;
    
    my $info;
    if((!defined $pid)  || ($pid eq "") ){
        #read the first lines of last_instance.info;
        $info =  &CJ::retrieve_package_info();
        $pid = $info->{'pid'};
    }else{
        
        if(&CJ::is_valid_pid($pid)){
            # read info from $run_history_file
            $info =  &CJ::retrieve_package_info($pid);
            if(!defined($info)){ &CJ::err("No such job found in CJ database.")};
            
        }else{
            &CJ::err("incorrect usage: nothing to show");
        }
        
        
    }
    
    
    
    $account     =   $info->{'account'};
    $local_path  =   $info->{'local_path'};
    $remote_path =   $info->{'remote_path'};
    $job_id      =   $info->{'job_id'};
    $save_path   =   $info->{'save_path'};
    
    
    my $short_pid = substr($pid,0,8);

    if(defined($info->{'clean'})){
        CJ::message("Nothing to clean. Package $short_pid has been cleaned on $info->{'clean'}->{'date'}->{'datestr'}.");
        exit 0;
    }
    
    
    
    
    
    # make sure s/he really want a deletion
    CJ::message("Are you sure you would like to clean $short_pid? Y/N");
    my $yesno =  <STDIN>; chomp($yesno);
    
    if(lc($yesno) eq "y" or lc($yesno) eq "yes"){
    
    CJ::message("Cleaning $short_pid");
    my $local_clean     = "$local_path\*";
    my $remote_clean    = "$remote_path\*";
    my $save_clean      = "$save_path\*";
    
    
    if (defined($job_id) && $job_id ne "") {
        CJ::message("Deleting jobs associated with package $short_pid");
        my @job_ids = split(',',$job_id);
        $job_id = join(' ',@job_ids);
        my $cmd = "rm -rf $local_clean; rm -rf $save_clean; ssh ${account} 'qdel $job_id; rm -rf $remote_clean' " ;
        &CJ::my_system($cmd,$verbose);
    }else {
        my $cmd = "rm -rf $local_clean;rm -rf $save_clean; ssh ${account} 'rm -rf $remote_clean' " ;
        &CJ::my_system($cmd,$verbose);
    }
    
    
    
    
    
    my $date = &CJ::date();
    # Find the last number
    my $lastnum=`grep "." $history_file | tail -1  | awk \'{print \$1}\' `;
    my $hist_date = (split('\s', $date->{datestr}))[0];
    my $flag = "clean";
    # ADD THIS CLEAN TO HISTRY
    my $history = sprintf("%-15u%-15s%-21s%-10s",$lastnum+1, $hist_date,substr($pid,0,8), $flag);
    &CJ::add_to_history($history);
        
        
#    my @time_array = ( $time =~ m/../g );
#    $time = join(":",@time_array);
#    # Add the change to run_history file
#my $text =<<TEXT;
#    DATE -> $hist_date
#    TIME -> $time
#TEXT
        my $change={date => $date};
&CJ::add_change_to_run_history($pid, $change, "clean");
        
}
    
    exit 0;

}







sub show
{
    my ($pid, $num, $show_tag) = @_;
    
    
    my $info;
    if( (!defined $pid) || ($pid eq "") ){
        #read last_instance.info;
        $info = &CJ::retrieve_package_info();
        $pid = $info->{'pid'};
        
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

    
    my $short_pid = substr($pid,0,8);
    if(defined($info->{'clean'}->{'date'})){
        CJ::message("Nothing to show. Package $short_pid has been cleaned on $info->{'clean'}->{'date'} at $info->{'clean'}->{'time'}.");
        exit 0;
    }
   
    my $account     = $info->{'account'};
    my $remote_path = $info->{'remote_path'};
    my $runflag     = $info->{'runflag'};
    
    
    my $script;
    if($show_tag eq "program" ){
    my $program     = $info->{'program'};
        if($num){
          $script = (`ssh ${account} 'cat $remote_path/$num/$program'`) ;chomp($script);
        }else{
          $script = (`ssh ${account} 'cat $remote_path/$program'`) ;chomp($script);
        }
    }elsif($show_tag eq "error" ){
         if($num){
           $script = (`ssh ${account} 'cat $remote_path/$num/logs/*stderr'`) ;chomp($script);
         }else{
           $script = (`ssh ${account} 'cat $remote_path/logs/*stderr'`) ;chomp($script);
         }
        
    }elsif($show_tag eq "ls" ){
        if($num){
            $script = (`ssh ${account} 'ls -C1 $remote_path/$num/'`) ;chomp($script);
        }else{
            $script = (`ssh ${account} 'ls -C1 $remote_path/'`) ;chomp($script);
        }
    }
        
    print "$script \n";
        
    exit 0;
    
}












sub show_info
{
    my ($pid) = @_;
   
    my $info;
    if( (!defined $pid) || ($pid eq "") ){
        #read last_instance.info;
        $info = &CJ::retrieve_package_info();
        $pid = $info->{'pid'};
        
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
    
    
    #print '-' x 35;print "\n";
    print "\n";
    print "\033[32mpid $info->{pid}\033[0m\n";
    print "date: $info->{date}->{datestr}\n";
    print "user: $info->{user}\n";
    print "local_host: $info->{local_host} ($info->{local_ip})\n";
    print "remote_account: $info->{account}\n";
    print "script: $info->{program}\n";
    print "remote_path: $info->{remote_path}\n";
    print "initial_flag: $info->{runflag}\n";
    print "reruned: ",1+$#{$info->{rerun}} . " times \n" if($info->{rerun}) ;
    print "cleaned: $info->{clean}->{date}->{datestr}\n" if($info->{clean}) ;
    print "\n";
    print ' ' x 10; print "$info->{message}\n";
    print "\n";
    
    #print '-' x 35;print "\n";
    
    
    exit 0;

}




















sub get_state
{
    my ($pid,$num) = @_;
    
    my $info;
    if( (!defined $pid) || ($pid eq "") ){
        #read last_instance.info;
        $info = &CJ::retrieve_package_info();
        $pid = $info->{'pid'};
        
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
    
    my $short_pid = substr($info->{pid},0,8);
    if($info->{'clean'}){
        CJ::message("Nothing to show. Package $short_pid has been cleaned on $info->{'clean'}->{'date'}->{datestr}.");
        exit 0;
    }

    
    
    
    my $account = $info->{'account'};
    my $job_id  = $info->{'job_id'};
    my $bqs     = $info->{'bqs'};
    my $runflag = $info->{'runflag'};
    
    
    
    
    if($runflag =~ m/^par*/){
        
        # par case
        my @job_ids = split(',',$job_id);
        my $jobs = join('|', @job_ids);
      
        
        my $REC_STATES;
        my $REC_IDS;
        if($bqs eq "SGE"){
            $REC_STATES = (`ssh ${account} 'qstat -u \\* | grep -E "$jobs" ' | awk \'{print \$5}\'`) ;chomp($REC_STATES);
            $REC_IDS = (`ssh ${account} 'qstat -u \\* | grep -E "$jobs" ' | awk \'{print \$1}\'`) ;chomp($REC_IDS);
            
        }elsif($bqs eq "SLURM"){
            $REC_STATES = (`ssh ${account} 'sacct -n --jobs=$job_id | grep -v "^[0-9]*\\." ' | awk \'{print \$6}\'`) ;chomp($REC_STATES);
            $REC_IDS =  (`ssh ${account} 'sacct -n --jobs=$job_id | grep -v "^[0-9]*\\." ' | awk \'{print \$1}\'`) ;chomp($REC_IDS);
            
            #$states = (`ssh ${account} 'sacct -n --format=state --jobs=$job_id'`) ;chomp($state);
            
        }else{
            &CJ::err("Unknown batch queueing system");
        }
        
        my @rec_states = split('\n',$REC_STATES);
        my @rec_ids = split('\n',$REC_IDS);

        
        my $states={};
        foreach my $i (0..$#rec_ids){
            my $key = $rec_ids[$i];
            my $val = $rec_states[$i];
            $states->{$key} = $val;
        }
            

        if((!defined $num) || ($num eq "")){
            print "\033[32mpid $info->{'pid'}\033[0m\n";
            print "remote_account: $account\n";
            foreach my $i (0..$#job_ids)
            {
                my $counter = $i+1;
                my $state;
                if($states->{$job_ids[$i]}){
                $state= $states->{$job_ids[$i]}; chomp($state);
                }else{
                $state = "Unknown";
                }
                #$state = s/^\s+|\s+$/;
                $state =~ s/[^A-Za-z]//g;
                print "$counter     " . "$job_ids[$i]      "  . "$state" . "\n";
            }
        }elsif(&CJ::isnumeric($num) && $num <= $#job_ids+1){
            print '-' x 50;print "\n";
            print "\033[32mpid $info->{'pid'}\033[0m\n";
            print "remote_account: $account\n";
            my $tmp = $num -1;
            my $val = $states->{$job_ids[$tmp]};
            if (! $val){
            $val = "unknwon";
            }
            print "$num     " . "$job_ids[$tmp]      "  . "$val" . "\n";
            
            
        }else{
            my $lim =1+$#job_ids;
            &CJ::err("incorrect entry. Input $num >= $lim.")
        }
        
        print '-' x 35;print "\n";
        
    }else{
        my $state;
        if($bqs eq "SGE"){
            $state = (`ssh ${account} 'qstat | grep $job_id' | awk \'{print \$5}\'`) ;chomp($state);
        }elsif($bqs eq "SLURM"){
            $state = (`ssh ${account} 'sacct | grep $job_id | grep -v "^[0-9]*\\." ' | awk \'{print \$6}\'`) ;chomp($state);
        }else{
            &CJ::err("Unknown batch queueing system");
        }
        
        if(!$state){
        $state = "Unknown";
        }
        
        print "\n";
        print "\033[32mpid $info->{'pid'}\033[0m\n";
        print "remote_account: $account\n";
        print "job_id: $job_id\n";
        print "state: $state\n";
        
    
    }
    
    
    
    exit 0;

    
    
    
    

}





sub grep_var_line
{
    my ($pattern, $string) = @_;
    
    # go to $TOP and look for the length of the found var;
    my $this_line;
    my @lines = split /\n/, $string;
    foreach my $line (@lines) {
        if($line =~ /^\s*(?<!\%)\s*${pattern}\s*=.*/){
            $this_line = $line;
            last;
        }
    }
    if($this_line){
        return $this_line;
    }else{
        &CJ::err(" Variable '$pattern' is not declared.\n");
    }
}







sub host{
    my ($machine_name) = @_;
    
    my $ssh_config = {};

    
    
    my $lines;
    open(my $FILE, $ssh_config_file) or  die "could not open $ssh_config_file: $!";
    local $/ = undef;
    $lines = <$FILE>;
    close ($FILE);
    
    my $this_host ;
    if($lines =~ /\[$machine_name\](.*?)\[$machine_name\]/isg)
    {
        $this_host = $1;
    }else{
        &CJ::err(".ssh_config:: Machine $machine_name not found. ")
    }
    my ($user) = $this_host =~ /User[\t\s]*(.*)/;$user =~ s/^\s+|\s+$//g;
    my ($host) = $this_host =~ /Host[\t\s]*(.*)/;$host =~ s/^\s+|\s+$//g;
    my ($bqs)  = $this_host =~ /Bqs[\t\s]*(.*)/ ;$bqs =~ s/^\s+|\s+$//g;
    my ($remote_repo)  = $this_host =~ /Repo[\t\s]*(.*)/ ;$remote_repo =~ s/^\s+|\s+$//g;
    my ($remote_matlabpath)  = $this_host =~ /MATlib[\t\s]*(.*)/;$remote_repo =~ s/^\s+|\s+$//g;
    my $account  = $user . "@" . $host;
    
    
    $ssh_config->{'account'}         = $account;
    $ssh_config->{'bqs'}             = $bqs;
    $ssh_config->{'remote_repo'}     = $remote_repo;
    $ssh_config->{'matlib'}          = $remote_matlabpath;
    
    return $ssh_config;
}





sub retrieve_package_info{
    
    my ($pid) = @_;
    
    if(!$pid){
        $pid    =   `sed -n '1{p;q;}' $last_instance_file`;chomp($pid);
    }
    
    
    my $this_record       = read_record($pid);
    
    my $info = undef;
    if(defined($this_record)){
        
        $info = decode_json $this_record;
    }

return $info;
}
















sub date{
my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
$year 	+= 1900;
my @month_abbr = qw( Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec );
my @day_abbr = qw( Sun Mon Tue Wed Thu Fri Sat );

my @t = localtime(time);
my $gmt_offset_in_seconds = timegm(@t) - timelocal(@t);
    my $abs_offset;
    my $sign="";
    if($gmt_offset_in_seconds<0){
        $abs_offset = $gmt_offset_in_seconds * (-1);
        $sign = "-";
    }else{
        $abs_offset = $gmt_offset_in_seconds ;
    }
    
my ($gmt_offset_hour, $remainder_in_second) = (int($abs_offset/3600), $abs_offset%3600);
(my $gmt_offset_min, $remainder_in_second) = (int($remainder_in_second/60), $remainder_in_second%60);

my $offset = sprintf("%s%02d:%02d:%02d", $sign,$gmt_offset_hour,$gmt_offset_min,$remainder_in_second);
my $datestr = sprintf ("%04d-%03s-%02d  %02d:%02d:%02d  \(GMT %s\)", $year, $month_abbr[$mon], $mday, $hour,$min, $sec, $offset);

my $date = {
        year    => $year,
        month   => $month_abbr[$mon],
        day     => $mday,
        hour    => $hour,
        min     => $min,
        sec     => $sec,
        gmt_offset => $offset,
        datestr  => $datestr
};
    
    
    return $date;
}

# Check the package name given is valid
sub is_valid_pid
{
my ($name) = @_;
    
if(!defined($name)){
$name = ""
}
# CJ uses a default abbreviation of SHA which has 8 first characters!
if( $name =~ m/\b[0-9a-f]{8,40}\b/){
return 1;
}else{
return 0;
}
}




# Bash header based on the Batch Queueing System (BQS)
sub bash_header{
    my ($bqs) = @_;

my $HEADER;
if($bqs eq "SGE"){
$HEADER=<<SGE_HEADER;
#!/bin/bash -l
#\$ -cwd
#\$ -S /bin/bash
SGE_HEADER
}elsif($bqs eq "SLURM"){
$HEADER=<<SLURM_HEADER;
#!/bin/bash -l
SLURM_HEADER
}else{
die "unknown BQS"
}
return $HEADER;
}

# Check Numeric
sub isnumeric
{
my ($s) = @_;
if($s =~ /^[0-9,.E]+$/){
return 1;
}else{
return 0;
}

}


sub err{
    my ($message) = @_;
    die(' ' x 5 . "CJerr::$message\n");
}

sub warning{
    my ($msg) = @_;
    print(' ' x 5 . "CJwarning::$msg\n");
}


sub message{
    my ($msg) = @_;
    print(' ' x 5 . "CJmessage::$msg\n");
}


sub my_system
{
   my($cmd,$verbose) = @_;
    if($verbose){
        print("system: ",$cmd,"\n");
        system("$cmd");
        
    }else{
        system("$cmd >> $CJlog  2>&1") ;#Error messages get sent to same place as standard output.
    }

}



sub touch
{
    &my_system("touch $_[0]");
}








sub writeFile
{
    
    # it should generate a bak up later!
    my ($path, $contents) = @_;
    open(FILE,">$path") or die "can't create file $path";
    print FILE $contents;
    close FILE;
}

sub readFile
{
    my ($filepath)  = @_;

    my $content;
    open(my $fh, '<', $filepath) or die "cannot open file $filepath";
    {
    local $/;
    $content = <$fh>;
    }
    close($fh);
    
    return $content;
}




sub add_to_history
{
    my ($text) = @_;
    # ADD THIS SAVE TO HISTRY
    open (my $FILE , '>>', $history_file) or die("could not open file '$history_file' $!");
    print $FILE "$text\n";
    close $FILE;
    
}



sub add_to_run_history
{
    my ($runinfo_json) = @_;
my $text=<<TEXT;
$runinfo_json
TEXT
    
# ADD THIS SAVE TO HISTRY
open (my $FILE , '>>', $run_history_file) or die("could not open file '$run_history_file' $!");
print $FILE "$text\n";
close $FILE;
}



sub add_change_to_run_history
{
    my ($pid, $change,$type) = @_;
    
    my $this_record = &CJ::read_record($pid);
    my $info = decode_json $this_record;
    

if(lc($type) eq "clean"){
    $info->{clean}->{date} = $change->{date};
    #say Dumper($info);
 
}elsif(lc($type) eq "rerun"){
    
       if($info->{'rerun'}){
           $info->{'job_id'} = $change->{new_job_id};
           my $change_record = "$change->{date}->{datestr} > $change->{old_job_id}";
           push $info->{'rerun'},$change_record;
           #say Dumper($info);
       }else{
           #firt time calling rerun
           $info->{'job_id'} = $change->{new_job_id};
           my $change_record = "$change->{date}->{datestr} > $change->{old_job_id}";
           $info->{'rerun'}  = [$change_record];
           #say Dumper($info);
       }
#
#        
}else{
       &CJ::err("Change of type '$type' is  not recognized");
}
    
    &CJ::update_record($pid,$info);
}




sub update_record{
    my ($pid,$new_info) = @_;
    #my $old_record = read_record($pid);
    my $new_record = encode_json($new_info);
    my $cmd="sed -i '' 's|.*$pid.*|$new_record|'  $run_history_file";
    &CJ::my_system($cmd,0);
}


sub read_record{
    my ($pid) = @_;
    my $record = `grep -A 1 $pid $run_history_file` ; chomp($record);
    return $record;
}




sub read_qsub{
    my ($qsub_file) = @_;

    open my $FILE, '<', $qsub_file or CJ::err("Job submission failed. Try --verbose for error explanation.");

my @job_ids;
while(<$FILE>){
    my $job_id_info = $_;chomp($job_id_info);
    my ($this_job_id) = $job_id_info =~/(\d+)/; # get the first string of integer, i.e., job_id
    push @job_ids, $this_job_id;
}
close $FILE;

return \@job_ids;
}


sub remove_extention
{
    my ($program) = @_;
    
    my @program_name    = split /\./,$program;
    my $lastone = pop @program_name;
    my $program_name   =   join "\_",@program_name;  # NOTE: Dots in the name are replace by \_

    return $program_name;
    
}


sub reexecute_cmd{
    my ($cmd_num,$verbose) = @_;
    if (!$cmd_num){
        $cmd_num = `wc -l < $cmd_history_file `; chomp($cmd_num); $cmd_num =~ s/^\s+|\s+$//g;
    }
    
    my $cmd= &CJ::get_cmd($cmd_num, 0);
    #print "$cmd\n";
    system("$cmd");
}



sub get_cmd{
    my ($cmd_num, $is_interactive) = @_;

    my $cmd;
    if($is_interactive){
    $cmd=`grep '^\\b$cmd_num\\b' $cmd_history_file | awk \'{\$1=\"\";\$2=\"\";\$3=\"\"; print \$0}\' `;
    }else{
    $cmd=`grep '^\\b$cmd_num\\b' $cmd_history_file | awk \'{\$1=\"\"; print \$0}\' `;
    }
    $cmd =~ s/^\s+|\s+$//g;
    return $cmd;
}


sub add_cmd{
    my ($cmdline) = @_;
    
    my $lastnum=`grep "." $cmd_history_file | tail -1  | awk \'{print \$1}\' `;
    if(! $lastnum){
        $lastnum = 0;
    }

    
    
    
    my $cmd_history = sprintf("%-15u%s",$lastnum+1, $cmdline );chomp($cmd_history);
    
    open (my $FILE , '>>', $cmd_history_file) or die("could not open file '$cmd_history_file' $!");
    print $FILE "$cmd_history\n";
    close $FILE;
    
    
    
    my $records_to_keep = 5000;
    my $cmd = "tail -n $records_to_keep $cmd_history_file > /tmp/cmd_history_file.tmp; cat /tmp/cmd_history_file.tmp > $cmd_history_file; rm /tmp/cmd_history_file.tmp";
    system($cmd);
    
}



1;
