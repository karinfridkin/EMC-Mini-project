# EMC-Mini-project

---

## Problem → Idea → Outcome
- **Problem**: Simulating a full EMC dictionary over many T2 values is slow (1-4 hours).
- **Idea**: Skip T2 points where the EMC curves change slowly, keep dense sampling where they change fast, then **interpolate along T2**.
- **Outcome**: Same fitting pipeline, **faster dictionary generation**. In our test: **MAPE ≈ 0.01%** vs. the full dictionary.

---

## How it works
1. **Prune** the T2 grid by rules (e.g., 1–80 ms every 5 ms; 81–300 ms every 10 ms; >300 ms every 25 ms).
2. **Interpolate** the pruned EMC tensor back to the **original T2 grid** (default `pchip`).
3. **Compare** T2 maps (bias, MAPE, percentiles) to validate.

---


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



