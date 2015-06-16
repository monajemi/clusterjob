% this is a MATLAB test script
% for clusterjob
% Copyright 2015 Hatef Monajemi (monajemi@stanford.edu)

filename = 'Results.txt';
SUID     = 'monajemi';

l = 1:10;
for i = 1:length(l)
fid = fopen(filename, 'at');
fprintf(fid, '%s, %s\n','SUID','counter');
fprintf(fid, '%s, %i\n', SUID,i);
fclose(fid);
end
