classdef DCEDesignSAPortabilityTest < matlab.unittest.TestCase
% Static cross-platform checks. They run on any OS, and are written to catch
% the problems that only show up on a different one:
%   * case-sensitive file systems (Linux, and macOS by default on some volumes):
%     every DCEDesignSA.<name> reference must match a file name exactly;
%   * case-insensitive file systems: no two package files may differ only by case;
%   * hard-coded absolute paths or Windows path separators;
%   * non-ASCII characters in executable code (MATLAB reads source files using
%     the machine's default encoding on some platforms, which garbles UTF-8
%     string literals; keep them to comments, or build them with char()).
% Behavioural portability (paths containing spaces, temp folders) is covered in
% DCEDesignSAUnitTest (export tests). The CI workflow in .github/workflows runs
% the whole suite on Linux, Windows and macOS.

    properties
        Root
        Files
    end

    methods (TestClassSetup)
        function locateSources(testCase)
            testCase.Root = fileparts(fileparts(mfilename('fullpath')));
            pkg = dir(fullfile(testCase.Root, '+DCEDesignSA', '*.m'));
            testCase.Files = [fullfile({pkg.folder}, {pkg.name}), ...
                {fullfile(testCase.Root, 'dce_tool.m')}];
        end
    end

    methods (Test)
        function everyPackageReferenceMatchesAFileNameExactly(testCase)
            pkg   = dir(fullfile(testCase.Root, '+DCEDesignSA', '*.m'));
            names = erase({pkg.name}, '.m');
            for i = 1:numel(testCase.Files)
                txt  = fileread(testCase.Files{i});
                tok  = regexp(txt, 'DCEDesignSA\.([A-Za-z_]\w*)', 'tokens');
                refs = unique(cellfun(@(c) c{1}, tok, 'UniformOutput', false));
                for k = 1:numel(refs)
                    testCase.verifyTrue(any(strcmp(refs{k}, names)), ...
                        sprintf('%s refers to DCEDesignSA.%s, which does not match any file name exactly (case matters on Linux).', ...
                        testCase.Files{i}, refs{k}));
                end
            end
        end

        function noTwoPackageFilesDifferOnlyByCase(testCase)
            pkg   = dir(fullfile(testCase.Root, '+DCEDesignSA', '*.m'));
            names = lower({pkg.name});
            testCase.verifyEqual(numel(unique(names)), numel(names));
        end

        function noHardCodedAbsolutePathsOrWindowsSeparators(testCase)
            % drive letter (a single letter not preceded by a word character),
            % UNC path, or a typical POSIX home/temp prefix
            pat = ['(^|[^A-Za-z0-9_])[A-Za-z]:\\', '|', '\\\\[A-Za-z]', '|', '/Users/', '|', '/home/', '|', '/tmp/'];
            for i = 1:numel(testCase.Files)
                for line = codeLines(testCase.Files{i})
                    if ~isempty(regexp(line.code, pat, 'once'))
                        testCase.verifyFail(sprintf('%s:%d hard-coded path: %s', ...
                            testCase.Files{i}, line.number, strtrim(line.code)));
                    end
                end
            end
        end

        function noPlatformSpecificCalls(testCase)
            pat = '\<(ispc|ismac|isunix|winqueryreg|actxserver|dos|system|feature\s*\()\>';
            for i = 1:numel(testCase.Files)
                for line = codeLines(testCase.Files{i})
                    testCase.verifyEmpty(regexp(line.code, pat, 'once'), ...
                        sprintf('%s:%d platform-specific call: %s', testCase.Files{i}, line.number, strtrim(line.code)));
                end
            end
        end

        function executableCodeContainsOnlyAscii(testCase)
            for i = 1:numel(testCase.Files)
                for line = codeLines(testCase.Files{i})
                    bad = line.code(double(line.code) > 127);
                    testCase.verifyEmpty(bad, sprintf( ...
                        '%s:%d non-ASCII character(s) in code (use char(%d) instead): %s', ...
                        testCase.Files{i}, line.number, double(bad(1:min(1,end))), strtrim(line.code)));
                end
            end
        end
    end
end

function lines = codeLines(file)
% Return the executable part of every source line (comments removed), as a
% struct array with fields number and code. A '%' starts a comment unless it
% is inside a character vector; a quote is a string delimiter unless it
% follows an identifier character, ')', ']', '}' or '.' (transpose).
    raw   = splitlines(string(fileread(file)));
    lines = struct('number', {}, 'code', {});
    for n = 1:numel(raw)
        s = char(raw(n));
        inStr = false; cut = numel(s);
        for j = 1:numel(s)
            c = s(j);
            if inStr
                if c == ''''
                    if j < numel(s) && s(j+1) == ''''
                        continue                       % doubled quote inside a string
                    end
                    inStr = false;
                end
            elseif c == '%'
                cut = j - 1; break
            elseif c == ''''
                prev = ' ';
                if j > 1, prev = s(j-1); end
                if ~(isstrprop(prev, 'alphanum') || any(prev == ')]}.''_'))
                    inStr = true;
                end
            end
        end
        lines(end+1) = struct('number', n, 'code', s(1:cut)); %#ok<AGROW>
    end
end
