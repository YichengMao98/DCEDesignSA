function export_to_qsf(design_struct, filename, varargin)
% EXPORT_TO_QSF Converts a DCE design structure into a Qualtrics Survey
% Format (QSF) file that can be directly imported into Qualtrics.
%
%   Each choice set in design_struct becomes a single Multiple Choice
%   question in Qualtrics. The question displays a formatted HTML table
%   showing the attribute header row and one row per alternative, with
%   radio buttons for respondent selection.
%
%   The correct QSF structure requires:
%     1. A single BL element listing ALL blocks (not one BL per block).
%     2. A single FL element defining the survey flow.
%     3. Individual SQ elements for each question.
%
%   INPUTS:
%       design_struct - (struct array) Output of build_survey_schema.
%       filename      - (string) Output .qsf file path.
%
%   OPTIONAL name-value inputs:
%       'SurveyName'   - (string) Survey title. Default: 'DCE Survey'.
%       'no_choice'    - (logical) Whether last row is no-choice.
%                        Default: false.
%       'NoChoiceLabel'- (string) No-choice display text.
%                        Default: 'None of the above'.
%       'QuestionStem' - (string) Text above each choice table.
%                        Default: 'Please select your preferred option'.

    %% Parse optional inputs
    p = inputParser;
    addParameter(p, 'SurveyName',    'DCE Survey');
    addParameter(p, 'no_choice',     false);
    addParameter(p, 'NoChoiceLabel', 'None of the above');
    addParameter(p, 'QuestionStem',  'Please select your preferred option');
    parse(p, varargin{:});

    survey_name     = p.Results.SurveyName;
    no_choice       = p.Results.no_choice;
    no_choice_label = p.Results.NoChoiceLabel;
    question_stem   = p.Results.QuestionStem;

    if ~endsWith(filename, '.qsf')
        filename = [filename, '.qsf'];
    end

    n_cs = length(design_struct);
    block_ids    = arrayfun(@(i) sprintf('BL_%04d', i), 1:n_cs, 'UniformOutput', false);
    question_ids = arrayfun(@(i) sprintf('QID%d', i),   1:n_cs, 'UniformOutput', false);

    %% Build JSON as a character array directly
