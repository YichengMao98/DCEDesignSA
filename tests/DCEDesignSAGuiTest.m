classdef DCEDesignSAGuiTest < matlab.unittest.TestCase
% Tests of the dce_tool GUI, driven through the same callback handles the
% controls use. They are tagged 'GUI' and skipped automatically when a
% uifigure cannot be created (for example on a headless machine without the
% needed graphics support). Run without them: run_tests('ExcludeGUI', true).

    properties
        App
    end

    methods (TestClassSetup)
        function addPackageToPath(testCase)
            root = fileparts(fileparts(mfilename('fullpath')));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture(root));
        end
    end

    methods (TestMethodSetup)
        function openApp(testCase)
            try
                testCase.App = dce_tool();
            catch ME
                testCase.assumeFail(['A uifigure could not be created here: ' ME.message]);
            end
            testCase.addTeardown(@() delete(testCase.App.UIFigure));
        end
    end

    methods (Test, TestTags = {'GUI'})
        function stepsRevealInOrderAndBuildTheModelLabels(testCase)
            app = testCase.App;
            testCase.verifyEqual(app.Step2Panel.Visible, matlab.lang.OnOffSwitchState.off);
            defineAttributes(app);
            app.NextBtn.ButtonPushedFcn(app.NextBtn, []);
            testCase.verifyEqual(app.Step2Panel.Visible, matlab.lang.OnOffSwitchState.on);
            app.ModelListBox.Value = app.ModelListBox.Items;
            app.ConfirmBtn.ButtonPushedFcn(app.ConfirmBtn, []);
            testCase.verifyEqual(app.Step3Panel.Visible, matlab.lang.OnOffSwitchState.on);
            testCase.verifyEqual(app.Step4Panel.Visible, matlab.lang.OnOffSwitchState.on);
            testCase.verifyEqual(app.MeanTable.RowName, {'X1 Lv1'; 'X2 Lv1'; 'X2 Lv2'});
        end

        function attributeWithASingleLevelIsRejectedBeforeStep2(testCase)
            app = testCase.App;
            app.AttrTable.Data = {'X1', 1, 'Lv1', '-', '-', '-', '-', '-'};
            app.NextBtn.ButtonPushedFcn(app.NextBtn, []);
            testCase.verifyEqual(app.Step2Panel.Visible, matlab.lang.OnOffSwitchState.off);
        end

        function priorTablesGainAndLoseOrderAndAscRowsAndKeepUserEdits(testCase)
            app = testCase.App;
            defineAttributes(app);
            app.NextBtn.ButtonPushedFcn(app.NextBtn, []);
            app.ModelListBox.Value = app.ModelListBox.Items;
            app.ConfirmBtn.ButtonPushedFcn(app.ConfirmBtn, []);
            rows = @() app.MeanTable.RowName;
            base = {'X1 Lv1'; 'X2 Lv1'; 'X2 Lv2'};

            m = app.MeanTable.Data; m{1,1} = 0.5; app.MeanTable.Data = m;
            v = app.VarTable.Data;  v{1,2} = 0.3; app.VarTable.Data = v;

            tick(app.OrderEffectChk, true);
            testCase.verifyEqual(rows(), [base; {'Order position 1'}]);
            app.NAltsField.Value = 3;
            app.NAltsField.ValueChangedFcn(app.NAltsField, []);
            testCase.verifyEqual(rows(), [base; {'Order position 1'; 'Order position 2'}]);
            tick(app.NoChoiceChk, true);
            r = rows();
            testCase.verifyEqual(r{end}, 'ASC (no-choice)');
            testCase.verifyNumElements(r, 6);
            tick(app.OrderEffectChk, false);
            testCase.verifyEqual(rows(), [base; {'ASC (no-choice)'}]);

            testCase.verifyEqual(app.MeanTable.Data{1,1}, 0.5);
            testCase.verifyEqual(app.VarTable.Data{1,2}, 0.3);
            testCase.verifyEqual(app.VarTable.Data{2,1}, '');        % lower triangle stays display-only
        end

        function editingALowerTriangleCovarianceCellIsReverted(testCase)
            app = testCase.App;
            defineAttributes(app);
            app.NextBtn.ButtonPushedFcn(app.NextBtn, []);
            app.ModelListBox.Value = app.ModelListBox.Items;
            app.ConfirmBtn.ButtonPushedFcn(app.ConfirmBtn, []);
            before = app.VarTable.Data;
            v = app.VarTable.Data; v{2,1} = 9; app.VarTable.Data = v;
            ev = struct('Indices', [2 1], 'PreviousData', before{2,1}, 'NewData', 9);
            app.VarTable.CellEditCallback(app.VarTable, ev);
            testCase.verifyEqual(app.VarTable.Data{2,1}, before{2,1});
        end

        function advancedSettingsDialogEnablesNDrawsOnlyForSampledMethods(testCase)
            app = testCase.App;
            app.AdvSettingsBtn.ButtonPushedFcn(app.AdvSettingsBtn, []);
            dlg = findall(0, 'Type', 'figure', 'Name', 'Advanced Settings');
            testCase.addTeardown(@() delete(dlg(isvalid(dlg))));
            testCase.assertNumElements(dlg, 1);
            dd = findall(dlg, 'Type', 'uidropdown');
            method = dd(cellfun(@(c) isequal(c, {'SR','halton','PMC'}), {dd.Items}));
            ndraws = findall(dlg, 'Type', 'uinumericeditfield', 'Limits', [1 1e6]);
            testCase.verifyEqual(ndraws.Enable, matlab.lang.OnOffSwitchState.off);   % SR ignores n_draws
            method.Value = 'PMC';
            method.ValueChangedFcn(method, []);
            testCase.verifyEqual(ndraws.Enable, matlab.lang.OnOffSwitchState.on);
            btn = findall(dlg, 'Type', 'uibutton', 'Text', 'Cancel');
            btn.ButtonPushedFcn(btn, []);
            testCase.verifyEmpty(findall(0, 'Type', 'figure', 'Name', 'Advanced Settings'));
        end

        function generateRunsEndToEndAndOpensTheResultsWindow(testCase)
            app = testCase.App;
            defineAttributes(app);
            app.NextBtn.ButtonPushedFcn(app.NextBtn, []);
            app.ModelListBox.Value = app.ModelListBox.Items;
            app.ConfirmBtn.ButtonPushedFcn(app.ConfirmBtn, []);
            tick(app.NoChoiceChk, true);
            tick(app.OrderEffectChk, true);
            app.NCSetsField.Value = 4;
            app.TermBtnGroup.SelectedObject = app.TermTimeBtn;
            app.TermBtnGroup.SelectionChangedFcn(app.TermBtnGroup, []);
            app.MaxValueField.Value = 1;
            app.MaxValueField.ValueChangedFcn(app.MaxValueField, []);

            before = findall(0, 'Type', 'figure', 'Name', 'DCE Design Results');
            app.GenerateBtn.ButtonPushedFcn(app.GenerateBtn, []);
            after = setdiff(findall(0, 'Type', 'figure', 'Name', 'DCE Design Results'), before);
            testCase.addTeardown(@() delete(after(isvalid(after))));
            testCase.assertNumElements(after, 1);

            boxes = findall(after, 'Type', 'uitextarea');
            txt = strjoin(string(vertcat(boxes.Value)), newline);
            testCase.verifySubstring(char(txt), 'Fixed Attributes:');
            testCase.verifyEmpty(regexp(char(txt), '<[^>]+>', 'once'), ...
                'results text must not contain HTML tags');
        end
    end
end

function defineAttributes(app)
    app.AttrTable.Data = {'X1', 2, 'Lv1', 'Lv2', '-', '-', '-', '-'; ...
                          'X2', 3, 'Lv1', 'Lv2', 'Lv3', '-', '-', '-'};
end

function tick(box, value)
    box.Value = value;
    box.ValueChangedFcn(box, []);
end
