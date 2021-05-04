classdef ElectrodeActiveComponentInputParams < ElectroChemicalComponentInputParams
 
    properties
        
        %% parameters for the electrode components
        % shortcut used here
        % am : ActiveMaterial parameters (class ActiveMaterialInputParams)
        am
        amName
                
        thermalConductivity
        heatCapacity
        
    end

    methods

        function paramobj = ElectrodeActiveComponentInputParams()
            paramobj = paramobj@ElectroChemicalComponentInputParams();
            paramobj.am = ActiveMaterialInputParams();
            paramobj.amName = char();
            paramobj.EffectiveElectricalConductivity = 'not used';
        end
        
    end
    
end
