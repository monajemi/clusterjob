% This is an example of parrun-reduce 
% uing Clusterjob
% Copyright 2015 Hatef Monajemi (monajemi@stanford.edu) 

close all
clear all
clc


% Always initiate your outputs
output.size   = 5;
output.Matrix = zeros(output.size,output.size);


for i = 1:5
  for j = 1:5
    output.Matrix(i,j) = i+j
 

% save results
filename='Results.mat';
savestr   = sprintf('save ''%s'' output', filename);
eval(savestr);
fprintf('CREATED OUTPUT FILE %s EXPERIMENT COMPLETE\n',filename);

  end
end











