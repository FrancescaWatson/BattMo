classdef CurrentCollectorInputParams < ElectronicComponentInputParams
%
% Input parameter class for :class:`CurrentCollector <Electrochemistry.CurrentCollector>`
%
    properties
        
        couplingTerm % coupling term specification of the current collector (with external stimulation)

        thermalConductivity % Thermal conductivity of current collector
        heatCapacity % Heat capacity of current collector

        density % Density of current collector [kg m^-3]
    end
    
    methods
        
        function paramobj = CurrentCollectorInputParams(jsonstruct);
            paramobj = paramobj@ElectronicComponentInputParams(jsonstruct);
            paramobj.couplingTerm = struct();
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
