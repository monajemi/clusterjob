package CJ::Scripts;
# This is part of Clusterjob that handles generation of shell scripts
# Copyright 2015 Hatef Monajemi (monajemi@stanford.edu)

use strict;
use warnings;
use CJ;
use Data::Dumper;
use CJ::CJVars;
use CJ::Matlab;
use feature 'state';
#====================================
#       BUILD A BASH WRAPPER
#====================================


sub build_reproducible_script{
	my ($programType, $program, $path, $runflag) = @_;
	if ($programType eq "matlab"){
		my $matlab = CJ::Matlab->new($path,$program);
		$matlab->build_reproducible_script($runflag); 
	}elsif($programType eq "r"){
		#TODO: implement this:
		#CJ::R::build_reproducible_script($program, $local_sep_Dir, $runflag) if ($programType eq "r");
		CJ::err('not implemented yet');	
	}else{
		CJ::err("Program type .$programType not recognized." );
	}
	
}


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
        
$array_bashMain_script.="mkdir ${remote_sep_Dir}/\$SLURM_ARRAY_TASK_ID/logs\n";
$array_bashMain_script.="mkdir ${remote_sep_Dir}/\$SLURM_ARRAY_TASK_ID/scripts\n";
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
     $master_script = &CJ::Scripts::make_master_script($master_script,$runflag,$program,$date,$pid,$bqs,$submit_defaults,$qSubmitDefault,$remote_sep_Dir,$qsub_extra,$total_jobs);
    return  $master_script;
}



