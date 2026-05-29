function write_qualtrics_txt(design_struct, filename, format, custom_title, f)
% WRITE_QUALTRICS_TXT  Generates a Qualtrics Advanced Format text file.
%
%   Renders each choice set as an HTML table embedded in a Qualtrics
%   Multiple-Choice (single-answer) question block.
%
%   PARTIAL-PROFILE HIGHLIGHT RULE
%   --------------------------------
%   When f > 0 (partial-profile design), attributes whose levels VARY
%   across the real alternatives are the "active" (non-fixed) attributes.
%   These rows are highlighted in yellow (#ffff00) so that respondents
%   immediately see which attributes are actually different — matching the
%   standard partial-profile survey presentation convention.
%
%   Fixed attributes, by construction of the design, share the SAME level
%   across every alternative in a choice set. Because their values are
%   identical, unique(row_vals) returns a scalar → no highlight is applied.
%   This is the correct behaviour: fixed attributes are intentionally held
%   constant and should not draw the respondent's attention.
%
%   When f == 0 (full-profile design) enable_highlight is false, so NO
%   rows are ever highlighted, regardless of whether values happen to differ.
%
%   INPUTS
%   ------
%   design_struct  - Struct array produced by build_survey_schema.
%                    Each element must have:
%                      .Alternatives  (table)  attribute values per alternative
%                      .AltLabels     (string array or cell array of strings)
%   filename       - Output file path (string), e.g. "survey.txt"
%   format         - "long" or "short" (currently both render identically;
%                    reserved for future layout variants)
%   custom_title   - (optional) Question stem shown above the table.
%                    Pass [] to use the built-in default.
%   f              - Number of fixed attributes per choice set.
%                      f == 0  →  full-profile  (no highlighting)
%                      f  > 0  →  partial-profile (highlight varying rows)
%
%   OUTPUT
%   ------
%   A UTF-8 text file in Qualtrics Advanced Format, importable via
%   Survey Tools → Import Survey in the Qualtrics interface.

    arguments
        design_struct
        filename      (1,1) string
        format        (1,1) string = "long"
        custom_title              = []
        f                         = 0
    end

    % ── Default question stem ──────────────────────────────────────────────
    if isempty(custom_title)
        custom_title = "Assuming all other conditions are the same, " + ...
                       "based on the descriptions in the table, " + ...
                       "which product would you prefer?";
    end

    % ── Partial-profile flag ───────────────────────────────────────────────
    % Only activate row highlighting when the design is partial-profile.
    % In full-profile mode every attribute is shown without visual emphasis.
    enable_highlight = (f > 0);

    % ── Open file ─────────────────────────────────────────────────────────
    fid = fopen(filename, 'w', 'n', 'UTF-8');
    if fid == -1
        error('WRITE_QUALTRICS_TXT: Cannot create or open file: %s', filename);
    end
    fprintf(fid, '[[AdvancedFormat]]\n\n');

    % ── Loop over choice sets ──────────────────────────────────────────────
    for i = 1:length(design_struct)

        fprintf(fid, '[[Block:ChoiceSet_%d]]\n', i);
        fprintf(fid, '[[Question:MC:SingleAnswer:Vertical]]\n');

        current_alts     = design_struct(i).Alternatives;   % MATLAB table
        attr_names       = current_alts.Properties.VariableNames;
        num_attrs        = length(attr_names);
        num_total_options = height(current_alts);

        % ── Retrieve alternative labels safely ────────────────────────────
        % build_survey_schema stores AltLabels as a string array, not a
        % cell array. We normalise here so that both formats are handled,
        % preventing a subscript-type error when using {} on a string array.
        raw_labels = design_struct(i).AltLabels;
        if ischar(raw_labels) || isstring(raw_labels)
            % Convert string array → cell array of char vectors for uniform access
            alt_labels = cellstr(raw_labels);
        else
            % Already a cell array — use as-is
            alt_labels = raw_labels;
        end

        % ── Identify the "No Choice" alternative (if present) ─────────────
        % The no-choice option is displayed as a separate radio button below
        % the table, never as a column inside the attribute table.
        is_no_choice = false(1, num_total_options);
        for o = 1:num_total_options
            label = strtrim(string(alt_labels{o}));
            if contains(label, 'No Choice', 'IgnoreCase', true) || ...
               contains(label, 'None',      'IgnoreCase', true) || ...
               contains(label, 'opt-out',   'IgnoreCase', true)
                is_no_choice(o) = true;
            end
        end

        real_opt_indices = find(~is_no_choice);   % column indices for table
        num_real_options = length(real_opt_indices);

        % ── Build HTML question header ─────────────────────────────────────
        q_str = sprintf( ...
            "<div style='font-family:sans-serif;font-size:18px;" + ...
            "font-weight:bold;margin-bottom:10px;'>Choice Set %d</div>", i) + ...
            sprintf( ...
            "<div style='font-family:sans-serif;margin-bottom:15px;'>%s</div>", ...
            custom_title);

        % ── Open HTML table ───────────────────────────────────────────────
        q_str = q_str + ...
            "<table style='width:100%%;border-collapse:collapse;" + ...
            "font-family:sans-serif;table-layout:fixed;" + ...
            "text-align:center;border:1px solid #000;'>";

        % ── Table header row ──────────────────────────────────────────────
        q_str = q_str + ...
            "<thead><tr style='border-bottom:1px solid #000;" + ...
            "background-color:#f2f2f2;'>" + ...
            "<th style='padding:10px;border-right:1px solid #000;" + ...
            "width:25%%;text-align:left;'>Attribute</th>";
        for count = 1:num_real_options
            q_str = q_str + sprintf( ...
                "<th style='padding:10px;border-right:1px solid #000;'>" + ...
                "Option %c</th>", char(64 + count));
        end
        q_str = q_str + "</tr></thead><tbody>";

        % ── Attribute rows ────────────────────────────────────────────────
        for k = 1:num_attrs

            % Collect the string value of this attribute for each real option
            row_vals = strings(1, num_real_options);
            for idx = 1:num_real_options
                o    = real_opt_indices(idx);
                temp = current_alts{o, k};
                % Unwrap nested cells (can occur when table was built from
                % a cell-of-cells)
                while iscell(temp)
                    temp = temp{1};
                end
                row_vals(idx) = strtrim(string(temp));
            end

            % ── Highlight decision ──────────────────────────────────────
            % Highlight this row ONLY when:
            %   (a) partial-profile mode is active (enable_highlight == true)
            %   AND
            %   (b) the attribute VALUES differ across real alternatives
            %       (i.e. it is a non-fixed / active attribute in this set)
            %
            % Fixed attributes are guaranteed by the design to share the
            % same level, so unique(row_vals) will have length 1 → no highlight.
            % Non-fixed attributes vary → unique(row_vals) length > 1 → yellow.
            row_bg = "white";
            if enable_highlight && length(unique(row_vals)) > 1
                row_bg = "#ffff00";
            end

            % Render the table row
            q_str = q_str + sprintf( ...
                "<tr style='background-color:%s;border-bottom:1px solid #000;'>", ...
                row_bg) + sprintf( ...
                "<td style='padding:8px;border-right:1px solid #000;" + ...
                "font-weight:bold;text-align:left;'>%s</td>", attr_names{k});
            for idx = 1:num_real_options
                q_str = q_str + sprintf( ...
                    "<td style='padding:8px;border-right:1px solid #000;'>%s</td>", ...
                    row_vals(idx));
            end
            q_str = q_str + "</tr>";
        end

        q_str = q_str + "</tbody></table><br>";
        fprintf(fid, '%s\n', q_str);

        % ── Choice buttons ────────────────────────────────────────────────
        % One radio button per real alternative (labelled Option A, B, …),
        % plus an optional "None" button for the no-choice alternative.
        fprintf(fid, '[[Choices]]\n');
        for count = 1:num_real_options
            fprintf(fid, 'Option %c\n', char(64 + count));
        end
        if any(is_no_choice)
            fprintf(fid, 'None\n');
        end
        fprintf(fid, '\n');

    end % choice-set loop

    fclose(fid);
end