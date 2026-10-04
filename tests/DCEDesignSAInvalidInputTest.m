classdef DCEDesignSAInvalidInputTest < matlab.unittest.TestCase
% Invalid-input tests: every malformed call to DCEDesignSA.generate (and to the
% Result exporters) must fail fast with a specific, documented error identifier
% instead of failing deep inside the optimiser or silently returning a
% meaningless design.
%
% Identifiers:
%   DCEDesignSA:invalidInput        scalar/option values (cset, n_alt, f, coding, ...)
%   DCEDesignSA:invalidAttributes   nlevels / attr_cell problems
%   DCEDesignSA:invalidPrior        prior_mean / prior_var problems
%   DCEDesignSA:invalidTermination  termination / max_value problems

    properties (TestParameter)
        bad = DCEDesignSAInvalidInputTest.cases();
    end

    methods (TestClassSetup)
        function addPackageToPath(testCase)
            root = fileparts(fileparts(mfilename('fullpath')));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture(root));
        end
    end

    methods (Test)
        function malformedCallIsRejectedWithTheDocumentedIdentifier(testCase, bad)
            testCase.verifyError(@() DCEDesignSA.generate(bad.args{:}), bad.id);
        end

        function exportWithAnUnsupportedFormatIsRejected(testCase)
            res = DCEDesignSA.generate(2, 2, 'nlevels', [2 2], 'termination', 'time', 'max_value', 1);
            tmp = testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
            threw = false;
            try
                res.export_qualtrics(fullfile(tmp.Folder, 'x'), 'wide');
            catch
                threw = true;
            end
            testCase.verifyTrue(threw, 'an unsupported Qualtrics format must raise an error');
            testCase.verifyFalse(isfile(fullfile(tmp.Folder, 'x.txt')) && ...
                ~isempty(fileread(fullfile(tmp.Folder, 'x.txt'))), ...
                'no partial Qualtrics file should be left behind');
        end

        function exportOfAnEmptyDesignIsRejected(testCase)
            empty = DCEDesignSA.Result({}, [], 0, 0, struct('f', 0), [], 0);
            tmp = testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
            testCase.verifyError(@() empty.export_csv(fullfile(tmp.Folder, 'e')), ?MException);
        end
    end

    methods (Static)
        function s = cases()
            T = {'termination', 'time', 'max_value', 1};
            add = @(id, varargin) struct('id', id, 'args', {varargin});
            I  = 'DCEDesignSA:invalidInput';
            A  = 'DCEDesignSA:invalidAttributes';
            P  = 'DCEDesignSA:invalidPrior';
            Tm = 'DCEDesignSA:invalidTermination';
            s = struct();
            % attributes
            s.no_attributes            = add(A, 4, 2);
            s.one_level_attribute      = add(A, 4, 2, 'nlevels', [3 1], T{:});
            s.non_integer_levels       = add(A, 4, 2, 'nlevels', [3 2.5], T{:});
            s.attr_cell_numeric_labels = add(A, 4, 2, 'attr_cell', struct('A', {{1, 2}}), T{:});
            s.attr_cell_level_mismatch = add(A, 4, 2, 'attr_cell', struct('A', {{'a','b'}}), 'nlevels', 3, T{:});
            % scalar options
            s.cset_zero                = add(I, 0, 2, 'nlevels', [3 2], T{:});
            s.cset_negative            = add(I, -3, 2, 'nlevels', [3 2], T{:});
            s.cset_fractional          = add(I, 2.5, 2, 'nlevels', [3 2], T{:});
            s.cset_nan                 = add(I, NaN, 2, 'nlevels', [3 2], T{:});
            s.n_alt_one                = add(I, 4, 1, 'nlevels', [3 2], T{:});
            s.n_alt_zero               = add(I, 4, 0, 'nlevels', [3 2], T{:});
            s.f_equals_attribute_count = add(I, 4, 2, 'nlevels', [3 2], 'f', 2, T{:});
            s.f_above_attribute_count  = add(I, 4, 2, 'nlevels', [3 2], 'f', 5, T{:});
            s.f_negative               = add(I, 4, 2, 'nlevels', [3 2], 'f', -1, T{:});
            s.f_fractional             = add(I, 4, 2, 'nlevels', [3 2], 'f', 0.5, T{:});
            s.coding_unknown           = add(I, 4, 2, 'nlevels', [3 2], 'coding', 'banana', T{:});
            s.order_effect_text        = add(I, 4, 2, 'nlevels', [3 2], 'order_effect', 'yes', T{:});
            s.no_choice_two            = add(I, 4, 2, 'nlevels', [3 2], 'no_choice', 2, T{:});
            s.n_draws_zero             = add(I, 4, 2, 'nlevels', [3 2], 'n_draws', 0, T{:});
            s.seed_negative            = add(I, 4, 2, 'nlevels', [3 2], 'seed', -1, T{:});
            s.seed_fractional          = add(I, 4, 2, 'nlevels', [3 2], 'seed', 1.5, T{:});
            s.seed_text                = add(I, 4, 2, 'nlevels', [3 2], 'seed', 'abc', T{:});
            % interactions
            s.interaction_not_a_cell   = add(I, 4, 2, 'nlevels', [3 2], 'interactions', [1 2], T{:});
            s.interaction_bad_index    = add(I, 4, 2, 'nlevels', [3 2], 'interactions', {[1 5]}, T{:});
            s.interaction_same_attr    = add(I, 4, 2, 'nlevels', [3 2], 'interactions', {[1 1]}, T{:});
            s.interaction_wrong_shape  = add(I, 4, 2, 'nlevels', [3 2], 'interactions', {[1 2 3]}, T{:});
            s.interaction_duplicate    = add(I, 4, 2, 'nlevels', [3 2 2], 'interactions', {[1 2], [2 1]}, T{:});
            % priors
            s.prior_mean_wrong_length  = add(P, 4, 2, 'nlevels', [3 2], 'prior_mean', [0 0], T{:});
            s.prior_mean_nan           = add(P, 4, 2, 'nlevels', [3 2], 'prior_mean', [0 NaN 0], T{:});
            s.prior_var_wrong_size     = add(P, 4, 2, 'nlevels', [3 2], 'prior_var', eye(2), T{:});
            s.prior_var_not_symmetric  = add(P, 4, 2, 'nlevels', [3 2], 'prior_var', [1 .5 0; 0 1 0; 0 0 1], T{:});
            s.prior_var_not_pos_def    = add(P, 4, 2, 'nlevels', [3 2], 'prior_var', [1 2 0; 2 1 0; 0 0 1], T{:});
            s.prior_var_nan            = add(P, 4, 2, 'nlevels', [3 2], 'prior_var', [1 NaN 0; NaN 1 0; 0 0 1], T{:});
            % termination
            s.termination_unknown      = add(Tm, 4, 2, 'nlevels', [3 2], 'termination', 'foo');
            s.time_without_max_value   = add(Tm, 4, 2, 'nlevels', [3 2], 'termination', 'time');
            s.adaptive_with_max_value  = add(Tm, 4, 2, 'nlevels', [3 2], 'termination', 'adaptive', 'max_value', 5);
            s.max_value_negative       = add(Tm, 4, 2, 'nlevels', [3 2], 'termination', 'time', 'max_value', -5);
            s.max_value_zero           = add(Tm, 4, 2, 'nlevels', [3 2], 'termination', 'cycle', 'max_value', 0);
            s.max_value_infinite       = add(Tm, 4, 2, 'nlevels', [3 2], 'termination', 'time', 'max_value', Inf);
            s.cycle_count_fractional   = add(Tm, 4, 2, 'nlevels', [3 2], 'termination', 'cycle', 'max_value', 1.5);
            % other
            s.unknown_sampling_method  = add('priors:UnknownMethod', 4, 2, 'nlevels', [3 2], 'sampling_method', 'sobol', T{:});
            s.unknown_option_name      = add('MATLAB:InputParser:UnmatchedParameter', 4, 2, 'nlevels', [3 2], 'foo', 1, T{:});
        end
    end
end
