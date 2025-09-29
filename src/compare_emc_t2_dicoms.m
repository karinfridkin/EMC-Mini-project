function compare_emc_t2_dicoms(fullDicom, interpDicom)
% Compare two T2-map DICOM files (voxel-wise % error).
% fullDicom   = path to T2_map_Full  DICOM (from original dictionary)
% interpDicom = path to T2_map_interp DICOM (from interpolated dictionary)

assert(isfile(fullDicom),   'File not found: %s', fullDicom);
assert(isfile(interpDicom), 'File not found: %s', interpDicom);

% Read & Rescale helper
readT2 = @(p) localReadRescaled(p);
T2full   = double(readT2(fullDicom));
T2interp = double(readT2(interpDicom));

% If these are multi-slice, take the first slice for a quick comparison.
if ndims(T2full)   > 2, T2full   = T2full(:,:,1);   end                                                                                                               
if ndims(T2interp) > 2, T2interp = T2interp(:,:,1); end

% Align sizes if needed (compare intersection)
if ~isequal(size(T2full), size(T2interp))
    sz = min(size(T2full), size(T2interp));
    warning('Map sizes differ; comparing common region [%d %d].', sz(1), sz(2));
    T2full   = T2full(  1:sz(1), 1:sz(2));
    T2interp = T2interp(1:sz(1), 1:sz(2));
end

% Mask: valid, positive values
mask = isfinite(T2full) & isfinite(T2interp) & (T2full>0) & (T2interp>0);

pctErr = nan(size(T2full));
pctErr(mask) = 100*(T2interp(mask) - T2full(mask))./T2full(mask);

absPE = abs(pctErr(mask));
fprintf('\n=== Percent Error (interp vs full) ===\n');
fprintf('Pixels compared: %d\n', nnz(mask));
fprintf('Bias (mean %%): %.2f\n', mean(pctErr(mask)));
fprintf('MAPE (mean abs %%): %.2f\n', mean(absPE));
fprintf('Median |%%err|: %.2f\n', median(absPE));
fprintf('95th pct |%%err|: %.2f\n', prctile(absPE,95));

% Visualize
figure('Color','w','Name','EMC T2 Compare (DICOM)');
subplot(1,3,1); imagesc(T2full);   axis image off; colorbar; title('Full T2');
subplot(1,3,2); imagesc(T2interp); axis image off; colorbar; title('Interp T2');
subplot(1,3,3); imagesc(pctErr,[-50 50]); axis image off; colorbar; title('% Error (±50)');

end

function A = localReadRescaled(p)
% Read DICOM and apply RescaleSlope/Intercept if present
info = dicominfo(p);
A = dicomread(info);
A = double(A);
if isfield(info,'RescaleSlope') && ~isempty(info.RescaleSlope)
    A = A .* double(info.RescaleSlope);
end
if isfield(info,'RescaleIntercept') && ~isempty(info.RescaleIntercept)
    A = A + double(info.RescaleIntercept);
end
end
