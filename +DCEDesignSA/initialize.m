function result = initialize(cset, n_alt, nlevels, f, order_effect, no_choice)
% RANDOM_START Generates a random starting design for Bayesian D-optimal
% discrete choice experiments.
%
%   This function generates a random starting choice design matrix using
%   either a full-profile or partial-profile approach. Optionally, a
%   presentation order column can be appended, and a no-choice alternative
%   (an all-zero row) can be added to each choice set.
%
%   When no_choice is true, one additional row of zeros is appended to each
%   choice set after the regular alternatives. This row represents the
%   no-choice option, which has no attribute values and will receive an
%   alternative-specific constant (ASC) during the coding step in
%   transform_design.
%
%   INPUTS:
%       cset         - (integer) Number of choice sets in the design.
%       n_alt        - (integer) Number of regular alternatives per choice set,
%                      excluding the no-choice option.
%       nlevels      - (vector) Number of levels for each attribute.
%       f            - (integer) Number of attributes fixed per choice set.
%                         - f = 0: Full-profile design.
%                         - f > 0: Partial-profile design.
%       order_effect - (logical, optional) Whether to append a random
%                      presentation order column. The no-choice alternative
%                      does not participate in the ordering.
%                         - false (default): No order column appended.
%                         - true: Order column appended for regular alternatives.
%       no_choice    - (logical, optional) Whether to append a no-choice
%                      alternative (all zeros) to each choice set.
%                         - false (default): No no-choice row appended.
%                         - true: One all-zero row appended per choice set.
%
%   OUTPUT:
%       result       - (matrix) Design matrix of size
%                      (cset * n_alt_total) x length(nlevels), where
%                      n_alt_total = n_alt + 1 if no_choice = true.
%                      If order_effect = true, one additional order column
%                      is appended (only covering the regular alternatives).

    if nargin < 5 || isempty(order_effect)
        order_effect = false;
    end
    if nargin < 6 || isempty(no_choice)
        no_choice = false;
    end

% Initialize an empty cell array to hold the design data
    data = cell(1, length(nlevels));

% Full-Profile Design: assign completely random levels for each attribute
    if f == 0
        for i = 1:length(nlevels)
            data{i} = randi([1, nlevels(i)], cset * n_alt, 1);
        end
        result = cell2mat(data);
    else
% Partial-Profile Design: fix f randomly selected attributes per choice set
        for cs = 1:cset
% Randomly select which attributes are fixed in this choice set
            fixed_vars = randperm(length(nlevels), f);
            for i = 1:length(nlevels)
                if ismember(i, fixed_vars)
% Fixed attributes share a single random level across all alternatives
                    fixed_value = randi([1, nlevels(i)], 1, 1);
                    data{i}((cs-1)*n_alt+1:cs*n_alt, 1) = repmat(fixed_value, n_alt, 1);
                else
% Non-fixed attributes must have at least two distinct levels to ensure
% variation within the choice set
                    all_same = true;
                    while all_same
                        random_values = randi([1, nlevels(i)], n_alt, 1);
                        if length(unique(random_values)) > 1
                            all_same = false;
                        end
                    end
                    data{i}((cs-1)*n_alt+1:cs*n_alt, 1) = random_values;
                end
            end
        end
        result = cell2mat(data);
    end

% Append no-choice rows (all zeros) to each choice set if requested.
% These rows are inserted after the regular alternatives and before the
% order column so that transform_design can identify them by their zero values.
    if no_choice
        n_attr = length(nlevels);
        result_with_nc = zeros(cset * (n_alt + 1), n_attr);
        for cs = 1:cset
% Copy regular alternative rows into the expanded matrix
            src_rows  = (cs-1)*n_alt+1 : cs*n_alt;
            dest_rows = (cs-1)*(n_alt+1)+1 : cs*(n_alt+1)-1;
            result_with_nc(dest_rows, :) = result(src_rows, :);
% The last row of each choice set is the no-choice alternative (all zeros)
            result_with_nc(cs*(n_alt+1), :) = zeros(1, n_attr);
        end
        result = result_with_nc;
    end

% Append presentation order column for regular alternatives only.
% The no-choice alternative is excluded from the ordering.
    if order_effect
        n_alt_total = size(result, 1) / cset;
        randomorder = [];
        for idx = 1:cset
            order = randperm(n_alt, n_alt);
% Append a placeholder (0) for the no-choice row so the column length matches
            if no_choice
                order = [order, 0];
            end
            randomorder = [randomorder, order];
        end
        result = [result, randomorder'];
    end

end
