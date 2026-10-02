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
%                        When true, an order covariate is added to the model
%                        (Mao, Kessels & Mee 2025): n_alt-1 effects-coded
%                        position parameters alpha are estimated jointly with
%                        beta, so the information matrix is computed for
%                        (beta, alpha) and the SA also optimises the
%                        presentation order. Default: false.
%       'coding'       - (string) Attribute coding scheme: 'effect' or 'dummy'.
%                        Default: 'effect'.
%       'no_choice'    - (logical) Whether to include a no-choice alternative
%                        in each choice set. When true, one all-zero row is
%                        appended per choice set and an ASC is added to the
%                        parameter vector. Default: false.
%       'prior_mean'   - (vector) Prior mean vector. Length must equal the
%                        computed parameter dimension, ordered: main effects,
%                        interactions, order positions (if order_effect),
%                        no-choice ASC (if no_choice). Default: zeros(1, dim).
%       'prior_var'    - (matrix) Prior covariance matrix of size dim x dim.
%                        Default: eye(dim) * 1.
%       'sampling_method' - (string) Method used to approximate the prior
%                        integral (see DCEDesignSA.priors): 'SR' (spherical-
%                        radial cubature, default and unchanged from the
%                        original behaviour), 'halton' (quasi-Monte Carlo),
%                        or 'PMC' (plain/pseudo Monte Carlo).
%       'n_draws'      - (integer) Number of draws used for 'halton' or
%                        'PMC'. Ignored for 'SR'. Default: 1000.
%       'seed'         - (nonnegative integer or []) Seed for MATLAB's random
%                        number generator, applied once at the start of the
%                        run (covers the initial design, SA moves, and the
%                        'halton'/'PMC' prior draws). Default: [] (no seeding;
%                        each run differs). The caller's RNG state is restored
%                        afterwards. Exact reproducibility also needs a
%                        termination rule that doesn't depend on machine speed:
%                        with 'time', the number of iterations completed in the
%                        budget varies between runs, so results can still
%                        differ; use 'cycle' or 'adaptive'.
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
    addParameter(p, 'sampling_method', 'SR');
    addParameter(p, 'n_draws',         1000);
    addParameter(p, 'seed',            []);
    parse(p, varargin{:});

    nlevels         = p.Results.nlevels;
    attr_cell       = p.Results.attr_cell;
    f               = p.Results.f;
    interactions    = p.Results.interactions;
    termination     = p.Results.termination;
    max_value       = p.Results.max_value;
    order_effect    = p.Results.order_effect;
    coding          = p.Results.coding;
    no_choice       = p.Results.no_choice;
    prior_mean      = p.Results.prior_mean;
    prior_var       = p.Results.prior_var;
    sampling_method = p.Results.sampling_method;
    n_draws         = p.Results.n_draws;
    seed            = p.Results.seed;

    %% Optional reproducibility: seed the global RNG for this run only
    if ~isempty(seed)
        if ~isnumeric(seed) || ~isscalar(seed) || ~isfinite(seed) || seed ~= fix(seed) ...
                || seed < 0 || seed > 2^32 - 2
            error('DCEDesignSA:invalidInput', ...
                '''seed'' must be an integer between 0 and 2^32-2, or [] for no seeding.');
        end
        rng_state = rng;
        restore_rng = onCleanup(@() rng(rng_state));
        rng(seed);
    end

    %% Validate scalar options up front, so a bad value fails here with a
    % clear message instead of deep inside the SA (or, worse, silently
    % producing a meaningless design).
    require_integer(cset,    'cset',    1);
    require_integer(n_alt,   'n_alt',   2);
    require_integer(n_draws, 'n_draws', 1);
    order_effect = require_logical(order_effect, 'order_effect');
    no_choice    = require_logical(no_choice,    'no_choice');
    if isstring(coding) && isscalar(coding), coding = char(coding); end
    if ~ischar(coding) || ~ismember(coding, {'effect','dummy'})
        error('DCEDesignSA:invalidInput', '''coding'' must be ''effect'' or ''dummy''.');
    end
    if isstring(termination) && isscalar(termination), termination = char(termination); end
    if ~ischar(termination) || ~ismember(termination, {'adaptive','time','cycle'})
        error('DCEDesignSA:invalidTermination', ...
            'termination must be ''adaptive'', ''time'', or ''cycle''.');
    end
    if strcmp(termination, 'adaptive') && ~isempty(max_value)
        error('DCEDesignSA:invalidTermination', ...
            'max_value should not be provided when termination is ''adaptive''.');
    end
    if any(strcmp(termination, {'time', 'cycle'})) && isempty(max_value)
        error('DCEDesignSA:invalidTermination', ...
            'max_value must be provided when termination is ''time'' or ''cycle''.');
    end
    if ~isempty(max_value)
        if ~isnumeric(max_value) || ~isscalar(max_value) || ~isfinite(max_value) || max_value <= 0
            error('DCEDesignSA:invalidTermination', ...
                'max_value must be a positive finite scalar (seconds for ''time'', cycles for ''cycle'').');
        end
        if strcmp(termination, 'cycle') && max_value ~= fix(max_value)
            error('DCEDesignSA:invalidTermination', ...
                'max_value must be an integer number of cycles when termination is ''cycle''.');
        end
    end

   %% Validate and Parse Attribute Inputs (Supports Struct and Cell)
    if ~isempty(attr_cell)
        % Use the new parsing function to extract names, levels, and labels
        [parsed_nlevels, attr_labels, attr_names] = DCEDesignSA.parse_attr_labels(attr_cell);
        
        % Validate that all labels are strings (Dynamic check for Struct or Cell)
        for i = 1:length(attr_labels)
            current_attr_labels = attr_labels{i};
            for j = 1:length(current_attr_labels)
                if ~ischar(current_attr_labels{j}) && ~isstring(current_attr_labels{j})
                    error('DCEDesignSA:invalidAttributes', ...
                        'Attribute %d, Level %d must be a string, but received %s.', ...
                        i, j, class(current_attr_labels{j}));
                end
            end
        end

        % Check consistency with nlevels if both are provided
        if isempty(nlevels)
            nlevels = parsed_nlevels;
        elseif ~isequal(nlevels, parsed_nlevels)
            error('DCEDesignSA:invalidAttributes', ...
                'The provided nlevels %s does not match attr_cell-derived levels %s.', ...
                mat2str(nlevels), mat2str(parsed_nlevels));
        end
    elseif ~isempty(nlevels)
        % If only nlevels is provided, generate default attribute names (Attr1, Attr2...)
        attr_names = arrayfun(@(i) sprintf('Attr%d', i), 1:length(nlevels), 'UniformOutput', false);
        attr_labels = []; % No string labels available
    else
        % Neither provided
        error('DCEDesignSA:invalidAttributes', ...
            'You must provide either ''nlevels'' or ''attr_cell'' (as a struct or cell).');
    end

    %% Validate attribute levels, fixed attributes and interactions
    if ~isnumeric(nlevels) || ~isvector(nlevels) || any(~isfinite(nlevels)) ...
            || any(nlevels ~= fix(nlevels)) || any(nlevels < 2)
        error('DCEDesignSA:invalidAttributes', ...
            'Every attribute needs an integer number of levels >= 2 (got %s).', mat2str(nlevels));
    end
    nlevels = nlevels(:)';
    nattr   = numel(nlevels);
    if ~isnumeric(f) || ~isscalar(f) || ~isfinite(f) || f ~= fix(f) || f < 0 || f > nattr - 1
        error('DCEDesignSA:invalidInput', ...
            '''f'' (number of fixed attributes) must be an integer between 0 and %d (number of attributes - 1).', nattr - 1);
    end
    if ~iscell(interactions)
        error('DCEDesignSA:invalidInput', ...
            '''interactions'' must be a cell array of attribute-index pairs, e.g. {[1 2]}.');
    end
    seen_pairs = zeros(0, 2);
    for i = 1:numel(interactions)
        pair = interactions{i};
        if ~isnumeric(pair) || numel(pair) ~= 2 || any(pair ~= fix(pair)) ...
                || any(pair < 1) || any(pair > nattr) || pair(1) == pair(2)
            error('DCEDesignSA:invalidInput', ...
                'interactions{%d} must be a pair of two different attribute indices between 1 and %d.', i, nattr);
        end
        pair = sort(pair(:)');
        if ismember(pair, seen_pairs, 'rows')
            error('DCEDesignSA:invalidInput', 'interactions{%d} duplicates an earlier interaction.', i);
        end
        seen_pairs(end+1, :) = pair; %#ok<AGROW>
    end

    %% Compute prior parameter dimension
    % Base dimension from main effects (effects or dummy coding)
    dim = sum(nlevels) - length(nlevels);
    % Add interaction terms
    for i = 1:length(interactions)
        pair = interactions{i};
        dim  = dim + (nlevels(pair(1)) - 1) * (nlevels(pair(2)) - 1);
    end
    % Order covariate: (n_alt - 1) effects-coded position parameters (alpha)
    if order_effect
        dim = dim + (n_alt - 1);
    end
    % Add one dimension for the no-choice ASC
    if no_choice
        dim = dim + 1;
    end

    %% Validate or set prior_mean
    if isempty(prior_mean)
        prior_mean = zeros(1, dim);
    else
        if ~isnumeric(prior_mean) || ~isvector(prior_mean) || any(~isfinite(prior_mean))
            error('DCEDesignSA:invalidPrior', 'prior_mean must be a numeric vector with finite entries.');
        end
        if length(prior_mean) ~= dim
            error('DCEDesignSA:invalidPrior', ...
                'prior_mean has length %d but expected %d based on nlevels, interactions, order_effect, and no_choice.', ...
                length(prior_mean), dim);
        end
    end

    %% Validate or set prior_var
    if isempty(prior_var)
        prior_var = eye(dim) * 1;
    else
        if ~isnumeric(prior_var) || any(~isfinite(prior_var(:)))
            error('DCEDesignSA:invalidPrior', 'prior_var must be a numeric matrix with finite entries.');
        end
        [r, c] = size(prior_var);
        if r ~= dim || c ~= dim
            error('DCEDesignSA:invalidPrior', ...
                'prior_var is %dx%d but expected %dx%d based on nlevels, interactions, order_effect, and no_choice.', ...
                r, c, dim, dim);
        end
        if norm(prior_var - prior_var', 'fro') > 1e-10 * max(1, norm(prior_var, 'fro'))
            error('DCEDesignSA:invalidPrior', 'prior_var must be symmetric.');
        end
        [~, not_pd] = chol(prior_var);
        if not_pd
            error('DCEDesignSA:invalidPrior', 'prior_var must be positive definite.');
        end
    end

    %% Generate quadrature/sampling points and weights from the prior
    [pts, wts, n_draws_used] = DCEDesignSA.priors(prior_mean, prior_var, ...
        'method', sampling_method, 'n_draws', n_draws);

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

    % Calculate probabilities in the same presentation order as decoded_X.
    X_encoded = DCEDesignSA.encode(global_best_X, nlevels, 'interactions' ,interactions,'order_effect', order_effect, 'coding',coding,'no_choice' ,no_choice);
    order_positions = [];
    if order_effect
        raw_order = reshape(global_best_X(:, end), n_alt + no_choice, cset);
        order_positions = raw_order(1:n_alt, :);
    end
    avg_probs = DCEDesignSA.calculate_average_probabilities( ...
        X_encoded, pts, n_alt, no_choice, wts, order_positions);

    %% Wrap results into a Class Object (JSS Requirement)
    % Collect metadata for the Result object
    meta.cset = cset;
    meta.n_alt = n_alt;
    meta.no_choice = no_choice;
    meta.has_no_choice = no_choice;
    meta.coding = coding;
    meta.nlevels = nlevels;
    meta.attr_names = attr_names;
    meta.attr_labels = attr_labels;
    meta.inf_error = inf_error;
    meta.interactions = interactions;
    meta.f = f;
    meta.order_effect =order_effect;
    meta.sampling_method    = sampling_method;
    meta.n_draws_requested  = n_draws;
    meta.n_draws_used       = n_draws_used;
    meta.seed               = seed;

    % Return the Result object instead of multiple variables
    % The first output 'global_best_X' now holds the object
    res_obj = DCEDesignSA.Result(decoded_X, global_best_X, global_best_D, total_time, meta, avg_probs,inf_error);
    % Use the first output to return the object
    global_best_X = res_obj;

end

%% ------------------------------------------------------------------------
function require_integer(value, name, minimum)
% Error unless value is a finite real integer scalar >= minimum.
    if ~isnumeric(value) || ~isscalar(value) || ~isreal(value) || ~isfinite(value) ...
            || value ~= fix(value) || value < minimum
        error('DCEDesignSA:invalidInput', ...
            '''%s'' must be an integer scalar >= %d.', name, minimum);
    end
end

function out = require_logical(value, name)
% Accept true/false or 0/1 and return a logical scalar; error otherwise.
    if islogical(value) && isscalar(value)
        out = value;
    elseif isnumeric(value) && isscalar(value) && (value == 0 || value == 1)
        out = logical(value);
    else
        error('DCEDesignSA:invalidInput', '''%s'' must be true or false.', name);
    end
end

