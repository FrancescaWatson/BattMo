classdef ElectrolyteInputParams < ElectroChemicalComponentInputParams
%
% Input parameter class for :code:`Electrolyte` model
%    
    properties
        
        compnames % Names of the components in the electrolyte
        sp % Structure given properties of each component
        
        %
        % Input parameter for the separator (:class:`SeparatorInputParams
        % <Electrochemistry.SeparatorInputParams>`)
        %
        Separator
        
        thermalConductivity % Intrinsic Thermal conductivity of the electrolyte
        specificHeatCapacity        % Specific Heat capacity of the electrolyte
        
        
        Conductivity
        DiffusionCoefficient
        
        density % Density [kg m^-3] (Note : only of the liquid part, the density of the separator is given there)

        BruggemanCoefficient
        
    end
    
    methods

        function paramobj = ElectrolyteInputParams(jsonstruct)
            
            paramobj = paramobj@ElectroChemicalComponentInputParams(jsonstruct);
            
            pick = @(fd) pickField(jsonstruct, fd);
            paramobj.Separator = SeparatorInputParams(pick('Separator'));
            
            paramobj.EffectiveElectricalConductivity = 'not used';
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
