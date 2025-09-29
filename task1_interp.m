function [sparseFile, interpFile, keptFrac] = task1_interp(srcFile, lowT2_ms, method)

if nargin<2 || isempty(lowT2_ms), lowT2_ms = 21; end
if nargin<3 || isempty(method),   method   = 'linear'; end
assert(exist(srcFile,'file')==2, 'File not found: %s', srcFile);

% Load dictionary
S = load(srcFile);
assert(isfield(S,'T2_tse_arr') && isfield(S,'echo_train_modulation'), ...
       'Dictionary must contain T2_tse_arr and echo_train_modulation');

T2 = S.T2_tse_arr(:);              
E  = S.echo_train_modulation;     

% Units for threshold 
if max(T2) > 2
    lowT2 = lowT2_ms;  units = 'ms';
else
    lowT2 = lowT2_ms/1000;  units = 's';
end

% Find T2 dimension in E
t2dim = find(size(E)==numel(T2), 1, 'first'); %Index (dimension number) inside E that corresponds to the T2 axis.
assert(~isempty(t2dim),'Could not find T2 dimension in echo_train_modulation');

% Bring T2 to the first dimension
ord = 1:ndims(E); % Create an index vector from 1 up to the number of dimensions in E.
ord([1,t2dim]) = ord([t2dim,1]); % Places t2dim in the first axis
E1  = permute(E, ord);               % Reorder E so that the first dimension is T2.
sz1 = size(E1);
nT2 = sz1(1);
rest = max(1, prod(sz1(2:end)));     % Collapse all the non-T2 dimensions into a single number
E2  = reshape(E1, [nT2, rest]);      % [nT2 x rest] - flatten E1 into a 2D matrix.

% Keep/drop: from threshold up keep/drop alternating
keep = true(nT2,1);
idx  = find(T2 >= lowT2);
if ~isempty(idx)
    keep(idx(2:2:end)) = false;      % drop every 2nd at/above threshold
end
T2s = T2(keep);
E2s = E2(keep,:);
keptFrac = numel(T2s)/numel(T2); % Acceleration factor

% Save partial dictionary
S_sparse = S;
origT2 = S.T2_tse_arr;
if isrow(origT2)
    S_sparse.T2_tse_arr = T2s(:).';   % row vector
else
    S_sparse.T2_tse_arr = T2s(:);     % column vector (default)
end     
S_sparse.echo_train_modulation = ipermute(reshape(E2s, [numel(T2s), sz1(2:end)]), ord); % Returns to original dimensions (size and ord)
[p,b,~]    = fileparts(srcFile); % path p, base name b, and extension (ignored)
sparseFile = fullfile(p, [b '_task1_sparse.mat']); 
save(sparseFile, '-struct', 'S_sparse', '-v7.3'); % Saves the struct fields directly into the MAT-file

% Interpolate back to the FULL T2 grid (column-wise along T2)
% Vectorized Interpolation
x   = double(T2s);
xq  = double(T2);
E2i = interp1(x, double(E2s), xq, method, 'extrap'); % Interpolate 

E2i = max(E2i, 0);                          % clamp negatives (physically intensity ≥ 0)
E_interp = ipermute(reshape(E2i, [nT2, sz1(2:end)]), ord); % Undo the earlier collapse, dimensions back to the ORIGINAL order

% Save INTERPOLATED dictionary
S_interp = S;                                % keep original metadata as-is
S_interp.echo_train_modulation = E_interp;   % only replace EMC tensor
interpFile = fullfile(p, [b '_task1_interp.mat']);
save(interpFile, '-struct', 'S_interp', '-v7.3');

fprintf('Task1: units=%s | kept %d/%d T2 (keptFrac=%.3f ~ accel ≈ %.2fx)\n  saved:\n   %s\n   %s\n', ...
    units, numel(T2s), numel(T2), keptFrac, 1/keptFrac, sparseFile, interpFile);
end
