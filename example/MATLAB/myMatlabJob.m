% this is a MATLAB test script
% for clusterjob
% Copyright 2015 Hatef Monajemi (monajemi@stanford.edu)

filename = 'Results.txt';
SUID     = 'monajemi';
for i = 1:10
fid = fopen(filename, 'at');
fprintf(fid, '%s, %i\n', SUID,i);
fclose(fid);
end