% jsonencode in MATLAB sometimes produces structures incompatible with
% Qualtrics; we build the JSON string manually for full control.

    lines = {};
    lines{end+1} = '{';
    lines{end+1} = '"SurveyEntry":{';
    lines{end+1} = sprintf('"SurveyID":"SV_DCEDesignSA",');
    lines{end+1} = sprintf('"SurveyName":"%s",', esc(survey_name));
    lines{end+1} = '"SurveyDescription":"",';
    lines{end+1} = '"SurveyOwnerID":"",';
    lines{end+1} = '"SurveyBrandID":"",';
    lines{end+1} = '"DivisionID":"",';
    lines{end+1} = '"SurveyLanguage":"EN",';
    lines{end+1} = '"SurveyActiveResponseSet":"",';
    lines{end+1} = '"SurveyStatus":"Inactive",';
    lines{end+1} = '"SurveyStartDate":"0000-00-00 00:00:00",';
    lines{end+1} = '"SurveyExpirationDate":"0000-00-00 00:00:00",';
    lines{end+1} = sprintf('"SurveyCreationDate":"%s",', datestr(now,'yyyy-mm-dd HH:MM:SS'));
    lines{end+1} = '"CreatorID":"",';
    lines{end+1} = sprintf('"LastModified":"%s",', datestr(now,'yyyy-mm-dd HH:MM:SS'));
    lines{end+1} = '"LastAccessed":"0000-00-00 00:00:00",';
    lines{end+1} = '"LastActivated":"0000-00-00 00:00:00",';
    lines{end+1} = '"Deleted":null';
    lines{end+1} = '},';

    lines{end+1} = '"SurveyElements":[';

    %% Survey Options element
    lines{end+1} = '{';
    lines{end+1} = '"SurveyID":"SurveyOptions",';
    lines{end+1} = '"Element":"SO",';
    lines{end+1} = '"PrimaryAttribute":"Survey Options",';
    lines{end+1} = sprintf('"SecondaryAttribute":"%s",', esc(survey_name));
    lines{end+1} = '"Payload":{';
    lines{end+1} = '"BackButton":"false",';
    lines{end+1} = '"SaveAndContinue":"true",';
    lines{end+1} = '"SurveyProtection":"PublicSurvey",';
    lines{end+1} = '"BallotBoxStuffingPrevention":"false",';
    lines{end+1} = '"NoIndex":"Yes",';
    lines{end+1} = '"SecureResponseFiles":"true",';
    lines{end+1} = '"SurveyExpiration":"None",';
    lines{end+1} = '"SurveyTermination":"DefaultMessage",';
    lines{end+1} = '"Header":"",';
    lines{end+1} = '"Footer":"",';
    lines{end+1} = '"ProgressBarDisplay":"None",';
    lines{end+1} = '"PartialData":"+7 days",';
    lines{end+1} = '"ValidationMessage":"",';
    lines{end+1} = '"InactiveSurvey":"DefaultMessage",';
    lines{end+1} = sprintf('"SurveyTitle":"%s",', esc(survey_name));
    lines{end+1} = '"SkinLibrary":"qualtrics",';
    lines{end+1} = '"SkinType":"templated",';
    lines{end+1} = '"Skin":{"brandingId":"","templateId":"*base"},';
    lines{end+1} = '"NewScoring":1';
    lines{end+1} = '}';
    lines{end+1} = '},';

    %% Single BL element with all blocks
    lines{end+1} = '{';
    lines{end+1} = '"SurveyID":"Survey Blocks",';
    lines{end+1} = '"Element":"BL",';
    lines{end+1} = '"PrimaryAttribute":"Survey Blocks",';
    lines{end+1} = '"SecondaryAttribute":"",';
    lines{end+1} = '"Payload":{';
    for i = 1:n_cs
        lines{end+1} = sprintf('"%s":{', block_ids{i});
        lines{end+1} = '"Type":"Standard",';
        lines{end+1} = sprintf('"Description":"%s",', design_struct(i).BlockName);
        lines{end+1} = sprintf('"ID":"%s",', block_ids{i});
        lines{end+1} = sprintf('"BlockElements":[{"Type":"Question","QuestionID":"%s"}],', question_ids{i});
        lines{end+1} = '"Options":{"BlockLocking":"false","RandomizeQuestions":"false","Looping":""}';
        if i < n_cs
            lines{end+1} = '},';
        else
            lines{end+1} = '}';
        end
    end
    lines{end+1} = '}';
    lines{end+1} = '},';

    %% Survey Flow element
    lines{end+1} = '{';
    lines{end+1} = '"SurveyID":"Survey Flow",';
    lines{end+1} = '"Element":"FL",';
    lines{end+1} = '"PrimaryAttribute":"Survey Flow",';
    lines{end+1} = '"SecondaryAttribute":"",';
    lines{end+1} = '"Payload":{';
    lines{end+1} = '"Type":"Root",';
    lines{end+1} = '"FlowID":"FL_1",';
    lines{end+1} = '"Flow":[';
    for i = 1:n_cs
        if i < n_cs
            lines{end+1} = sprintf('{"Type":"Standard","ID":"%s","Flow":[]},', block_ids{i});
        else
            lines{end+1} = sprintf('{"Type":"Standard","ID":"%s","Flow":[]}', block_ids{i});
        end
    end
    lines{end+1} = '],';
    lines{end+1} = sprintf('"Properties":{"Count":%d,"RemovedFieldsets":[]}', n_cs);
    lines{end+1} = '}';
    lines{end+1} = '},';

    %% One SQ element per choice set
    for i = 1:n_cs
        cs        = design_struct(i);
        attr_names= cs.Alternatives.Properties.VariableNames;
        n_attrs   = length(attr_names);
        n_alts    = height(cs.Alternatives);
        n_regular = n_alts - no_choice;

        html = build_html_table(cs, attr_names, n_attrs, n_regular, ...
            no_choice, no_choice_label);

        lines{end+1} = '{';
        lines{end+1} = sprintf('"SurveyID":"%s",', question_ids{i});
        lines{end+1} = '"Element":"SQ",';
        lines{end+1} = sprintf('"PrimaryAttribute":"%s",', question_ids{i});
        lines{end+1} = sprintf('"SecondaryAttribute":"Choice Set %d",', i);
        lines{end+1} = '"Payload":{';
        lines{end+1} = '"Type":"MC",';
        lines{end+1} = '"Selector":"SAVR",';
        lines{end+1} = '"SubSelector":"TX",';
        lines{end+1} = sprintf('"QuestionText":"%s<br\\/><br\\/>%s",', ...
            esc(question_stem), esc(html));
        lines{end+1} = sprintf('"DataExportTag":"Q%d",', i);
        lines{end+1} = sprintf('"QuestionID":"%s",', question_ids{i});
        lines{end+1} = sprintf('"QuestionDescription":"Choice Set %d",', i);
        lines{end+1} = '"Validation":{"Settings":{"ForceResponse":"ON","ForceResponseType":"ON","Type":"None"}},';

        % Choices
        lines{end+1} = '"Choices":{';
        for r = 1:n_regular
            if r < n_regular || no_choice
                lines{end+1} = sprintf('"c%d":{"Display":"%s"},', r, esc(char(cs.AltLabels(r))));
            else
                lines{end+1} = sprintf('"c%d":{"Display":"%s"}', r, esc(char(cs.AltLabels(r))));
            end
        end
        if no_choice
            lines{end+1} = sprintf('"c%d":{"Display":"%s"}', n_alts, esc(no_choice_label));
        end
        lines{end+1} = '},';

        % ChoiceOrder
        co_parts = arrayfun(@(x) num2str(x), 1:n_alts, 'UniformOutput', false);
        lines{end+1} = sprintf('"ChoiceOrder":[%s],', strjoin(co_parts, ','));
        lines{end+1} = sprintf('"NextChoiceId":%d,', n_alts+1);
        lines{end+1} = '"NextAnswerId":1,';
        lines{end+1} = '"Language":[],';
        lines{end+1} = sprintf('"BlockID":"%s"', block_ids{i});
        lines{end+1} = '}';  % end Payload

        if i < n_cs
            lines{end+1} = '},';
        else
            lines{end+1} = '}';
        end
    end

    lines{end+1} = ']';  % end SurveyElements
    lines{end+1} = '}';  % end root

    %% Write to file
    json_str = strjoin(lines, newline);
    fid = fopen(filename, 'w', 'n', 'UTF-8');
    if fid == -1
        error('Cannot open file for writing: %s', filename);
    end
    fprintf(fid, '%s', json_str);
    fclose(fid);

    fprintf('QSF written to: %s  (%d choice sets)\n', filename, n_cs);
