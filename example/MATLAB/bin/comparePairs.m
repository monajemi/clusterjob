% sample M pairs in a class of n 
% people for birthday problem
		
function k = comparePairs(n,C,birthdayMap)	 
		m = size(C,1);
		indicator = zeros(m,1);
		for j = 1:m
		indicator(j) = birthdayMap(C(j,1))==birthdayMap(C(j,2)); % measure success of failure 
		end
		k = sum(indicator); 									 % number of success		
end