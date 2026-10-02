function [pts, wts, n_draws_used] = priors(priorMean, priorVariance, varargin)
% GEN_DRAWS Generates parameter draws and weights for approximating the
% integrals involved in the Bayesian D-optimality criterion.
%
%   [pts, wts] = priors(priorMean, priorVariance)
%   [pts, wts, n_draws_used] = priors(priorMean, priorVariance, 'method', 'halton', 'n_draws', 1000)
%
%   INPUTS:
%       priorMean     - (vector) Mean of the prior distribution.
%       priorVariance - (matrix) Covariance matrix of the prior distribution.
%
%   OPTIONAL name-value inputs:
%       'method'  - (string) Sampling/quadrature method for the prior:
%                     'SR'     - Spherical-radial cubature (default, unchanged
%                                from the original behaviour). Deterministic;
%                                the number of points is fixed by the prior
%                                dimension. See Gotwalt et al. (2009).
%                     'halton' - Quasi-Monte Carlo using a scrambled Halton
%                                sequence mapped through N(priorMean, priorVariance).
%                                Equal weights.
%                     'PMC'    - Plain (pseudo) Monte Carlo: i.i.d. draws
%                                sampled directly from N(priorMean, priorVariance).
%                                Equal weights.
%       'n_draws' - (integer) Number of draws to generate for 'halton' or
%                     'PMC'. Ignored for 'SR', whose point count is
%                     determined by the prior dimension. Default: 1000.
%                     Floored at the SR cubature point count for the given
%                     dimension (see sr_point_count below) so that
%                     'halton'/'PMC' are never run on fewer, lower-quality
%                     draws than the deterministic default would use; a
%                     smaller request is bumped up with a warning.
%
%   OUTPUTS:
%       pts          - (matrix) Generated parameter draws (dim x S).
%       wts          - (vector) Associated weights (for SR) or uniform
%                      weights (for 'halton'/'PMC'), summing to 1.
%       n_draws_used - (integer) The actual number of draws/points used
%                      (S = size(pts,2)). For 'SR' this is the cubature
%                      point count (n_draws is ignored). For 'halton'/'PMC'
%                      this equals the requested n_draws, unless it was
%                      below the SR floor and got raised (see enforce_min_draws).
%
%   REFERENCES:
%       [1] Gotwalt, C. M., Jones, B. A., & Steinberg, D. M. (2009).
%           Fast computation of designs robust to parameter uncertainty for nonlinear settings.
%           Technometrics, 51(1), 88-95.

    ip = inputParser;
    addParameter(ip, 'method',  'SR');
    addParameter(ip, 'n_draws', 1000);
    parse(ip, varargin{:});
    method  = ip.Results.method;
    n_draws = ip.Results.n_draws;

    % Number of parameters
    dim = length(priorMean);

    method_lc = lower(method);
    if any(strcmp(method_lc, {'halton','pmc'}))
        % Only draw-based methods have a floor to enforce; 'SR' ignores
        % n_draws entirely, so gating here avoids ever warning about a
        % dimension the user didn't ask to sample.
        n_draws = enforce_min_draws(n_draws, dim);
    end

    switch method_lc
        case 'sr'
            pw   = twoSpherePointsAndWeights(dim);
            npts = size(pw,1);
            wts  = pw(:, dim + 1)';
            pts  = pw(:,1:dim)';
            pv   = chol( priorVariance );
            pts  = pv' * pts;
            for bidx = 1:npts
                pts(:, bidx) = pts(:, bidx) + priorMean';
            end
            n_draws_used = npts;

        case 'halton'
            pts = get_halton_draws(priorMean, priorVariance, n_draws);
            wts = ones(1, n_draws) / n_draws;
            n_draws_used = n_draws;

        case 'pmc'
            pv  = chol(priorVariance);
            z   = randn(dim, n_draws);
            pts = pv' * z + priorMean(:);
            wts = ones(1, n_draws) / n_draws;
            n_draws_used = n_draws;

        otherwise
            error('priors:UnknownMethod', ...
                'Unknown sampling method "%s". Use ''SR'', ''halton'', or ''PMC''.', method);
    end
end

%% Internal Function:
function n = sr_point_count(dim)
% Number of points the deterministic SR cubature rule produces for a given
% prior dimension. Derived by actually calling twoSpherePointsAndWeights
% (the same function the 'sr' case uses) rather than a separately
% maintained formula, so this can never drift out of sync with SR's real
% behaviour if the cubature construction ever changes.
    n = size(twoSpherePointsAndWeights(dim), 1);
