classdef FullSolidDiffusionModel < SolidDiffusionModel

    properties

        np  % Number of particles
        N   % Discretization parameters in spherical direction

    end

    methods

        function model = FullSolidDiffusionModel(paramobj)

            model = model@SolidDiffusionModel(paramobj);

            fdnames = {'np'                    , ...
                       'N'};

            model = dispatchParams(model, paramobj, fdnames);
            model.operators = model.setupOperators();
            
        end

        function model = registerVarAndPropfuncNames(model)

            %% Declaration of the Dynamical Variables and Function of the model
            % (setup of varnameList and propertyFunctionList)

            model = registerVarAndPropfuncNames@SolidDiffusionModel(model);
                        
            varnames = {};
            % concentration
            varnames{end + 1} = 'c';
            % surface concentration
            varnames{end + 1} = 'cSurface';
            % Mass accumulation term
            varnames{end + 1} = 'massAccum';
            % flux term
            varnames{end + 1} = 'flux';
            % Mass source term
            varnames{end + 1} = 'massSource';
            % Mass conservation equation
            varnames{end + 1} = 'massCons';
            % Mass conservation equation
            varnames{end + 1} = 'solidDiffusionEq';
            
            model = model.registerVarNames(varnames);

            fn = @FullSolidDiffusionModel.updateFlux;
            inputnames = {'c', 'D'};
            model = model.registerPropFunction({'flux', fn, inputnames});
            
            fn = @FullSolidDiffusionModel.updateMassConservation;
            inputnames = {'massAccum', 'flux', 'massSource'};
            model = model.registerPropFunction({'massCons', fn, inputnames});

            fn = @FullSolidDiffusionModel.updateMassSource;
            model = model.registerPropFunction({'massSource', fn, {'R'}});
            
            fn = @FullSolidDiffusionModel.updateMassAccum;
            model = model.registerPropFunction({'massAccum', fn, {'c'}});
            
            fn = @FullSolidDiffusionModel.assembleSolidDiffusionEquation;
            model = model.registerPropFunction({'solidDiffusionEq', fn, {'c', 'cSurface', 'massSource', 'D'}});
            
        end
        
        function operators = setupOperators(model)
            
            np = model.np;
            N  = model.N;
            rp = model.rp;
            
            celltbl.cells = (1 : np)';
            celltbl = IndexArray(celltbl);

            Scelltbl.Scells = (1 : N)';
            Scelltbl = IndexArray(Scelltbl);

            cellScelltbl = crossIndexArray(celltbl, Scelltbl, {}, 'optpureproduct', true);
            cellScelltbl = sortIndexArray(cellScelltbl, {'cells', 'Scells'});

            endScelltbl.Scells = N;
            endScelltbl = IndexArray(endScelltbl);
            endcellScelltbl = crossIndexArray(cellScelltbl, endScelltbl, {'Scells'});

            G = cartGrid(N, rp); 
            r = G.nodes.coords;

            G.cells.volumes   = 4/3*pi*(r(2 : end).^3 - r(1 : (end - 1)).^3);
            G.cells.centroids = (r(2 : end) + r(1 : (end - 1)))./2;

            G.faces.centroids = r;
            G.faces.areas     = 4*pi*r.^2;
            G.faces.normals   = G.faces.areas;

            rock.perm = ones(N, 1);
            rock.poro = ones(N, 1);

            op = setupOperatorsTPFA(G, rock);
            C = op.C;
            T = op.T;
            T_all = op.T_all;

            % We use that we know *apriori* the indexing given by cartGrid
            Tbc = T_all(N); % half-transmissibility for of the boundary face
            Tbc = repmat(Tbc, np, 1);
            
            Sfacetbl.Sfaces = (1 : (N - 1))'; % index of the internal faces (correspond to image of C')
            Sfacetbl = IndexArray(Sfacetbl);
            cellSfacetbl = crossIndexArray(celltbl, Sfacetbl, {}, 'optpureproduct', true);
            
            Grad = -diag(T)*C;

            [i, j, grad] = find(Grad);
            ScellSfacetbl.Sfaces = i;
            ScellSfacetbl.Scells = j;
            ScellSfacetbl = IndexArray(ScellSfacetbl);

            cellScellSfacetbl = crossIndexArray(celltbl, ScellSfacetbl, {}, 'optpureproduct', true);

            map = TensorMap();
            map.fromTbl = ScellSfacetbl;
            map.toTbl = cellScellSfacetbl;
            map.mergefds = {'Scells', 'Sfaces'};
            map = map.setup();

            grad = map.eval(grad);

            prod = TensorProd();
            prod.tbl1 = cellScellSfacetbl;
            prod.tbl2 = cellScelltbl;
            prod.tbl3 = cellSfacetbl;
            prod.mergefds = {'cells'};
            prod.reducefds = {'Scells'};

            Grad = SparseTensor();
            Grad = Grad.setFromTensorProd(grad, prod);
            Grad = Grad.getMatrix();

            map = TensorMap();
            map.fromTbl = celltbl;
            map.toTbl = cellSfacetbl;
            map.mergefds = {'cells'};
            map = map.setup();

            flux = @(D, c) - map.eval(D).*(Grad*c);

            [i, j, d] = find(C');

            clear ScellSfacetbl
            ScellSfacetbl.Scells = i;
            ScellSfacetbl.Sfaces = j;
            ScellSfacetbl = IndexArray(ScellSfacetbl);

            cellScellSfacetbl = crossIndexArray(celltbl, ScellSfacetbl, {}, 'optpureproduct', true);

            map = TensorMap();
            map.fromTbl = ScellSfacetbl;
            map.toTbl = cellScellSfacetbl;
            map.mergefds = {'Scells', 'Sfaces'};
            map = map.setup();

            d = map.eval(d);

            prod = TensorProd();
            prod.tbl1 = cellScellSfacetbl;
            prod.tbl2 = cellSfacetbl;
            prod.tbl3 = cellScelltbl;
            prod.mergefds = {'cells'};
            prod.reducefds = {'Sfaces'};
            prod = prod.setup();

            divMat = SparseTensor();
            divMat = divMat.setFromTensorProd(d, prod);
            divMat = divMat.getMatrix();

            div = @(u) divMat*u;

            %% External flux map (from the boundary conditions)

            map = TensorMap();
            map.fromTbl = endcellScelltbl;
            map.toTbl = cellScelltbl;
            map.mergefds = {'cells', 'Scells'};
            map = map.setup();

            f = map.eval(ones(endcellScelltbl.num, 1));

            prod = TensorProd();
            prod.tbl1 = cellScelltbl;
            prod.tbl2 = celltbl;
            prod.tbl3 = cellScelltbl;
            prod.mergefds = {'cells'};

            mapFromBc = SparseTensor();
            mapFromBc = mapFromBc.setFromTensorProd(f, prod);
            mapFromBc = mapFromBc.getMatrix();

            mapToBc = mapFromBc';
            
            %% map from cell (celltbl) to cell-particle (cellScelltbl)
            map = TensorMap();
            map.fromTbl = celltbl;
            map.toTbl = cellScelltbl;
            map.mergefds = {'cells'};
            map = map.setup();

            mapToParticle = SparseTensor();
            mapToParticle = mapToParticle.setFromTensorMap(map);
            mapToParticle = mapToParticle.getMatrix();
            
            vols = G.cells.volumes;

            map = TensorMap();
            map.fromTbl = Scelltbl;
            map.toTbl = cellScelltbl;
            map.mergefds = {'Scells'};
            map = map.setup();

            vols = map.eval(vols);

            operators = struct('div'      , div       , ...
                               'flux'     , flux      , ...
                               'mapFromBc', mapFromBc , ...
                               'mapToParticle', mapToParticle, ...
                               'mapToBc'  , mapToBc   , ...
                               'Tbc'      , Tbc       , ...
                               'vols'     , vols);
            
        end

        function state = updateMassSource(model, state)
            
            op = model.operators;
            rp = model.rp;
            vsa = model.volumetricSurfaceArea;
            
            Rvol = state.Rvol;

            Rvol = op.mapFromBc*Rvol;
            
            state.massSource = -Rvol*((4*pi*rp^2)/vsa);
            
        end
        
        function state = updateMassAccum(model, state, state0, dt)

            op = model.operators;
            
            c = state.c;
            c0 = state0.c;
            
            state.massAccum = 1/dt*op.vols.*(c - c0);
            
        end
        
        function state = updateMassConservation(model, state)
           
            op = model.operators;
            
            flux       = state.flux;
            massSource = state.massSource;
            massAccum  = state.massAccum;
            
            state.massCons = massAccum + op.div(flux) - massSource;

        end
        
        function state = updateFlux(model, state)
            
            op = model.operators;
            
            c = state.c;
            D = state.D;
            
            state.flux = op.flux(D, c);
            
        end
    
        function state = assembleSolidDiffusionEquation(model, state)
            
        %% TODO : change name of this function
            op = model.operators;

            c     = state.c;
            D     = state.D;
            cSurf = state.cSurface;
            src   = state.massSource;

            %% TODO fix this operaton. Implement better dispatch
            D = op.mapToParticle*D;
            D = op.mapToBc*D;
            
            eq = D.*op.Tbc.*(op.mapToBc*c - cSurf) + op.mapToBc*src;
            
            state.solidDiffusionEq = eq;
            
        end
        
        
    end
    
end


%{
Copyright 2021-2022 SINTEF Industry, Sustainable Energy Technology
and SINTEF Digital, Mathematics & Cybernetics.

This file is part of The Battery Modeling Toolbox BattMo

BattMo is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

BattMo is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with BattMo.  If not, see <http://www.gnu.org/licenses/>.
%}
    
