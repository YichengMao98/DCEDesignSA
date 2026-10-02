function X_code = encode(X, nlevels, varargin)
%fprintf('transform_design received: size(X)=%dx%d, length(nlevels)=%d\n', size(X,1), size(X,2), length(nlevels));
% TRANSFORM_DESIGN Applies attribute coding to a design matrix and optionally
% appends an alternative-specific constant (ASC) column for the no-choice option.
%
%   This function serves as the main coding wrapper in the SA framework. It
%   applies either effects coding or dummy coding to all attribute columns,
%   and when order_effect is true, codes the presentation-order column into
%   (J-1) effects-coded position columns (the order covariate z of Mao,
%   Kessels & Mee 2025, Eq. 3, with J = number of regular alternatives per
%   choice set), so the position effect alpha enters the information matrix.
%   When no_choice is true, it appends an ASC column where the no-choice
%   alternative receives ASC = 1 and all regular alternatives receive ASC = 0.
%
%   The no-choice alternative is identified as the last row of each choice set
%   and is expected to contain all zeros in its attribute columns. Its coded
%   representation is a zero vector for all attribute columns, with ASC = 1.
%
%   INPUTS:
%       X            - (matrix) Raw design matrix. If order_effect = true,
%                      the last column stores the presentation position
%                      (1..J for regular alternatives, 0 for the no-choice
%                      row). If no_choice = true, the last row of each
%                      choice set is the no-choice alternative (all zeros).
%       nlevels      - (vector) Number of levels for each attribute.
%       interactions - (cell array) Pairs of attribute indices for which
%                      interaction terms should be computed. Use {} for
%                      main-effects-only designs.
%       order_effect - (logical) Whether the last column of X is a presentation
%                      order column. Default: false.
%       coding       - (string) Coding scheme to apply to attribute columns.
%                         - 'effect': Effects-type coding (default).
%                         - 'dummy': Dummy coding.
%       no_choice    - (logical) Whether a no-choice alternative is present as
%                      the last row of each choice set. When true, an ASC column
%                      is appended: ASC = 1 for no-choice rows, ASC = 0 otherwise.
%                      Default: false.
%
%   OUTPUT:
%       X_code       - (matrix) Coded design matrix. Column order: the effect-
%                      or dummy-coded attribute columns, then interaction
%                      terms, then (if order_effect) the J-1 position columns
%                      (position j < J -> unit vector e_j, position J -> all
%                      -1, no-choice row -> all 0), then (if no_choice) the
%                      ASC indicator last. This matches the prior_mean /
%                      prior_var ordering used by dce_tool.
    p = inputParser;
    
    addRequired(p, 'X');
    addRequired(p, 'nlevels');
    
    % Set default values as they are in your 'generate' script
    addParameter(p, 'interactions', {});
    addParameter(p, 'order_effect', false);
    addParameter(p, 'coding', 'effect');
    addParameter(p, 'no_choice', false);
    
    % Parse varargin
    parse(p, X, nlevels, varargin{:});
    
    % Extract results
    interactions = p.Results.interactions;
    order_effect = p.Results.order_effect;
    coding       = p.Results.coding;
    no_choice    = p.Results.no_choice;

% Split off the presentation-order column; it is coded separately below and
% appended after the attribute/interaction columns.
    if order_effect
        X_attr    = X(:, 1:end-1);
        order_pos = X(:, end);
    else
        X_attr = X;
    end

    [numRows, ~] = size(X_attr);

% Pre-allocate the coded attribute matrix
    X_code = zeros(numRows, sum(nlevels) - length(nlevels));
    %fprintf('size X: %d x %d, size X_attr: %d x %d, length(nlevels): %d\n', ...
    %size(X,1), size(X,2), size(X_attr,1), size(X_attr,2), length(nlevels));
% Apply the selected coding scheme row by row
    for row = 1:numRows
        if no_choice && all(X_attr(row, :) == 0)
% No-choice rows have all-zero attribute values; coded representation stays zero
            X_code(row, :) = zeros(1, sum(nlevels) - length(nlevels));
        else
            if strcmp(coding, 'effect')
                X_code(row, :) = DCEDesignSA.effCode(X_attr(row, :), nlevels);
            elseif strcmp(coding, 'dummy')
                X_code(row, :) = DCEDesignSA.dummyCode(X_attr(row, :), nlevels);
            end
        end
    end

% Append interaction terms if specified
    if ~isempty(interactions)
        interactionMatrix = [];
        colIndex = [1, cumsum(nlevels - 1) + 1];
        colIndex = colIndex(1:end-1);
        for i = 1:length(interactions)
            cols  = interactions{i};
            col1  = cols(1);
            col2  = cols(2);
            startCol1   = colIndex(col1);
            startCol2   = colIndex(col2);
            nLevelsCol1 = nlevels(col1) - 1;
            nLevelsCol2 = nlevels(col2) - 1;
            for level1 = 0:(nLevelsCol1 - 1)
                for level2 = 0:(nLevelsCol2 - 1)
                    interactionColumn = X_code(:, startCol1 + level1) .* ...
                                        X_code(:, startCol2 + level2);
                    interactionMatrix = [interactionMatrix, interactionColumn];
                end
            end
        end
        X_code = [X_code, interactionMatrix];
    end

% Order covariate: effects-code the presentation position into J-1 columns.
% Position j < J -> unit vector e_j; position J (last) -> all -1; rows with
% position 0 (the no-choice row) -> all 0. J is recovered as the largest
% position present, which is n_alt because every choice set contains a full
% permutation 1..n_alt.
    if order_effect
        J = max(order_pos);
        order_code = zeros(numRows, J - 1);
        for row = 1:numRows
            pos = order_pos(row);
            if pos >= 1 && pos < J
                order_code(row, pos) = 1;
            elseif pos == J
                order_code(row, :) = -1;
            end
        end
        X_code = [X_code, order_code];
    end

% Append ASC column when no_choice is active.
% The no-choice row (identified by all-zero attribute values) receives ASC = 1;
% all regular alternative rows receive ASC = 0.
% ASC goes LAST to match the prior_mean/prior_var/beta ordering used by
% dce_tool (main effects, interactions, order positions, then the no-choice
% ASC). Do not move it to the front — that misaligned the prior with the
% columns and was a real SA/D-value bug.
    if no_choice
        asc_col = zeros(numRows, 1);
        for row = 1:numRows
            if all(X_attr(row, :) == 0)
                asc_col(row) = 1;
            end
        end
        X_code = [X_code, asc_col];
    end

end
