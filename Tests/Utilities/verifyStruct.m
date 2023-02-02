function verifyStruct(testCase, state, refstate)


    import matlab.unittest.constraints.IsEqualTo
    import matlab.unittest.constraints.RelativeTolerance

    % Compare each data point in state with refstate
    reltol = 1e-6;
    state.Control.E
    refstate.Control.E
    testCase.assertThat(state, IsEqualTo(refstate, ...
                                         'Within', RelativeTolerance(reltol)));

end
