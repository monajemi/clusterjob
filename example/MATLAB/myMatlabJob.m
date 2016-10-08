% this is a MATLAB test script
% for clusterjob
% Copyright 2015 Hatef Monajemi (monajemi@stanford.edu)

filename = 'Results.txt';
SUID     = 'monajemi';

l = 1:10;
k = [20,40,60,80,100];

rng(1969);
r = rand(length(k));

fid = fopen(filename, 'at');
fprintf(fid, '%s, %s, %s, %s\n','SUID','counter1', 'counter2','random_number');

for i = 1:length(l)
 for j = 1:length(k)
	
	counter = (i-1)*length(k) + j ;	
	% open a file for testing gather
	file2 = sprintf('file_%i', counter);
	fid2 = fopen(file2,'at');
        fprintf(fid2, '%i\n', counter);
	 fclose(fid2)


	% File for testing reduce
	fprintf(fid, '%s, %i,%i, %f\n', SUID,i,j,r(j));
  end
end

fclose(fid);
