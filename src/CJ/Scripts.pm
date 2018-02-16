package CJ::Scripts;
# This is part of Clusterjob that handles generation of shell scripts
# Copyright 2015 Hatef Monajemi (monajemi@stanford.edu)

use strict;
use warnings;
use CJ;
use Data::Dumper;
use CJ::CJVars;
use CJ::Matlab;
use CJ::Python;
use feature 'state';
use feature 'say';


sub build_rrun_bashMain_script{
my ($extra) = @_;
    
my $date = $extra->{date};
my $remote_sep_Dir = $extra->{remote_sep_Dir};
my $bqs = $extra->{bqs};

my $docstring=<<DOCSTRING;
# SLURM ARRAY HANDLER
# COPYRIGHT  2014 CLUSTERJOB (CJ)
# CONTACT:   Hatef Monajemi (monajemi AT stanford DOT edu)
# DATE   :   $date->{datestr}
DOCSTRING
    
my $HEADER = &CJ::bash_header($bqs);
my $array_bashMain_script=$HEADER;
$array_bashMain_script.="$docstring";
    
    
if($bqs eq "SLURM"){
        
    #$array_bashMain_script.="mkdir ${remote_sep_Dir}/\$SLURM_ARRAY_TASK_ID/logs\n";
    #$array_bashMain_script.="mkdir ${remote_sep_Dir}/\$SLURM_ARRAY_TASK_ID/scripts\n";
$array_bashMain_script.="bash  ${remote_sep_Dir}/\$SLURM_ARRAY_TASK_ID/bashMain.sh\n";
    
}else{
        &CJ::err("Unknown BQS for RRUN/RDEPLOY");
}
    
return $array_bashMain_script;
    
}



sub build_rrun_master_script
{
    my ($nloop, $idx_tags,$ranges,$extra) = @_;
    
    
    # Run this to create the directories, etc.
    my $loop_script = build_nloop_master_script($nloop, $idx_tags,$ranges,$extra);
    
    
    
    
    my $TOP = $extra->{TOP};
    my $FOR = $extra->{FOR};
    my $BOT = $extra->{BOT};
    my $local_sep_Dir = $extra->{local_sep_Dir};
    my $remote_sep_Dir=$extra->{remote_sep_Dir};
    my $runflag = $extra->{runflag};
    my $program = $extra->{program};
    my $date = $extra->{date} ;
    my $pid =$extra->{pid} ;
    my $bqs = $extra->{bqs};
    my $submit_defaults=$extra->{submit_defaults};
    my $qSubmitDefault = $extra->{qSubmitDefault};
    my $qsub_extra = $extra->{qsub_extra};
    my $ssh = $extra->{ssh};
    my $total_jobs = $extra->{totalJobs};
    my $master_script;
     $master_script = &CJ::Scripts::make_master_script($master_script,$runflag,$program,$date,$pid,$ssh,$submit_defaults,$qSubmitDefault,$remote_sep_Dir,$qsub_extra,$total_jobs);
    return  $master_script;
}



sub build_nloop_master_script
{
	my ($nloop, $idx_tags,$ranges,$extra) = @_;
		
	my $master_script;
	my $itr = 0; 			 #$ranges->[$itr]);  0<=itr<=nloops-1
	$master_script = nForLoop(\&build_nloop_code,$extra,$nloop,$itr,$idx_tags,$ranges);
	return $master_script;
}

sub nForLoop
	{	
		my ($code,$extra,$n,$u,$idx_tags,$ranges,@rest) = @_;
		
		state $master_script;
		state $counter=0;
		
		if(not $n){
			($counter,$master_script) = $code->($master_script,$counter,$extra,@rest);  # return master_script
			return;
		}
		
		my $total_loops = scalar @{$idx_tags};	
		my @idx_set = split(',', $ranges->{$idx_tags->[$u]});	
		foreach my $i (0..$#idx_set ){
					my @new = ($idx_tags->[$u],$idx_set[$i]);
					&nForLoop($code,$extra,$n-1,$u+1,$idx_tags,$ranges,@rest,@new);	
		}
		
        return $master_script;	
}




