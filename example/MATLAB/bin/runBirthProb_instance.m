function runBirthProb_instance(D,n,nMonte,file)
C = nchoosek(1:n,2);   
m = size(C,1);
for j = 1:nMonte
		tic;
		birthdayMap = randsample(D,n,true);   % Draw realization of a class consisting of n people.
		k = comparePairs(n,C,birthdayMap);
		tElapsed = toc; 
		
    	fid = fopen(file,'at');
	    fprintf(fid, '%i,%i,%i,%i,%f\n', n, D, m, k, tElapsed);
    	fclose(fid);		        		
end