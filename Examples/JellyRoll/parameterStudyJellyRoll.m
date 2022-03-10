
%% loading modules

mrstModule add ad-core multimodel mrst-gui battery mpfa agmg

paramListSetup = setupParamList();

paramlist  = paramListSetup.paramlist;
paramnames = paramListSetup.paramnames;
nparams    = paramListSetup.nparams;
getind     = paramListSetup.getind;
selectedparams = {};


selectedparams = [];
for iparam = 1 : numel(paramnames)
    paramname = paramnames{iparam};
    nval = numel(paramlist{getind(paramname)}.values);
    n = size(selectedparams, 2);
    if isempty(selectedparams)
        selectedparams = (1 : nval);
    else
        selectedparams1 = repmat(selectedparams, 1, nval);
        selectedparams2 = rldecode((1 : nval)', n*ones(nval, 1))';
        selectedparams = [selectedparams1; selectedparams2];
    end
end

inputs = {};

for ind = 1 : size(selectedparams, 2)
   
    selectedparam = selectedparams(:, ind);
    inputs{end + 1} = setupInputFromParam(selectedparam, paramListSetup);
    
end

doparallel = false;

if doparallel

    delete(gcp('nocreate'))
    p = parpool('local', 6);
    opt = parforOptions(p);
    parfor (ind = 1 : numel(inputs), opt)
        jellyRollSimFunc2(inputs{ind});
    end

else
    
    for ind = 1 : numel(inputs)
        jellyRollSimFunc2(inputs{ind});
    end
    
end
