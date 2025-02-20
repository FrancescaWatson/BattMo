function jsonstruct = mergeJsonStructs(jsonstructs, varargin)
% - We call a json structure (abbreviated jsonstruct) a MATLAB structure of the form that are produced by the jsondecode command
% - The input jsonstructs is list jsonstruct
% - The command mergeJsonStructs merges recursively all the jsonstruct contained in the list jsonstructs
% - If two jsonstruct assign the same field, then the first one is applied and a warning message is sent. use warn=false to switch off message

    opt = struct('warn', true);
    opt.tree = {};
    opt = merge_options(opt, varargin{:});

    % needed to produce meaningfull error message
    tree = opt.tree;
    
    if numel(jsonstructs) == 1
        jsonstruct = jsonstructs{1};
        return;
    end
    
    jsonstruct1 = jsonstructs{1};
    jsonstruct2 = jsonstructs{2};
    if numel(jsonstructs) >= 2
        jsonstructrests = jsonstructs(3 : end);
    else
        jsonstructrests = {};
    end

    fds1 = fieldnames(jsonstruct1);
    fds2 = fieldnames(jsonstruct2);

    jsonstruct = jsonstruct1;

    for ifd2 = 1 : numel(fds2)
        
        fd2 = fds2{ifd2};
        
        if ~ismember(fd2, fds1)
            % ok, add the substructure
            jsonstruct.(fd2) = jsonstruct2.(fd2);
        else
            if isstruct(jsonstruct.(fd2)) && isstruct(jsonstruct2.(fd2))
                % we have to check the substructure
                subtree = tree;
                subtree{end + 1} = fd2;
                subjsonstruct = mergeJsonStructs({jsonstruct.(fd2), jsonstruct2.(fd2)}, 'warn', opt.warn, 'tree', subtree);
                jsonstruct.(fd2) = subjsonstruct;
            elseif ~isstruct(jsonstruct.(fd2)) && ~isstruct(jsonstruct2.(fd2)) && isequal(jsonstruct.(fd2), jsonstruct2.(fd2))
                % ok. Both are given but same values
            elseif opt.warn
                varname = horzcat(tree, fd2);
                fprintf('parameter %s is assigned twice with different values. we use the value from first jsonstruct.\n', strjoin(varname, '.'));
            end
        end
    end

    if ~isempty(jsonstructrests)
        jsonstruct = mergeJsonStructs({jsonstruct, jsonstructrests{:}}, 'warn', opt.warn, 'tree', {});
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
