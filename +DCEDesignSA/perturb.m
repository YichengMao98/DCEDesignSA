function [csRows, modified_X] = perturb(X, n_alt, nlevels, f, interactions, order_effect, no_choice)
% RANDOM_MODIFY_2 Randomly modifies one element of the design matrix to
% generate a neighbouring candidate design during simulated annealing.
%
%   This function applies a single stochastic perturbation to the current
%   design matrix. It supports full-profile and partial-profile designs,
%   optional presentation order modification, and designs that include a
%   no-choice alternative as the last row of each choice set.
%
%   When no_choice is true, the no-choice row (last row of each choice set)
%   is never selected for modification because its attribute values are
%   structurally fixed at zero. Row selection is therefore restricted to
%   the regular alternatives only.
%
%   When order_effect is true and the last column is selected, the
%   presentation order of the regular alternatives within the affected
%   choice set is replaced with a different random permutation. The
%   no-choice alternative does not participate in the ordering.
%
%   INPUTS:
%       X            - (matrix) Current design matrix.
%       n_alt        - (integer) Number of regular alternatives per choice set,
%                      excluding the no-choice row.
%       nlevels      - (vector) Number of levels for each attribute.
%       f            - (integer) Number of fixed attributes per choice set.
%                         - f = 0: Full-profile design.
%                         - f > 0: Partial-profile design.
%       interactions - (cell array) Interaction constraints. Use {} for none.
%       order_effect - (logical) Whether the last column stores presentation
%                      order. Default: false.
%       no_choice    - (logical) Whether the last row of each choice set is
%                      the no-choice alternative. Default: false.
%
%   OUTPUTS:
%       csRows      - (vector) Row indices of the modified choice set,
%                     including the no-choice row if no_choice = true.
%       modified_X  - (matrix) Updated design matrix after perturbation.



    [numRows, numCols] = size(X);

% Determine the total number of rows per choice set
    if no_choice
        n_alt_total = n_alt + 1;
    else
        n_alt_total = n_alt;
    end

% Restrict row selection to regular alternatives only (exclude no-choice rows)
    if no_choice
% Build a list of all valid (non-no-choice) row indices
        valid_rows = [];
        n_cs = numRows / n_alt_total;
        for cs = 1:n_cs
            cs_start = (cs-1)*n_alt_total + 1;
            cs_end   = cs_start + n_alt - 1; % Exclude last row (no-choice)
            valid_rows = [valid_rows, cs_start:cs_end];
        end
        row_idx = valid_rows(randi(length(valid_rows)));
    else
        row_idx = randi(numRows);
    end

    col_idx = randi(numCols);
    csRows  = DCEDesignSA.selectRows(row_idx, n_alt_total);
    modified_X = X;

% ── Order column branch ───────────────────────────────────────────────────
% When the order column is selected, replace the permutation for regular
% alternatives in this choice set. The no-choice row order placeholder (0)
% is preserved unchanged.
    if order_effect && col_idx == numCols
        fr = floor(row_idx / n_alt_total);
        if fr * n_alt_total == row_idx
            rows = (row_idx - n_alt_total + 1):row_idx;
        else
            rows = (fr * n_alt_total + 1):(fr * n_alt_total + n_alt_total);
        end
% Only permute the regular alternative rows, not the no-choice placeholder
        regular_rows = rows(1:n_alt);
% Draw a random permutation different from the current one. Rejection
% sampling is uniform over the other n_alt!-1 permutations (n_alt >= 2 so it
% terminates) without enumerating all n_alt! of them.
        currentOrder = X(regular_rows, end)';
        newOrder     = currentOrder;
        while isequal(newOrder, currentOrder)
            newOrder = randperm(n_alt);
        end
        modified_X(regular_rows, end) = newOrder';
        csRows = rows;
        return;
    end

