% this is a MATLAB test script
% for clusterjob
% Copyright 2015 Hatef Monajemi (monajemi@stanford.edu)

filename = 'Results.txt';
SUID     = 'monajemi';

l = 1:10;
k = 2:5;


fid = fopen(filename, 'at');
fprintf(fid, '%s, %s, %s\n','SUID','counter1', 'counter2');

for i = 1:length(l)
 for j = 1:length(k)
	fprintf(fid, '%s, %i, %i\n', SUID,i,j);
  end
end

fclose(fid);