sub build_nloop_code
{		   
	my ($master_script,$counter,$extra,@rest) = @_;
		
	   $counter++;
	   # print "$counter\n";
	   my $TOP            = $extra->{TOP};
	   my $FOR            = $extra->{FOR};
	   my $BOT            = $extra->{BOT};
	   my $local_sep_Dir  = $extra->{local_sep_Dir};
	   my $remote_sep_Dir = $extra->{remote_sep_Dir};
	   my $runflag        = $extra->{runflag};
       my $path           = $extra->{path};
	   my $program        = $extra->{program};
	   my $date           = $extra->{date} ;
	   my $pid            = $extra->{pid} ;
	   my $bqs            = $extra->{bqs};
	   my $submit_defaults=$extra->{submit_defaults};
       my $qSubmitDefault = $extra->{qSubmitDefault};
       my $qsub_extra     = $extra->{qsub_extra};
	   my $ssh = $extra->{ssh};

    
       my $codeobj = &CJ::CodeObj($path,$program);
    
       #============================================
       #     BUILD EXP FOR this (v0,v1,...)
       #============================================
       my $new_script = $codeobj->buildParallelizedScript($TOP,$FOR,$BOT,@rest);
       #============================================
       #   COPY ALL NECESSARY FILES INTO THE
       #   EXPERIMENTS FOLDER
       #============================================
       
       mkdir "$local_sep_Dir/$counter";
       my $this_path  = "$local_sep_Dir/$counter/$program";
       &CJ::writeFile($this_path,$new_script);
       # build reproducible script for each run
  	   CJ::message("Creating reproducible script(s) reproduce_$program") if ($counter==1);
       &CJ::CodeObj("$local_sep_Dir/$counter",$program)->build_reproducible_script($runflag);
	
       
       
       # build bashMain.sh for each parallel package
       my $remote_par_sep_dir = "$remote_sep_Dir/$counter";
       my $sh_script = &CJ::Scripts::make_par_shell_script($ssh,$program,$pid,$bqs,$counter,$remote_par_sep_dir);
       my $local_sh_path = "$local_sep_Dir/$counter/bashMain.sh";
       &CJ::writeFile($local_sh_path, $sh_script);
    
       # build logs and scripts directories
       # this is essentail for rrun!
       my $cmd = "mkdir  $local_sep_Dir/$counter/logs; mkdir  $local_sep_Dir/$counter/scripts";
       &CJ::my_system($cmd,0);
    
       $master_script = &CJ::Scripts::make_master_script($master_script,$runflag,$program,$date,$pid,$ssh,$submit_defaults,$qSubmitDefault,$remote_sep_Dir,$qsub_extra,$counter);
	   return ($counter,$master_script);
}










##########################
sub build_conda_venv_bash{
##########################
    my ($ssh) = @_;

# Determine easy_install version
my $python_version_tag = "";
&CJ::err("python module not defined in ssh_config file.") if not defined $ssh->{'py'};

if( $ssh->{'py'} =~ /python\D?(((\d).\d).\d)/i ) {
$python_version_tag = $3;
}elsif( $ssh->{'py'} =~ /python\D?((\d).\d)/i ){
$python_version_tag = $2;
}else{
CJ::err("Cannot decipher pythonX.Y.Z version");
}

my $user_required_pyLib = join (" ", split(":",$ssh->{'pylib'}) );

    
# we check to see if the file has been changed.
my $ssh_config_check;
if( -f $ssh_config_md5 ){
    $ssh_config_check = &CJ::ssh_config_md5('check')
}else{
    $ssh_config_check = 1;
}

&CJ::ssh_config_md5('update') if ($ssh_config_check);
    
# Conda should be aviable.
# from commit
# 8ced93afebb9aaee12689d3aff473c9f02bb9d78
# we are moving to anaconda virtual env for python
my $venv = "CJ_python_venv";

my $env =<<'BASH';

# if venv does not exists and ssh_config has changed since last time
# create a new venv
if [ -z "$(conda info --envs | grep  <CONDA_VENV>)" ] ;then
    echo " Creating <CONDA_VENV> ..."
    echo " conda create --yes -n  <CONDA_VENV> python=<version_tag> numpy <libs>"
    conda create --yes -n  <CONDA_VENV> python=<version_tag> numpy <libs>
      
elif [ <ssh_config_check> -eq 1 ]; then
   
    echo " Updating <CONDA_VENV> ..."
    echo "conda env remove --yes -n <CONDA_VENV>"
    conda env remove --yes -n <CONDA_VENV>
    echo " conda create --yes -n  <CONDA_VENV> python=<version_tag> numpy <libs>"
    conda create --yes -n  <CONDA_VENV> python=<version_tag> numpy <libs>

else
    #  For python, if conda venv already exists, just use it!
    echo "Using available <CONDA_VENV>"
fi

BASH


$env =~ s|<version_tag>|$python_version_tag|g;
$env =~ s|<libs>|$user_required_pyLib|g;
$env =~ s|<CONDA_VENV>|$venv|g;
$env =~ s|<ssh_config_check>|$ssh_config_check|g;
    
return $env;
    
}









