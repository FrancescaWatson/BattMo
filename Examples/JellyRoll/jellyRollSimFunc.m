function model = jellyRollSimFunc(input, varargin)
    
    opt = struct('onlyModel', false);
    opt = merge_options(opt, varargin{:});

    options    = input.options;
    params     = input.params;
    CRate      = input.CRate;
    initstate  = input.initstate;
    simcase    = input.simcase; % charge or discharge
    dataFolder = input.dataFolder;    
    

    %% We setup defaultparams (4680 battery) and merge it with params as given by input.params
    
    r0 = 2*milli*meter; 

    % widths of each component ordered as
    % - positive current collector
    % - positive electrode
    % - electrolyte separator 
    % - negative electrode
    % - negative current collector

    widths = 1e-6*[25, 64, 15, 57, 15];
            
    widthDict = containers.Map( ...
        {'ElectrolyteSeparator',... 
         'NegativeActiveMaterial',...
         'NegativeCurrentCollector',...
         'PositiveActiveMaterial',...
         'PositiveCurrentCollector'},...
        widths); 

    nwidths = [widthDict('PositiveActiveMaterial');...
               widthDict('PositiveCurrentCollector');...
               widthDict('PositiveActiveMaterial');...
               widthDict('ElectrolyteSeparator');...
               widthDict('NegativeActiveMaterial');...
               widthDict('NegativeCurrentCollector');...
               widthDict('NegativeActiveMaterial');...
               widthDict('ElectrolyteSeparator')]; 

    dr = sum(nwidths);
    rOuter = 46*milli*meter/2;
    L = 80*milli*meter; 
    
    dR = rOuter - r0; 
    nwindings = ceil(dR/dr);

    % number of cell in radial direction for each component (same ordering as above).

    nrDict = containers.Map( ...
        {'ElectrolyteSeparator',... 
         'NegativeActiveMaterial',...
         'NegativeCurrentCollector',...
         'PositiveActiveMaterial',...
         'PositiveCurrentCollector'},...
        [3, 3, 3, 3, 3]); 


    % number of cells in the angular direction
    nas = 10; 
    
    % number of discretization cells in the longitudonal
    nL = 3;

    default_tabparams.tabcase   = 'aligned tabs'; % 'tabless'
    default_tabparams.width     = 3*milli*meter;
    default_tabparams.fractions = linspace(0.01, 0.9, 6);

    defaultparams = struct('nwindings'   , nwindings, ...
                           'r0'          , r0       , ...
                           'widthDict'   , widthDict, ...
                           'nrDict'      , nrDict   , ...
                           'nas'         , nas      , ...
                           'L'           , L        , ...
                           'nL'          , nL       , ...
                           'tabparams'   , default_tabparams, ...
                           'initElytec'  , 1000     , ...
                           'angleuniform', false); 

    if ~isempty(params)
        args = cellfun(@(fd) {fd, params.(fd)}, fieldnames(params), 'uniformoutput', false);
        args = horzcat(args{:});
        params = merge_options(defaultparams, args{:});
    else
        params = defaultparams;
    end
    
    %% setup and merge default options
    defaultcooling = struct('top', 10, ...
                            'side', 10);
    
    defaultoptions = struct('use_thermal'                 , true                 , ...
                            'use_solid_diffusion'         , true                 , ...
                            'coolingparams'               , defaultcooling       , ...
                            'ActiveMaterialVolumeFraction', []                , ...
                            'gridcase'                    , 'spiral'             , ...
                            'linearsolver'                , 'agmg'               , ...
                            'doprofiling'                 , false                , ...
                            'jsonfilename'                , 'lithiumbattery.json', ...
                            'use_packed'                  , true                 , ...
                            'nosim'                       , false);
    options = merge_options(defaultoptions, options{:});

    % setup mrst modules
    mrstModule add ad-core multimodel mrst-gui battery mpfa nwm agmg

    mrstVerbose off

    % The input parameters can be given in json format. The json file is read and used to populate the paramobj object.
    jsonfilename = options.jsonfilename;
    jsonfilename = strcat('ParameterData/BatteryCellParameters/LithiumIonBatteryCell/', jsonfilename);
    jsonstruct = parseBatmoJson(jsonfilename); 
    paramobj = BatteryInputParams(jsonstruct); 

    % params.depth = params.r0; 
    % gen = SectorBatteryGenerator(); 
    switch options.gridcase
      case 'flat'        
        gen = FlatBatteryGenerator(); 
      case 'sector'
        gen = SectorBatteryGenerator(); 
      case 'spiral'
        gen = SpiralBatteryGenerator(); 
      otherwise
        error()
    end

    th = 'ThermalModel';
    paramobj.(th).externalHeatTransferCoefficientSideFaces = options.coolingparams.side;
    paramobj.(th).externalHeatTransferCoefficientTopFaces = options.coolingparams.top;
        
    paramobj = gen.updateBatteryInputParams(paramobj, params);
    
    if ~isempty(options.ActiveMaterialVolumeFraction)
        paramobj.NegativeElectrode.ActiveMaterial.volumeFraction = options.ActiveMaterialVolumeFraction;
        paramobj.PositiveElectrode.ActiveMaterial.volumeFraction = options.ActiveMaterialVolumeFraction;
    end
    
    model = Battery(paramobj, ...
                    'use_thermal'        , options.use_thermal, ...
                    'use_solid_diffusion', options.use_solid_diffusion); 

    if opt.onlyModel
        return
    end
    
    [cap, cap_neg, cap_pos, specificEnergy] = computeCellCapacity(model);
    fprintf('ratio : %g, energy : %g\n', cap_neg/cap_pos, specificEnergy/hour);
    
    % Schedule with two phases : activation and operation
    % 
    % Activation phase with exponentially increasing time step
    fac   = 2; 
    total = 1.4*hour/CRate; 
    n     = 10; 
    dt0   = total*1e-6; 
    times = getTimeSteps(dt0, n, total, fac); 

    %% We compute the cell capacity
    C = computeCellCapacity(model); 
    inputI = (C/hour)*CRate; 
    inputE = 3; 

    %% We setup the schedule 

    tt = times(2 : end); 

    step = struct('val', diff(times), 'control', ones(numel(tt), 1)); 

    pe = 'PositiveElectrode'; 
    cc = 'CurrentCollector'; 
    stopFunc = @(model, state, state_prev) (state.(pe).(cc).I < 1e-3*inputI && state.time> hour/(2*CRate)); 
    tup = 0.1/CRate; 

    switch simcase
        
      case 'decharge'
       
        stopFunc = @(model, state, state_prev) (state.(pe).(cc).E < inputE+1e-4); 
        srcfunc  = @(time, I, E) rampupSwitchControl(time, tup, I, E, inputI, inputE); 
        control  = repmat(struct('src', srcfunc, 'stopFunction', stopFunc), 1, 1); 
        schedule = struct('control', control, 'step', step); 
        %% We setup the initial state
        initstate = model.setupInitialState(); 
        
        initstate.Electrolyte.c = params.initElytec*ones(model.Electrolyte.G.cells.num, 1);
        
      case 'charge'
        
        model.SOC = 0.01;
        initstate = model.setupInitialState();
        stopFunc  = @(model, state, state_prev) (state.(pe).(cc).I > - 1e-3*inputI  && state.time> hour/(2*CRate)); 
        srcfunc   = @(time, I, E) rampupSwitchControl(time, tup, I, E, -inputI, 4.2); 
        control   = repmat(struct('src', srcfunc, 'stopFunction', stopFunc), 1, 1); 
        schedule  = struct('control', control, 'step', step); 
        
      otherwise
        
        error('simcase not recognized')
    end

    % Setup nonlinear solver 
    nls = NonLinearSolver(); 

    % Change default maximum iteration number in nonlinear solver
    nls.maxIterations = 10; 
    % Change default behavior of nonlinear solver, in case of error
    nls.errorOnFailure = false; 
    % Change default tolerance for nonlinear solver
    model.nonlinearTolerance = 1e-4; 

    use_diagonal_ad = false;
    if(use_diagonal_ad)
        model.AutoDiffBackend = DiagonalAutoDiffBackend(); 
        model.AutoDiffBackend.useMex = true; 
        model.AutoDiffBackend.modifyOperators = true; 
        model.AutoDiffBackend.rowMajor = true; 
        model.AutoDiffBackend.deferredAssembly = false; % error with true for now
    else
        model.AutoDiffBackend = AutoDiffBackend(); 
    end
    nls.timeStepSelector = StateChangeTimeStepSelector('TargetProps', {{'PositiveElectrode', 'CurrentCollector', 'E'}}, 'targetChangeAbs', 0.03);
    switch options.linearsolver
      case 'agmg'
        mrstModule add agmg
        nls.LinearSolver = AGMGSolverAD('verbose', true, 'reduceToCell', true); 
        nls.LinearSolver.tolerance = 1e-3; 
        nls.LinearSolver.maxIterations = 30; 
        nls.maxIterations = 10; 
        nls.verbose = 10;
      case 'direct'
        disp('standard direct solver')
      case 'battery'
        reuse_setup = false; 
        nls.LinearSolver = LinearSolverBatteryExtra('method'      , 'matlab_cpr_agmg', ...
                                                    'verbosity'   , 1                , ...
                                                    'reduceToCell', true             , ...
                                                    'reuse_setup' , reuse_setup); 
        nls.LinearSolver.tolerance = 1e-5; 
        nls.LinearSolver.maxIterations = 20; 
        nls.maxIterations = 20;
      otherwise
        error()
    end
    model.nonlinearTolerance = 1e-4; 
    model.verbose = true; 

    % Run simulation, use tag generated by md5sum to generate unique name
    opttmp = rmfield(options, 'nosim'); 
    params.widthDict = struct(params.widthDict);
    params.nrDict = struct(params.nrDict); 
    opttmp.params = params;
    simname = md5sum(opttmp, simcase, CRate, initstate, schedule, jsonstruct);
    problem = packSimulationProblem(initstate, model, schedule,...
                                    dataFolder, 'Name', simname, 'NonLinearSolver', nls);
    problem.SimulatorSetup.OutputMinisteps = true; 
    
    % clearPackedSimulatorOutput(problem);
    h = problem.OutputHandlers.states;
    filename = fullfile(h.dataDirectory, h.dataFolder, 'simulationInput.mat');
    output.mass = computeCellMass(model);
    output.volume = sum(model.G.cells.volumes);
    output.jsonstruct = jsonstruct;
    save(filename, 'options', 'input', 'output');

    simulatePackedProblem(problem);

end

%% Process output


