function selected_rows = selectRows(row, n_alt)
% SELECTROWS Identifies the indices of alternatives within a choice set.
%
%   This function determines the corresponding row indices for all alternatives 
%   that belong to the same choice set as a given row index. 
%   INPUTS:
%       row    - (integer) The row index for which the corresponding choice set is determined.
%       n_alt  - (integer) The number of alternatives per choice set.
%
%   OUTPUT:
%       selected_rows - (vector) A row vector containing the indices of all alternatives 
%                       within the choice set corresponding to the input row.
%

    % Compute the index of the first row in the choice set
    fr = floor(row / n_alt);
    
    % Determine the indices of all rows within the same choice set
    if fr * n_alt == row
        rows = row - n_alt + 1 : row;
    else
        rows = fr * n_alt + 1 : fr * n_alt + n_alt;
    end

    % Assign the result to the output variable
    selected_rows = rows;
end