#######################
# Build master script
sub make_master_script{
#######################
my($master_script,$runflag,$program,$date,$pid,$ssh,$submit_defaults,$qSubmitDefault,$remote_sep_Dir,$qsub_extra,$counter) = @_;
    
    my $mem = $submit_defaults->{mem};
    my $runtime = $submit_defaults->{runtime};
    my $bqs = $ssh->{'bqs'};
    #my $numberTasks = $submit_defaults->{numberTasks};
    
    
    
# one time only
if( (!defined($master_script)) ||  ($master_script eq "")){
my $docstring=<<DOCSTRING;
# EXPERIMENT $program
# COPYRIGHT  2014 CLUSTERJOB (CJ)
# CONTACT:   Hatef Monajemi (monajemi AT stanford DOT edu)
# DATE   :   $date->{datestr}
DOCSTRING

my $HEADER = &CJ::bash_header($bqs);
$master_script=$HEADER;
$master_script.="$docstring";

}


#my $pid_head = substr($pid,0,8);  #short_pid

    my ($programName,$ext) = &CJ::remove_extension($program);


    if ($runflag  =~ /\brrun\b|\brdeploy\b/){
    
        my $tagstr="CJ_$pid\_\%a\_$programName";
        if($bqs eq "SLURM"){
            
            my $totalArrayJobs = $counter;    # in RRUN CASE, $counter is the last job's counter.
            
            if($qSubmitDefault){
                $master_script.="sbatch --array=1-$totalArrayJobs  --mem=$mem --time=$runtime $qsub_extra -J $tagstr -o ${remote_sep_Dir}/\%a/logs/${tagstr}.stdout -e ${remote_sep_Dir}/\%a/logs/${tagstr}.stderr ${remote_sep_Dir}/array_bashMain.sh \n"
            }else{
                $master_script.="sbatch --array=1-$totalArrayJobs $qsub_extra -J $tagstr -o ${remote_sep_Dir}/\%a/logs/${tagstr}.stdout -e ${remote_sep_Dir}/\%a/logs/${tagstr}.stderr ${remote_sep_Dir}/array_bashMain.sh \n"
            }
        }else{
            &CJ::err("Unknown BQS for RRUN/RDEPLOY");
        }
        
        
    }elsif(!($runflag =~ /^par.*/) ){
        
        
         $master_script .= "mkdir ${remote_sep_Dir}"."/logs" . "\n" ;
         $master_script .= "mkdir ${remote_sep_Dir}"."/scripts" . "\n" ;
    
        my $tagstr="CJ_$pid\_$programName";
        if($bqs eq "SGE"){
            if($qSubmitDefault){
                $master_script.= "qsub -S /bin/bash -w e -l h_vmem=$mem -l h_rt=$runtime $qsub_extra -N $tagstr -o ${remote_sep_Dir}/logs/${tagstr}.stdout -e ${remote_sep_Dir}/logs/${tagstr}.stderr ${remote_sep_Dir}/bashMain.sh \n";
            }else{
                $master_script.= "qsub -S /bin/bash -w e -l $qsub_extra -N $tagstr -o ${remote_sep_Dir}/logs/${tagstr}.stdout -e ${remote_sep_Dir}/logs/${tagstr}.stderr ${remote_sep_Dir}/bashMain.sh \n";
                
            }
            
            
        }elsif($bqs eq "SLURM"){
            
            if($qSubmitDefault){
                $master_script.="sbatch --mem=$mem --time=$runtime $qsub_extra -J $tagstr -o ${remote_sep_Dir}/logs/${tagstr}.stdout -e ${remote_sep_Dir}/logs/${tagstr}.stderr ${remote_sep_Dir}/bashMain.sh \n";
            }else{
                $master_script.="sbatch $qsub_extra -J $tagstr -o ${remote_sep_Dir}/logs/${tagstr}.stdout -e ${remote_sep_Dir}/logs/${tagstr}.stderr ${remote_sep_Dir}/bashMain.sh \n";
            }
        }else{
            &CJ::err("unknown BQS")
        }

    
    
    }elsif(defined($counter)){
    
    
        # Add QSUB to MASTER SCRIPT
        #$master_script .= "mkdir ${remote_sep_Dir}/$counter". "/logs"    . "\n" ;
        #$master_script .= "mkdir ${remote_sep_Dir}/$counter". "/scripts" . "\n" ;
        
        
        my $tagstr="CJ_$pid\_$counter\_$programName";
        if($bqs eq "SGE"){
            
            if($qSubmitDefault){
            $master_script.= "qsub -S /bin/bash -w e -l h_vmem=$mem  -l h_rt=$runtime $qsub_extra -N $tagstr -o ${remote_sep_Dir}/$counter/logs/${tagstr}.stdout -e ${remote_sep_Dir}/$counter/logs/${tagstr}.stderr ${remote_sep_Dir}/$counter/bashMain.sh \n";
            }else{
            $master_script.= "qsub -S /bin/bash -w e -l $qsub_extra -N $tagstr -o ${remote_sep_Dir}/$counter/logs/${tagstr}.stdout -e ${remote_sep_Dir}/$counter/logs/${tagstr}.stderr ${remote_sep_Dir}/$counter/bashMain.sh \n";
                
            }
        
        
        
        }elsif($bqs eq "SLURM"){

            if($qSubmitDefault){
             $master_script.="sbatch --mem=$mem --time=$runtime $qsub_extra -J $tagstr -o ${remote_sep_Dir}/$counter/logs/${tagstr}.stdout -e ${remote_sep_Dir}/$counter/logs/${tagstr}.stderr ${remote_sep_Dir}/$counter/bashMain.sh \n"
            }else{
             $master_script.="sbatch $qsub_extra -J $tagstr -o ${remote_sep_Dir}/$counter/logs/${tagstr}.stdout -e ${remote_sep_Dir}/$counter/logs/${tagstr}.stderr ${remote_sep_Dir}/$counter/bashMain.sh \n"
            }
        }else{
            &CJ::err("unknown BQS");
        }
        
        
    }else{
            &CJ::err("counter is not defined");
    }
    
    
    return $master_script;
}



