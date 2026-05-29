function info = InfoMNL(X, beta, cset)
% INFOMNL Computes the Fisher Information Matrix for a Given Design Matrix and Parameter Vector.
%
%   This function calculates the Fisher information matrix for a given design matrix
%   and parameter vector in the context of the Multinomial Logit (MNL) model. 
%
%   INPUTS:
%       X     - (matrix) Design matrix of size (N × K), where N is the number of total alternatives 
%               across all choice sets, and K is the number of attributes.
%       beta  - (vector) Parameter vector of size (K × 1), representing the model coefficients 
%               at which the information matrix is evaluated.
%       cset  - (integer) The number of choice set.
%
%   OUTPUT:
%       info  - (matrix) Fisher information matrix of size (K × K).
%
%   REFERENCES:
%       [1] Train, K. (2009). Discrete Choice Methods with Simulation. Cambridge University Press.

    [r, c] = size(X);
    nchoices = r / cset;
    info = zeros(c, c);
    for i = 0:cset-1
        xrow = X(i * nchoices + 1 : (i + 1) * nchoices, :);
        u = xrow * beta;
        exp_u = exp(u);
        p = exp_u ./ sum(exp_u);
        Pdiag = diag(p);
        info = info + xrow' * (Pdiag - p * p') * xrow;
    end
end
