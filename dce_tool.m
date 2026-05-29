classdef dce_tool < matlab.apps.AppBase
% DCE_TOOL  Discrete Choice Experiment Design Tool
%
% ── STEP 1 TABLE ───────────────────────────────────────────────────────
%   Col 1  : Attribute Name  (editable string)
%   Col 2  : Levels          (READ-ONLY display; changed via dropdown)
%   Col 3+ : Level Names     (editable; up to MAX_LEVELS=6 columns)
%
%   Level count is set by selecting a row then choosing from the
%   "Levels:" dropdown in the toolbar (JMP-style — no typing required).
%   Cells beyond the declared count show '—' and reject edits.
%
%   Quote characters typed by the user (" ' " " ' ') are stripped
%   automatically from every level name before they reach the package.
%
% ── DISPATCH LOGIC ─────────────────────────────────────────────────────
%   All rows default ('Lv#') → 'nlevels' vector passed to generate().
%   Any row customised        → 'attr_cell' struct passed to generate().
%     attr_cell.(name) = {{'Level1','Level2',...}}   (one wrap)
%
% ── RESULTS WINDOW ─────────────────────────────────────────────────────
%   Tab 1: Summary + Balance  Tab 2: Design Matrix  Tab 3: Probabilities
%   Bottom panel: Export to Qualtrics  +  Export to CSV

    properties (Constant, Access = private)
        MAX_LEVELS = 6
        INACTIVE   = '—'
    end

    properties (Access = public)
        UIFigure matlab.ui.Figure

        % Step 1
        Step1Panel    matlab.ui.container.Panel
        AddBtn        matlab.ui.control.Button
        DelAttrBtn    matlab.ui.control.Button
        LevDropLabel  matlab.ui.control.Label
        LevDropdown   matlab.ui.control.DropDown
        ApplyLevBtn   matlab.ui.control.Button     % Set Levels for selected row
        AttrTable     matlab.ui.control.Table
        NextBtn       matlab.ui.control.Button

        % Step 2
        Step2Panel     matlab.ui.container.Panel
        ModelListBox   matlab.ui.control.ListBox
        IntBtn         matlab.ui.control.Button
        DelItemBtn     matlab.ui.control.Button
        BackToStep1Btn matlab.ui.control.Button
        ConfirmBtn     matlab.ui.control.Button

        % Step 3
        Step3Panel     matlab.ui.container.Panel
        MeanLabel      matlab.ui.control.Label
        MeanTable      matlab.ui.control.Table
        CovLabel       matlab.ui.control.Label
        VarTable       matlab.ui.control.Table
        BackToStep2Btn matlab.ui.control.Button

        % Step 4
        Step4Panel        matlab.ui.container.Panel
        NCSetsLabel       matlab.ui.control.Label
        NCSetsField       matlab.ui.control.NumericEditField
        NAltsLabel        matlab.ui.control.Label
        NAltsField        matlab.ui.control.NumericEditField
        NFixedLabel       matlab.ui.control.Label
        NFixedField       matlab.ui.control.NumericEditField
        NoChoiceChk       matlab.ui.control.CheckBox
        OrderEffectChk    matlab.ui.control.CheckBox
        Sep4Label         matlab.ui.control.Label
        TermLabel         matlab.ui.control.Label
        TermBtnGroup      matlab.ui.container.ButtonGroup
        TermAdaptiveBtn   matlab.ui.control.RadioButton
        TermTimeBtn       matlab.ui.control.RadioButton
        TermCycleBtn      matlab.ui.control.RadioButton
        MaxValueLabel     matlab.ui.control.Label
        MaxValueField     matlab.ui.control.NumericEditField
        GenerateBtn       matlab.ui.control.Button
    end

    properties (Access = private)
        SelectedAttrRow = []
        DCEData         = []
        LastResult      = []
    end

    % ══════════════════════════════════════════════════════════════════
    % PRIVATE HELPERS
    % ══════════════════════════════════════════════════════════════════
    methods (Access = private)

        % Build a fresh data row.
        function row = makeAttrRow(app, attrName, nLevels)
            row = cell(1, 2 + app.MAX_LEVELS);
            row{1} = attrName;
            row{2} = nLevels;
            for c = 1:app.MAX_LEVELS
                if c <= nLevels
                    row{2+c} = sprintf('Lv%d', c);
                else
                    row{2+c} = app.INACTIVE;
                end
            end
        end

        % True when every active cell is still the default 'Lv#' placeholder.
        function tf = rowIsDefault(app, row)
            nL = row{2};
            tf = true;
            for c = 1:nL
                if ~strcmp(app.stripQuotes(strtrim(row{2+c})), sprintf('Lv%d',c))
                    tf = false; return;
                end
            end
        end

        % ── QUOTE STRIPPING ──────────────────────────────────────────
        % Removes all common quote variants from a single string.
        % This is called on every level name before it leaves the GUI.
        % Handles: straight " '  and curly " " ' '
        function s = stripQuotes(~, raw)
            s = raw;
            for q = {'"', '''', char(8220), char(8221), char(8216), char(8217)}
                s = strrep(s, q{1}, '');
            end
            s = strtrim(s);
        end

        % Extract active level names as a flat cell array of clean char.
        % ALL quote characters are stripped here — the single safe extraction point.
        function names = getLevelNames(app, row)
            nL    = row{2};
            names = cell(1, nL);
            for c = 1:nL
                names{c} = app.stripQuotes(char(row{2+c}));
            end
        end

    end

    % ══════════════════════════════════════════════════════════════════
    % CALLBACKS
    % ══════════════════════════════════════════════════════════════════
    methods (Access = private)

        % ── Step 1: Add row ───────────────────────────────────────────
        % ── Step 1: Add row ───────────────────────────────────────────
        % The new row uses whatever level count is currently shown in the
        % dropdown.  We do NOT set SelectedAttrRow here — doing so while a
        % cell is still in edit mode causes the table to lock up and refuse
        % further adds.  Row selection is tracked only via CellSelectionCallback.
        function AddButtonPushed(app, ~, ~)
            data = app.AttrTable.Data;
            if isempty(data)||~iscell(data), data = cell(0,2+app.MAX_LEVELS); end
            newID = size(data,1)+1;
            nL    = str2double(app.LevDropdown.Value);
            row   = app.makeAttrRow(sprintf('X%d', newID), nL);
            app.AttrTable.Data = [data; row];
            % Keep SelectedAttrRow pointing at the new last row so the
            % dropdown sync in AttrTableCellSelected shows the right count,
            % but only after the data assignment is complete.
            app.SelectedAttrRow = newID;
        end

        % ── Step 1: Track selected row ────────────────────────────────
        function AttrTableCellSelected(app, ~, event)
            if ~isempty(event.Indices)
                app.SelectedAttrRow = event.Indices(1);
                % Sync dropdown to show the selected row's current count
                data = app.AttrTable.Data;
                if app.SelectedAttrRow <= size(data,1)
                    app.LevDropdown.Value = num2str(data{app.SelectedAttrRow, 2});
                end
            end
        end

        % ── Step 1: Delete selected row ───────────────────────────────
        function DelAttrButtonPushed(app, ~, ~)
            if isempty(app.SelectedAttrRow), return; end
            data = app.AttrTable.Data;
            if app.SelectedAttrRow > size(data,1), return; end
            data(app.SelectedAttrRow,:) = [];
            app.AttrTable.Data  = data;
            app.SelectedAttrRow = [];
        end

        % ── Step 1: Apply level count from dropdown to selected row ──────
        % The dropdown shows the count for new rows by default.
        % When the user selects an existing row the dropdown syncs to it.
        % Clicking "Apply" writes the chosen count back to that row.
        % This is explicit — no silent side-effects on dropdown change.
        function ApplyLevButtonPushed(app, ~, ~)
            r = app.SelectedAttrRow;
            if isempty(r)
                uialert(app.UIFigure, 'Select a row first, then choose a level count.', ...
                    'No Row Selected', 'Icon','warning');
                return;
            end
            data = app.AttrTable.Data;
            if r > size(data,1), return; end
            nNew      = str2double(app.LevDropdown.Value);
            data{r,2} = nNew;
            for c = 1:app.MAX_LEVELS
                if c <= nNew
                    if strcmp(data{r,2+c}, app.INACTIVE)
                        data{r,2+c} = sprintf('Lv%d', c);
                    end
                else
                    data{r,2+c} = app.INACTIVE;
                end
            end
            app.AttrTable.Data = data;
        end

        % ── Step 1: Cell edit gate ─────────────────────────────────────
        % Levels column (col 2) is read-only — reject any direct edit.
        % Level-name cells beyond the declared count are reverted to INACTIVE.
        function AttrTableCellEdit(app, ~, event)
            r    = event.Indices(1);
            c    = event.Indices(2);
            data = app.AttrTable.Data;
            if c == 2
                data{r,2} = event.PreviousData;   % revert — use dropdown
                app.AttrTable.Data = data;
            elseif c > 2
                if (c-2) > data{r,2}
                    data{r,c} = app.INACTIVE;
                    app.AttrTable.Data = data;
                end
            end
        end

        % ── Step 1 → Step 2 ──────────────────────────────────────────
        function NextButtonPushed(app, ~, ~)
            data = app.AttrTable.Data;
            if isempty(data), return; end
            for i = 1:size(data,1)
                if data{i,2} < 2
                    uialert(app.UIFigure, ...
                        sprintf('Attribute "%s" needs at least 2 levels.',data{i,1}), ...
                        'Validation Error','Icon','error');
                    return;
                end
            end
            app.ModelListBox.Items = cellstr(data(:,1));
            app.lockStep1(true);
            app.Step2Panel.Visible = 'on';
        end

        % ── Step 2 → Step 1 ──────────────────────────────────────────
        function BackToStep1Pushed(app, ~, ~)
            app.lockStep1(false);
            app.Step2Panel.Visible = 'off';
            app.Step3Panel.Visible = 'off';
            app.Step4Panel.Visible = 'off';
        end

        % ── Step 2: Add interaction ───────────────────────────────────
        function InteractionButtonPushed(app, ~, ~)
            sel = app.ModelListBox.Value;
            if numel(sel) < 2, return; end
            newTerm = char(strjoin(string(sel),'*'));
            items   = cellstr(app.ModelListBox.Items(:));
            if ~any(strcmp(items,newTerm))
                app.ModelListBox.Items = [items; {newTerm}];
            end
        end

        % ── Step 2: Delete items ──────────────────────────────────────
        function DelItemButtonPushed(app, ~, ~)
            sel = app.ModelListBox.Value;
            if isempty(sel), return; end
            items = cellstr(app.ModelListBox.Items(:));
            items(ismember(items,sel)) = [];
            app.ModelListBox.Items = items;
            app.ModelListBox.Value = {};
        end

        % ── Step 2 → Step 3 (Confirm) ────────────────────────────────
        function ConfirmModelPushed(app, ~, ~)
            attrData   = app.AttrTable.Data;
            modelItems = cellstr(app.ModelListBox.Items(:));
            labels     = {};

            for i = 1:numel(modelItems)
                item = modelItems{i};
                if contains(item,'*')
                    parts = strsplit(item,'*');
                    r1 = find(strcmp(attrData(:,1),strtrim(parts{1})),1);
                    r2 = find(strcmp(attrData(:,1),strtrim(parts{2})),1);
                    if isempty(r1)||isempty(r2), continue; end
                    nms1 = app.getLevelNames(attrData(r1,:));
                    nms2 = app.getLevelNames(attrData(r2,:));
                    for j=1:(numel(nms1)-1)
                        for k=1:(numel(nms2)-1)
                            labels{end+1} = sprintf('%s %s * %s %s', ...
                                strtrim(parts{1}),nms1{j}, ...
                                strtrim(parts{2}),nms2{k}); %#ok<AGROW>
                        end
                    end
                else
                    idx = find(strcmp(attrData(:,1),strtrim(item)),1);
                    if isempty(idx), continue; end
                    nms = app.getLevelNames(attrData(idx,:));
                    for j=1:(numel(nms)-1)
                        labels{end+1} = sprintf('%s %s',strtrim(item),nms{j}); %#ok<AGROW>
                    end
                end
            end

            dim = numel(labels);
            if dim == 0, return; end

            app.DCEData.ModelTerms = modelItems;
            app.DCEData.Labels     = labels;
            app.DCEData.PriorMean  = zeros(dim,1);
            app.DCEData.PriorVar   = eye(dim);

            app.rebuildPriorTables(labels, zeros(dim,1), eye(dim));
            app.lockStep2(true);
            app.Step3Panel.Visible = 'on';
            app.Step4Panel.Visible = 'on';
        end

        % ── Step 3: Prior mean cell edit ──────────────────────────────
        function MeanTableCellEdit(app, ~, event)
            idx = event.Indices(1);
            val = event.NewData;
            if ~isnumeric(val), val = 0; end
            app.DCEData.PriorMean(idx) = val;
        end

        % ── Step 3: Covariance cell edit ──────────────────────────────
        function VarTableCellEdit(app, ~, event)
            i = event.Indices(1);  j = event.Indices(2);
            val = event.NewData;
            if ~isnumeric(val)||isnan(val), val = 0; end
            if j < i, return; end
            data = app.VarTable.Data;
            data{i,j} = val;  data{j,i} = val;
            app.VarTable.Data         = data;
            app.DCEData.PriorVar(i,j) = val;
            app.DCEData.PriorVar(j,i) = val;
        end

        % ── Step 3 → Step 2 ──────────────────────────────────────────
        function BackToStep2Pushed(app, ~, ~)
            app.lockStep2(false);
            app.Step3Panel.Visible = 'off';
            app.Step4Panel.Visible = 'off';
        end

        % ── Step 4: No-choice checkbox ────────────────────────────────
        function NoChoiceChanged(app, ~, ~)
            if app.Step3Panel.Visible ~= "on", return; end
            if isempty(app.DCEData.Labels),     return; end
            checked = app.NoChoiceChk.Value;
            curMean = app.DCEData.PriorMean;
            curVar  = app.DCEData.PriorVar;
            curLbls = app.DCEData.Labels;
            if checked
                newMean = [curMean(:); 0];
                newVar  = zeros(size(curVar,1)+1);
                newVar(1:end-1,1:end-1) = curVar;
                newVar(end,end)         = 1;
                newLbls = [curLbls, {'ASC (no-choice)'}];
            else
                if numel(curLbls) < 2, return; end
                newMean = curMean(1:end-1);
                newVar  = curVar(1:end-1,1:end-1);
                newLbls = curLbls(1:end-1);
            end
            app.DCEData.PriorMean = newMean;
            app.DCEData.PriorVar  = newVar;
            app.DCEData.Labels    = newLbls;
            app.rebuildPriorTables(newLbls, newMean, newVar);
        end

        % ── Step 4: Termination radio ─────────────────────────────────
        function TerminationChanged(app, ~, ~)
            sel = app.TermBtnGroup.SelectedObject.Text;
            switch sel
                case 'Adaptive'
                    app.MaxValueField.Enable = 'off';
                    app.MaxValueLabel.Enable = 'off';
                    app.MaxValueLabel.Text   = 'Max value:';
                    app.DCEData.Termination  = 'adaptive';
                    app.DCEData.MaxValue     = [];
                case 'Time (s)'
                    app.MaxValueField.Enable = 'on';
                    app.MaxValueLabel.Enable = 'on';
                    app.MaxValueLabel.Text   = 'Max seconds:';
                    app.DCEData.Termination  = 'time';
                    app.DCEData.MaxValue     = app.MaxValueField.Value;
                case 'Cycles'
                    app.MaxValueField.Enable = 'on';
                    app.MaxValueLabel.Enable = 'on';
                    app.MaxValueLabel.Text   = 'Max cycles:';
                    app.DCEData.Termination  = 'cycle';
                    app.DCEData.MaxValue     = app.MaxValueField.Value;
            end
        end

        function MaxValueChanged(app, ~, ~)
            app.DCEData.MaxValue = app.MaxValueField.Value;
        end

        % ── Step 4: Generate ─────────────────────────────────────────
        function GenerateButtonPushed(app, ~, ~)
            app.DCEData.NChoiceSets = app.NCSetsField.Value;
            app.DCEData.NAlts       = app.NAltsField.Value;
            app.DCEData.NFixed      = app.NFixedField.Value;
            app.DCEData.NoChoice    = app.NoChoiceChk.Value;
            app.DCEData.OrderEffect = app.OrderEffectChk.Value;

            sel = app.TermBtnGroup.SelectedObject.Text;
            switch sel
                case 'Adaptive', app.DCEData.Termination='adaptive'; app.DCEData.MaxValue=[];
                case 'Time (s)', app.DCEData.Termination='time';     app.DCEData.MaxValue=app.MaxValueField.Value;
                case 'Cycles',   app.DCEData.Termination='cycle';    app.DCEData.MaxValue=app.MaxValueField.Value;
            end

            % Flush prior table edits
            dim = numel(app.DCEData.Labels);
            mCell = app.MeanTable.Data;
            for i = 1:dim
                v = mCell{i,1}; if isnumeric(v), app.DCEData.PriorMean(i) = v; end
            end
            vCell = app.VarTable.Data;
            for i = 1:dim
                for j = i:dim
                    v = vCell{i,j};
                    if isnumeric(v)&&~isnan(v)
                        app.DCEData.PriorVar(i,j)=v; app.DCEData.PriorVar(j,i)=v;
                    end
                end
            end

            % Dispatch: nlevels vs attr_cell
            tData  = app.AttrTable.Data;
            nAttrs = size(tData,1);
            allDefault = true;
            for i = 1:nAttrs
                if ~app.rowIsDefault(tData(i,:)), allDefault=false; break; end
            end

            if allDefault
                nlevels = zeros(1,nAttrs);
                for i = 1:nAttrs, nlevels(i) = tData{i,2}; end
                attrArg = {'nlevels', nlevels};
            else
                % Build attr_cell struct.
                % getLevelNames() returns plain {'name1','name2',...} (quotes stripped).
                % Assigned directly to the struct field — NO extra wrapping.
                % This matches: attr_cell.Brand = {'Cooper','ISIS','Goldie'}
                % which is equivalent to: struct('Brand',{{'Cooper','ISIS','Goldie'}})
                % IMPORTANT: attr_cell.(fname) must be a plain cell array of char,
                % e.g. {'Cooper','ISIS','Goldie'} — NOT {{...}}.
                % When using struct('Brand', {{'a','b'}}) constructor syntax the
                % outer {} is needed to prevent scalar expansion, but here we are
                % assigning directly to a field, so no wrapping is needed at all.
                attr_cell = struct();
                for i = 1:nAttrs
                    fname = matlab.lang.makeValidName(strtrim(tData{i,1}));
                    lvls  = app.getLevelNames(tData(i,:));   % plain {'name1','name2',...}
                    attr_cell.(fname) = lvls;                % NO extra wrap
                end
                attrArg = {'attr_cell', attr_cell};
            end

            % Build interactions
            attrNames = tData(:,1);
            modelItems = app.DCEData.ModelTerms;
            interactions = {};
            for i = 1:numel(modelItems)
                item = modelItems{i};
                if contains(item,'*')
                    parts = strsplit(item,'*');
                    idx1 = find(strcmp(attrNames,strtrim(parts{1})),1);
                    idx2 = find(strcmp(attrNames,strtrim(parts{2})),1);
                    if ~isempty(idx1)&&~isempty(idx2)
                        interactions{end+1} = [idx1,idx2]; %#ok<AGROW>
                    end
                end
            end

            optArgs = [attrArg, { ...
                'f',            app.DCEData.NFixed, ...
                'interactions', interactions, ...
                'termination',  app.DCEData.Termination, ...
                'order_effect', app.DCEData.OrderEffect, ...
                'coding',       'effect', ...
                'no_choice',    app.DCEData.NoChoice, ...
                'prior_mean',   app.DCEData.PriorMean(:)', ...
                'prior_var',    app.DCEData.PriorVar }];
            if ~isempty(app.DCEData.MaxValue)
                optArgs = [optArgs, {'max_value', app.DCEData.MaxValue}];
            end

            % ── Progress dialog ───────────────────────────────────────
            % Shown while SA runs so the user knows generation is in progress.
            % The dialog is non-cancellable (SA has no clean interrupt hook).
            dlg = uiprogressdlg(app.UIFigure, ...
                'Title',   'Generating Design', ...
                'Message', 'Running simulated annealing optimisation...', ...
                'Indeterminate', true, ...
                'Cancelable', false);
            app.GenerateBtn.Enable = 'off';
            drawnow;                             % ensure dialog renders

            try
                result = DCEDesignSA.generate( ...
                    app.DCEData.NChoiceSets, ...
                    app.DCEData.NAlts, ...
                    optArgs{:});
                close(dlg);
                app.GenerateBtn.Enable = 'on';
                app.LastResult = result;
                app.openResultsWindow(result);
            catch ME
                close(dlg);
                app.GenerateBtn.Enable = 'on';
                uialert(app.UIFigure, ME.message, 'Generate Error','Icon','error');
            end
        end

        % ── Lock / unlock helpers ─────────────────────────────────────
        function lockStep1(app, tf)
            s = matlab.lang.OnOffSwitchState(~tf);
            app.AddBtn.Enable      = s;
            app.DelAttrBtn.Enable  = s;
            app.LevDropdown.Enable = s;
            app.ApplyLevBtn.Enable = s;
            if tf
                app.AttrTable.ColumnEditable = false(1, 2+app.MAX_LEVELS);
            else
                app.AttrTable.ColumnEditable = [true, false, true(1,app.MAX_LEVELS)];
            end
        end

        function lockStep2(app, tf)
            s = matlab.lang.OnOffSwitchState(~tf);
            app.IntBtn.Enable       = s;
            app.DelItemBtn.Enable   = s;
            app.ConfirmBtn.Enable   = s;
            app.ModelListBox.Enable = s;
        end

        % ── Rebuild Step 3 prior tables ───────────────────────────────
        function rebuildPriorTables(app, labels, meanVec, varMat)
            dim = numel(labels);
            app.MeanTable.Data           = num2cell(meanVec(:));
            app.MeanTable.RowName        = labels;
            app.MeanTable.ColumnName     = {'Prior Mean'};
            app.MeanTable.ColumnEditable = true;

            varCell = cell(dim,dim);
            for r = 1:dim
                for c = 1:dim
                    if c >= r, varCell{r,c} = varMat(r,c);
                    else,       varCell{r,c} = ''; end
                end
            end
            app.VarTable.Data           = varCell;
            app.VarTable.RowName        = labels;
            app.VarTable.ColumnName     = labels;
            app.VarTable.ColumnEditable = true(1,dim);
        end

        % ── Results window ────────────────────────────────────────────
        % Three content tabs + a combined export panel at the bottom.
        % The export panel has two rows:
        %   Row 1 – Export to Qualtrics (.txt)
        %   Row 2 – Export to CSV
        function openResultsWindow(app, result)
            rFig = uifigure('Name','DCE Design Results','Position',[120 80 940 800]);
            tg   = uitabgroup(rFig,'Position',[10 110 920 680]);

            % Tab 1 – Summary + balance
            t1 = uitab(tg,'Title','Summary & Balance');
            uitextarea(t1, ...
                'Value',    [evalc('result.summary()'), newline, evalc('result.show_level_balance()')], ...
                'Editable','off','FontName','Courier New','FontSize',11, ...
                'Position',[10 10 900 645]);

            % Tab 2 – Design matrix
            t2 = uitab(tg,'Title','Design Matrix');
            dm = result.DesignMatrix;
            if ~isempty(dm) && size(dm,1) > 1
                headers  = dm(1,:);
                dataRows = dm(2:end,:);
                uit2 = uitable(t2,'Data',dataRows,'ColumnName',headers, ...
                    'RowName',{},'ColumnEditable',false,'Position',[10 10 900 645]);
                ncols = numel(headers);
                uit2.ColumnWidth = repmat({max(60,floor(890/ncols))},1,ncols);
            else
                uilabel(t2,'Text','No design data.','Position',[20 300 300 22]);
            end

            % Tab 3 – Choice probabilities
            t3 = uitab(tg,'Title','Choice Probabilities');
            uitextarea(t3, ...
                'Value',    evalc('result.prior_average_prob()'), ...
                'Editable','off','FontName','Courier New','FontSize',11, ...
                'Position',[10 10 900 645]);

            % ── Export panel (two rows) ───────────────────────────────
            expPanel = uipanel(rFig,'Title','Export', ...
                'Position',[10 5 920 100]);

            % Row 1 – Qualtrics (.txt, always long format)
            uilabel(expPanel,'Text','Qualtrics:','FontWeight','bold', ...
                'Position',[10 52 75 22]);
            uilabel(expPanel,'Text','Filename:','Position',[90 52 62 22]);
            fnField = uieditfield(expPanel,'text','Value','dce_design', ...
                'Tooltip','Saved as <name>.txt in long format', ...
                'Position',[155 52 310 22]);
            uibutton(expPanel,'Text','Export .txt', ...
                'BackgroundColor',[0.18 0.63 0.27],'FontColor',[1 1 1], ...
                'FontWeight','bold','Position',[480 48 130 30], ...
                'ButtonPushedFcn',@(~,~) app.doExportQualtrics(result, fnField));

            % Row 2 – CSV
            uilabel(expPanel,'Text','CSV:','FontWeight','bold', ...
                'Position',[10 14 75 22]);
            uilabel(expPanel,'Text','Filename:','Position',[90 14 62 22]);
            csvField = uieditfield(expPanel,'text','Value','dce_design', ...
                'Tooltip','Saved as <name>.csv', ...
                'Position',[155 14 310 22]);
            uibutton(expPanel,'Text','Export .csv', ...
                'BackgroundColor',[0.18 0.45 0.75],'FontColor',[1 1 1], ...
                'FontWeight','bold','Position',[480 10 130 30], ...
                'ButtonPushedFcn',@(~,~) app.doExportCSV(result, csvField));
        end

        % ── Qualtrics export (always long format) ─────────────────────
        function doExportQualtrics(app, result, fnField)
            fname = strtrim(fnField.Value);
            if isempty(fname), fname = 'dce_design'; end
            try
                result.export_qualtrics(fname, 'long');
                uialert(app.UIFigure,sprintf('Saved as "%s.txt".',fname), ...
                    'Export Complete','Icon','success');
            catch ME
                uialert(app.UIFigure,ME.message,'Export Error','Icon','error');
            end
        end

        % ── CSV export ────────────────────────────────────────────────
        function doExportCSV(app, result, csvField)
            fname = strtrim(csvField.Value);
            if isempty(fname), fname = 'dce_design'; end
            try
                result.export_csv(fname);
                uialert(app.UIFigure,sprintf('Saved as "%s.csv".',fname), ...
                    'Export Complete','Icon','success');
            catch ME
                uialert(app.UIFigure,ME.message,'Export Error','Icon','error');
            end
        end

    end % private callbacks

    % ══════════════════════════════════════════════════════════════════
    % COMPONENT CREATION
    % ══════════════════════════════════════════════════════════════════
    methods (Access = private)
        function createComponents(app)

            app.UIFigure = uifigure('Name','DCE Design Tool', ...
                'Position',[60 60 1200 820]);

            % ── Step 1 Panel ──────────────────────────────────────────
            app.Step1Panel = uipanel(app.UIFigure, ...
                'Title','Step 1: Attribute Definition', ...
                'Position',[10 390 650 420]);

            uilabel(app.Step1Panel, ...
                'Text',['Levels: choose count then click "+ Add".  ' ...
                        'To change an existing row: select it, pick a count, click "Set Levels".  ' ...
                        'Col 3+: level names — click any cell to rename.'], ...
                'WordWrap','on','Position',[12 374 625 34]);

            % ── Toolbar layout ────────────────────────────────────────
            % [Levels: ▼]  [Set Levels]  |  [+ Add Attribute]  [Delete Selected]
            app.LevDropLabel = uilabel(app.Step1Panel, ...
                'Text','Levels:','Position',[12 348 52 20]);

            app.LevDropdown = uidropdown(app.Step1Panel, ...
                'Items',    {'2','3','4','5','6'}, ...
                'Value',    '3', ...
                'Position', [64 344 58 26]);

            app.AddBtn = uibutton(app.Step1Panel, ...
                'Text',            '+ Add Attribute', ...
                'BackgroundColor', [0.88 1.00 0.88], ...
                'Position',        [128 344 120 26], ...
                'ButtonPushedFcn', @app.AddButtonPushed);

            app.ApplyLevBtn = uibutton(app.Step1Panel, ...
                'Text',            'Set Levels', ...
                'BackgroundColor', [0.88 0.94 1.00], ...
                'Position',        [256 344 82 26], ...
                'ButtonPushedFcn', @app.ApplyLevButtonPushed);

            app.DelAttrBtn = uibutton(app.Step1Panel, ...
                'Text',            'Delete Selected', ...
                'FontColor',       [0.75 0 0], ...
                'Position',        [356 344 110 26], ...
                'ButtonPushedFcn', @app.DelAttrButtonPushed);

            % ── Attribute table ───────────────────────────────────────
            colNames  = [{'Attribute Name','Levels'}, ...
                          arrayfun(@(k)sprintf('Level %d',k), ...
                              1:app.MAX_LEVELS,'UniformOutput',false)];
            colWidths = [{130},{52}, repmat({78},1,app.MAX_LEVELS)];
            colEdit   = [true, false, true(1,app.MAX_LEVELS)];

            app.AttrTable = uitable(app.Step1Panel, ...
                'Position',              [10 12 625 324], ...
                'ColumnName',            colNames, ...
                'ColumnWidth',           colWidths, ...
                'ColumnEditable',        colEdit, ...
                'Data',                  cell(0,2+app.MAX_LEVELS), ...
                'CellSelectionCallback', @app.AttrTableCellSelected, ...
                'CellEditCallback',      @app.AttrTableCellEdit);

            % ── Next button ───────────────────────────────────────────
            app.NextBtn = uibutton(app.UIFigure, ...
                'Text','Next  >>  Step 2', ...
                'BackgroundColor',[0.80 0.90 1.00], ...
                'Position',[490 354 165 32], ...
                'ButtonPushedFcn',@app.NextButtonPushed);

            % ── Step 2 Panel ──────────────────────────────────────────
            app.Step2Panel = uipanel(app.UIFigure, ...
                'Title','Step 2: Model Specification', ...
                'Position',[10 10 650 335],'Visible','off');

            app.ModelListBox = uilistbox(app.Step2Panel, ...
                'Position',[10 58 628 248],'Multiselect','on');

            app.IntBtn = uibutton(app.Step2Panel, ...
                'Text','+ Interaction','Position',[10 14 115 30], ...
                'ButtonPushedFcn',@app.InteractionButtonPushed);

            app.DelItemBtn = uibutton(app.Step2Panel, ...
                'Text','Delete item','FontColor',[0.75 0 0], ...
                'Position',[135 14 95 30], ...
                'ButtonPushedFcn',@app.DelItemButtonPushed);

            app.BackToStep1Btn = uibutton(app.Step2Panel, ...
                'Text','<< Back  Step 1','Position',[240 14 120 30], ...
                'ButtonPushedFcn',@app.BackToStep1Pushed);

            app.ConfirmBtn = uibutton(app.Step2Panel, ...
                'Text','Confirm Model  >>  Step 3', ...
                'BackgroundColor',[0.70 1.00 0.70], ...
                'Position',[415 8 220 40], ...
                'ButtonPushedFcn',@app.ConfirmModelPushed);

            % ── Step 3 Panel ──────────────────────────────────────────
            app.Step3Panel = uipanel(app.UIFigure, ...
                'Title','Step 3: Prior Specification', ...
                'Position',[675 410 515 400],'Visible','off');

            app.BackToStep2Btn = uibutton(app.Step3Panel, ...
                'Text','<< Back  Step 2','Position',[10 364 138 26], ...
                'ButtonPushedFcn',@app.BackToStep2Pushed);

            app.MeanLabel = uilabel(app.Step3Panel, ...
                'Text','Prior mean vector','FontWeight','bold', ...
                'Position',[10 338 200 20]);

            app.MeanTable = uitable(app.Step3Panel, ...
                'Position',[10 210 490 125],'ColumnName',{'Prior Mean'}, ...
                'ColumnEditable',true,'CellEditCallback',@app.MeanTableCellEdit);

            app.CovLabel = uilabel(app.Step3Panel, ...
                'Text','Prior covariance matrix  (upper triangle; lower mirrors)', ...
                'FontWeight','bold','Position',[10 188 450 20]);

            app.VarTable = uitable(app.Step3Panel, ...
                'Position',[10 12 490 172],'CellEditCallback',@app.VarTableCellEdit);

            % ── Step 4 Panel ──────────────────────────────────────────
            app.Step4Panel = uipanel(app.UIFigure, ...
                'Title','Step 4: Design Options', ...
                'Position',[675 10 515 390],'Visible','off');

            app.NCSetsLabel = uilabel(app.Step4Panel, ...
                'Text','Number of choice sets:','Position',[15 340 195 22]);
            app.NCSetsField = uieditfield(app.Step4Panel,'numeric', ...
                'Value',16,'Limits',[1 9999],'RoundFractionalValues','on', ...
                'Position',[218 340 80 22]);

            app.NAltsLabel = uilabel(app.Step4Panel, ...
                'Text','Alternatives per choice set:','Position',[15 300 195 22]);
            app.NAltsField = uieditfield(app.Step4Panel,'numeric', ...
                'Value',2,'Limits',[2 20],'RoundFractionalValues','on', ...
                'Position',[218 300 80 22]);

            app.NFixedLabel = uilabel(app.Step4Panel, ...
                'Text','Number of fixed profiles:','Position',[15 260 195 22]);
            app.NFixedField = uieditfield(app.Step4Panel,'numeric', ...
                'Value',0,'Limits',[0 99],'RoundFractionalValues','on', ...
                'Position',[218 260 80 22]);

            app.NoChoiceChk = uicheckbox(app.Step4Panel, ...
                'Text','Include no-choice option','Value',false, ...
                'Position',[15 224 240 22],'ValueChangedFcn',@app.NoChoiceChanged);

            app.OrderEffectChk = uicheckbox(app.Step4Panel, ...
                'Text','Account for order effect','Value',false, ...
                'Position',[15 194 240 22]);

            app.Sep4Label = uilabel(app.Step4Panel, ...
                'Text','','BackgroundColor',[0.65 0.65 0.65], ...
                'Position',[10 175 490 2]);

            app.TermLabel = uilabel(app.Step4Panel, ...
                'Text','Termination Criterion','FontWeight','bold', ...
                'Position',[15 150 200 22]);

            app.TermBtnGroup = uibuttongroup(app.Step4Panel, ...
                'BorderType','none','Position',[10 108 490 38], ...
                'SelectionChangedFcn',@app.TerminationChanged);

            app.TermAdaptiveBtn = uiradiobutton(app.TermBtnGroup, ...
                'Text','Adaptive','Value',true,'Position',[0 8 100 22]);
            app.TermTimeBtn     = uiradiobutton(app.TermBtnGroup, ...
                'Text','Time (s)','Value',false,'Position',[110 8 90 22]);
            app.TermCycleBtn    = uiradiobutton(app.TermBtnGroup, ...
                'Text','Cycles','Value',false,'Position',[210 8 80 22]);

            app.MaxValueLabel = uilabel(app.Step4Panel, ...
                'Text','Max value:','Enable','off','Position',[15 72 120 22]);
            app.MaxValueField = uieditfield(app.Step4Panel,'numeric', ...
                'Value',100,'Limits',[1 1e8],'RoundFractionalValues','on', ...
                'Enable','off','ValueChangedFcn',@app.MaxValueChanged, ...
                'Position',[140 72 100 22]);

            app.GenerateBtn = uibutton(app.Step4Panel, ...
                'Text','Generate Design','BackgroundColor',[1.00 0.80 0.40], ...
                'FontWeight','bold','Position',[360 14 140 40], ...
                'ButtonPushedFcn',@app.GenerateButtonPushed);

        end % createComponents
    end

    % ══════════════════════════════════════════════════════════════════
    % CONSTRUCTOR
    % ══════════════════════════════════════════════════════════════════
    methods (Access = public)
        function app = dce_tool
            createComponents(app)
            registerApp(app, app.UIFigure)
            app.DCEData = struct( ...
                'Attributes',  [], ...
                'ModelTerms',  {{}}, ...
                'Labels',      {{}}, ...
                'PriorMean',   [], ...
                'PriorVar',    [], ...
                'NChoiceSets', 16, ...
                'NAlts',       2, ...
                'NFixed',      0, ...
                'NoChoice',    false, ...
                'OrderEffect', false, ...
                'Termination', 'adaptive', ...
                'MaxValue',    []);
        end
    end

end % classdef