function [OCP, dUdT] = updateOCPFunc_nmc111(c, T, cmax)
    
    Tref = 298.15;  % [K]

    theta = c./cmax;
    
    coeff1_refOCP = [ -4.656   , ...
                      0        , ...
                      + 88.669 , ...
                      0        , ...
                      - 401.119, ...
                      0        , ...
                      + 342.909, ...
                      0        , ...
                      - 462.471, ...
                      0        , ...
                      + 433.434];
    
    coeff2_refOCP =[ -1      , ...
                     0       , ...
                     + 18.933, ...
                     0       , ...
                     - 79.532, ...
                     0       , ...
                     + 37.311, ...
                     0       , ...
                     - 73.083, ...
                     0       , ...
                     + 95.960];
    
    refOCP = polyval(coeff1_refOCP(end:-1:1),theta)./ polyval(coeff2_refOCP(end:-1:1),theta);    
    
    % Calculate the entropy change at the given lithiation
    
    coeff1_dUdT = [0.199521039        , ...
                   - 0.928373822      , ...
                   + 1.364550689000003, ...
                   - 0.611544893999998];
    
    coeff2_dUdT = [1                  , ...
                   - 5.661479886999997, ...
                   + 11.47636191      , ... 
                   - 9.82431213599998 , ...
                   + 3.048755063];
    
    dUdT = -1e-3.*polyval(coeff1_dUdT(end:-1:1),theta)./ polyval(coeff2_dUdT(end:-1:1),theta);
    
    % Calculate the open-circuit potential of the active material
    OCP = refOCP + (T - Tref) .* dUdT;
    
end