function T0 = calibrate_temp(X, cset, n_alt, nlevels, pts, wts, f, interactions, order_effect, coding, no_choice)
% RANDOMWALKT0 Estimates a suitable initial temperature for simulated annealing
% via a short random walk on the design space.
%
%   A good initial temperature should allow the SA algorithm to accept almost
%   all proposed moves at the start, enabling broad exploration of the design
%   space. This function performs 100 random perturbations using the same
%   random_modify_2 function as the main SA loop, records the absolute changes
%   in the Bayesian D-optimality value, and sets T0 such that the initial
%   acceptance probability is approximately 99%.
%
%   Using the same perturbation mechanism as the main loop ensures that the
%   temperature scale is correctly matched to the actual magnitude of objective
%   function changes, including those from order column swaps and no-choice
%   designs.
%
%   INPUTS:
%       X            - (matrix) Initial design matrix.
%       cset         - (integer) Number of choice sets.
%       n_alt        - (integer) Number of regular alternatives per choice set.
%       nlevels      - (vector) Number of levels for each attribute.
%       pts          - (matrix) Prior parameter draws (K x S).
%       wts          - (vector) Weights for each parameter draw.
%       f            - (integer) Number of fixed attributes. Use 0 for full-profile.
%       interactions - (cell array) Interaction constraints. Use {} for none.
%       order_effect - (logical) Whether the last column stores presentation order.
%                      Default: false.
%       coding       - (string) Coding scheme: 'effect' or 'dummy'. Default: 'effect'.
%       no_choice    - (logical) Whether a no-choice alternative is present.
%                      Default: false.
%
%   OUTPUT:
%       T0 - (scalar) Initial temperature. Computed as max(|delta|) / log(0.99),
%            where delta is the vector of observed objective function changes
%            during the random walk. Changes larger than 100 are excluded as
%            outliers to avoid an artificially high starting temperature.
% n_alt_total is the number of rows per choice set passed to InfoMNL,
% which expects the number of alternatives per choice set (including no-choice)
        current_X        = X;
    current_X_code   = DCEDesignSA.encode(current_X, nlevels,'interactions' ,interactions,'order_effect', order_effect, 'coding',coding,'no_choice' ,no_choice);
    current_D        = DCEDesignSA.calc_BayesianD(current_X_code, pts, wts, cset);
    current_infomats = DCEDesignSA.information_matrix(current_X_code, pts, wts, cset);
 
    delta = [];
    for t = 1:100
        [row_idx, X_new] = DCEDesignSA.perturb(current_X, n_alt, nlevels, f, interactions, order_effect, no_choice);
        [new_DB, infomats_new] = DCEDesignSA.update_information_matrix(current_X, X_new, nlevels, interactions, row_idx, pts, wts, current_infomats, order_effect, coding, no_choice);
        delta(end+1)     = abs(new_DB - current_D);
        current_X        = X_new;
        current_infomats = infomats_new;
        current_D        = new_DB;
    end
 
% Exclude extreme outliers before computing T0 to prevent an inflated
% starting temperature that would slow convergence
    delta = delta(delta <= 100);
    T0    = abs(max(delta) / log(0.99));
end
