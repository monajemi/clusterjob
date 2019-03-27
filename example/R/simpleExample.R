# This is a test R script for CJ
# Author: Hatef Monajemi Jan 9 2017

rm(list=ls())

library(ggplot2)
library(Matrix)

myFile = "results.csv";
system(paste("rm ", myFile));

B = c(1,3,4);
L=length(B);

for (i in 1:L){
        for (j in 1:5){
                       # write to a csv file for testing reduce    
					   data = sprintf("%i,%i,%i\n",i,j,i+j);          
                       cat(data, file = myFile, append = TRUE); 
 }
}
