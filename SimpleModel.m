classdef SimpleModel < PhysicalModel
    
    properties
        modelname
        isnamespaceroot
        namespace
        
        varnames
        pvarnames
        
    end
    
    
    methods
        function model = SimpleModel(modelname, varargin)
            model = model@PhysicalModel([]);
            model = merge_options(model, varargin{:});
            model.modelname = modelname;
            model.namespace = {model.getModelName()};
        end

        function state = validateState(model, state)
            
            varnames = model.getVarNames();
            
            for i = 1 : numel(varnames)
                varname = varnames{i};
                name = varname.fullname;
                if ~isfield(state, name)
                    state.(name) = [];
                end
            end
            
        end
        
        function modelname = getModelName(model);
            modelname = model.modelname;
        end
        
        function varnames = getModelPrimaryVarNames(model)
        % List the primary variables. For SimpleModel the variable names only consist of those declared in the model (no child)
            varnames = model.pvarnames;
        end
        
        
        function varnames = getModelVarNames(model)
        % List the variable names (primary variables are handled separately). For SimpleModel the variable names only consist of
        % those declared in the model (no child)
            varnames = model.varnames;
        end
        
        function varnames = getVarNames(model)
        % Collect all the variable names (primary and the others). External variable names can be added there
            varnames1 = model.getModelPrimaryVarNames;
            varnames2 = model.getModelVarNames;
            varnames = horzcat(varnames1, varnames2);
        end

        function names = getPrimaryVarNames(model)
        % Returns full primary variable names (i.e. including namespaces)
            varnames = model.getModelPrimaryVarNames();
            names = model.addNameSpace(namespaces, names);
        end
        
        function names = getFullVarNames(model)
        % Returns full names (i.e. including namespaces)
            varnames = model.getVarNames();
            names = model.addNameSpace(namespaces, names);
        end

        
        function fullnames = addNameSpace(model, varnames)
        % Return a name (string) which identify uniquely the pair (namespace, name). This is handled here by adding "_" at the
        % end of the namespace and join it to the name.
            if iscell(names)
                for ind = 1 : numel(namespaces)
                    fullnames{ind} = model.addNameSpace(namespaces{ind}, names{ind});
                end
            else
                fullnames = varnames.join();
            end
        end
        
        function [fn, index] = getVariableField(model, name, varargin)
        % In this function the variable name is associated to a field name (fn) which corresponds to the field where the
        % variable is stored in the state.  See PhysicalModel
            
            if isa(name, 'VarName')
                fn = name.fullname();
            elseif iscell(name)
                name = join({model.namespace{:}, name{:}}, '_');
                fn = name{1};
            else
                % search in the local name
                varnames = model.getVarNames();
                for i = 1 : numel(varnames)
                    if strcmp(name, varnames{i}.name)
                        fn = varnames{i}.fullname;
                    end
                end
            end

            index = 1;
            
        end

        function varnames = assignCurrentNameSpace(model, names)
        % utility function which returns a cell consisting of the current model namespace with the same size as names.
            namespace = model.namespace;
            n = numel(names);
            for ind = 1 : n
                varnames{ind} = VarName(namespace, names{ind});
            end
        end
        
    end

end