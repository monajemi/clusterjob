% This is an example of parrun-reduce 
% uing Clusterjob for cells with structure in them
% Copyright 2015 Hatef Monajemi (monajemi@stanford.edu) 

close all
clear all
clc


% Always initiate your outputs
output.myStructCell = cell(5,5);
output.myCharCell = cell(5,5);
output.myMatrix = zeros(5,5);




for i = 1:5
for j = 1:5

    mystruct.i = i;
    mystruct.j = j;

    output.myMatrix(i,j) = i+j;
    output.myStructCell{i,j} = mystruct;
    output.myCharCell{i,j}   = 'i,j';

% save results
filename='Results.mat';
savestr   = sprintf('save ''%s'' output', filename);
eval(savestr);
fprintf('CREATED OUTPUT FILE %s EXPERIMENT COMPLETE\n',filename);

  end
end