% ── Attribute modification branch ─────────────────────────────────────────
% Full-profile design: directly replace the selected attribute level
    if f == 0
        all_possible_values = 1:nlevels(col_idx);
        all_possible_values(all_possible_values == modified_X(row_idx, col_idx)) = [];
        new_value = all_possible_values(randi(length(all_possible_values)));
        modified_X(row_idx, col_idx) = new_value;
        return;
    end

% Partial-profile design: respect fixed/non-fixed column structure
    current_value = modified_X(row_idx, col_idx);
    new_value     = generateRandomValue(current_value, nlevels(col_idx));

% Exclude the order column and no-choice row from fixed/non-fixed detection
    all_cols = 1:numCols;
    if order_effect
        all_cols = 1:(numCols - 1);
    end

% Use only regular alternative rows when determining fixed columns
    regular_csRows = csRows(1:n_alt);
    fixed_cols     = find(all(X(regular_csRows(1), all_cols) == X(regular_csRows, all_cols)));
    not_fixed_cols = setdiff(all_cols, fixed_cols);

% Without interaction constraints
    if isempty(interactions)
        if ismember(col_idx, fixed_cols)
            modified_X(row_idx, col_idx) = new_value;
            random_not_fixed_col = not_fixed_cols(randi(length(nlevels) - f));
            new_fixed_value = randi(nlevels(random_not_fixed_col));
            modified_X(regular_csRows, random_not_fixed_col) = new_fixed_value;
        else
            modified_X(row_idx, col_idx) = new_value;
            if length(unique(modified_X(regular_csRows, col_idx))) == 1
                random_fixed_col = fixed_cols(randi(f));
                fixed_value      = modified_X(regular_csRows(1), random_fixed_col);
                new_value        = generateRandomValue(fixed_value, nlevels(random_fixed_col));
                modified_X(regular_csRows(randi(n_alt)), random_fixed_col) = new_value;
            end
        end
        return;
    end

% With interaction constraints
    if ismember(col_idx, fixed_cols)
        A = {};
        for i = 1:length(interactions)
            if ismember(col_idx, interactions{i})
                A{end+1} = interactions{i};
            end
        end
        B = {};
        for j = 1:length(fixed_cols)
            if fixed_cols(j) ~= col_idx
                B{end+1} = sort([col_idx, fixed_cols(j)]);
            end
        end
        interaction_fulfilled = all(cellfun(@(x) any(cellfun(@(y) isequal(x, y), B)), A));

        if interaction_fulfilled
            modified_X(row_idx, col_idx) = new_value;
            random_not_fixed_col = not_fixed_cols(randi(length(nlevels) - f));
            new_fixed_value = randi(nlevels(random_not_fixed_col));
            modified_X(regular_csRows, random_not_fixed_col) = new_fixed_value;
        else
            p = f / length(nlevels);
            if rand() <= p
                modified_X(regular_csRows, col_idx) = new_value;
            else
                modified_X(row_idx, col_idx) = new_value;
                random_not_fixed_col = not_fixed_cols(randi(length(nlevels) - f));
                new_fixed_value = randi(nlevels(random_not_fixed_col));
                modified_X(regular_csRows, random_not_fixed_col) = new_fixed_value;
            end
        end
    else
        modified_X(row_idx, col_idx) = new_value;
        if length(unique(modified_X(regular_csRows, col_idx))) == 1
            random_fixed_col = fixed_cols(randi(f));
            fixed_value      = modified_X(regular_csRows(1), random_fixed_col);
            new_value        = generateRandomValue(fixed_value, nlevels(random_fixed_col));
            modified_X(regular_csRows(randi(n_alt)), random_fixed_col) = new_value;
        end
    end

    %% Internal helper
    function new_value = generateRandomValue(current_value, nlevels_attr)
    % Select a new attribute level uniformly at random, excluding the current value
        all_possible_values = 1:nlevels_attr;
        all_possible_values(all_possible_values == current_value) = [];
        new_value = all_possible_values(randi(length(all_possible_values)));
    end

end
