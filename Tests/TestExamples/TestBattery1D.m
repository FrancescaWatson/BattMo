classdef TestBattery1D < matlab.unittest.TestCase

    properties (TestParameter)
        
        jsonfile                   = {'ParameterData/BatteryCellParameters/LithiumIonBatteryCell/lithium_ion_battery_nmc_graphite.json'};
        controlPolicy              = {'CCCV', 'IEswitch'};
        use_thermal                = {true, false};
        include_current_collector  = {true, false};
        diffusionmodel             = {'simplified'};
        
    end
    
    methods

        function test = TestBattery1D()
            mrstModule reset
            mrstModule add ad-core mrst-gui mpfa
        end
        
        function states = test1d(test, jsonfile, controlPolicy, use_thermal, include_current_collector, useSimplifiedDiffusionModel, varargin)
            
        %% Setup the properties of Li-ion battery materials and cell design
        % The properties and parameters of the battery cell, including the
        % architecture and materials, are set using an instance of
        % :class:`BatteryInputParams <Battery.BatteryInputParams>`. This class is
        % used to initialize the simulation and it propagates all the parameters
        % throughout the submodels. The input parameters can be set manually or
        % provided in json format. All the parameters for the model are stored in
        % the paramobj object.
            jsonstruct = parseBattmoJson('ParameterData/BatteryCellParameters/LithiumIonBatteryCell/lithium_ion_battery_nmc_graphite.json');

            jsonstruct.include_current_collector = include_current_collector;
            jsonstruct.use_thermal = use_thermal;
            
            jsonstruct.NegativeElectrode.ActiveMaterial.useSimplifiedDiffusionModel = useSimplifiedDiffusionModel;
            jsonstruct.PositiveElectrode.ActiveMaterial.useSimplifiedDiffusionModel = useSimplifiedDiffusionModel;

            paramobj = BatteryInputParams(jsonstruct);

            use_cccv = strcmpi(controlPolicy, 'CCCV');
            if use_cccv
                cccvstruct = struct( 'controlPolicy'     , 'CCCV',  ...
                                     'CRate'             , 1         , ...
                                     'lowerCutoffVoltage', 2         , ...
                                     'upperCutoffVoltage', 4.1       , ...
                                     'dIdtLimit'         , 0.01      , ...
                                     'dEdtLimit'         , 0.01);
                cccvparamobj = CcCvControlModelInputParams(cccvstruct);
                paramobj.Control = cccvparamobj;
            end


            % We define some shorthand names for simplicity.
            ne      = 'NegativeElectrode';
            pe      = 'PositiveElectrode';
            elyte   = 'Electrolyte';
            thermal = 'ThermalModel';
            am      = 'ActiveMaterial';
            itf     = 'Interface';
            sd      = 'SolidDiffusion';
            ctrl    = 'Control';

            %% Setup the geometry and computational mesh
            % Here, we setup the 1D computational mesh that will be used for the
            % simulation. The required discretization parameters are already included
            % in the class BatteryGenerator1D. 
            gen = BatteryGenerator1D();

            % Now, we update the paramobj with the properties of the mesh. 
            paramobj = gen.updateBatteryInputParams(paramobj);

            %%  Initialize the battery model. 
            % The battery model is initialized by sending paramobj to the Battery class
            % constructor. see :class:`Battery <Battery.Battery>`.
            model = Battery(paramobj);
            model.AutoDiffBackend= AutoDiffBackend();

            %% Compute the nominal cell capacity and choose a C-Rate
            % The nominal capacity of the cell is calculated from the active materials.
            % This value is then combined with the user-defined C-Rate to set the cell
            % operational current. 

            CRate = model.Control.CRate;

            %% Setup the time step schedule 
            % Smaller time steps are used to ramp up the current from zero to its
            % operational value. Larger time steps are then used for the normal
            % operation.
            switch model.(ctrl).controlPolicy
              case 'CCCV'
                total = 3.5*hour/CRate;
              case 'IEswitch'
                total = 1.4*hour/CRate;
              otherwise
                error('control policy not recognized');
            end

            n     = 100;
            dt    = total/n;
            
            n = 10;
            
            step  = struct('val', dt*ones(n, 1), 'control', ones(n, 1));

            % we setup the control by assigning a source and stop function.
            % control = struct('CCCV', true); 
            %  !!! Change this to an entry in the JSON with better variable names !!!

            switch model.Control.controlPolicy
              case 'IEswitch'
                tup = 0.1; % rampup value for the current function, see rampupSwitchControl
                srcfunc = @(time, I, E) rampupSwitchControl(time, tup, I, E, ...
                                                            model.Control.Imax, ...
                                                            model.Control.lowerCutoffVoltage);
                % we setup the control by assigning a source and stop function.
                control = struct('src', srcfunc, 'IEswitch', true);
              case 'CCCV'
                control = struct('CCCV', true);
              otherwise
                error('control policy not recognized');
            end

            % This control is used to set up the schedule
            schedule = struct('control', control, 'step', step); 

            %% Setup the initial state of the model
            % The initial state of the model is dispatched using the
            % model.setupInitialState()method. 
            initstate = model.setupInitialState(); 

            %% Setup the properties of the nonlinear solver 
            nls = NonLinearSolver(); 
            % Change default maximum iteration number in nonlinear solver
            nls.maxIterations = 10; 
            % Change default behavior of nonlinear solver, in case of error
            NLS.errorOnFailure = false; 
            nls.timeStepSelector=StateChangeTimeStepSelector('TargetProps', {{'Control','E'}}, 'targetChangeAbs', 0.03);
            % Change default tolerance for nonlinear solver
            model.nonlinearTolerance = 1e-3*model.Control.Imax;
            % Set verbosity
            model.verbose = true;

            %% Run the simulation
            [wellSols, states, report] = simulateScheduleAD(initstate, model, schedule, 'OutputMinisteps', true, 'NonLinearSolver', nls); 

            %% Process output and recover the output voltage and current from the output states.
            ind = cellfun(@(x) not(isempty(x)), states); 
            states = states(ind);
            Enew = cellfun(@(x) x.Control.E, states); 
            Inew = cellfun(@(x) x.Control.I, states);
            Tmax = cellfun(@(x) max(x.ThermalModel.T), states);
            % [SOCN, SOCP] =  cellfun(@(x) model.calculateSOC(x), states);
            time = cellfun(@(x) x.time, states); 
            
        end
        
    end

    methods (Test)

        function testBattery(test, jsonfile, controlPolicy, use_thermal, include_current_collector, diffusionmodel)

            switch diffusionmodel
              case 'full'
                useSimplifiedDiffusionModel = false;
              case 'simplified'
                useSimplifiedDiffusionModel = true;
            end
            
            states = test1d(test, jsonfile, controlPolicy, use_thermal, include_current_collector, useSimplifiedDiffusionModel);
            verifyStruct(test, states{end}, sprintf('TestBattery1D%s', controlPolicy));
            
        end

    end
    
end

%{
Copyright 2009-2022 SINTEF Digital, Mathematics & Cybernetics.

This file is part of The MATLAB Reservoir Simulation Toolbox (MRST).

MRST is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

MRST is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with MRST.  If not, see <http://www.gnu.org/licenses/>.
%}
