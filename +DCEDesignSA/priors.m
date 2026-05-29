function [pts, wts] = priors(priorMean, priorVariance)
% GEN_DRAWS Generates quadrature points and weights using spherical-radial (SR) based method.
%
%   This function generates quadrature points and their associated weights for for approximating the integrals 
%   involved in the Bayesian D-optimality criterion. 
%   INPUTS:
%       priorMean     - (vector) Mean of the prior distribution.
%       priorVariance - (matrix) Covariance matrix of the prior distribution.
%   OUTPUTS:
%       pts - (matrix) Generated quadrature points.
%       wts - (vector) Associated weights (for SR) or uniform weights (for Halton).
%
%   REFERENCES:
%       [1] Gotwalt, C. M., Jones, B. A., & Steinberg, D. M. (2009). 
%           Fast computation of designs robust to parameter uncertainty for nonlinear settings. 
%           Technometrics, 51(1), 88-95.
   

    % Number of parameters
    p = length(priorMean);
    pw = twoSpherePointsAndWeights(p);
    npts = size(pw,1);
    wts = pw(:, p + 1)';
    pts = pw(:,1:p)';
    pv = chol( priorVariance );
    pts = pv' * pts;
    for bidx = 1:npts
        pts(:, bidx) = pts(:, bidx) + priorMean';
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
function halton_draws = get_halton_draws(beta, ndraws)
    % Generate Halton sequence of low-discrepancy quasi-random numbers
    p = length(beta); % Number of dimensions
    halton_seq = haltonset(p, 'Skip', 100, 'Leap', 10); % Generate Halton set
    halton_seq = scramble(halton_seq, 'RR2'); % Apply scrambling for better uniformity

    % Get first `ndraws` samples
    draws_unif_beta = net(halton_seq, ndraws);

    % Convert uniform draws to normal distribution
    halton_draws = zeros(ndraws, p);
    for i = 1:p
        halton_draws(:, i) = norminv(draws_unif_beta(:, i), beta(i), 1);
    end
end

