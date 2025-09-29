function [interpFile, pctSaved, keepMask] = task2_adv_interp(srcFile, rules, method)
% TASK2_ADV_INTERP  Rule-based skip + interpolate back to full T2 grid.
% rules(r): fields in **ms**: t2_min, t2_max (can be Inf), stride (keep every k-th)

% Defolt method = pchip 
if nargin<3 || isempty(method), method = 'pchip'; end

assert(exist(srcFile,'file')==2, 'File not found: %s', srcFile);
S = load(srcFile);
assert(isfield(S,'T2_tse_arr') && isfield(S,'echo_train_modulation'), ...
       'Missing fields T2_tse_arr / echo_train_modulation in %s', srcFile);

T2 = S.T2_tse_arr(:);           % native units (s or ms)
E  = S.echo_train_modulation;

% T2 units for rule matching (ms) 
if max(T2) <= 1, T2_ms = 1000*T2; else, T2_ms = T2; end

% Find T2 dim + bring to front 
t2dim = find(size(E) == numel(T2), 1, 'first'); % Find which axis of E has length equal to the number of T2 grid points.
assert(~isempty(t2dim), 'Could not find T2 dimension in echo_train_modulation');
perm = 1:max(ndims(E),2); % [1,2...N] Min 2 dimension
if t2dim ~= 1, perm([1,t2dim]) = perm([t2dim,1]); end  % T2 to first dimension 
E1 = permute(E, perm);                           % [nT2 x ...] producing E1 where dimension 1 is T2

% Enforce monotonic ascending T2 and reorder E accordingly 
[Ts, order] = sort(T2(:), 'ascend'); % sort T2 for the interp1 function
if ~isequal(T2(:), Ts)
    T2    = Ts;
    T2_ms = T2_ms(order);
    E1    = E1(order,:,:,:,:);
end
nT2 = numel(T2);

% Build KEEP mask by rules (on ms scale) 
keepMask = false(nT2,1);
for r = 1:numel(rules)
    assert(all(isfield(rules,{'t2_min','t2_max','stride'})), 'Each rule needs t2_min/t2_max/stride');
    lo = rules(r).t2_min;  hi = rules(r).t2_max;  k = max(1, round(rules(r).stride)); 
    idx = find(T2_ms >= lo & T2_ms <= hi); 
    if isempty(idx), continue; end
    mark = false(size(idx));  mark(1:k:end) = true;
    keepMask(idx(mark)) = true;
end

% anchor endpoints (makes the interp1 safe)
keepMask(1) = true; keepMask(end) = true;

kept = nnz(keepMask);  N = nT2;
assert(kept >= 2, 'Too few T2 samples kept (kept=%d). Relax rules.', kept);
pctSaved = 100*(1 - kept/N);

% Flatten non-T2 dims to columns
sz1   = size(E1); if numel(sz1)==1, sz1 = [sz1 1]; end
nRest = prod(sz1(2:end));                        % Compute how many columns we'll have after flattening
E1r   = reshape(E1, [N, nRest]);                 % [nT2 x rest]
Ekr   = E1r(keepMask,:);                         % kept rows only
T2k   = T2(keepMask);

% Vectorized interpolation back to full grid (method default pchip) 
Efullr = interp1(double(T2k), double(Ekr), double(T2), method, 'extrap');  % [nT2 x rest]
% pchip/spline can produce tiny negative values
Efullr = max(Efullr, 0);

% Warn if extrapolation would have been needed (shouldn't with anchors)
need_extrap = (min(T2) < min(T2k)) || (max(T2) > max(T2k));
if need_extrap, warning('Extrapolation occurred at T2 edges. Check rules/anchors.'); end

% Reshape back + restore original dim order 
Efull = reshape(Efullr, sz1);
Enew  = ipermute(Efull, perm);

% Save: keep all original metadata (drop-in replacement dict) 
S_interp = S;
S_interp.echo_train_modulation = Enew;                     % replace tensor only
S_interp.T2_tse_arr            = reshape(T2, size(S.T2_tse_arr));  % keep original shape

[folder, base, ~] = fileparts(srcFile);
interpFile = fullfile(folder, [base '_task2_interp.mat']);
save(interpFile, '-struct', 'S_interp', '-v7.3');

fprintf('Task2: kept %d/%d → saved %.1f%% time | method=%s\n  wrote: %s\n', ...
        kept, N, pctSaved, method, interpFile);
end
