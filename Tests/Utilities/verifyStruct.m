function verifyStruct(testCase, state, refstate)


    import matlab.unittest.constraints.IsEqualTo
    import matlab.unittest.constraints.RelativeTolerance

    % Compare each data point in state with refstate
    reltol = 1e-5;
    fprintf('state.Control.E %f\n', state.Control.E);
    fprintf('refstate.Control.E %f\n', refstate.Control.E);
    testCase.assertThat(state, IsEqualTo(refstate, ...
                                         'Within', RelativeTolerance(reltol)));

end
