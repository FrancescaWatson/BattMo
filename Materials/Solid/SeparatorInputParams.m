classdef SeparatorInputParams < ComponentInputParams
%
% Input class for :class:`Separator <Electrochemistry.Separator>`
%    
    properties
        
        thickness
        porosity
        rp
        Gurley
        
        thermalConductivity
        heatCapacity
        
    end
    
    methods

        function paramobj = SeparatorInputParams(jsonstruct)
            paramobj = paramobj@ComponentInputParams(jsonstruct);
        end
        
    end
    
    
end