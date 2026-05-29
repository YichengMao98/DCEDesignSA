classdef Result
    % RESULT Class to store DCE design results and compute choice probabilities.

    properties
        DesignMatrix    % Decoded design (cell array)
        RawMatrix       % Encoded design (numeric matrix)
        D_Value         % Final D-error value
        TimeTaken       % Execution time
        Metadata        % Struct for additional info
        AvgProbs        % Choice probabilities [N_alts x N_sets]
        InfError        % Percentage of draws with infinite D-error
    end

    methods
        function obj = Result(decodedX, rawX, dVal, t, meta, probs, infError)
            arguments
                decodedX
                rawX
                dVal
                t
                meta
                probs
                infError
            end
            obj.DesignMatrix = decodedX;
            obj.RawMatrix    = rawX;
            obj.D_Value      = dVal;
            obj.TimeTaken    = t;
            obj.Metadata     = meta;
            obj.AvgProbs     = probs;
            obj.InfError     = infError;
        end

        function summary(obj)
            meta           = obj.Metadata;
            no_choice      = isfield(meta,'no_choice')    && meta.no_choice;
            interaction    = isfield(meta,'interactions') && ~isempty(meta.interactions);
            fixed_profiles = meta.f;
            order_effect   = isfield(meta,'order_effect') && meta.order_effect;

            fprintf('\n================ EXPERIMENTAL DESIGN SUMMARY ================\n');
            fprintf('%-25s %s\n',  'Optimization Status:', 'Complete');
            fprintf('%-25s %s\n',  'Opt-out Option:',      string(no_choice));
            fprintf('%-25s %d\n',  'Fixed Profiles:',      fixed_profiles);
            fprintf('%-25s %s\n',  'Interaction Model:',   string(interaction));
            fprintf('%-25s %s\n',  'Order Effect:',        string(order_effect));
            fprintf('------------------------------------------------------------\n');
            fprintf('%-25s %.6f\n',    'D-Value:',             obj.D_Value);
            fprintf('%-25s %.2f%%\n',  'Inf. Error (Draws):',  obj.InfError);
            fprintf('%-25s %.2f seconds\n', 'Execution Time:', obj.TimeTaken);
            fprintf('============================================================\n\n');
        end

        function prior_average_prob(obj)
            if isempty(obj.AvgProbs)
                fprintf('No probability data available for this design.\n');
                return;
            end
            fprintf('================ CHOICE PROBABILITY ANALYSIS ================\n');
            fprintf('Analysis of average choice probabilities per set:\n\n');
            [num_alts, num_sets] = size(obj.AvgProbs);
            RowNames = arrayfun(@(x) sprintf('set%d',x), 1:num_sets, 'UniformOutput',false)';
            ColNames = cell(1, num_alts);
            for j = 1:num_alts
                if j==num_alts && isfield(obj.Metadata,'has_no_choice') && obj.Metadata.has_no_choice
                    ColNames{j} = 'Pr(no_choice)';
                else
                    ColNames{j} = sprintf('Pr(alt%d)',j);
                end
            end
            wide_table = array2table(obj.AvgProbs', ...
                'VariableNames',ColNames,'RowNames',RowNames);
            disp(wide_table);
            fprintf('============================================================\n');
        end

        function export_qualtrics(obj, filename, format, custom_title, f)
            % EXPORT_QUALTRICS  Export the design to a Qualtrics-ready .txt file.
            arguments
                obj
                filename    (1,1) string
                format      (1,1) string = "long"
                custom_title       = []
                f                  = 0
            end
            DCEDesignSA.export_to_qualtrics(obj.DesignMatrix, filename, format, custom_title, f);
        end

        function export_csv(obj, filename)
            % EXPORT_CSV  Export the decoded design matrix to a CSV file.
            %
            %   The file is written to the current MATLAB working directory.
            %   Row 1 of the CSV contains the column headers (Choice Set,
            %   Alternative, and one column per attribute).
            %   Subsequent rows contain the design data.
            %
            %   Usage:
            %       result.export_csv('my_design')   → saves my_design.csv
            %
            arguments
                obj
                filename (1,1) string = "dce_design"
            end

            if isempty(obj.DesignMatrix) || size(obj.DesignMatrix,1) < 2
                error('No design data available to export.');
            end

            % Row 1 = headers, rows 2..end = data
            headers  = obj.DesignMatrix(1,:);
            dataRows = obj.DesignMatrix(2:end,:);

            % Convert every cell to a string so writetable handles mixed types
            strData = cellfun(@(x) string(x), dataRows, 'UniformOutput', true);

            % Build table with valid variable names (restored afterwards)
            validH = matlab.lang.makeValidName(headers);
            T = array2table(strData, 'VariableNames', validH);
            T.Properties.VariableNames = headers;

            % Ensure .csv extension
            fname = char(filename);
            if ~endsWith(fname, '.csv')
                fname = [fname, '.csv'];
            end

            writetable(T, fname);
            fprintf('Design exported to "%s".\n', fname);
        end

        function show_level_balance(obj)
            fprintf('\n================ ATTRIBUTE LEVEL BALANCE ====================\n');
            fprintf('Frequency count for each attribute level (excluding No-Choice):\n\n');
            attr_names = obj.Metadata.attr_names;
            nlevels    = obj.Metadata.nlevels;
            X          = obj.RawMatrix;
            if isfield(obj.Metadata,'order_effect') && obj.Metadata.order_effect
                X = X(:, 1:end-1);
            end
            if isfield(obj.Metadata,'has_no_choice') && obj.Metadata.has_no_choice
                n_alt        = obj.Metadata.n_alt;
                cset         = obj.Metadata.cset;
                alts_per_set = n_alt + 1;
                keep_rows    = true(size(X,1),1);
                for i = 1:cset
                    keep_rows(i*alts_per_set) = false;
                end
                X = X(keep_rows,:);
            end
            for i = 1:length(attr_names)
                current_attr_data = X(:,i);
                num_levels        = nlevels(i);
                counts = zeros(1, num_levels);
                for j = 1:num_levels
                    counts(j) = sum(current_attr_data == j);
                end
                if isfield(obj.Metadata,'attr_labels') && ~isempty(obj.Metadata.attr_labels) && ...
                        length(obj.Metadata.attr_labels) >= i
                    col_headers = obj.Metadata.attr_labels{i};
                else
                    col_headers = arrayfun(@(l) sprintf('Lvl_%d',l), 1:num_levels, 'UniformOutput',false);
                end
                fprintf('Attribute: %s\n', attr_names{i});
                T = array2table(counts,'VariableNames',col_headers);
                T.Properties.RowNames = {'Count'};
                disp(T);
                fprintf('\n');
            end
            fprintf('============================================================\n');
        end

        function showDesign(obj)
            if isempty(obj.DesignMatrix)
                fprintf('No design matrix available to display.\n'); return;
            end
            headers   = obj.DesignMatrix(1,:);
            data      = obj.DesignMatrix(2:end,:);
            cleanData = string(data);
            validH    = matlab.lang.makeValidName(headers);
            T = array2table(cleanData,'VariableNames',validH);
            T.Properties.VariableNames = headers;
            fprintf('\n================== GENERATED EXPERIMENTAL DESIGN ==================\n');
            disp(T);
            fprintf('===================================================================\n\n');
        end
    end
end