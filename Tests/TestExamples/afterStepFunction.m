function  [model, states, reports, solver, ok] = afterStepFunction(model, states, reports, solver, schedule, simtime)

    fprintf('In afterStepFunction:\n');
    fprintf('model %s\n', obj2hash(model));
    fprintf('states %s\n', obj2hash(states));
    fprintf('solver %s\n', obj2hash(solver));
    fprintf('schedule %s\n', obj2hash(schedule));
    fprintf('simtime %s\n', obj2hash(simtime));

    ok = 1;

end
