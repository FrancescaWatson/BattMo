    

[model, initState] = get3DexampleModel();
G = model.G;


[filepath,name,ext] = fileparts(mfilename('fullpath')); % TODO: Make this relative to module path?
fname = fullfile('C:\Users\francescaw\FranFiles\battmo-github','temp_output','test_vtk3Dexample.hdf');


battMo2vtkhdf(model,initState,fname);