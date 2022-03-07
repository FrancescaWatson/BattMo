classdef ThermalComponent < BaseModel
    
    properties
        
       EffectiveThermalConductivity
       EffectiveHeatCapacity % in [J][K]^-1[m]^-3

       couplingTerm
       externalHeatTransferCoefficient
       externalTemperature
       
       bcfacecellmap
       bccells
       
    end
    
    methods
        
        function model = ThermalComponent(paramobj)
            
            model = model@BaseModel();
            
            % OBS : All the models should have same backend (this is not assigned automaticallly for the moment)
            model.AutoDiffBackend = SparseAutoDiffBackend('useBlocks', false);
            
            fdnames = {'G', ...
                       'EffectiveThermalConductivity', ...
                       'EffectiveHeatCapacity', ...
                       'couplingTerm', ...
                       'externalHeatTransferCoefficient', ...
                       'externalTemperature'};
            model = dispatchParams(model, paramobj, fdnames);
            
            % setup discrete differential operators
            model.operators = localSetupOperators(model.G);
            
            if ~isempty(model.EffectiveThermalConductivity)
                nc = model.G.cells.num;
                model.EffectiveThermalConductivity = model.EffectiveThermalConductivity*ones(nc, 1);
                model.EffectiveHeatCapacity = model.EffectiveHeatCapacity*ones(nc, 1);
            end
            
            model = setupMapping(model);

            model = model.registerVarAndPropfuncNames();
                    
        end
        
        function model = registerVarAndPropfuncNames(model)
            %% Declaration of the Dynamical Variables and Function of the model
            % (setup of varnameList and propertyFunctionList)

            varnames = {'T', ...
                        'jHeatBcSource'       , ...
                        'jHeatOhmSource'      , ...
                        'jHeatChemicalSource' , ...
                        'jHeatReactionSource' , ...
                        'jHeatSource'         , ...
                        'jHeat'               , ...
                        'accumHeat'           , ...
                        'energyCons'};

            model = model.registerVarNames(varnames);
            
            fn = @ThermalComponent.updateHeatFlux;
            model = model.registerPropFunction({'jHeat', fn, {'T'}});
            
            fn = @ThermalComponent.updateHeatSourceTerm;
            inputnames = {'jHeatOhmSource', ...
                          'jHeatChemicalSource', ...
                          'jHeatReactionSource'};
            model = model.registerPropFunction({'jHeatSource', fn, inputnames});
            
            fn = @ThermalComponent.updateEnergyConservation;
            inputnames = {'jHeatBcSource', ...
                          'jHeatSource'  , ...
                          'jHeat'        , ...
                          'accumHeat'};
            model = model.registerPropFunction({'energyCons', fn, inputnames});
            
        end
        
        function model = setupMapping(model)
        % Aggregate face contribution to cell
            
            if isempty(model.couplingTerm.couplingfaces)
                % this corresponds the the 1D case where the heat transfer with the exterior is given as a volumetric transfer and not a
                % transfer across external faces
                model.bccells = model.couplingTerm.couplingcells;
                model.bcfacecellmap = speye(numel(model.bccells));
                
            else
                bccellfacetbl.cells = model.couplingTerm.couplingcells;
                bccellfacetbl.faces = model.couplingTerm.couplingfaces;
                bccellfacetbl = IndexArray(bccellfacetbl);
                bccelltbl = projIndexArray(bccellfacetbl, {'cells'});
                
                map = TensorMap();
                map.fromTbl = bccellfacetbl;
                map.toTbl = bccelltbl;
                map.mergefds = {'cells'};
                
                bcfacecellmap = SparseTensor();
                bcfacecellmap = bcfacecellmap.setFromTensorMap(map);
                bcfacecellmap = bcfacecellmap.getMatrix();
                
                model.bcfacecellmap = bcfacecellmap;
                model.bccells = bccelltbl.get('cells');
            end
            
        end
        
            
            
        function state = updateHeatFlux(model, state)

            k = model.EffectiveThermalConductivity;
            T = state.T;
            
            jHeat = assembleFlux(model, T, k); 

            state.jHeat = jHeat;
            
        end
        
        function state = updateHeatSourceTerm(model, state)
        % sum up the heat source terms
            state.jHeatSource = state.jHeatOhmSource + state.jHeatChemicalSource + state.jHeatReactionSource;
            
        end
            
        function state = updateEnergyConservation(model, state)
        % Here, we assume that the fields are updated
        % - jHeatBcSource
        % - jHeatSource 
        % - accumHeat
            
            state = model.updateHeatFlux(state);
            
            flux     = state.jHeat;
            bcsource = state.jHeatBcSource;
            source   = state.jHeatSource;
            accum    = state.accumHeat;
            
            energyCons = assembleConservationEquation(model, flux, bcsource, source, accum);
            
            state.energyCons = energyCons;
            
        end

        function state = updateThermalBoundarySourceTerms(model, state)

            G          = model.G;
            coupterm   = model.couplingTerm;
            T_ext      = model.externalTemperature;
            lambda_ext = model.externalHeatTransferCoefficient;
            lambda     = model.EffectiveThermalConductivity;
            
            coupcells = coupterm.couplingcells;
            coupfaces = coupterm.couplingfaces;
            nc = model.G.cells.num;
              
            T = state.T;
            T = T(coupcells);
            
            if isempty(coupfaces)
                % 1D case (External faces are not available, we consider a volumetric cooling instead)
                A = G.cells.volumes(coupcells);
                t_eff = lambda_ext*A;
            else
                % Face couling (multidimensional case)
                A = G.faces.areas(coupfaces);
                t_ext = lambda_ext.*A;
                
                t = model.operators.harmFaceBC(lambda, coupfaces);
                
                t_eff = 1./(1./t + 1./t_ext);
            end
            
            jHeatBcSource = zeros(nc, 1);
            if isa(T, 'ADI')
                adsample = getSampleAD(T);
                adbackend = model.AutoDiffBackend;
                jHeatBcSource = adbackend.convertToAD(jHeatBcSource, adsample);
            end
            
            jHeatBcSource(model.bccells) = model.bcfacecellmap*(t_eff.*(T_ext - T));
            
            state.jHeatBcSource = jHeatBcSource;
            
        end
        
    end
    
end




%{
Copyright 2009-2021 SINTEF Industry, Sustainable Energy Technology
and SINTEF Digital, Mathematics & Cybernetics.

This file is part of The Battery Modeling Toolbox BatMo

BatMo is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

BatMo is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with BatMo.  If not, see <http://www.gnu.org/licenses/>.
%}
