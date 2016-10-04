% this is a Matlab script for testing 
% cj parrun, reduce commands.
% Author: Hatef Monajemi June 28 2016

file = 'results.txt';

for i = 1:2
	for j = 1:2
		for k  = 1:3
			for l = 1:2	
				% write to a text file for testing reduce 	        
		        fid = fopen(file,'at');
		       % fprintf(fid, '%i,%i,%i\n', i,j,i+j);
		        fprintf(fid, '%i,%i,%i,%i,%i\n', i,j,k,l,i+j+k+l);
		        fclose(fid)
	end
  end
 end
end
													
	