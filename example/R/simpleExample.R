# This is a test R script for CJ
# Author: Hatef Monajemi Jan 9 2017

rm(list=ls())

library(tidyverse)
library(Matrix)

myFile = "results.csv";
system(paste("rm ", myFile));

for (i in 1:3){
        for (j in 1:5){
                       # write to a csv file for testing reduce    
					   data = sprintf("%i,%i,%i\n",i,j,i+j);          
                       cat(data, file = myFile, append = TRUE); 
 }
}
