function results = run_tests(varargin)
% RUN_TESTS  Run the DCEDesignSA test suite (unit, invalid-input, portability, GUI).
%
%   results = run_tests
%   results = run_tests('ExcludeGUI', true)      % skip tests tagged 'GUI'
%   results = run_tests('Verbose', true)
%
% Requires MATLAB R2020b or later. Halton-sampling tests are skipped when the
% Statistics and Machine Learning Toolbox is not available; GUI tests are
% skipped when a uifigure cannot be created.

    p = inputParser;
    addParameter(p, 'ExcludeGUI', false, @(x) islogical(x) && isscalar(x));
    addParameter(p, 'Verbose',    false, @(x) islogical(x) && isscalar(x));
    parse(p, varargin{:});

    import matlab.unittest.TestSuite
    import matlab.unittest.TestRunner
    import matlab.unittest.selectors.HasTag

    root  = fileparts(mfilename('fullpath'));
    suite = TestSuite.fromFolder(fullfile(root, 'tests'));
    if p.Results.ExcludeGUI
        suite = suite.selectIf(~HasTag('GUI'));
    end

    if p.Results.Verbose
        runner = TestRunner.withTextOutput('OutputDetail', matlab.unittest.Verbosity.Detailed);
    else
        runner = TestRunner.withTextOutput;
    end
    results = runner.run(suite);
    disp(table(results));

    if nargout == 0 && any([results.Failed])
        error('run_tests:failures', '%d test(s) failed.', nnz([results.Failed]));
    end
end
