% SETUP_PATHS  Add this project's folders to the MATLAB path (this session only).
root = fileparts(mfilename('fullpath'));
addpath(fullfile(root, 'common'), fullfile(root, 'tx'), fullfile(root, 'rx'), fullfile(root, 'sim'), fullfile(root, 'data'));
fprintf('Paths added from %s\n', root);