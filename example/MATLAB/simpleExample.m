% This is a test Matlab script for CJ
% Author: Hatef Monajemi June 28 2016

file = 'results.txt';

for i = 1:2 
	for j = 1:4
				% write to a text file for testing reduce 	        
		        fid = fopen(file,'at');                     % This is a test
		        fprintf(fid, '%i,%i,%i\n', i,j,i+j);
		        fclose(fid)
 end
end
													
	
