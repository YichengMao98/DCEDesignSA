function xrow = dummyCode(X, nlevels)
% DUMMYCODE Encodes categorical attributes using dummy coding for discrete choice models.
%
%   This function applies dummy coding to transform categorical attributes
%   into numerical representations suitable for discrete choice modelling.
%   The last level of each attribute is used as the reference category.
%
%   INPUTS:
%       X        - (vector) A vector representing the categorical levels of attributes.
%       nlevels  - (vector) A vector specifying the number of levels for each attribute.
%
%   OUTPUT:
%       xrow     - (vector) A transformed vector of coded attributes using dummy coding.
%
%   EXAMPLE:
%       Suppose an attribute has three levels (1, 2, 3):
%       Dummy coding representation would be:
%           Level 1 → [ 1,  0]
%           Level 2 → [ 0,  1]
%           Level 3 → [ 0,  0] (Reference category)

% Determine the number of factors (attributes)
    nf = length(nlevels);
% Compute the total number of dummy-coded variables
    df = sum(nlevels) - nf;
% Initialize output vector with zeros
    xrow = zeros(1, df);
% Initialize starting index for dummy coding
    startidx = 1;
% Iterate through each attribute to apply dummy coding
    for i = 1:nf
        nl = nlevels(i); % Number of levels for the current attribute
        xtmp = zeros(1, nl - 1); % Preallocate binary coding vector
        if X(i) < nl
            xtmp(X(i)) = 1; % Assign binary 1 to the corresponding level
        end
        % Reference category (last level) remains all zeros
% Assign the dummy-coded values to the output vector
        xrow(startidx:startidx + nl - 2) = xtmp;
% Update the index for the next attribute
        startidx = startidx + nl - 1;
    end
end