% Script for running tests using github actions

% Display matlab version
disp(version)

% Debug
testdir = pwd;
[~, res] = system('git rev-parse --short HEAD');
fprintf('%s %s', pwd, res);

dirs = {'autodiff', 'core', 'model-io', 'solvers', 'visualization'};
for k = 1:numel(dirs)
    cd(sprintf('../MRST/mrst-%s', dirs{k}));
    [~, res] = system('git rev-parse --short HEAD');
    fprintf('%s %s', pwd, res);
    cd(testdir)
end

% Setup BattMo
global MRST_BATCH
MRST_BATCH = true;

run('../startupBattMo.m')

mrstSettings('set', 'useMEX', false);

mrstModule add ad-core mpfa

% Setup tests
import matlab.unittest.TestSuite;
import matlab.unittest.selectors.HasParameter;
import matlab.unittest.parameters.Parameter;
import matlab.unittest.TestRunner

% Run tests
suite = TestSuite.fromClass(?TestBattery1D);
suite = suite.selectIf(HasParameter('Property', 'testSize', 'Value', 'short'));
results = suite.run();

% Display results
t = table(results)

% Assert
assertSuccess(results);
