% Script for running tests using github actions

% Setup BattMo
global MRST_BATCH
MRST_BATCH = true;

run('../startupBattMo.m')

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
assertSuccess(results);
