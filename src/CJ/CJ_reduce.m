function C = CJ_reduce(A,B)
% This function reduces the contents of mapped A, and B
% through CJ

% CHECK A, and B of of the same class and size
if( ~check(A,B) ) ; error('   CJerr::A, and B are of different size or class'); end;


if(     isa(A,'double') )
C = reduce_double(A,B);

elseif( isa(A, 'cell'))  % double or char
C = reduce_cell(A,B);

elseif( isa(A,'struct') )
flds = fields(A);
for j = 1:length(flds)
    if( isa(A.(flds{j}),'double') )
    C.(flds{j}) = reduce_double( A.(flds{j}) , B.(flds{j}) );
    elseif(isa(A.(flds{j}),'char') )
    C.(flds{j}) = reduce_char( A.(flds{j}) , B.(flds{j}) );
    elseif( isa(A.(flds{j}),'cell')  )
    C.(flds{j}) = reduce_cell( A.(flds{j}) , B.(flds{j}) );
else
    error('   CJerr:: class %s is not recognized', class(A.(flds{j})) );
end
end

else
error('   CJerr::Not implemeneted yet');
end



end  %CJ_reduce




function c = reduce_cell(a,b);

if( ~check(a,b) ) ; error('   CJerr::a, and b are of different size or class'); end;

if(  isequaln(a,b) )
c = a;
return;
end

w = cellfun( @(x) isa(x,'char') , a, 'UniformOutput', false );
if(sum([w{:}]) > 0)   % if we find one character
c = cellfun( @reduce_char , a, b, 'UniformOutput', false );
else
c = cellfun( @reduce_double , a, b, 'UniformOutput', false );
end

end  %reduce_cell







function c = reduce_double(a,b)

if(  isequaln(a,b) )
c = a;
return;
end

% check if the class of elements is double
if(~ strcmp( class(a) , 'double') ); error('   CJerr::Beyond the scope of CJ at the moment. Cells must contain double or char class variables'); end
if(~ strcmp( class(b) , 'double') ); error('   CJerr::Beyond the scope of CJ at the moment. Cells must contain double or char class variables'); end


A = num2cell(a);
B = num2cell(b);

if(isempty(A))
A = cell(size(B));
elseif(isempty(B))
B = cell(size(A));
end





function z = myAdd(x,y)
if ( isempty(x) || isnan(x)     )
z = y;
elseif ( isempty(y) || isnan(y)     )
z = x;
else
z = x+y;
end
end

C = cellfun( @myAdd , A, B, 'UniformOutput', false );

c = cell2mat(C);

end %reduce_double







function c = reduce_char(a,b)

if(  isequaln(a,b) )
c = a;
return;
end

% check if the class of elements is double
if(~ (strcmp( class(a) , 'char') || strcmp( class(a) , 'double') ) );
error('   CJerr::Beyond the scope of CJ at the moment. Cells must contain double or char class variables');
end
if(~ (strcmp( class(b) , 'char') || strcmp( class(b) , 'double') ) );
error('   CJerr::Beyond the scope of CJ at the moment. Cells must contain double or char class variables');
end

if ( isempty(a) || sum(any(isnan(a)))==prod(size(a))      )
c = b;
elseif( isempty( b )  || sum(any(isnan(b)))==prod(size(b))  )
c = a;
else
error('   CJerr:: Sorry, I dont know how to reduce them!');
end


end %reduce_char












% Check
function c = check(A,B)
c = true;
if( ~ strcmp(class(A), class(B)) ); c = false ;end;
if( length(size(A)) ~= length(size(B))); c = false;end;

for i = 1:length(size(A))
if(size(A,i)~=size(B,i)); c = false; end;
end

end %check