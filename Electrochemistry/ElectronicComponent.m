classdef ElectronicComponent < BaseModel
    
    properties
        
        EffectiveElectricalConductivity % Effective electrical conductivity
        constants
        
    end

    methods
        
        function model = ElectronicComponent(paramobj)
        % Here, :code:`paramobj` is instance of :class:`ElectronicComponentInputParams <Electrochemistry.ElectronicComponentInputParams>`
            
            model = model@BaseModel();

            % OBS : All the models should have same backend (this is not assigned automaticallly for the moment)
            model.AutoDiffBackend = SparseAutoDiffBackend('useBlocks', false);
            
            fdnames = {'G', ...
                       'EffectiveElectricalConductivity'};
            
            model = dispatchParams(model, paramobj, fdnames);
            
            % setup discrete differential operators
            model.operators = localSetupOperators(model.G, 'assembleCellFluxOperator', true);
            
            model.constants = PhysicalConstants();
            
        end


        function state = updateFaceCurrent(model, state)
            
            G = model.G;
            nf = G.faces.num;
            intfaces = model.operators.internalConn;
            
            j       = state.j;
            jFaceBc = state.jFaceBc;
            
            zeroFaceAD = model.AutoDiffBackend.convertToAD(zeros(nf, 1), j);
            jFace = zeroFaceAD + jFaceBc;
            jFace(intfaces) = j;
            
            state.jFace = jFace;
            
        end
        
        
        function state = updateCurrent(model, state)
        % Assemble electrical current which is stored in :code:`state.j`
            sigmaeff = model.EffectiveElectricalConductivity;
            phi = state.phi;
            
            j = assembleFlux(model, phi, sigmaeff); 

            state.j = j;
            
        end
        
        function state = updateChargeConservation(model, state)
        % Assemble residual of the charge conservation equation which is stored in :code:`state.chargeCons`
           
            state = model.updateCurrent(state);

            flux   = state.j;
            bcsource = state.jBcSource;
            source = state.eSource;
            accum  = zeros(model.G.cells.num,1);
            
            chargeCons = assembleConservationEquation(model, flux, bcsource, source, accum);
            
            state.chargeCons = chargeCons;
            
        end
        
    end
end

