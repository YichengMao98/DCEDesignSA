function write_qualtrics_txt(design_struct, filename, format, custom_title, f)
% Generates a Qualtrics Advanced Format text file.
    arguments
        design_struct
        filename (1,1) string
        format (1,1) string = "long" % This logic now focuses on a clean table + choices
        custom_title = []
        f = 0 
    end
    
    if isempty(custom_title)
        custom_title = "Assuming all other conditions are the same, based on the descriptions in the table, which product would you prefer?";
    end
    
    % FIX 2: Auto-append .txt extension if missing
    fname = char(filename);
    if ~endsWith(fname, '.txt')
        fname = [fname, '.txt'];
    end

    fid = fopen(fname, 'w', 'n', 'UTF-8');
    if fid == -1, error('Cannot create file: %s', fname); end
    fprintf(fid, '[[AdvancedFormat]]\n\n');
    
    for i = 1:length(design_struct)
        fprintf(fid, '[[Block:ChoiceSet_%d]]\n', i);
        fprintf(fid, '[[Question:MC:SingleAnswer:Vertical]]\n');
        
        current_alts = design_struct(i).Alternatives;
        attr_names = current_alts.Properties.VariableNames;
        num_attrs = length(attr_names);
        num_total_options = height(current_alts);
        alt_labels = design_struct(i).AltLabels;
        
        % 1. Identify "No Choice" index and separate data
        is_no_choice = false(1, num_total_options);
        for o = 1:num_total_options
            label = string(alt_labels{o});
            if contains(label, 'No Choice', 'IgnoreCase', true) || ...
               contains(label, 'None', 'IgnoreCase', true) || ...
               contains(label, 'opt-out', 'IgnoreCase', true)
                is_no_choice(o) = true;
            end
        end
        
        % Count how many real options go into the table
        real_opt_indices = find(~is_no_choice);
        num_real_options = length(real_opt_indices);
        
        % 2. Header and Instruction
        q_str = sprintf("<div style='font-family: sans-serif; font-size: 18px; font-weight: bold; margin-bottom: 10px;'>Choice Set %d</div>", i) + ...
                sprintf("<div style='font-family: sans-serif; margin-bottom: 15px;'>%s</div>", custom_title);
            
        q_str = q_str + "<table style='width:100%%; border-collapse: collapse; font-family: sans-serif; table-layout: fixed; text-align: center; border: 1px solid #000;'>";
        
        % 3. Table Rendering (Only for Real Options)
        % Header Row
        q_str = q_str + "<thead><tr style='border-bottom: 1px solid #000; background-color: #f2f2f2;'>" + ...
                        "<th style='padding: 10px; border-right: 1px solid #000; width: 25%%; text-align: left;'>Attribute</th>";
        for count = 1:num_real_options
            q_str = q_str + sprintf("<th style='padding: 10px; border-right: 1px solid #000;'>Option %c</th>", char(64+count));
        end
        q_str = q_str + "</tr></thead><tbody>";
        
        % Attribute Rows
        for k = 1:num_attrs
            row_vals = strings(1, num_real_options);
            for idx = 1:num_real_options
                o = real_opt_indices(idx);
                temp = current_alts{o, k}; 
                if iscell(temp), temp = temp{1}; end
                row_vals(idx) = strtrim(string(temp));
            end
            
            % FIX 1: Always highlight rows where values vary across options.
            % Yellow = attribute is NOT fixed (values differ across alternatives).
            % White  = attribute IS fixed (all alternatives share the same value).
            if length(unique(row_vals)) > 1
                row_bg = "#ffff00";   % varying — highlight yellow
            else
                row_bg = "white";     % fixed — no highlight
            end
            
            q_str = q_str + sprintf("<tr style='background-color: %s; border-bottom: 1px solid #000;'>", row_bg) + ...
                    sprintf("<td style='padding: 8px; border-right: 1px solid #000; font-weight: bold; text-align: left;'>%s</td>", attr_names{k});
            for idx = 1:num_real_options
                q_str = q_str + sprintf("<td style='padding: 8px; border-right: 1px solid #000;'>%s</td>", row_vals(idx));
            end
            q_str = q_str + "</tr>";
        end
        
        q_str = q_str + "</tbody></table><br>";
        fprintf(fid, '%s\n', q_str);
        
        % 4. Choice Buttons (Table Options + No Choice)
        fprintf(fid, '[[Choices]]\n');
        for count = 1:num_real_options
            fprintf(fid, 'Option %c\n', char(64+count));
        end
        
        % Add No Choice options at the bottom of the list
        if any(is_no_choice)
            fprintf(fid, 'None\n'); 
        end
        fprintf(fid, '\n');
    end
    fclose(fid);
end