function export_to_qualtrics(X_decoded, filename, format, custom_title, f)
% EXPORT_TO_QUALTRICS
% Routes the design matrix to the writer based on "long" or "short" format.
% FIX 2: .txt extension is appended automatically inside write_qualtrics_txt.

    arguments
        X_decoded {iscell}
        filename (1,1) string
        format (1,1) string = "long"
        custom_title = []
        f = 0 
    end

    % 1. Parse the decoded matrix into a structured format
    design_struct = DCEDesignSA.build_survey_schema(X_decoded);

    % 2. Route based on requested layout format
    switch lower(format)
        case {'long', 'short'}
            DCEDesignSA.write_qualtrics_txt(design_struct, filename, format, custom_title, f);
        otherwise
            error('Format "%s" is not supported. Use "long" or "short".', format);
    end
end