function design_struct = build_survey_schema(X_decoded)
% BUILD_SURVEY_SCHEMA Split a decoded design into one entry per choice set.
%
%   INPUT:
%       X_decoded - (cell array) Decoded design as returned by decode_X: the
%                   first row holds the headers, column 1 the choice-set label,
%                   column 2 the alternative label, columns 3+ the attributes.
%
%   OUTPUT:
%       design_struct - (struct array) One element per choice set with fields
%                       BlockName, Alternatives (table) and AltLabels.

    % Headers and raw data
    headers = X_decoded(1, :);
    data = X_decoded(2:end, :);

    cs_column = data(:, 1);
    unique_cs = unique(cs_column, 'stable');

    design_struct = struct('BlockName', {}, 'Alternatives', {}, 'AltLabels', {});

    for i = 1:length(unique_cs)
        match_idx = strcmp(cs_column, unique_cs{i});
        cs_data = data(match_idx, :);

        design_struct(i).BlockName = unique_cs{i};

        % Alternative labels
        labels = cs_data(:, 2);
        design_struct(i).AltLabels = string(labels);

        % Attribute values (column 3 onwards)
        attr_values = cs_data(:, 3:end);
        [rows, cols] = size(attr_values);
        clean_table_data = cell(rows, cols);

        for r = 1:rows
            for c = 1:cols
                val = attr_values{r, c};

                % Unwrap any nested cells down to the underlying value
                while iscell(val)
                    val = val{1};
                end

                if isnumeric(val)
                    % Keep numeric levels as doubles (not as characters, which
                    % could introduce control characters when converted)
                    clean_table_data{r, c} = double(val);
                else
                    clean_table_data{r, c} = string(val);
                end
            end
        end

        % Variable names for the table
        varNames = headers(3:end);
        design_struct(i).Alternatives = cell2table(clean_table_data, 'VariableNames', varNames);
    end
end
