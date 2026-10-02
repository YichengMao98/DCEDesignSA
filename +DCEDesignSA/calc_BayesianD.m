function[DB, inf_error] = calc_BayesianD(xmat, pts, wts, cset)
% CALC_BAYESIAND Computes the Bayesian D-optimality criterion for a given design.
%
%   This function evaluates the Bayesian D-optimality criterion for a given 
%   design matrix. It computes the expected log-determinant of the 
%   Fisher information matrix over a set of parameter draws weighted by their 
%   associated probabilities.
%
%   INPUTS:
%       xmat - (matrix) Design matrix of size (N × K), where N is the total number 
%              of alternatives across all choice sets, and K is the number of attributes.
%       pts  - (matrix) A matrix of parameter draws, where each column represents a 
%              sampled parameter vector from the prior distribution.
%       wts  - (vector) A weight vector corresponding to each sampled parameter vector.
%       cset - (integer) The number of alternatives per choice set.
%
%   OUTPUT:
%       DB - (scalar) The Bayesian D-optimality criterion value.
%
%   REFERENCES:
%       [1] Kessels, R., Goos, P., and Vandebroek, M. (2006). 
%       A comparison of criteria to design efficient choice experiments. 
%       Journal of Marketing Research, 43(3):409–419.


    DB = 0;
    inf_count = 0; % Counter for draws where det(info) <= 0
    for idx = 1:length(wts)
        beta = pts(:, idx);  % Extract the current parameter sample
        
        % Compute the Fisher information matrix
        info = DCEDesignSA.InfoMNL(xmat, beta, cset);
        det_info = det(info);
        %fprintf('calc_BayesianD: det(info)=%.6f\n', det(info));
        % Evaluate Bayesian D-optimality function
        if det_info >= 0
            DB = DB + log(det_info) * wts(idx);
        else
            % Infinite D-error case:
            inf_count = inf_count + 1;
        end
    end
    % Final calculation of the percentage of infinite draws
    inf_error = (inf_count / length(wts));
    if inf_count > 0
        % Penalize singular or invalid matrices. Pinned exactly to -10000
        % here (rather than overwritten mid-loop) so DB is a stable function
        % of inf_error: any other draws' log-det terms are discarded, not
        % added on top of the sentinel. Matches update_information_matrix.m.
        DB = -10000;
    end

end
