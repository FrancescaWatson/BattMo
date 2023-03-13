function  [model, states, reports, solver, ok] = afterStepFunction(model, states, reports, solver, schedule, simtime)

    fprintf('In afterStepFunction:\n');
    fprintf('model %s\n', obj2hash(model));
    fprintf('states %s\n', obj2hash(states));
    fprintf('solver %s\n', obj2hash(solver));
    fprintf('schedule %s\n', obj2hash(schedule));

    ok = 1;

    ind = cellfun(@(x) not(isempty(x)), states);
    %states = states(ind);
    %state = states{end};
    reports = reports(ind);
    report = reports{end};

    report
    report.StepReports{1}
    report.StepReports{1}.NonlinearReport{:}


    fprintf('\n\n---------------------------------------------------\n\n\n');

end
