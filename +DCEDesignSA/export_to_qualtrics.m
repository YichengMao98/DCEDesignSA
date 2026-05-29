function export_to_qualtrics(X_decoded, filename, format, custom_title, f)
% EXPORT_TO_QUALTRICS  Entry point for exporting a DCE design to Qualtrics.
%
%   This function converts the decoded design matrix produced by decode_X
%   into a Qualtrics-importable survey file. It delegates schema parsing to
%   build_survey_schema and file writing to write_qualtrics_txt.
%
%   DESIGN CONVENTION — FULL vs PARTIAL PROFILE
%   ---------------------------------------------
%   The parameter f controls how write_qualtrics_txt renders the survey:
%
%     f == 0  →  Full-profile design.
%                Every attribute is shown for every alternative with no
%                visual emphasis (no row highlighting).
%
%     f  > 0  →  Partial-profile design.
%                f attributes are held FIXED (same level across all
%                alternatives) within each choice set. The remaining
%                attributes VARY and are the actual decision-relevant
%                differences. These varying rows are highlighted in yellow
%                so respondents immediately focus on what differs.
%
%   IMPORTANT: f must match the value used when generating the design via
%   initialize() / SA(). Passing the wrong f will produce incorrect
%   highlighting because the highlight rule is derived from f > 0, not
%   from re-inspecting the raw design matrix.
%
%   INPUTS
%   ------
%   X_decoded    - Cell array produced by decode_X. Row 1 is the header;
%                  subsequent rows contain choice-set label, alternative
%                  label, and attribute values.
%   filename     - Output file path (string), e.g. "my_survey.txt".
%                  The file will be overwritten if it already exists.
%   format       - Layout format: "long" (default) or "short".
%                  Both currently produce the same HTML table layout.
%                  Reserved for future rendering variants.
%   custom_title - (optional) Character vector or string for the question
%                  stem shown above each choice-set table. Pass [] to
%                  use the built-in default question text.
%   f            - (optional, default 0) Number of fixed attributes per
%                  choice set.
%                    0  →  full-profile  (no highlighting)
%                    >0  →  partial-profile (highlight varying rows)
%
%   OUTPUT
%   ------
%   A UTF-8 plain-text file in Qualtrics Advanced Format. Import it via:
%     Qualtrics → Create Survey → Import a QSF or TXT file.

    arguments
        X_decoded    {iscell}
        filename     (1,1) string
        format       (1,1) string = "long"
        custom_title              = []
        f                         = 0
    end

    % ── Input guard: f must be a non-negative integer ──────────────────────
    % A common mistake is passing a logical or a float. Catch it early.
    if ~isnumeric(f) || ~isscalar(f) || f < 0 || floor(f) ~= f
        error('EXPORT_TO_QUALTRICS: f must be a non-negative integer scalar. ' + ...
              'Use f=0 for full-profile or f>0 for partial-profile.');
    end

    % ── Step 1: Parse decoded matrix into per-choice-set structs ──────────
    % build_survey_schema extracts the header row, groups rows by choice-set
    % label, and returns a struct array with fields:
    %   .BlockName     – choice-set identifier string
    %   .Alternatives  – MATLAB table of attribute values (rows = alts)
    %   .AltLabels     – string array of alternative labels
    design_struct = DCEDesignSA.build_survey_schema(X_decoded);

    % ── Step 2: Route to the writer ────────────────────────────────────────
    % Both "long" and "short" currently delegate to write_qualtrics_txt,
    % which handles the HTML table rendering and partial-profile highlighting.
    % The format string is forwarded in case write_qualtrics_txt introduces
    % layout branches in the future.
    switch lower(format)
        case {'long', 'short'}
            DCEDesignSA.write_qualtrics_txt( ...
                design_struct, filename, format, custom_title, f);
        otherwise
            error('EXPORT_TO_QUALTRICS: Unsupported format "%s". ' + ...
                  'Use "long" or "short".', format);
    end

end