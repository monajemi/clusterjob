# This is a test Python script for CJ
# Author: Hatef Monajemi June 11 2017
import numpy as np;
import csv;

SUID = 'monajemi'
file = SUID+'_results.csv';

Var  = np.array([1,2,3,4,10,5]);

for i in range(len(Var)):
    for j in np.array([1,2,3,6]):    # This is a comment
        # write to a text file for testing reduce
        with open(file,'a') as csvfile:
            resultswriter = csv.writer(csvfile,delimiter=',');
            resultswriter.writerow([i,j,i+j]);
													
	
