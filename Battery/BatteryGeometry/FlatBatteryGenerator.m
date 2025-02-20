classdef FlatBatteryGenerator < SpiralBatteryGenerator

    properties
        depth
    end
    
    methods
        
        function gen = FlatBatteryGenerator()
            gen = gen@SpiralBatteryGenerator();  
        end
        
        function [paramobj, gen] = setupGrid(gen, paramobj, params)
    
            gen = flatGrid(gen);
            paramobj.G = gen.G;
            
        end

        function [paramobj, gen] = updateBatteryInputParams(gen, paramobj, params)
                    
            gen.nwindings = params.nwindings;
            gen.depth     = params.depth;
            gen.widthDict = params.widthDict;
            gen.nrDict    = params.nrDict;
            gen.nas       = params.nas;
            gen.L         = params.L;
            gen.nL        = params.nL;
            
            paramobj = gen.setupBatteryInputParams(paramobj, []);
            
        end
        
    end
    
end


%{
Copyright 2021-2023 SINTEF Industry, Sustainable Energy Technology
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