end

%% Internal Function:
function n_draws = enforce_min_draws(n_draws, dim)
% Floor n_draws at the SR method's point count for this dimension, so
% 'halton'/'PMC' never approximate the prior integral with fewer draws
% than the default deterministic method would use.
    min_draws = sr_point_count(dim);
    if n_draws < min_draws
        warning('priors:NDrawsTooSmall', ...
            ['n_draws=%d is below the SR cubature point count (%d) for ' ...
             'dim=%d; using %d instead.'], n_draws, min_draws, dim, min_draws);
        n_draws = min_draws;
    end
end

%% Internal Function:
function  simplexp =simplexPoints(p)
swt = ones(2 * p + 2,1) * (p * (7 - p)) / (2 * (p + 1) ^ 2 * (p + 2));
mwt = ones((p + 1) * p,1)* (2 * (p - 1) ^ 2) / (p * (p + 1) ^ 2 * (p + 2));
wt = [swt;mwt];
v = zeros(p + 1, p);
for i = 1:(p + 1)
        for j = 1:p
            if j < i
                v(i, j) = -sqrt((p + 1) / (p * (p - j + 2) * (p - j + 1)));
            elseif j == i
                v(i, j) = sqrt(((p + 1) * (p - i + 1)) / (p * (p - i + 2)));
            else
                v(i, j) = 0;
            end
        end
end
m = zeros(((p + 1) * p) / 2, p);
cCount = 1;
    for i = 1:p
        for j = (i + 1):(p + 1)
            tmp = (v(i, :) + v(j, :)) / 2;
            d = sqrt(tmp * tmp');
            m(cCount, :) = tmp / d;
            cCount = cCount + 1;
        end
    end
pts = [v;-v; m;-m];
simplexp=[pts,wt];
end

%% Internal Function: 
function ptwt = twoSpherePointsAndWeights(p)
         pt0 = zeros(1, p);
         wt0 = 8 / ((p + 2) * (p + 4));
         wt1 = simplexPoints( p );
         wt2 = wt1;
         pt1 = wt1(:,1:p);
         wt1(:, 1 : p) = [];
         pt1 = pt1*sqrt( p + 4 - sqrt( 2 * p + 8 ) );
         wt1 = wt1*p * (p + 2) / ((p + 4) * (2 - sqrt( 2 * p + 8 )) ^ 2);
         pt2 = wt2(:,1:p);

         wt2(:, 1 : p) = [];
         pt2 = pt2*sqrt( p + 4 + sqrt( 2 * p + 8 ) );
         wt2 = wt2*p * (p + 2) / ((p + 4) * (2 + sqrt( 2 * p + 8 )) ^ 2);
         wt = [wt0 ;wt1 ; wt2];
         pt = [pt0 ; pt1; pt2];
         ptwt = [pt,wt];
end

%% Internal Function:
function pts = get_halton_draws(priorMean, priorVariance, ndraws)
    % Generate a scrambled Halton (quasi-Monte Carlo) sequence and map it
    % through N(priorMean, priorVariance) via the inverse normal CDF per
    % dimension followed by the prior's Cholesky factor, so that
    % correlation structure in priorVariance is preserved (unlike a
    % per-dimension unit-variance draw).
    %
    % Returns pts as (dim x ndraws), using the same "pv' * Z + priorMean"
    % column-per-draw convention as the 'sr' and 'pmc' cases in priors(),
    % rather than a separate row-per-draw convention — one shared
    % orientation for how the prior's Cholesky factor is applied, instead
    % of three independently-written ones.
    dim = length(priorMean);
    halton_seq = haltonset(dim, 'Skip', 1000, 'Leap', 100); % Generate Halton set
    halton_seq = scramble(halton_seq, 'RR2'); % Apply scrambling for better uniformity

    % Get first `ndraws` samples, mapped to independent standard normals
    u = net(halton_seq, ndraws);        % ndraws x dim, Uniform(0,1)
    z = norminv(u, 0, 1)';               % dim x ndraws, standard normal

    % Impose the prior covariance and mean
    pv  = chol(priorVariance);          % upper-triangular: priorVariance = pv' * pv
    pts = pv' * z + priorMean(:);
end