######################
sub make_shell_script{
######################

    my ($ssh,$program,$pid,$bqs,$remote_path) = @_;

    my $sh_script  = &CJ::shell_head($bqs);
    $sh_script    .= &CJ::shell_neck($program,$pid, $remote_path);             # setting PID, and SHELLSCRIPT, LOGFILE PATH
    $sh_script    .= &CJ::Scripts::make_CJrun_bash_script($ssh,$program,$bqs); # Program specific Mat, Py, R,
    $sh_script    .= &CJ::shell_toe($bqs);

return $sh_script;
}



############################
sub make_CJrun_bash_script{
############################
my ($ssh,$program,$bqs) = @_;

my $codeobj = &CJ::CodeObj(undef,$program);  # This doesnt need a path at this stage;
    
my  $CJrun_bash_script   = 'cat <<THERE > $SHELLSCRIPT' . "\n";
    $CJrun_bash_script  .= &CJ::bash_header($bqs);
    $CJrun_bash_script  .= $codeobj->CJrun_body_script($ssh);
    $CJrun_bash_script  .= 'THERE' . "\n";
    $CJrun_bash_script  .= 'chmod a+x $SHELLSCRIPT' . "\n";
    $CJrun_bash_script  .= 'bash $SHELLSCRIPT > $LOGFILE' . "\n";
    
return $CJrun_bash_script;
    
}




###############################
sub make_CJrun_par_bash_script{
###############################
    
    my ($ssh,$program,$bqs) = @_;
    
    my $codeobj = CJ::CodeObj(undef,$program);  # This doesnt need a path at this stage;
    
    my  $CJrun_bash_script   = 'cat <<THERE > $SHELLSCRIPT' . "\n";
    $CJrun_bash_script      .= &CJ::bash_header($bqs);
    $CJrun_bash_script      .= $codeobj->CJrun_par_body_script($ssh);
    $CJrun_bash_script      .= 'THERE' . "\n";
    $CJrun_bash_script      .= 'chmod a+x $SHELLSCRIPT' . "\n";
    $CJrun_bash_script      .= 'bash $SHELLSCRIPT > $LOGFILE' . "\n";

        return $CJrun_bash_script;
}





###############################
# parallel shell script
# BUILD A PARALLEL BASH WRAPPER
sub make_par_shell_script{
###############################

my ($ssh,$program,$pid,$bqs,$counter,$remote_path) = @_;

   my $codeobj       = &CJ::CodeObj(undef,$program);  # This doesnt need a path at this stage;
   
    my $sh_script    = &CJ::shell_head($bqs);
       $sh_script   .= &CJ::par_shell_neck($program,$pid,$counter,$remote_path);  # setting PID, and SHELLSCRIPT, LOGFILE PATH
       $sh_script   .= &CJ::Scripts::make_CJrun_par_bash_script($ssh,$program,$bqs); # Program specific Mat, Py, R,
       $sh_script   .= &CJ::shell_toe($bqs);

    
return $sh_script;
}	    
		
1;		
