
# CJ has its own randState upon calling
# to reproduce results one needs to set
# the internal State of the global stream
# to the one saved when ruuning the code for
# the fist time;
import os,sys,pickle,numpy,random;
CJsavedState = pickle.load(open('CJrandState.pickle','rb'));
numpy.random.set_state(CJsavedState['numpy_CJsavedState']);
random.setstate(CJsavedState['CJsavedState']);
    
sys.path.append('../.');
import numpy as np;
import csv;
SUID = 'monajemi'
file = SUID+'_results.csv';
Var0  = np.array([1,2,3]);
Var1  = [1,2];
with open('file.txt','w') as myfile:

    for i in range(len(Var0)):
        for j in range(len(Var1)):    

            if ( i != 2 or j != 0 ): continue;
            with open(file,'a') as csvfile:
                resultswriter = csv.writer(csvfile,delimiter=',');
                resultswriter.writerow([i,j,Var0[i]+Var1[j] ]);
