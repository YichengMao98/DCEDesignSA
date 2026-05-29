function [nlevels, attr_labels, attr_names] = parse_attr_labels(attr_input)
% PARSE_ATTR_LABELS Extracts level counts, labels, and attribute names.
%
%   INPUT:
%       attr_input - Can be a struct or a cell array.
%                  - Struct example: struct('Brand', {{'A','B'}}, 'Price', {{'1','2'}})
%                  - Cell example: {{'A','B'}, {'1','2'}}
%
%   OUTPUTS:
%       nlevels     - Vector of level counts for each attribute.
%       attr_labels - Original string labels for decoding.
%       attr_names  - Names of the attributes for the table header.

    if isstruct(attr_input)
        % Handle struct input (dictionary-like)
        attr_names = fieldnames(attr_input)'; % Extract field names as attribute names
        n_attrs = length(attr_names);
        nlevels = zeros(1, n_attrs);
        attr_labels = cell(1, n_attrs);
        for i = 1:n_attrs
            labels = attr_input.(attr_names{i});
            nlevels(i) = length(labels);
            attr_labels{i} = labels;
        end
    else
        % Handle legacy cell array input
        n_attrs = length(attr_input);
        nlevels = zeros(1, n_attrs);
        attr_labels = attr_input;
        % Generate default names (Attr1, Attr2, ...) if no names are provided
        attr_names = arrayfun(@(i) sprintf('Attr%d', i), 1:n_attrs, 'UniformOutput', false);
        for i = 1:n_attrs
            nlevels(i) = length(attr_input{i});
        end
    end
end