end


%% -------------------------------------------------------------------------
function html = build_html_table(cs, attr_names, n_attrs, n_regular, ...
    no_choice, no_choice_label)
% Build the HTML table string embedded in the Qualtrics question text.

    tbl  = 'border-collapse:collapse;width:100%;table-layout:fixed;';
    th   = 'border:1px solid #ccc;padding:8px;background:#f2f2f2;text-align:center;font-weight:bold;';
    td   = 'border:1px solid #ccc;padding:8px;text-align:center;';
    td_nc= 'border:1px solid #ccc;padding:8px;text-align:center;font-style:italic;color:#666;';

    html = sprintf('<table style=\\"%s\\">', tbl);
    html = [html, '<thead><tr>'];
    for c = 1:n_attrs
        html = [html, sprintf('<th style=\\"%s\\">%s</th>', th, attr_names{c})];
    end
    html = [html, '</tr></thead><tbody>'];

    for r = 1:n_regular
        html = [html, '<tr>'];
        for c = 1:n_attrs
            val = cs.Alternatives{r, c};
            if isnumeric(val)
                val_str = num2str(val);
            else
                val_str = char(string(val));
            end
            html = [html, sprintf('<td style=\\"%s\\">%s</td>', td, val_str)];
        end
        html = [html, '</tr>'];
    end

    if no_choice
        html = [html, sprintf('<tr><td colspan=\\"%d\\" style=\\"%s\\">%s</td></tr>', ...
            n_attrs, td_nc, no_choice_label)];
    end

    html = [html, '</tbody></table>'];
end


%% -------------------------------------------------------------------------
function s = esc(s)
% Escape characters that would break JSON string values:
% backslash must come first to avoid double-escaping.
    s = strrep(s, '\', '\\');
    s = strrep(s, '"', '\"');
    s = strrep(s, sprintf('\n'), '\n');
    s = strrep(s, sprintf('\r'), '\r');
    s = strrep(s, sprintf('\t'), '\t');
end