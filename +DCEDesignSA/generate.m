function [global_best_X, global_best_D, total_time] = generate(cset, n_alt, varargin)
% GENERATE Main interface for generating Bayesian D-optimal discrete choice designs
% using simulated annealing.
%
%   This function provides a convenient entry point for the SA framework. It
%   validates all user inputs, constructs default prior distributions when none
%   are supplied, generates a random starting design, calls the core SA
%   optimisation routine, and returns the best design in a decoded, human-readable
%   format.
%
%   The prior dimension is computed automatically from nlevels and interactions.
%   When no_choice is true, one additional dimension is added to accommodate the
%   alternative-specific constant (ASC) for the no-choice option.
%
%   INPUTS:
%       cset   - (integer) Number of choice sets.
%       n_alt  - (integer) Number of regular alternatives per choice set,
%                excluding the no-choice option.
%
%   REQUIRED name-value inputs (one or both):
%       'nlevels'    - (vector) Number of levels for each attribute.
%       'attr_cell' - (cell array) String labels for each attribute level.
%                     If both are provided, they must be consistent.
%
%   OPTIONAL name-value inputs:
%       'f'            - (integer) Number of fixed attributes per choice set.
%                        Default: 0 (full-profile).
%       'interactions' - (cell array) Pairs of interacting attribute indices.
%                        Example: {[1,2]} means attribute 1 and 2 interact.
%                        Default: {} (main effects only).
%       'termination'  - (string) Stopping criterion: 'adaptive', 'time', or
%                        'cycle'. Default: 'adaptive'.
%       'max_value'    - (numeric) Maximum seconds or cycles. Required when
%                        termination is 'time' or 'cycle'. Default: [].
%       'order_effect' - (logical) Whether to model presentation order effects.
%                        Default: false.
%       'coding'       - (string) Attribute coding scheme: 'effect' or 'dummy'.
%                        Default: 'effect'.
%       'no_choice'    - (logical) Whether to include a no-choice alternative
%                        in each choice set. When true, one all-zero row is
%                        appended per choice set and an ASC is added to the
%                        parameter vector. Default: false.
%       'prior_mean'   - (vector) Prior mean vector. Length must equal the
%                        computed parameter dimension. Default: zeros(1, dim).
%       'prior_var'    - (matrix) Prior covariance matrix of size dim x dim.
%                        Default: eye(dim) * 1.
%
%   OUTPUTS:
%       global_best_X  - (cell array) Best design in decoded format. The first
%                        column contains choice set labels (CS1, CS2, ...), the
%                        second column contains alternative labels (Alt1, Alt2, ...),
%                        and the remaining columns contain attribute levels as
%                        strings (if attr_cell provided) or integers.
%       global_best_D  - (scalar) Best Bayesian D-optimality value found.
%       total_time     - (scalar) Total runtime in seconds.

    %% Parse name-value inputs
    p = inputParser;
    addParameter(p, 'nlevels',       []);
    addParameter(p, 'attr_cell',     []);
    addParameter(p, 'f',             0);
    addParameter(p, 'interactions',  {});
    addParameter(p, 'termination',   'adaptive');
    addParameter(p, 'max_value',     []);
    addParameter(p, 'order_effect',  false);
    addParameter(p, 'coding',        'effect');
    addParameter(p, 'no_choice',     false);
    % Updated parameter names to snake_case as per our naming plan
    addParameter(p, 'prior_mean',    []);
    addParameter(p, 'prior_var',     []);
    parse(p, varargin{:});

    nlevels        = p.Results.nlevels;
    attr_cell      = p.Results.attr_cell;
    f              = p.Results.f;
    interactions   = p.Results.interactions;
    termination    = p.Results.termination;
    max_value      = p.Results.max_value;
    order_effect   = p.Results.order_effect;
    coding         = p.Results.coding;
    no_choice      = p.Results.no_choice;
    prior_mean     = p.Results.prior_mean;
    prior_var      = p.Results.prior_var;

   %% Validate and Parse Attribute Inputs (Supports Struct and Cell)
    if ~isempty(attr_cell)
        % Use the new parsing function to extract names, levels, and labels
        [parsed_nlevels, attr_labels, attr_names] = DCEDesignSA.parse_attr_labels(attr_cell);
        
        % Validate that all labels are strings (Dynamic check for Struct or Cell)
        for i = 1:length(attr_labels)
            current_attr_labels = attr_labels{i};
            for j = 1:length(current_attr_labels)
                if ~ischar(current_attr_labels{j}) && ~isstring(current_attr_labels{j})
                    error('Attribute %d, Level %d must be a string, but received %s.', ...
                        i, j, class(current_attr_labels{j}));
                end
            end
        end

        % Check consistency with nlevels if both are provided
        if isempty(nlevels)
            nlevels = parsed_nlevels;
        elseif ~isequal(nlevels, parsed_nlevels)
            error('The provided nlevels %s does not match attr_cell-derived levels %s.', ...
                mat2str(nlevels), mat2str(parsed_nlevels));
        end
    elseif ~isempty(nlevels)
        % If only nlevels is provided, generate default attribute names (Attr1, Attr2...)
        attr_names = arrayfun(@(i) sprintf('Attr%d', i), 1:length(nlevels), 'UniformOutput', false);
        attr_labels = []; % No string labels available
    else
        % Neither provided
        error('You must provide either ''nlevels'' or ''attr_cell'' (as a struct or cell).');
    end

    %% Compute prior parameter dimension
    % Base dimension from main effects (effects or dummy coding)
    dim = sum(nlevels) - length(nlevels);
    % Add interaction terms
    for i = 1:length(interactions)
        pair = interactions{i};
        dim  = dim + (nlevels(pair(1)) - 1) * (nlevels(pair(2)) - 1);
    end
    % Add one dimension for the no-choice ASC
    if no_choice
        dim = dim + 1;
    end

    %% Validate or set prior_mean
    if isempty(prior_mean)
        prior_mean = zeros(1, dim);
    else
        if length(prior_mean) ~= dim
            error('prior_mean has length %d but expected %d based on nlevels, interactions, and no_choice.', ...
                length(prior_mean), dim);
        end
    end

    %% Validate or set prior_var
    if isempty(prior_var)
        prior_var = eye(dim) * 1;
    else
        [r, c] = size(prior_var);
        if r ~= dim || c ~= dim
            error('prior_var is %dx%d but expected %dx%d based on nlevels, interactions, and no_choice.', ...
                r, c, dim, dim);
        end
    end

    %% Generate quadrature points and weights from the prior (Renamed call)
    [pts, wts] = DCEDesignSA.priors(prior_mean, prior_var);

    %% Validate termination / max_value combination
    valid_termination = {'adaptive', 'time', 'cycle'};
    if ~ischar(termination) || ~ismember(termination, valid_termination)
        error('termination must be ''adaptive'', ''time'', or ''cycle''.');
    end
    if strcmp(termination, 'adaptive') && ~isempty(max_value)
        error('max_value should not be provided when termination is ''adaptive''.');
    end
    if any(strcmp(termination, {'time', 'cycle'})) && isempty(max_value)
        error('max_value must be provided when termination is ''time'' or ''cycle''.');
    end

    %% Generate random starting design (Renamed call)
    X = DCEDesignSA.initialize(cset, n_alt, nlevels, f, order_effect, no_choice);

    %% Run SA optimisation (Renamed call)
    [global_best_X, global_best_D, total_time,inf_error] = DCEDesignSA.SA( ...
        X, cset, n_alt, nlevels, pts, wts, f, interactions, termination, max_value, ...
        order_effect, coding, no_choice);

    %% Decode the optimised design to a human-readable format  
    if ~isempty(attr_cell)
        [~, attr_labels, attr_names] = DCEDesignSA.parse_attr_labels(attr_cell);
        decoded_X = DCEDesignSA.decode_X(global_best_X, attr_names, ...
            'n_alt', n_alt, ...
            'cset', cset, ...
            'attr_labels', attr_labels, ...
            'order_effect', order_effect, ...
            'no_choice', no_choice);
    else
        % Create default attribute names
        attr_names = arrayfun(@(i) sprintf('Attr%d', i), 1:length(nlevels), 'UniformOutput', false);
        decoded_X = DCEDesignSA.decode_X(global_best_X, attr_names, ...
            'n_alt', n_alt, ...
            'cset', cset, ...
            'order_effect', order_effect, ...
            'no_choice', no_choice);
    end

    % Calculate probabilities using the final design and prior draws
    X_encoded = DCEDesignSA.encode(global_best_X, nlevels, 'interactions' ,interactions,'order_effect', order_effect, 'coding',coding,'no_choice' ,no_choice);
    avg_probs = DCEDesignSA.calculate_average_probabilities(X_encoded, pts, n_alt, no_choice);

    %% Wrap results into a Class Object (JSS Requirement)
    % Collect metadata for the Result object
    meta.cset = cset;
    meta.n_alt = n_alt;
    meta.no_choice = no_choice;
    meta.coding = coding;
    meta.nlevels = nlevels;
    meta.attr_names = attr_names;
    meta.attr_labels = attr_labels;
    meta.inf_error = inf_error;
    meta.interactions = interactions;
    meta.f = f;
    meta.order_effect =order_effect;

    % Return the Result object instead of multiple variables
    % The first output 'global_best_X' now holds the object
    res_obj = DCEDesignSA.Result(decoded_X, global_best_X, global_best_D, total_time, meta, avg_probs,inf_error);
    % Use the first output to return the object
    global_best_X = res_obj;
    
end

