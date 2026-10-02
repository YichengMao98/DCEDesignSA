function [global_best_X, global_best_D, total_time,final_inf_error] = SA(X, cset, n_alt, nlevels, pts, wts, f, interactions, termination, max_value, order_effect, coding, no_choice)
% BAYESIAN_D_OPTIMAL_SA_FULL Optimises a Bayesian D-optimal discrete choice
% design using simulated annealing (SA).
%
%   This function implements the core SA loop for generating Bayesian
%   D-optimal choice designs. Starting from an initial design matrix, it
%   iteratively proposes random perturbations and accepts or rejects them
%   according to the Metropolis criterion. The Fisher information matrix is
%   updated efficiently at each iteration using a rank-one update rather than
%   a full recomputation.
%
%   The algorithm supports three termination modes. In adaptive mode, the
%   algorithm runs until a full cycle produces no improvement in the best
%   Bayesian D-optimality value found. In time mode, it stops after a fixed
%   number of seconds. In cycle mode, it stops after a fixed number of outer
%   cycles.
%
%   When f > 0, a partial-profile design is assumed and f attributes are held
%   fixed within each choice set. When interactions is non-empty, interaction
%   terms are included in the coded design matrix. When order_effect is true,
%   the last column of X stores presentation order and is excluded from coding.
%   When no_choice is true, the last row of each choice set is a no-choice
%   alternative with all attribute values set to zero and an ASC of 1.
%
%   INPUTS:
%       X            - (matrix) Initial design matrix.
%       cset         - (integer) Number of choice sets.
%       n_alt        - (integer) Number of regular alternatives per choice set,
%                      excluding the no-choice row.
%       nlevels      - (vector) Number of levels for each attribute.
%       pts          - (matrix) Prior parameter draws (K x S).
%       wts          - (vector) Weights for each parameter draw.
%       f            - (integer) Number of fixed attributes per choice set.
%                         - f = 0: Full-profile design.
%                         - f > 0: Partial-profile design.
%       interactions - (cell array) Interaction constraints. Use {} for none.
%       termination  - (string) Stopping criterion:
%                         - 'adaptive': Stop when no improvement is found.
%                         - 'time': Stop after max_value seconds.
%                         - 'cycle': Stop after max_value outer cycles.
%       max_value    - (numeric) Maximum time (seconds) or cycle count.
%                      Required for 'time' and 'cycle'. Use [] for 'adaptive'.
%       order_effect - (logical) Whether the last column of X stores
%                      presentation order. Default: false.
%       coding       - (string) Coding scheme: 'effect' or 'dummy'.
%                      Default: 'effect'.
%       no_choice    - (logical) Whether a no-choice alternative is present as
%                      the last row of each choice set. Default: false.
%
%   OUTPUTS:
%       global_best_X  - (matrix) Design matrix achieving the highest Bayesian
%                        D-optimality value found during the search.
%       global_best_D  - (scalar) Best Bayesian D-optimality value found.
%       total_time     - (scalar) Total wall-clock runtime in seconds.

% fprintf('size of X at start of SA_full: %d x %d\n', size(X,1), size(X,2));

    %% Initialisation
    initial_temp     = DCEDesignSA.calibrate_temp(X, cset, n_alt, nlevels, pts, wts, f, interactions, order_effect, coding, no_choice);
    current_X        = X;
    current_X_code   = DCEDesignSA.encode(current_X, nlevels,'interactions' ,interactions,'order_effect', order_effect, 'coding',coding,'no_choice' ,no_choice);
    %current_D        = DCEDesignSA.calc_BayesianD(current_X_code, pts, wts, cset);
    current_infomats = DCEDesignSA.information_matrix(current_X_code, pts, wts, cset);
    [current_D, current_inf_err] = DCEDesignSA.calc_BayesianD(current_X_code, pts, wts, cset);
 
    start_time = tic;
 
    global_best_X = current_X;
    global_best_D = current_D;
    global_best_inf_error = current_inf_err;
    total_iter    = 0;
    cycle         = 1;
    improved_in_cycle = true;
 
    %% Main SA loop
    while true
        elapsed_time = toc(start_time);
 
% Check termination conditions before starting each new cycle
        if strcmp(termination, 'time') && elapsed_time >= max_value
            break;
        elseif strcmp(termination, 'cycle') && cycle > max_value
            break;
        elseif strcmp(termination, 'adaptive') && ~improved_in_cycle
            fprintf('No improvement in cycle %d, stopping the algorithm.\n', cycle);
            break;
        end
 
        temp    = initial_temp;
        t       = 1;
        no_accept         = 0;
        improved_in_cycle = false;
 
        while no_accept <= 1000
            elapsed_time = toc(start_time);
            if strcmp(termination, 'time') && elapsed_time >= max_value
                break;
            end
            total_iter = total_iter + 1;
 
% Propose a neighbouring design by randomly modifying one element
            [csRows, X_new] = DCEDesignSA.perturb(current_X, n_alt, nlevels, f, interactions, order_effect, no_choice);
 
% Efficiently update the information matrix for the modified choice set only
            [new_DB, infomats_new, new_inf_err] = DCEDesignSA.update_information_matrix(current_X, X_new, nlevels, interactions, csRows, pts, wts, current_infomats, order_effect, coding, no_choice);

% Metropolis acceptance criterion: always accept improvements, accept
% deteriorations with a probability that decreases as temperature falls.
% "||" short-circuits, so rand() is only drawn when new_DB < current_D,
% matching the original if/elseif's behaviour exactly.
            accept = (new_DB >= current_D) || (rand() < exp((new_DB - current_D) / temp));
            if accept
                current_X        = X_new;
                current_D        = new_DB;
                current_infomats = infomats_new;
                current_inf_err  = new_inf_err;
                no_accept        = 0;
            else
                no_accept = no_accept + 1;
            end

            elapsed_time = toc(start_time);
            if current_D > global_best_D
                global_best_X         = current_X;
                global_best_D         = current_D;
                global_best_inf_error = current_inf_err;
                improved_in_cycle = true;
               % fprintf('cycle: %d, total_iter: %d, time: %.4f, DB_best: %.6f\n', ...
                 %   cycle, total_iter, elapsed_time, global_best_D);
            end
 
            t    = t + 1;
            temp = initial_temp / t;
        end
 
        fprintf('End of cycle: %d, total_iter: %d, time: %.4f, DB_best: %.6f\n', ...
            cycle, total_iter, elapsed_time, global_best_D);
        cycle = cycle + 1;
    end
 
    total_time = toc(start_time);
    final_inf_error = global_best_inf_error;
end
