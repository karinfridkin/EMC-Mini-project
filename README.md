# EMC-Mini-project

---

## Problem → Idea → Outcome
- **Problem**: Simulating a full EMC dictionary over many T2 values is slow (1-4 hours).
- **Idea**: Skip T2 points where the EMC curves change slowly, keep dense sampling where they change fast, then **interpolate along T2**.
- **Outcome**: Same fitting pipeline, **faster dictionary generation**. In our test: **MAPE ≈ 0.01%** vs. the full dictionary.

---
## Why the decay is **not** mono-exponential

Multi-spin-echo (TSE/CPMG) trains don’t follow a simple `S(t)=S0·exp(−t/T2)` (as in theory) because:
- **Imperfect refocusing (B1⁺ inhomogeneity / flip-angle errors)** creates **stimulated echoes** that mix with primary echoes.
- **Slice-profile & crusher** schemes redistribute coherence pathways (EPG formalism), altering the apparent decay.
- Optional effects (exchange, diffusion during gradients) further deviate from a single exponential.

➡️ Therefore we use a **Bloch/EPG-simulated EMC dictionary** over **(T2, B1⁺, …)** rather than fitting a mono-exponential.

---

## How we measure success (comparison factors)

We compare the **T2 map from the full dictionary** to the **T2 map from the interpolated dictionary**.  
Per-voxel percent error is:
**err(i) = 100 * ( T2_interp(i) - T2_full(i) ) / T2_full(i)  %**
(Computed only on **valid voxels**: finite and > 0. DICOM values are first rescaled using **RescaleSlope/Intercept**.)

**Reported metrics**
- **Pixels compared** — number of voxels.  
- **Bias (mean %)** — average signed % error. *Goal:* ≈ 0%.  
- **MAPE (mean abs %)** — average abs % error. *Goal:* ≪ 1%.  
- **Median |%err|** — robust central tendency. *Goal:* ≈ 0%.  
- **95th pct |%err|** — tail error; 95% of voxels are below this value. *Goal:* < ~1%.

---

## Results (snapshots)
<img width="1058" height="614" alt="image" src="https://github.com/user-attachments/assets/bf72dfc3-4b17-4026-a565-a64a28f1e914" />

**Left:** T2 map with the full dictionary vs. with the interpolated dictionary.  
**Right:** Voxel-wise % error (interp vs full), display range ±1%.

**Example stats**:
- Pixels compared: **9,177**  
- **Bias**: 0.00% **MAPE**: **0.01%** **Median |%err|**: 0.00% **95th pct |%err|**: 0.00%  
- Dictionary diff (relative Frobenius): **8.7e-4**

---
## How to run Task2

1. **Setup**
   - Clone this repo and open MATLAB.
   - Add sources to the path:
     ```matlab
     addpath(genpath('src'));
     ```
   - Point `dicPath` to your **EMC dictionary** (`.mat` that contains `T2_tse_arr` and `echo_train_modulation`).  
     Example:
     ```matlab
     dicPath = 'data/SEMC149.mat';  % or an absolute path on your machine
     ```

2. **Create an interpolated dictionary (Task 2)**
   - Define the banded rules (ms) and run:
     ```matlab
     rules = struct( ...
       't2_min',{  1,  81, 301}, ...
       't2_max',{ 80, 300, Inf}, ...
       'stride',{  5,  10,  25});

     [interpDicPath, pctSaved, keepMask] = task2_adv_interp(dicPath, rules, 'pchip');
     ```
   - This writes `*_task2_interp.mat` next to your source dictionary and prints the **% time saved**.

3. **Generate T2 maps in the GUI**
   - Open the **EMC T2 FIT GUI** (per your setup).
   - Load the experimental dataset.
   - Run **baseline** with the **full dictionary** (B1 fit **OFF**, per assignment) and export the DICOM.
   - change file name to  'T2_map_Full'.
   - Run again with the **interpolated dictionary** (`interpDicPath`) and export the DICOM (e.g., `...T2map_EMCt-task2_interp.dcm`).
   - change file name to  `T2_map_interpAdvanced`.

4. **Compare maps (voxel-wise % error)**
   ```matlab
   compare_emc_t2_dicoms( ...
     'path/T2_map_Full.dcm', ...
     'path/T2_map_interpAdvanced.dcm');



