% This is a test Matlab script for CJ
% Author: Hatef Monajemi June 28 2016

file = 'results.txt';


n_list = [2^5]

for i = 1:length(n_list)
   for j = 1:4
	% write to a text file for testing reduce 	        
	fid = fopen(file,'at');   
	fprintf(fid, '%i,%i,%i\n', i,j,i+j);
	fclose(fid)
   end
end
													
	
