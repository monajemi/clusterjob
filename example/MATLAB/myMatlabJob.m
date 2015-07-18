% this is a MATLAB test script
% for clusterjob
% Copyright 2015 Hatef Monajemi (monajemi@stanford.edu)

filename = 'Results.txt';
SUID     = 'monajemi';

l = 1:10;
k = [0.2,.4 ,.6 ,.8 ,1e-4];

r = rand(length(k));
fid = fopen(filename, 'at');
fprintf(fid, '%s, %s, %s\n','SUID','counter1', 'counter2');

for i = 1:length(l)
 for j = 1:length(k)
	
	counter = (i-1)*length(k) + j ;	
	% open a file for testing gather
	file2 = sprintf('file_%i', counter);
	fid2 = fopen(file2,'at');
        fprintf(fid2, '%i\n', counter);
	fclose(fid2)

	% File for testing reduce
	fprintf(fid, '%s, %i, %i\n', SUID,i,r(j));
  end
end

fclose(fid);
