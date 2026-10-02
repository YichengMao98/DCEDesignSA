function [new_DB, infomats_new, new_inf_error] = update_information_matrix(current_X, X_new, nlevels, interactions, csRows, pts, wts, current_infomats, order_effect, coding, no_choice)
% UPDATE_INFORMATION_MATRIX Efficiently updates the Fisher information matrices
% for the modified choice set and computes the new Bayesian D-optimality value.
%
%   Rather than recomputing the full information matrix from scratch, this
%   function applies a rank-one update by subtracting the contribution of the
%   old choice set and adding the contribution of the new choice set. This
%   makes each SA iteration significantly faster for large designs.
%
%   When order_effect is true, the presentation order column is stripped
%   before coding. When no_choice is true, the no_choice flag is forwarded
%   to transform_design so that the ASC column is correctly appended.
%
%   INPUTS:
%       current_X       - (matrix) Current design matrix before modification.
%       X_new           - (matrix) Proposed design matrix after modification.
%       nlevels         - (vector) Number of levels for each attribute.
%       interactions    - (cell array) Interaction constraints. Use {} for none.
%       csRows          - (vector) Row indices of the modified choice set.
%       pts             - (matrix) Prior parameter draws (K x S), where S is
%                         the number of quadrature points.
%       wts             - (vector) Weights for each parameter draw.
%       current_infomats- (3D matrix) Current Fisher information matrices of
%                         size (K x K x S).
%       order_effect    - (logical) Whether the last column stores presentation
%                         order. Default: false.
%       coding          - (string) Coding scheme: 'effect' or 'dummy'.
%                         Default: 'effect'.
%       no_choice       - (logical) Whether a no-choice alternative is present.
%                         Default: false.
%
%   OUTPUTS:
%       new_DB        - (scalar) Updated Bayesian D-optimality value. Pinned
%                       to exactly -10000 if any information matrix becomes
%                       singular/indefinite for any of the S draws (the
%                       accumulated log-det sum from the remaining draws
%                       is discarded in that case, not added on top).
%       infomats_new  - (3D matrix) Updated Fisher information matrices of
%                       size (K x K x S).
%       new_inf_error - (scalar) Fraction of the S prior draws for which the
%                       updated information matrix is singular/indefinite
%                       (det < 0), i.e. the same "infinite D-error" quantity
%                       computed by calc_BayesianD.m, kept in sync with
%                       new_DB at every SA iteration instead of only at the
%                       initial random design.



% Code both the current and proposed designs using the same coding scheme
    current_X_code = DCEDesignSA.encode(current_X, nlevels, 'interactions' ,interactions,'order_effect', order_effect, 'coding',coding,'no_choice' ,no_choice);
    X_new_code     = DCEDesignSA.encode(X_new,     nlevels, 'interactions' ,interactions,'order_effect', order_effect, 'coding',coding,'no_choice' ,no_choice);

% Extract only the rows of the modified choice set for the rank-one update
    X_sel     = current_X_code(csRows, :);
    X_sel_new = X_new_code(csRows, :);
    infomats_new = zeros(size(X_sel, 2), size(X_sel, 2), length(wts));
    new_DB = 0;
    inf_count = 0;

    for idx = 1:length(wts)
        beta = pts(:, idx);
        info_old     = current_infomats(:, :, idx);

% Compute information contributions for the old and new choice sets
        info_sel     = DCEDesignSA.InfoMNL(X_sel,     beta, 1);
        info_sel_new = DCEDesignSA.InfoMNL(X_sel_new, beta, 1);

% Rank-one update: replace old contribution with new contribution
        info_new = info_old + info_sel_new - info_sel;
        infomats_new(:, :, idx) = info_new;

        if det(info_new) >= 0
            new_DB = new_DB + log(det(info_new)) * wts(idx);
        else
            inf_count = inf_count + 1;
        end
    end

    new_inf_error = inf_count / length(wts);
    if inf_count > 0
% Penalise singular or indefinite information matrices. Pinned exactly to
% -10000 here (rather than overwritten mid-loop) so new_DB is a stable
% function of new_inf_error: any later non-singular draws' log-det terms
% are discarded, not added on top of the sentinel.
        new_DB = -10000;
    end
end
