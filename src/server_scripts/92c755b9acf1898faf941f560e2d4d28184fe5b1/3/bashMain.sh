#!/bin/bash -l
echo JOB_ID $SLURM_JOBID
echo WORKDIR $SLURM_SUBMIT_DIR
echo START_DATE `date`
DIR=/home/hatefmonajemi/CJRepo_Remote/simpleExample/92c755b9acf1898faf941f560e2d4d28184fe5b1/3;
PROGRAM="simpleExample";
PID="92c755b9acf1898faf941f560e2d4d28184fe5b1";
COUNTER=3;
cd $DIR;
    #mkdir scripts
    #mkdir logs
SHELLSCRIPT=${DIR}/scripts/CJrun.${PID}.${COUNTER}.sh;
LOGFILE=${DIR}/logs/CJrun.${PID}.${COUNTER}.log;
cat <<THERE > $SHELLSCRIPT
#!/bin/bash -l
    
# activate python venv
source activate CJ_python_venv

python <<HERE

# make sure each run has different random number stream
import os,sys,pickle,numpy,random;
    
# Add path for parrun
deli  = "/";
path  = os.getcwd();
path  = path.split(deli);
path.pop();
sys.path.append(deli.join(path));
    
#GET A RANDOM SEED FOR THIS COUNTER
numpy.random.seed(${COUNTER});
seed_0 = numpy.random.randint(10**6);
mydate = numpy.datetime64('now');
#sum(100*clock)
seed_1 = numpy.sum(100*numpy.array([mydate.astype(object).year, mydate.astype(object).month, mydate.astype(object).day, mydate.astype(object).hour, mydate.astype(object).minute, mydate.astype(object).second]));
#seed = sum(100*clock) + randi(10^6);
seed = seed_0 + seed_1;

    
# Set the seed for python and numpy (for reproducibility purposes);
random.seed(seed);
numpy.random.seed(seed);

CJsavedState = {'myversion': sys.version, 'mydate':mydate, 'numpy_CJsavedState': numpy.random.get_state(), 'CJsavedState': random.getstate()}

fname = "$DIR/CJrandState.pickle";
with open(fname, 'wb') as RandStateFile:
	pickle.dump(CJsavedState, RandStateFile);

# del vars that we create tmp
del deli,path,seed_0,seed_1,seed,CJsavedState;
    
# CJsavedState = pickle.load(open('CJrandState.pickle','rb'));

os.chdir("$DIR")
import ${PROGRAM};
#exec(open('${PROGRAM}').read())

exit();
HERE

    
    
    
# Freeze the environment after you installed all the modules
# Reproduce with:
#      conda create --yes -n python_venv_$PID --file req.txt
TOPDIR="$(dirname ${DIR})"
if [ ! -f "\${TOPDIR}/${PID}_py_conda_req.txt" ]; then
    conda list -e > \${TOPDIR}/${PID}_py_conda_req.txt
fi

    
# Get out of virtual env and remove it
conda deactivate
    
    
THERE
chmod a+x $SHELLSCRIPT
bash $SHELLSCRIPT > $LOGFILE
echo ending job $SHELLSCRIPT
echo JOB_ID $SLURM_JOBID
echo END_DATE `date`
echo "done"
