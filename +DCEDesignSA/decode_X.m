function X_decoded = decode_X(X, attr_names, varargin)
% DECODE_X Converts numeric design to a human-readable format with headers.
%
%   INPUTS:
%       attr_names - (cell array) Column names for the attributes.
% 
%
%   This function post-processes the raw numeric design matrix returned by the
%   SA optimiser. It prepends a choice set label column (CS1, CS2, ...) and an
%   alternative label column (Alt1, Alt2, ...) to make the design easy to read
%   and export. Attribute values are optionally replaced with their original
%   string labels when attr_labels is provided.
%
%   When order_effect is true, the last column of X stores presentation order.
%   The rows within each choice set are reordered accordingly before decoding,
%   so that the output reflects the actual order in which alternatives would
%   be shown to respondents. The order column itself is not included in the
%   output. The alternative labels (Alt1, Alt2, ...) are assigned sequentially
%   to reflect presentation position, not the original row order.
%
%   When no_choice is true, the last row of each choice set is the no-choice
%   alternative. It is labelled 'No Choice' in the alternative column and its
%   attribute values are displayed as '-'.
%
%   INPUTS:
%       X     - (matrix) Numeric design matrix as returned by the SA optimiser.
%       n_alt - (integer) Number of regular alternatives per choice set,
%               excluding the no-choice row.
%       cset  - (integer) Number of choice sets.
%
%   OPTIONAL name-value inputs:
%       'attr_labels'  - (cell array) String labels for each attribute level,
%                        as returned by parse_attr_labels. When provided,
%                        numeric attribute values are replaced with strings.
%                        Default: [] (numeric values retained).
%       'order_effect' - (logical) Whether the last column of X stores
%                        presentation order. Default: false.
%       'no_choice'    - (logical) Whether the last row of each choice set is
%                        the no-choice alternative. Default: false.
%
%   OUTPUT:
%       X_decoded - (cell array) Decoded design matrix. Column 1 contains
%                   choice set labels, column 2 contains alternative labels,
%                   and the remaining columns contain attribute values as
%                   strings or integers.

    % Parse optional parameters
    p = inputParser;
    
    % Required inputs
    addRequired(p, 'X');
    addRequired(p, 'attr_names');
    
    % Optional parameters with default values (Flexible & Easy for small examples)
    addParameter(p, 'n_alt', 1);
    addParameter(p, 'cset', 1);
    addParameter(p, 'attr_labels', []);
    addParameter(p, 'order_effect', false);
    addParameter(p, 'no_choice', false);
    
    % Parse the inputs
    parse(p, X, attr_names, varargin{:});
    
    % Extract results from parser
    n_alt        = p.Results.n_alt;
    cset         = p.Results.cset;
    attr_labels  = p.Results.attr_labels;
    order_effect = p.Results.order_effect;
    no_choice    = p.Results.no_choice;

    n_alt_total = n_alt + no_choice;
    
    % Handle presentation order if order_effect is enabled
    if order_effect
        for cs = 1:cset
            rows = (cs-1)*n_alt_total+1 : cs*n_alt_total;
            regular_rows = rows(1:n_alt);
            % order(r) is the presentation position of row r (the same value
            % encode() turns into the position covariate). The profile shown
            % at position p is therefore the row r with order(r) == p, i.e.
            % the inverse permutation — using order directly is only correct
            % when the permutation is its own inverse.
            order = X(regular_rows, end);
            [~, shown_row] = sort(order);
            X(regular_rows, 1:end-1) = X(regular_rows(shown_row), 1:end-1);
        end
        X = X(:, 1:end-1);
    end

    [numRows, numCols] = size(X);

    % Decode numeric levels into strings or keep as numbers
    X_attr = cell(numRows, numCols);
    for row = 1:numRows
        for col = 1:numCols
            if no_choice && mod(row, n_alt_total) == 0
                X_attr{row, col} = '-'; % Placeholder for no-choice rows
            elseif ~isempty(attr_labels)
                X_attr{row, col} = attr_labels{col}{X(row, col)};
            else
                X_attr{row, col} = X(row, col);
            end
        end
    end

    % Build ChoiceSet and Alternative index columns
    cs_col  = cell(numRows, 1);
    alt_col = cell(numRows, 1);
    for cs = 1:cset
        rows = (cs-1)*n_alt_total+1 : cs*n_alt_total;
        for alt = 1:n_alt_total
            curr_row = rows(alt);
            cs_col{curr_row} = sprintf('CS%d', cs);
            if no_choice && alt == n_alt_total
                alt_col{curr_row} = 'No Choice';
            else
                alt_col{curr_row} = sprintf('Alt%d', alt);
            end
        end
    end

    % --- NEW: Construct the final output with a header row ---
    header = [{'ChoiceSet', 'Alternative'}, attr_names];
    data_body = [cs_col, alt_col, X_attr];
    X_decoded = [header; data_body]; 
end