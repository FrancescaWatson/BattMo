function problem = jellyProblemFunc(CRate, inputstate, simcase, varargin)
    
    opt = struct('params'             , []      , ...
                 'use_thermal'        , false   , ...
                 'use_solid_diffusion', false   , ...
                 'gridcase'           , 'flat'  ,...
                 'linearsolver'       , 'direct', ...
                 'jsonstruct', []);
    opt = merge_options(opt,varargin{:});

    % setup mrst modules
    mrstModule add ad-core multimodel mrst-gui battery mpfa nwm

    mrstVerbose off

    % The input parameters can be given in json format. The json file is read and used to populate the paramobj object.
    %jsonstruct = parseBatmoJson('JsonDatas/lithiumbattery.json');
    jsonstruct = opt.jsonstruct;
    paramobj = BatteryInputParams(jsonstruct); 
    params = opt.params; 
    % params.depth = params.r0; 
    % gen = SectorBatteryGenerator(); 
    switch opt.gridcase
      case 'flat'        
        gen = FlatBatteryGenerator(); 
      case 'sector'
        gen = SectorBatteryGenerator(); 
      case 'spiral'
        gen = SpiralBatteryGenerator(); 
      otherwise
        error()
    end
    
    paramobj = gen.updateBatteryInputParams(paramobj, params); 
    model = Battery(paramobj, 'use_thermal', opt.use_thermal, 'use_solid_diffusion', opt.use_solid_diffusion); 
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
    
    %stopFunc = @(model, state, state_prev) (state.(pe).(cc).I < 1e-3*inputI && state.time> hour/(2*CRate)); 
    tup = 0.1/CRate; 
    switch simcase
      case 'decharge'
        stopFunc = @(model, state, state_prev) (state.(pe).(cc).E < inputE+1e-4); 
        srcfunc = @(time, I, E) rampupSwitchControl(time, tup, I, E, inputI, inputE); 
        control = repmat(struct('src', srcfunc, 'stopFunction', stopFunc), 1, 1); 
        schedule = struct('control', control, 'step', step); 
        %% We setup the initial state
        initstate = model.setupInitialState(); 
      case 'charge'
        %initstate = inputstate; 
        %initstate.time = 0; 
        stopFunc = @(model, state, state_prev) (state.(pe).(cc).I > - 1e-3*inputI  && state.time> hour/(2*CRate)); 
        srcfunc = @(time, I, E) rampupSwitchControl(time, tup, I, E, -inputI, 4.2); 
        control = repmat(struct('src', srcfunc, 'stopFunction', stopFunc), 1, 1); 
        schedule = struct('control', control, 'step', step); 
        model.SOC =0.0;
        initstate = model.setupInitialState();
        %initstate = inputstate; 
        %initstate.time = 0; 
      otherwise
        error()
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
    switch opt.linearsolver
      case 'agmg'
        mrstModule add agmg
        nls.LinearSolver = AGMGSolverAD('verbose', true, 'reduceToCell', true); 
        nls.LinearSolver.tolerance = 1e-3; 
        nls.LinearSolver.maxIterations = 30; 
        nls.maxIterations = 10; 
        nls.verbose = 10
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
        nls.maxIterations = 20
      otherwise
        error()
    end
    model.nonlinearTolerance = 1e-5; 
    model.verbose = true; 

    % Run simulation
    opttmp = opt;
    opttmp.params.widthDict = struct(opttmp.params.widthDict); 
    opttmp.params.nrDict = struct(opttmp.params.nrDict); 
    %simname = md5sum(opttmp, simcase, CRate, inputstate, schedule, jsonstruct); 
    simname = md5sum(opttmp, simcase, CRate, jsonstruct); 
    problem = packSimulationProblem(initstate, model, schedule,...
                                        'JellyRole_29Nov_par', 'Name', simname, 'NonLinearSolver', nls); 
    problem.SimulatorSetup.OutputMinisteps = true; 
    
end

%% Process output