sub build_nloop_master_script
{
	my ($nloop, $idx_tags,$ranges,$extra) = @_;
		
	my $master_script;
	my $itr = 0; 			 #$ranges->[$itr]);  0<=itr<=nloops-1
	$master_script = nForLoop(\&build_nloop_matlab_code,$extra,$nloop,$itr,$idx_tags,$ranges);
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

sub build_nloop_matlab_code
{		   
	my ($master_script,$counter,$extra,@rest) = @_;
		
	   $counter++;
	   # print "$counter\n";
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

       
       #============================================
       #     BUILD EXP FOR this (v0,v1,...)
       #============================================
	   my @str;
	   while(@rest){
		   my $tag = shift @rest;
		   my $idx = shift @rest;
		   push @str , "$tag~=$idx";
	   } 
       
	   my $str = join('||',@str);
	   
	   
       my $INPUT;
       $INPUT .= "if ($str); continue;end";
       my $new_script = "$TOP \n $FOR \n $INPUT \n $BOT";
       undef $INPUT;                   #undef INPUT for the next run
      
       #============================================
       #   COPY ALL NECESSARY FILES INTO THE
       #   EXPERIMENTS FOLDER
       #============================================
       
       mkdir "$local_sep_Dir/$counter";
       my $this_path  = "$local_sep_Dir/$counter/$program";
       &CJ::writeFile($this_path,$new_script);
       # build reproducible script for each run
  	   CJ::message("Creating reproducible script(s) reproduce_$program") if ($counter==1);
	   CJ::Scripts::build_reproducible_script("matlab", $program,  "$local_sep_Dir/$counter", $runflag);
	
       
       
       # build bashMain.sh for each parallel package
       my $remote_par_sep_dir = "$remote_sep_Dir/$counter";
       my $sh_script = &CJ::Scripts::make_par_shell_script($ssh,$program,$pid,$bqs,$counter, $remote_par_sep_dir);
       my $local_sh_path = "$local_sep_Dir/$counter/bashMain.sh";
       &CJ::writeFile($local_sh_path, $sh_script);
    
       # build logs and scripts directories
        #my $cmd = "mkdir  $local_sep_Dir/$counter/logs; mkdir  $local_sep_Dir/$counter/scripts";
        #&CJ::my_system($cmd,0);
    
       $master_script = &CJ::Scripts::make_master_script($master_script,$runflag,$program,$date,$pid,$bqs,$submit_defaults,$qSubmitDefault,$remote_sep_Dir,$qsub_extra,$counter);
	   return ($counter,$master_script);
}





# ======
# Build master script
sub make_master_script{
    my($master_script,$runflag,$program,$date,$pid,$bqs,$submit_defaults,$qSubmitDefault,$remote_sep_Dir,$qsub_extra,$counter) = @_;
    
    my $mem = $submit_defaults->{mem};
    my $runtime = $submit_defaults->{runtime};
    #my $numberTasks = $submit_defaults->{numberTasks};
    
    
    
    
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
    
    
        ### FIXME: THIS CAN BE DELETED IF WE BUILD THESE TWO FILDERS LOCALLY
        # Add QSUB to MASTER SCRIPT
        $master_script .= "mkdir ${remote_sep_Dir}/$counter". "/logs"    . "\n" ;
        $master_script .= "mkdir ${remote_sep_Dir}/$counter". "/scripts" . "\n" ;
        
        
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




sub make_shell_script
    {
        my ($ssh,$program,$pid,$bqs) = @_;

my $sh_script;

if($bqs eq "SGE"){
$sh_script=<<'HEAD'
#!/bin/bash
#\$ -cwd
#\$ -S /bin/bash
    

echo JOB_ID $JOB_ID
echo WORKDIR $SGE_O_WORKDIR
DIR=`pwd`
HEAD
    
}elsif($bqs eq "SLURM"){
$sh_script=<<'HEAD'
#!/bin/bash -l
echo JOB_ID $SLURM_JOBID
echo WORKDIR $SLURM_SUBMIT_DIR
DIR=`pwd`
HEAD
}else{
&CJ::err("unknown BQS");
}
 
$sh_script.= <<'MID';
PROGRAM="<PROGRAM>";
PID=<PID>;
cd $DIR;
mkdir scripts
mkdir logs
SHELLSCRIPT=${DIR}/scripts/CJrun.${PID}.sh;
LOGFILE=${DIR}/logs/CJrun.${PID}.log;
MID

if($bqs eq "SGE"){
$sh_script.= <<'BASH';
cat <<THERE > $SHELLSCRIPT
#! /bin/bash
#$ -cwd
#$ -R y
#$ -S /bin/bash

echo starting job $SHELLSCRIPT
echo JOB_ID \$JOB_ID
echo WORKDIR \$SGE_O_WORKDIR
date
cd $DIR

module load <MATLAB_MODULE>
unset _JAVA_OPTIONS
matlab -nosplash -nodisplay <<HERE
<MATPATH>

% make sure each run has different random number stream
myversion = version;
mydate = date;
RandStream.setGlobalStream(RandStream('mt19937ar','seed', sum(100*clock)));
globalStream = RandStream.getGlobalStream;
CJsavedState = globalStream.State;
fname = sprintf('CJrandState.mat');
save(fname,'myversion','mydate', 'CJsavedState');
cd $DIR
run('${PROGRAM}');
quit;
HERE

echo ending job \$SHELLSCRIPT
echo JOB_ID \$JOB_ID
date
echo "done"
THERE
    
chmod a+x $SHELLSCRIPT
bash $SHELLSCRIPT > $LOGFILE
    
BASH
}elsif($bqs eq "SLURM"){
$sh_script.= <<'BASH';
cat <<THERE > $SHELLSCRIPT
#! /bin/bash -l

echo starting job \$SHELLSCRIPT
echo JOB_ID \$SLURM_JOBID
echo WORKDIR \$SLURM_SUBMIT_DIR
date
cd $DIR

module load <MATLAB_MODULE>
unset _JAVA_OPTIONS
matlab -nosplash -nodisplay <<HERE
<MATPATH>
% make sure each run has different random number stream
myversion = version;
mydate = date;
RandStream.setGlobalStream(RandStream('mt19937ar','seed', sum(100*clock)));
globalStream = RandStream.getGlobalStream;
CJsavedState = globalStream.State;
fname = sprintf('CJrandState.mat');
save(fname, 'myversion' ,'mydate', 'CJsavedState');
cd $DIR
run('${PROGRAM}');
quit;
HERE
    
echo ending job \$SHELLSCRIPT
echo JOB_ID \$SLURM_JOBID
date
echo "done"
THERE
    
chmod a+x $SHELLSCRIPT
bash $SHELLSCRIPT > $LOGFILE
    
BASH
}

        
        
my $pathText.=<<MATLAB;
        
% add user defined path
addpath $ssh->{matlib} -begin

% generate recursive path
addpath(genpath('.'));
    
try
    cvx_setup;
    cvx_quiet(true)
    % Find and add Sedumi Path for machines that have CVX installed
        cvx_path = which('cvx_setup.m');
    oldpath = textscan( cvx_path, '%s', 'Delimiter', '/');
    newpath = horzcat(oldpath{:});
    sedumi_path = [sprintf('%s/', newpath{1:end-1}) 'sedumi'];
    addpath(sedumi_path)
    
catch
    warning('CVX not enabled. Please set CVX path in .ssh_config if you need CVX for your jobs');
end

MATLAB

        
        
        
        
        
        
$sh_script =~ s|<PROGRAM>|$program|;
$sh_script =~ s|<PID>|$pid|;
$sh_script =~ s|<MATPATH>|$pathText|;
$sh_script =~ s|<MATLAB_MODULE>|$ssh->{mat}|;
    
return $sh_script;
}
       
	   
	   

# parallel shell script
#====================================
#       BUILD A PARALLEL BASH WRAPPER
#====================================

sub make_par_shell_script
{
my ($ssh,$program,$pid,$bqs,$counter,$remote_path) = @_;

my $sh_script;
if($bqs eq "SGE"){
    
$sh_script=<<'HEAD'
#!/bin/bash -l
#\$ -cwd
#\$ -S /bin/bash

echo JOB_ID $JOB_ID
echo WORKDIR $SGE_O_WORKDIR
DIR=<remote_path>
HEAD

}elsif($bqs eq "SLURM"){
$sh_script=<<'HEAD'
#!/bin/bash -l
echo JOB_ID $SLURM_JOBID
echo WORKDIR $SLURM_SUBMIT_DIR
DIR=<remote_path>
HEAD
}else{
&CJ::err("unknown BQS");
}
    

$sh_script.= <<'MID';
PROGRAM="<PROGRAM>";
PID=<PID>;
COUNTER=<COUNTER>;
cd $DIR;
mkdir scripts
mkdir logs
SHELLSCRIPT=${DIR}/scripts/CJrun.${PID}.${COUNTER}.sh;
LOGFILE=${DIR}/logs/CJrun.${PID}.${COUNTER}.log;
MID

if($bqs eq "SGE"){
$sh_script.= <<'BASH';
cat <<THERE > $SHELLSCRIPT
#! /bin/bash -l
#$ -cwd
#$ -R y
#$ -S /bin/bash

echo starting job $SHELLSCRIPT
echo JOB_ID \$JOB_ID
echo WORKDIR \$SGE_O_WORKDIR
date
cd $DIR

module load <MATLAB_MODULE>
unset _JAVA_OPTIONS
matlab -nosplash -nodisplay <<HERE
<MATPATH>

    
% add path for parrun
oldpath = textscan('$DIR', '%s', 'Delimiter', '/');
newpath = horzcat(oldpath{:});
bin_path = sprintf('%s/', newpath{1:end-1});
addpath(genpath(bin_path));  % recursive path
    
    
% make sure each run has different random number stream
myversion = version;
mydate = date;
    
% To get different Randstate for different jobs
rng(${COUNTER})
seed = sum(100*clock) + randi(10^6);
RandStream.setGlobalStream(RandStream('mt19937ar','seed', seed));
globalStream = RandStream.getGlobalStream;
CJsavedState = globalStream.State;
fname = sprintf('CJrandState.mat');
save(fname, 'myversion','mydate', 'CJsavedState');
cd $DIR
run('${PROGRAM}');
quit;
HERE

echo ending job \$SHELLSCRIPT
echo JOB_ID \$JOB_ID
date
echo "done"
THERE

chmod a+x $SHELLSCRIPT
bash $SHELLSCRIPT > $LOGFILE

BASH
}elsif($bqs eq "SLURM"){
$sh_script.= <<'BASH';
cat <<THERE > $SHELLSCRIPT
#! /bin/bash -l

echo starting job \$SHELLSCRIPT
echo JOB_ID \$SLURM_JOBID
echo WORKDIR \$SLURM_SUBMIT_DIR
date
cd $DIR

module load <MATLAB_MODULE>
unset _JAVA_OPTIONS
matlab -nosplash -nodisplay <<HERE
<MATPATH>

    
% add path for parrun
oldpath = textscan('$DIR', '%s', 'Delimiter', '/');
newpath = horzcat(oldpath{:});
bin_path = sprintf('%s/', newpath{1:end-1});
addpath(genpath(bin_path));
    
    
% make sure each run has different random number stream
myversion = version;
mydate = date;
% To get different Randstate for different jobs
rng(${COUNTER})
seed = sum(100*clock) + randi(10^6);
RandStream.setGlobalStream(RandStream('mt19937ar','seed', seed));
globalStream = RandStream.getGlobalStream;
CJsavedState = globalStream.State;
fname = sprintf('CJrandState.mat');
save(fname,'myversion', 'mydate', 'CJsavedState');
cd $DIR
run('${PROGRAM}');
quit;
HERE

echo ending job \$SHELLSCRIPT
echo JOB_ID \$SLURM_JOBID
date
echo "done"
THERE

chmod a+x $SHELLSCRIPT
bash $SHELLSCRIPT > $LOGFILE


BASH
}

my $pathText.=<<MATLAB;
    
% add user defined path
addpath $ssh->{matlib} -begin

% generate recursive path
addpath(genpath('.'));

try
cvx_setup;
cvx_quiet(true)
% Find and add Sedumi Path for machines that have CVX installed
    cvx_path = which('cvx_setup.m');
oldpath = textscan( cvx_path, '%s', 'Delimiter', '/');
newpath = horzcat(oldpath{:});
sedumi_path = [sprintf('%s/', newpath{1:end-1}) 'sedumi'];
addpath(sedumi_path)

catch
warning('CVX not enabled. Please set CVX path in .ssh_config if you need CVX for your jobs');
end

MATLAB




$sh_script =~ s|<PROGRAM>|$program|;
$sh_script =~ s|<PID>|$pid|;
$sh_script =~ s|<COUNTER>|$counter|;
$sh_script =~ s|<MATPATH>|$pathText|;
$sh_script =~ s|<MATLAB_MODULE>|$ssh->{mat}|;
$sh_script =~ s|<remote_path>|$remote_path|;
    

return $sh_script;
}	    
		
		
1;		
