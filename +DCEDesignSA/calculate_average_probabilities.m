function probs = calculate_average_probabilities(X_raw, pts, n_alt, has_no_choice)
% CALCULATE_AVERAGE_PROBABILITIES
% Computes mean choice probabilities using quadrature points (pts).
% Logic: V = X * Beta. If no_choice is true, X must include an ASC column.

    % 1. Get basic dimensions
    [n_rows_input, n_cols_X] = size(X_raw); % n_cols_X is number of attribute parameters
    [n_params_pts, n_draws] = size(pts);    % n_params_pts includes ASC if no_choice is true
    
    % 2. Adjust rows to include No Choice rows if they are missing
    if has_no_choice && mod(n_rows_input, n_alt) == 0
        n_sets = n_rows_input / n_alt;
        n_total_alts = n_alt + 1;
        X_padded_rows = zeros(n_sets * n_total_alts, n_cols_X);
        for s = 1:n_sets
            % Copy regular alternatives
            X_padded_rows((s-1)*n_total_alts + (1:n_alt), :) = X_raw((s-1)*n_alt + (1:n_alt), :);
            % The (s*n_total_alts)-th row remains zeros (No Choice attributes)
        end
    else
        X_padded_rows = X_raw;
        n_total_alts = n_alt + (has_no_choice == true);
        n_sets = size(X_padded_rows, 1) / n_total_alts;
    end

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
    
    exp_v = exp(utilities);
    
    % 5. Reshape and calculate probabilities
    % Dimensions: [Alt per set, Num sets, Num draws]
    exp_v_reshaped = reshape(exp_v, n_total_alts, n_sets, n_draws);
    
    % P_i = exp(V_i) / sum(exp(V_j))
    sum_exp_v = sum(exp_v_reshaped, 1);
    p_draws = exp_v_reshaped ./ sum_exp_v;
    
    % Average across all quadrature points (draws)
    probs = mean(p_draws, 3); 
end