classdef DCEDesignSAUnitTest < matlab.unittest.TestCase
% Unit tests for the DCEDesignSA package: coding, design initialisation and
% perturbation, information matrix / Bayesian D criterion, prior sampling,
% the incremental SA update, decoding, exports and reproducibility.
%
% Run with:  results = run_tests;   (from the repository root)

    properties (Constant)
        FastTermination = {'termination', 'time', 'max_value', 1}
    end

    methods (TestClassSetup)
        function addPackageToPath(testCase)
            root = fileparts(fileparts(mfilename('fullpath')));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture(root));
        end
    end

    %% ---------------------------------------------------------------- coding
    methods (Test)
        function effectCodingUsesMinusOneForLastLevel(testCase)
            testCase.verifyEqual(DCEDesignSA.effCode([3 2], [3 2]), [-1 -1 -1]);
            testCase.verifyEqual(DCEDesignSA.effCode([1 1], [3 2]), [1 0 1]);
            testCase.verifyEqual(DCEDesignSA.effCode([2 2], [3 2]), [0 1 -1]);
        end

        function dummyCodingUsesZerosForLastLevel(testCase)
            testCase.verifyEqual(DCEDesignSA.dummyCode([3 2], [3 2]), [0 0 0]);
            testCase.verifyEqual(DCEDesignSA.dummyCode([1 1], [3 2]), [1 0 1]);
            testCase.verifyEqual(DCEDesignSA.dummyCode([2 2], [3 2]), [0 1 0]);
        end

        function interactionColumnsAreProductsOfMainEffectColumns(testCase)
            nl = [3 3];
            X  = [3 3; 1 2; 2 3];
            Xc = DCEDesignSA.encode(X, nl, 'interactions', {[1 2]});
            testCase.verifySize(Xc, [3 8]);          % 2 + 2 main + 2*2 interaction
            % (level of attr 1 outer, level of attr 2 inner)
            testCase.verifyEqual(Xc(1,:), [-1 -1 -1 -1  1  1  1  1]);
            testCase.verifyEqual(Xc(2,:), [ 1  0  0  1  0  1  0  0]);
            testCase.verifyEqual(Xc(3,:), [ 0  1 -1 -1  0  0 -1 -1]);
        end

        function columnOrderIsMainInteractionOrderAscLast(testCase)
            nl = [3 2]; cset = 3; n_alt = 3;
            rng(1);
            X  = DCEDesignSA.initialize(cset, n_alt, nl, 0, true, true);
            Xc = DCEDesignSA.encode(X, nl, 'interactions', {[1 2]}, ...
                'order_effect', true, 'no_choice', true);
            k = sum(nl - 1); nint = (nl(1)-1) * (nl(2)-1);
            testCase.verifySize(Xc, [size(X,1), k + nint + (n_alt-1) + 1]);

            pos     = X(:, end);
            ordcols = Xc(:, k + nint + (1:n_alt-1));
            expected = zeros(numel(pos), n_alt-1);
            expected(pos == 1, :) = repmat([1 0],  nnz(pos == 1), 1);
            expected(pos == 2, :) = repmat([0 1],  nnz(pos == 2), 1);
            expected(pos == 3, :) = repmat([-1 -1], nnz(pos == 3), 1);
            testCase.verifyEqual(ordcols, expected);        % opt-out row (pos 0) -> zeros
            testCase.verifyEqual(Xc(:, end) == 1, pos == 0);  % ASC marks only the opt-out rows
        end

        function orderPositionChangesTheCodedMatrixAndCriterion(testCase)
            nl = [3 3 2]; cs = 6; na = 3;
            rng(4);
            X1 = DCEDesignSA.initialize(cs, na, nl, 0, true, false);
            X2 = X1;
            for s = 1:cs
                rows = (s-1)*na + (1:na);
                X2(rows, end) = circshift(X1(rows, end), 1);   % same attributes, new positions
            end
            dim = sum(nl-1) + (na-1);
            [pts, wts] = DCEDesignSA.priors(zeros(1,dim), eye(dim));
            D1 = DCEDesignSA.calc_BayesianD(DCEDesignSA.encode(X1, nl, 'order_effect', true), pts, wts, cs);
            D2 = DCEDesignSA.calc_BayesianD(DCEDesignSA.encode(X2, nl, 'order_effect', true), pts, wts, cs);
            testCase.verifyNotEqual(D1, D2);
        end
    end

    %% -------------------------------------------- initialisation & perturbation
    methods (Test)
        function initializeReturnsValidDesign(testCase)
            nl = [3 4 2]; cset = 10; n_alt = 3;
            rng(2);
            X = DCEDesignSA.initialize(cset, n_alt, nl, 0, true, true);
            testCase.verifySize(X, [cset*(n_alt+1), numel(nl)+1]);
            for s = 1:cset
                rows = (s-1)*(n_alt+1) + (1:n_alt);
                testCase.verifyEqual(sort(X(rows, end))', 1:n_alt);        % a permutation
                testCase.verifyEqual(X(s*(n_alt+1), :), zeros(1, numel(nl)+1)); % opt-out row
                for a = 1:numel(nl)
                    testCase.verifyTrue(all(X(rows, a) >= 1 & X(rows, a) <= nl(a)));
                end
            end
        end

        function initializePartialProfileHasExactlyFFixedAttributes(testCase)
            nl = [3 3 3 3]; cset = 30; n_alt = 3; f = 2;
            rng(3);
            X = DCEDesignSA.initialize(cset, n_alt, nl, f, false, false);
            for s = 1:cset
                rows = (s-1)*n_alt + (1:n_alt);
                testCase.verifyEqual(countFixed(X(rows, :)), f);
            end
        end

        function perturbationKeepsTheDesignStructurallyValid(testCase)
            nl = [3 3 3 3]; cset = 6; n_alt = 3; f = 1;
            for interactions = {{}, {[1 2]}}
                rng(5);
                X = DCEDesignSA.initialize(cset, n_alt, nl, f, true, true);
                for it = 1:600
                    [~, X] = DCEDesignSA.perturb(X, n_alt, nl, f, interactions{1}, true, true);
                    for s = 1:cset
                        rows = (s-1)*(n_alt+1) + (1:n_alt);
                        testCase.assertEqual(sort(X(rows, end))', 1:n_alt, 'order not a permutation');
                        testCase.assertEqual(X(s*(n_alt+1), :), zeros(1, numel(nl)+1), 'opt-out row modified');
                        testCase.assertEqual(countFixed(X(rows, 1:end-1)), f, 'wrong number of fixed attributes');
                        for a = 1:numel(nl)
                            testCase.assertTrue(all(X(rows, a) >= 1 & X(rows, a) <= nl(a)), 'level out of range');
                        end
                    end
                end
            end
        end

        function orderPerturbationDrawsADifferentPermutation(testCase)
            n_alt = 4; nl = [3 3];
            rng(6);
            X = DCEDesignSA.initialize(3, n_alt, nl, 0, true, false);
            moves = 0;
            for it = 1:300
                [~, Xn] = DCEDesignSA.perturb(X, n_alt, nl, 0, {}, true, false);
                if isequal(Xn(:, 1:end-1), X(:, 1:end-1)) && ~isequal(Xn, X)
                    moves = moves + 1;
                end
                testCase.assertFalse(isequal(Xn, X), 'perturbation left the design unchanged');
            end
            testCase.verifyGreaterThan(moves, 0);
        end
    end

    %% ------------------------------------- information matrix & D-criterion
    methods (Test)
        function infoMNLMatchesClosedFormForTwoAlternatives(testCase)
            b = 0.7;  p1 = exp(b) / (exp(b) + 1);
            info = DCEDesignSA.InfoMNL([1; 0], b, 1);
            testCase.verifyEqual(info, p1 * (1 - p1), 'AbsTol', 1e-12);
        end

        function infoMatrixIsSymmetricPositiveSemidefinite(testCase)
            rng(7);
            X = randn(12, 4); beta = randn(4, 1);
            info = DCEDesignSA.InfoMNL(X, beta, 4);
            testCase.verifyEqual(info, info', 'AbsTol', 1e-12);
            testCase.verifyGreaterThanOrEqual(min(eig(info)), -1e-10);
        end

        function bayesianDEqualsWeightedLogDeterminant(testCase)
            rng(8);
            X = randn(12, 3);
            [pts, wts] = DCEDesignSA.priors(zeros(1, 3), eye(3));
            expected = 0;
            for i = 1:numel(wts)
                expected = expected + wts(i) * log(det(DCEDesignSA.InfoMNL(X, pts(:, i), 4)));
            end
            [D, inf_error] = DCEDesignSA.calc_BayesianD(X, pts, wts, 4);
            testCase.verifyEqual(D, expected, 'AbsTol', 1e-9);
            testCase.verifyEqual(inf_error, 0);
        end

        function incrementalUpdateMatchesFullRecomputation(testCase)
            % Enough choice sets and full profiles keep the information matrix
            % well conditioned: for a (near-)singular matrix the sign of the
            % determinant is numerical noise, so the invalid-draw count of the
            % incremental and the full computation could legitimately differ.
            nl = [3 3 2]; cset = 14; n_alt = 3; f = 0; inter = {[1 2]};
            rng(9);
            X = DCEDesignSA.initialize(cset, n_alt, nl, f, true, true);
            dim = sum(nl-1) + 4 + (n_alt-1) + 1;
            [pts, wts] = DCEDesignSA.priors(0.1 * (1:dim), 0.5 * eye(dim));
            Xc    = DCEDesignSA.encode(X, nl, 'interactions', inter, 'order_effect', true, 'no_choice', true);
            infos = DCEDesignSA.information_matrix(Xc, pts, wts, cset);
            for it = 1:25
                [rows, Xn] = DCEDesignSA.perturb(X, n_alt, nl, f, inter, true, true);
                [Dn, infosN, ie] = DCEDesignSA.update_information_matrix(X, Xn, nl, inter, rows, ...
                    pts, wts, infos, true, 'effect', true);
                XcN = DCEDesignSA.encode(Xn, nl, 'interactions', inter, 'order_effect', true, 'no_choice', true);
                [Dfull, ieFull] = DCEDesignSA.calc_BayesianD(XcN, pts, wts, cset);
                testCase.assertEqual(ieFull, 0, 'test design must be non-singular');
                testCase.assertEqual(ie, 0);
                testCase.assertEqual(Dn, Dfull, 'AbsTol', 1e-8);
                testCase.assertEqual(infosN, DCEDesignSA.information_matrix(XcN, pts, wts, cset), 'AbsTol', 1e-9);
                X = Xn; infos = infosN;
            end
        end
    end

    %% ------------------------------------------------------- prior sampling
    methods (Test)
        function srQuadratureReproducesPriorMeanAndCovariance(testCase)
            mu = [0.5 -1 0.2]; S = [1 .5 .2; .5 2 .3; .2 .3 1.5];
            [pts, wts] = DCEDesignSA.priors(mu, S);
            testCase.verifyEqual(sum(wts), 1, 'AbsTol', 1e-10);
            m = pts * wts';
            testCase.verifyEqual(m', mu, 'AbsTol', 1e-9);
            C = (pts - m) * diag(wts) * (pts - m)';
            testCase.verifyEqual(C, S, 'AbsTol', 1e-8);
        end

        function pmcDrawsHaveEqualWeightsAndRoughlyTheRightMoments(testCase)
            mu = [1 -1]; S = [1 .6; .6 2];
            rng(10);
            [pts, wts, n] = DCEDesignSA.priors(mu, S, 'method', 'PMC', 'n_draws', 40000);
            testCase.verifyEqual(n, 40000);
            testCase.verifyEqual(wts, ones(1, 40000) / 40000);
            testCase.verifyEqual(mean(pts, 2)', mu, 'AbsTol', 0.05);
            testCase.verifyEqual(cov(pts'), S, 'AbsTol', 0.08);
        end

        function haltonDrawsPreserveTheCovarianceStructure(testCase)
            testCase.assumeTrue(license('test', 'Statistics_Toolbox') == 1, ...
                'Halton sampling needs the Statistics and Machine Learning Toolbox.');
            mu = [0 0 0]; S = [1 .8 0; .8 1 0; 0 0 1];
            [pts, ~, n] = DCEDesignSA.priors(mu, S, 'method', 'halton', 'n_draws', 4000);
            testCase.verifyEqual(n, 4000);
            testCase.verifyEqual(cov(pts'), S, 'AbsTol', 0.06);
        end

        function tooSmallNDrawsIsRaisedToTheSRPointCountWithAWarning(testCase)
            [~, ~, nSR] = DCEDesignSA.priors(zeros(1, 4), eye(4));
            testCase.verifyWarning(@() DCEDesignSA.priors(zeros(1, 4), eye(4), 'method', 'PMC', 'n_draws', 3), ...
                'priors:NDrawsTooSmall');
            testCase.applyFixture(matlab.unittest.fixtures.SuppressedWarningsFixture('priors:NDrawsTooSmall'));
            [pts, ~, n] = DCEDesignSA.priors(zeros(1, 4), eye(4), 'method', 'PMC', 'n_draws', 3);
            testCase.verifyEqual(n, nSR);
            testCase.verifySize(pts, [4, nSR]);
        end
    end

    %% ------------------------------------------------ decoding & probabilities
    methods (Test)
        function priorAverageUsesWeightsAndStableSoftmax(testCase)
            X = [1 0; 0 1];
            pts = [1000 0; 0 1000];
            p = DCEDesignSA.calculate_average_probabilities( ...
                X, pts, 2, false, [0.9 0.1]);
            testCase.verifyEqual(p, [0.9; 0.1], 'AbsTol', 1e-12);
        end

        function generatedProbabilitiesMatchDisplayedPositions(testCase)
            nl = [3 2]; cset = 8; n_alt = 3;
            mu = [0.6 -0.4 0.2 -0.15 0.30 0.5];
            Sigma = diag([0.2 0.7 1.1 0.5 0.3 0.8]);
            res = DCEDesignSA.generate(cset, n_alt, 'nlevels', nl, ...
                'order_effect', true, 'no_choice', true, ...
                'prior_mean', mu, 'prior_var', Sigma, ...
                'termination', 'time', 'max_value', 1, 'seed', 18);
            [pts, wts] = DCEDesignSA.priors(mu, Sigma);
            X = DCEDesignSA.encode(res.RawMatrix, nl, ...
                'order_effect', true, 'no_choice', true);
            expected = zeros(n_alt + 1, cset);
            for s = 1:cset
                rows = (s-1)*(n_alt+1) + (1:n_alt+1);
                u = X(rows, :) * pts;
                e = exp(u - max(u, [], 1));
                p = (e ./ sum(e, 1)) * wts(:);
                [~, shown] = sort(res.RawMatrix(rows(1:n_alt), end));
                expected(:, s) = [p(shown); p(end)];
            end
            testCase.verifyEqual(res.AvgProbs, expected, 'AbsTol', 1e-10);
            testCase.verifyEqual(sum(res.AvgProbs, 1), ones(1,cset), 'AbsTol', 1e-10);
        end

        function decodedPresentationOrderMatchesTheModelledPositions(testCase)
            nl = [4 4 4]; cset = 60; n_alt = 3;
            for nc = [false true]
                rng(2);
                X   = DCEDesignSA.initialize(cset, n_alt, nl, 0, true, nc);
                dec = DCEDesignSA.decode_X(X, {'A','B','C'}, 'n_alt', n_alt, 'cset', cset, ...
                    'order_effect', true, 'no_choice', nc);
                nat  = n_alt + nc;
                for s = 1:cset
                    rows = (s-1)*nat + (1:n_alt);
                    for p = 1:n_alt
                        raw   = rows(X(rows, end) == p);     % the row modelled at position p
                        shown = cell2mat(dec(rows(p) + 1, 3:end));   % +1: header row
                        testCase.assertEqual(shown, X(raw, 1:end-1));
                    end
                end
            end
        end

        function choiceProbabilitiesHaveOneColumnPerSetAndSumToOne(testCase)
            for cset = [4 5]      % 4 is a multiple of n_alt = 2: the phantom-set regression
                res = DCEDesignSA.generate(cset, 2, 'nlevels', [2 3], 'no_choice', true, ...
                    'termination', 'time', 'max_value', 1, 'seed', 1);
                testCase.verifySize(res.AvgProbs, [3, cset]);
                testCase.verifyEqual(sum(res.AvgProbs, 1), ones(1, cset), 'AbsTol', 1e-10);
            end
        end
    end

    %% ------------------------------------------------ end-to-end & reproducibility
    methods (Test)
        function reportedCriterionEqualsARecomputationFromTheReturnedDesign(testCase)
            % 8 sets x 2 degrees of freedom >= the 11 parameters, so the design can be non-singular
            nl = [3 3 2]; cset = 8; n_alt = 2;
            res = DCEDesignSA.generate(cset, n_alt, 'nlevels', nl, 'interactions', {[1 2]}, ...
                'order_effect', true, 'no_choice', true, ...
                'termination', 'time', 'max_value', 2, 'seed', 3);
            testCase.assertGreaterThan(res.D_Value, -10000, 'the optimiser found no non-singular design');
            dim = sum(nl-1) + 4 + (n_alt-1) + 1;
            [pts, wts] = DCEDesignSA.priors(zeros(1, dim), eye(dim));
            Xc = DCEDesignSA.encode(res.RawMatrix, nl, 'interactions', {[1 2]}, ...
                'order_effect', true, 'no_choice', true);
            [D, ie] = DCEDesignSA.calc_BayesianD(Xc, pts, wts, cset);
            testCase.verifyEqual(res.D_Value, D, 'AbsTol', 1e-8);
            testCase.verifyEqual(res.InfError, ie);
            testCase.verifyTrue(res.Metadata.has_no_choice);
            testCase.verifyEqual(res.Metadata.seed, 3);
        end

        function sameSeedGivesTheSameDesignAndTheCallersRngStateIsRestored(testCase)
            % 'cycle' termination is deterministic given the seed (unlike 'time'); a
            % small design keeps one full SA cycle short.
            args = {'nlevels', [2 2], 'termination', 'cycle', 'max_value', 1};
            rng(5); expected = rand;
            rng(5);
            a = DCEDesignSA.generate(3, 2, args{:}, 'seed', 42);
            b = DCEDesignSA.generate(3, 2, args{:}, 'seed', 42);
            testCase.verifyEqual(a.DesignMatrix, b.DesignMatrix);
            testCase.verifyEqual(a.D_Value, b.D_Value);
            testCase.verifyEqual(rand, expected, 'the caller''s RNG state must be restored');
        end

        function boundaryInputsAreAccepted(testCase)
            res = DCEDesignSA.generate(1, 2, 'nlevels', [2 2], 'f', 1, ...
                'order_effect', 1, 'no_choice', 0, 'termination', 'time', 'max_value', 1);
            testCase.verifyClass(res, 'DCEDesignSA.Result');
        end

        function summaryShowsTheReportedFields(testCase)
            res = DCEDesignSA.generate(3, 2, 'nlevels', [2 2], 'termination', 'time', ...
                'max_value', 1, 'seed', 7);
            txt = evalc('res.summary()');
            for label = ["Fixed Attributes:", "Random Seed:", "Invalid Draws:", ...
                    "Bayesian D-optimality Criterion value"]
                testCase.verifySubstring(txt, char(label));
            end
        end
    end

    %% ----------------------------------------------------------------- exports
    methods (Test)
        function csvExportRoundTrips(testCase)
            tmp = testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
            res = DCEDesignSA.generate(3, 2, 'nlevels', [2 3], 'no_choice', true, ...
                'termination', 'time', 'max_value', 1, 'seed', 1);
            file = fullfile(tmp.Folder, 'my design');        % a space in the path on purpose
            res.export_csv(file);
            T = readtable([file '.csv'], 'TextType', 'string');
            testCase.verifyEqual(height(T), size(res.DesignMatrix, 1) - 1);
            testCase.verifyEqual(string(T.Properties.VariableNames(1:2)), ["ChoiceSet", "Alternative"]);
        end

        function qualtricsExportWritesOneBlockPerChoiceSet(testCase)
            tmp = testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
            res = DCEDesignSA.generate(4, 2, 'nlevels', [2 3], 'no_choice', true, ...
                'termination', 'time', 'max_value', 1, 'seed', 1);
            file = fullfile(tmp.Folder, 'survey');
            res.export_qualtrics(file, 'long');
            txt = fileread([file '.txt']);
            testCase.verifyTrue(startsWith(txt, '[[AdvancedFormat]]'));
            testCase.verifyEqual(numel(strfind(txt, '[[Block:ChoiceSet_')), 4);
            testCase.verifySubstring(txt, 'None');
            % CSS widths must be literal percentages, not printf escapes
            testCase.verifyEmpty(strfind(txt, '%%'));
            testCase.verifySubstring(txt, 'width:100%;');
        end
    end
end

function n = countFixed(block)
% Number of attribute columns that are constant across the rows of a choice set.
    n = sum(all(block == block(1, :), 1));
end
