function log_csv(filename, varargin)
% LOG_CSV  Append one row to a CSV file, built from one or more structs.
%
%   log_csv('data/packets.csv', meta, row)
%     Every field of every struct becomes a column, in order. The header
%     line is written only when the file does not exist yet, so ALWAYS log
%     the same structs in the same order to the same file.
%     Numbers are written with 10 significant digits (NaN stays "NaN"),
%     logicals as 0/1, text in double quotes.
%
% Works in MATLAB and Octave (writetable does not exist in Octave). Open the
% result in Excel, or read it back with readtable('data/packets.csv').
%
% SYNTAX NOTES
%   - varargin collects all extra inputs into a cell array: varargin{1} is
%     the first struct, varargin{2} the second, and so on.
%   - fieldnames(s) returns the field names of a struct as a cell array.
%   - s.(name) reads a field whose name is stored in a variable.

names = {};  vals = {};
for a = 1:numel(varargin)
    s = varargin{a};
    f = fieldnames(s);
    for k = 1:numel(f)
        v = s.(f{k});
        names{end+1} = f{k}; %#ok<AGROW>
        if ischar(v)
            vals{end+1} = ['"' strrep(v, '"', '""') '"']; %#ok<AGROW>
        elseif islogical(v)
            vals{end+1} = sprintf('%d', v(1)); %#ok<AGROW>
        elseif isempty(v)
            vals{end+1} = 'NaN'; %#ok<AGROW>
        else
            vals{end+1} = sprintf('%.10g', double(v(1))); %#ok<AGROW>
        end
    end
end

isNew = ~exist(filename, 'file');
fid = fopen(filename, 'a');
assert(fid > 0, 'Cannot open %s for writing', filename);
if isNew
    fprintf(fid, '%s\n', strjoin(names, ','));
end
fprintf(fid, '%s\n', strjoin(vals, ','));
fclose(fid);
end
