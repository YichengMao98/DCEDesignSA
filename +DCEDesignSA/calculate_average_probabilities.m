function probs = calculate_average_probabilities(X_raw, pts, n_alt, has_no_choice, wts, order_positions)
% CALCULATE_AVERAGE_PROBABILITIES
% Compute prior-average choice probabilities for the coded design. The
% quadrature weights must be used for SR, which does not have equal weights.
% order_positions, when supplied, gives each regular raw row's presentation
% position and makes the returned rows agree with the decoded design.

    % 1. Get basic dimensions
    [~, n_cols_X] = size(X_raw); % n_cols_X is number of coded model columns
    [n_params_pts, n_draws] = size(pts);    % n_params_pts includes ASC if no_choice is true

    if nargin < 5 || isempty(wts)
        wts = ones(n_draws, 1) / n_draws;
    else
        wts = wts(:);
        if numel(wts) ~= n_draws || any(~isfinite(wts))
            error('calculate_average_probabilities:InvalidWeights', ...
                'Weights must contain one finite value per prior point.');
        end
    end
    if nargin < 6
        order_positions = [];
    end
    
    % 2. X_raw comes from encode(), which already contains the no-choice row
    % of every choice set, so the rows are used as-is. (An earlier version
    % tried to guess from mod(n_rows, n_alt) whether the no-choice rows were
    % missing; that guess is wrong whenever the number of choice sets is a
    % multiple of n_alt, and produced extra phantom sets in the output.)
    X_padded_rows = X_raw;
    n_total_alts  = n_alt + (has_no_choice == true);
    n_sets        = size(X_padded_rows, 1) / n_total_alts;

    % 3. Adjust columns to match pts (The ASC / Constant adjustment)
    % If pts has 1 more parameter than X has columns, we add the ASC column
    if n_cols_X < n_params_pts
        % Create an ASC column
        asc_column = zeros(size(X_padded_rows, 1), 1);
        if has_no_choice
            % For MNL, No Choice utility is usually represented by the ASC.
            % We set ASC = 1 for No Choice rows, and 0 for regular options.
            no_choice_row_indices = n_total_alts : n_total_alts : size(X_padded_rows, 1);
            asc_column(no_choice_row_indices) = 1;
        end
        X_final = [X_padded_rows, asc_column];
    else
        X_final = X_padded_rows;
    end

    % 4. Perform matrix multiplication
    % X_final: [N_rows x N_params]
    % pts: [N_params x N_draws]
    try
        utilities = X_final * pts; 
    catch ME
        fprintf('Dimension Mismatch Details:\n');
        fprintf('X_final size: [%d x %d]\n', size(X_final,1), size(X_final,2));
        fprintf('pts size: [%d x %d]\n', size(pts,1), size(pts,2));
        rethrow(ME);
    end
    
    % 5. Stable softmax within each choice set and prior point.
    utilities = reshape(utilities, n_total_alts, n_sets, n_draws);
    exp_v = exp(utilities - max(utilities, [], 1));
    p_draws = exp_v ./ sum(exp_v, 1);

    % Sum across prior points with their actual quadrature/sampling weights.
    probs = reshape(reshape(p_draws, [], n_draws) * wts, n_total_alts, n_sets);

    % The decoded design sorts profiles by presentation position. Apply the
    % same inverse permutation to the probability rows; opt-out stays last.
    if ~isempty(order_positions)
        if ~isequal(size(order_positions), [n_alt, n_sets])
            error('calculate_average_probabilities:InvalidOrder', ...
                'Order positions must have one row per regular alternative and one column per choice set.');
        end
        for s = 1:n_sets
            [sorted_positions, raw_rows] = sort(order_positions(:, s));
            if ~isequal(sorted_positions, (1:n_alt)')
                error('calculate_average_probabilities:InvalidOrder', ...
                    'Each choice set must contain every presentation position exactly once.');
            end
            probs(1:n_alt, s) = probs(raw_rows, s);
        end
    end
end
