
close all
clear all



pd.fc=10;
pd.SRFid=30; % must be even

pd.method='l2constr';
pd.oracle='nooracle';

pd.fid=pd.SRFid*pd.fc;
pd.fhi=pd.fc:pd.fc:pd.fid;
pd.SRF=pd.fhi/pd.fc;
pd.N=2*pd.fid; %must be even

pd.dpoints=2; % number of independent examples generated for each selection of parameters
pd.alpha=1;  %spike dynamic range

pd.n=2*pd.fc+1; % ?? do I need n?

P=[25,50,75,100,25e5,50e5,75e5,100e5];
r=[1];
d=[1,2];

output.param=cell(length(P),length(r),length(d));
%output.result=cell(length(P),length(r),length(d));

%output=zeros(length(P),length(r),length(d))



for i = 1:length(P)
    for j = 1:length(r)
     for  k = 1:length(d)

            pd.P=P(i);
            pd.r=r(j);
            pd.d=d(k);
            

             output.param{i,j,k} = pd;
          %  output.result{i,j,k}=run_superres_1d_fixedparam(pd);
            
            filename='Results.mat';
            savestr   = sprintf('save ''%s'' output', filename);
            eval(savestr);
            fprintf('CREATED OUTPUT FILE %s EXPERIMENT COMPLETE\n',filename);

            
        end
    end
end




