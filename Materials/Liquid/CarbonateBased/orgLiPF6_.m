classdef orgLiPF6_ < Electrolyte_

    methods

        function model = orgLiPF6_(name)

            model = model@Electrolyte_(name);

            model = model.setAlias({'Li'      , 'chargeCarrier')});
            model = model.setAlias({'LiSource', 'chargeCarrierSource')});
            model = model.setAlias({'LiFlux'  , 'chargeCarrierFlux')});
            model = model.setAlias({'LiAccum' , 'chargeCarrierAccum')});
            
            fn = @orgLiPF6.updateCurrent;
            inputnames = {'Li', 'T', 'phi'};
            fnmodel = {'.'};
            model = model.addPropFunction('j', fn, inputnames, fnmodel);
            
            fn = @orgLiPF6.updateLithiumFlux;
            inputnames = {'Li', 'j', 'T'};
            fnmodel = {'.'};
            model = model.addPropFunction('LiFlux', fn, inputnames, fnmodel);        

            
            
        end
        
    end

end