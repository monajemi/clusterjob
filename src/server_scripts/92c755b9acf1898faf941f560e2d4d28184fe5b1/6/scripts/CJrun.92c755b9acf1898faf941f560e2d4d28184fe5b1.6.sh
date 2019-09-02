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
numpy.random.seed(6);
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

fname = "/home/hatefmonajemi/CJRepo_Remote/simpleExample/92c755b9acf1898faf941f560e2d4d28184fe5b1/6/CJrandState.pickle";
with open(fname, 'wb') as RandStateFile:
	pickle.dump(CJsavedState, RandStateFile);

# del vars that we create tmp
del deli,path,seed_0,seed_1,seed,CJsavedState;
    
# CJsavedState = pickle.load(open('CJrandState.pickle','rb'));

os.chdir("/home/hatefmonajemi/CJRepo_Remote/simpleExample/92c755b9acf1898faf941f560e2d4d28184fe5b1/6")
import simpleExample;
#exec(open('simpleExample').read())

exit();
HERE

    
    
    
# Freeze the environment after you installed all the modules
# Reproduce with:
#      conda create --yes -n python_venv_92c755b9acf1898faf941f560e2d4d28184fe5b1 --file req.txt
TOPDIR="/home/hatefmonajemi/CJRepo_Remote/simpleExample/92c755b9acf1898faf941f560e2d4d28184fe5b1"
if [ ! -f "${TOPDIR}/92c755b9acf1898faf941f560e2d4d28184fe5b1_py_conda_req.txt" ]; then
    conda list -e > ${TOPDIR}/92c755b9acf1898faf941f560e2d4d28184fe5b1_py_conda_req.txt
fi

    
# Get out of virtual env and remove it
conda deactivate
    
    
