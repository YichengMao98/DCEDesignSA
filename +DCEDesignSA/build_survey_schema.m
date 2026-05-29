function design_struct = build_survey_schema(X_decoded)
    % 获取表头和原始数据
    headers = X_decoded(1, :);   
    data = X_decoded(2:end, :);  
    
    cs_column = data(:, 1);
    unique_cs = unique(cs_column, 'stable');
    
    design_struct = struct('BlockName', {}, 'Alternatives', {}, 'AltLabels', {});
    
    for i = 1:length(unique_cs)
        match_idx = strcmp(cs_column, unique_cs{i});
        cs_data = data(match_idx, :);
        
        design_struct(i).BlockName = unique_cs{i};
        
        % 提取标签
        labels = cs_data(:, 2);
        design_struct(i).AltLabels = string(labels); 
        
        % 提取属性（第3列往后）
        attr_values = cs_data(:, 3:end);
        [rows, cols] = size(attr_values);
        clean_table_data = cell(rows, cols);
        
        for r = 1:rows
            for c = 1:cols
                val = attr_values{r, c};
                
                % --- 关键：递归拆解所有嵌套的 Cell 并强制转为数字 ---
                while iscell(val)
                    val = val{1};
                end
                
                if isnumeric(val)
                    % 核心：double(val) 配合 num2str 可以消除控制字符
                    % 我们在这里先存为 double 类型的数字，而不是控制字符
                    clean_table_data{r, c} = double(val);
                else
                    clean_table_data{r, c} = string(val);
                end
            end
        end
        
        % 变量名处理
        varNames = headers(3:end);
        design_struct(i).Alternatives = cell2table(clean_table_data, 'VariableNames', varNames);
    end
end