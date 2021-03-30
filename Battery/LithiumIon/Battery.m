classdef Battery < PhysicalModel

    properties
        
        con = PhysicalConstants();

        % Temperature and SOC
        % for the moment here, for convenience. Will be moved
        T
        SOC

        % Input current
        J
        % Voltage cut
        Ucut

        % Components
        Electrolyte
        NegativeElectrode
        PositiveElectrode
    
        couplingTerms
        
    end
    
    methods
        
        function model = Battery(paramobj)
        % Shorcuts used here
        % elyte : Electrolyte
        % ne : NegativeElectrode
        % pe : PositiveElectrode
            
            model = model@PhysicalModel([]);
            
            model.AutoDiffBackend = SparseAutoDiffBackend('useBlocks',true);
            
            %% Setup the model using the input parameters
            fdnames = {'G', ...
                       'couplingTerms', ...
                       'T'  , ...
                       'SOC', ...
                       'J'  , ...
                       'Ucut'};
            
            model = dispatchParams(model, paramobj, fdnames);
            
            % Assign the components : Electrolyte, NegativeElectrode, PositiveElectrode
            model.Electrolyte       = Electrolyte(paramobj.elyte);
            model.NegativeElectrode = Electrode(paramobj.ne);
            model.PositiveElectrode = Electrode(paramobj.pe);
            
        end
    
        function [problem, state] = getEquations(model, state0, state,dt, drivingForces, varargin)
            
            time = state0.time + dt;
            state = model.initStateAD(state);
            
            %% for now temperature and SOC are kept constant
            nc = model.G.cells.num;
            state.T   = model.T*ones(nc, 1);
            state.SOC = model.SOC*ones(nc, 1);
            
            % Shortcuts
            battery = model;
            ne      = 'NegativeElectrode';
            pe      = 'PositiveElectrode';
            eac     = 'ElectrodeActiveComponent';
            cc      = 'CurrentCollector';
            elyte   = 'Electrolyte';

            automaticAssembly;
            
            %% Set up the governing equations
            
            eqs={};
            
            %% We collect mass and charge conservation equations for the electrolyte and the electrodes

            names = {'Electrolyte', 'NegativeElectrode', 'PositiveElectrode'};
            
            for i = 1 : numel(names)
                eqs{end + 1} = model.getProp(state,{names{i}, 'massCons'});
                eqs{end + 1} = model.getProp(state,{names{i}, 'chargeCons'});
            end
            
            %% We collect charge conservation equations for the current collectors
            
            names = {'NegativeCurrentCollector', 'PositiveCurrentCollector'};
            for i = 1 : numel(names)
                eqs{end + 1} = model.getProp(state, {names{i}, 'chargeCons'});
            end
            
            %% We setup and add the control equation (fixed total current at PositiveCurrentCollector)
            
            src = drivingForces.src(time);
            coupterm = model.getCoupTerm('bc-PositiveCurrentCollector');
            faces = coupterm.couplingfaces;
            bcval = state.PositiveCurrentCollector.E;
            cond_pcc = model.PositiveCurrentCollector.EffectiveElectronicConductivity;
            [trans_pcc, cells] = model.PositiveCurrentCollector.operators.harmFaceBC(cond_pcc, faces);
            control = src - sum(trans_pcc.*(bcval - state.PositiveCurrentCollector.phi(cells)));
            
            eqs{end+1} = -control;


            
        end

        function state = updateT(model, state)
            names = {'NegativeElectrode', 'PositiveElectrode', 'Electrolyte'};
            for ind = 1 : numel(names);
                name = names{ind};
                nc = model.(name).G.cells.num;
                state.(name).T = state.T(1)*ones(nc, 1);
            end
        end
        
        function initstate = setupInitialState(model)
        % Setup initial state
        %
        % Abbreviations used in this function 
        % elyte : Electrolyte
        % ne    : NegativeElectrode
        % pe    : PositiveElectrode
        % eac   : ElectrodeActiveComponent
        % cc    : CurrentCollector
            
            nc = model.G.cells.num;

            SOC = model.SOC;
            T   = model.T;
            
            initstate.T   =  T*ones(nc, 1);
            initstate.SOC =  SOC*ones(nc, 1);
            
            bat = model;
            elyte = 'Electrolyte';
            ne    = 'NegativeElectrode';
            pe    = 'PositiveElectrode';
            am    = 'ActiveMaterial';
            eac   = 'ElectrodeActiveComponent';
            cc    = 'CurrentCollector';
            
            %% synchronize temperatures
            initstate = model.updateT(initstate);
            initstate.(ne) = bat.(ne).updateT(initstate.(ne));
            initstate.(ne).(eac) = bat.(ne).(eac).updateT(initstate.(ne).(eac));
            initstate.(pe) = bat.(pe).updateT(initstate.(pe));
            initstate.(pe).(eac) = bat.(pe).(eac).updateT(initstate.(pe).(eac));
            
            %% setup initial NegativeElectrode state
            
            % shortcut
            % negAm : ActiveMaterial of the negative electrode
            
            negAm = bat.(ne).(eac).(am); 
            
            m = (1 ./ (negAm.theta100 - negAm.theta0));
            b = -m .* negAm.theta0;
            theta = (SOC - b) ./ m;
            c = theta .* negAm.Li.cmax;
            c = c*ones(negAm.G.cells.num, 1);

            initstate.(ne).(eac).(am).Li = c;
            initstate.(ne).(eac).(am) = negAm.updateMaterialProperties(initstate.(ne).(eac).(am));

            OCP = initstate.(ne).(eac).(am).OCP;
            initstate.(ne).(eac).(am).phi = OCP;

            %% setup initial PositiveElectrode state

            % shortcut
            % posAm : ActiveMaterial of the positive electrode
            
            posAm = bat.(pe).(eac).(am);
            
            m = (1 ./ (posAm.theta100 - posAm.theta0));
            b = -m .* posAm.theta0;
            theta = (SOC - b) ./ m;
            c = theta .* posAm.Li.cmax;
            c = c*ones(posAm.G.cells.num, 1);

            initstate.(pe).(eac).(am).Li = c;
            initstate.(pe).(eac).(am) = posAm.updateMaterialProperties(initstate.(pe).(eac).(am));

            OCP = initstate.(pe).(eac).(am).OCP;
            initstate.(pe).(eac).(am).phi = OCP;

            %% setup initial Electrolyte state

            initstate.(elyte).phi = zeros(bat.(elyte).G.cells.num, 1);
            cs = cell(2,1);
            initstate.(elyte).cs = cs;
            initstate.(elyte).cs{1} = 1000*ones(bat.(elyte).G.cells.num, 1);

            %% setup initial Current collectors state

            OCP = initstate.(ne).(eac).(am).OCP;
            OCP = OCP(1) .* ones(bat.(ne).(cc).G.cells.num, 1);
            initstate.(ne).(cc).phi = OCP;

            OCP = initstate.(pe).(eac).(am).OCP;
            OCP = OCP(1) .* ones(bat.(pe).(cc).G.cells.num, 1);
            initstate.(pe).(cc).phi = OCP;
            
            initstate.(pe).(cc).E = OCP(1);
            
        end
        
        function state = setupElectrolyteCoupling(model, state)
        % Setup the electrolyte coupling by adding ion sources from the electrodes
        % shortcuts:
        % elyte : Electrolyte
        % ne : NegativeElectrode
        % pe : PositiveElectrode
            
            elyte = model.Electrolyte;
            ionSourceName = elyte.ionSourceName;
            coupterms = model.couplingTerms;
            
            phi = state.Electrolyte.phi;
            if isa(phi, 'ADI')
                adsample = getSampleAD(phi);
                adbackend = model.AutoDiffBackend;
                elyte_Li_source = adbackend.convertToAD(elyte_Li_source, adsample);
            end
            
            ne_R = state.NegativeElectrode.ElectrodeActiveComponent.ActiveMaterial.R;
            coupterm = getCoupTerm(couplingterms, 'NegativeElectrode-Electrolyte');
            elytecells = coupterm.couplingcells(:, 2);
            elyte_Li_source(elytecells) = ne_R;            
            
            pe_R = state.PositiveElectrode.ElectrodeActiveComponent.ActiveMaterial.R;
            coupterm = getCoupTerm(couplingterms, 'PositiveElectrode-Electrolyte');
            elytecells = coupterm.couplingcells(:, 2);
            elyte_Li_source(elytecells) = pe_R;
            
            state.Electrolyte.(ionSourceName) = elyte_Li_source;
        
        end
        
        
        function state = setupElectrodeCoupling(model, state)
        % Setup electrod coupling by updating the potential and concentration of the electrolyte in the active component of the
        % electrode. There, those quantities are considered as input and used to compute the reaction rate.
        %
        %
        % WARNING : at the moment, we do not pass the concentrations
        %
        % shortcuts:
        % elyte : Electrolyte
        % neac  : NegativeElectrode.ElectrodeActiveComponent 
        % peac  : PositiveElectrode.ElectrodeActiveComponent
            
            elyte = model.Electrolyte;
            neac = model.NegativeElectrode.ElectrodeActiveComponent;
            peac = model.PositiveElectrode.ElectrodeActiveComponent;
            
            phi_elyte = state.Electrolyte.phi;
            
            elyte_cells = zeros(model.G.cells.num, 1);
            elyte_cells(elyte.G.mappings.cellmap) = (1 : elyte.G.cells.num)';

            phi_elyte_neac = phi_elyte(elyte_cells(neac.G.mappings.cellmap));
            phi_elyte_peac = phi_elyte(elyte_cells(peac.G.mappings.cellmap));

            state.NegativeElectrode.ElectrodeActiveComponent.phiElectrolyte = phi_elyte_neac;
            state.PositiveElectrode.ElectrodeActiveComponent.phiElectrolyte = phi_elyte_peac;
            
        end
        
        
    end
    
end
