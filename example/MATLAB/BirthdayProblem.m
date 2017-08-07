% This is a computer program to calculate
% the expected number of pairs in the brithday 
% problem.		
% Author: Hatef Monajemi June 28 2016

clear all
clc
		
nlist  = 2:365;
D 	   = 365;	
nMonte = 10000;

file = 'results.txt';    

for i = 1:length(nlist) 
	n = nlist(i);
	runBirthProb_instance(D,n,nMonte,file);
end
											
	