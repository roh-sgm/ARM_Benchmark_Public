# Emerging Architectures: Groundwater Modeling Benchmark Suite

**A Performance Benchmark of Apple ARM Silicon vs. x86 Architectures for Groundwater Model Calibration**

## Overview
This repository contains the benchmarking suite, automation scripts, and results database associated with the *Groundwater* journal Technology Spotlight article: *"Emerging Architectures: A Performance Benchmark of Apple ARM Silicon for Groundwater Modeling."*

As groundwater modeling enters the "ensemble era" (PESTPP-IES, PEST_HP), computational bottlenecks have shifted from single-run times to the throughput of thousands of realizations. This project benchmarks consumer-grade ARM-based hardware (specifically Apple Silicon) against traditional x86 workstations to evaluate viability, cost-efficiency, and thermal stability for high-throughput PEST workflows.

## Repository Contents

* **`benchmark_model/`**: Contains the model files and necessary executables.
    * [cite_start]`MODFLOW_files/`: The Biscayne Bay MODFLOW-USG dataset (compressed as `files.7z` [cite: 133, 134]).
    * `executables/`: Pre-compiled USG-TRANSPORT 1.8 binaries and automation scripts for Mac and Windows.
* [cite_start]**`Runtimes/`**: Contains the master results spreadsheet (`ByscayneMode_Benchmarks.xlsx`)[cite: 149].
* **`Scripts/`**: Python notebooks for post-processing and generating the plots/statistics found in the article.
* **`images/`**: Figures and heatmaps used in the publication.

## Benchmarking Methodology
[cite_start]The protocol mimics the workload of a PEST parallel calibration agent using **USG-TRANSPORT 1.8**[cite: 107, 133]. [cite_start]The model is executed repeatedly, systematically increasing the number of simultaneous agents from 1 to 16 per machine[cite: 138].

* [cite_start]**Metric:** "Maximum Runtime"—the time required for the *slowest* realization in the batch to complete[cite: 140].
* [cite_start]**Constraint:** All agents simulate identical model realizations to maintain strictly controlled hardware throughput comparison[cite: 44].

## Getting Started

### 1. Setup
1.  **Clone the repository:**
    ```bash
    git clone [https://github.com/roh-sgm/ARM_Benchmark_Public.git](https://github.com/roh-sgm/ARM_Benchmark_Public.git)
    cd ARM_Benchmark_Public
    ```
2.  **Extract Model Files:**
    Unzip `benchmark_model/MODFLOW_files/files.7z` into a working directory.

### 2. Choose Your OS Instructions

#### For Windows Users
The scripts are located in `benchmark_model/executables/Win/scripts`. [cite_start]They are provided as `.txt` files to avoid antivirus deletion[cite: 122].
1.  **Rename the scripts:**
    * [cite_start]`copy_files.txt` → `copy_files.bat` [cite: 123]
    * [cite_start]`open_and_run.txt` → `open_and_run.bat` [cite: 126]
    * [cite_start]`clean_up.txt` → `clean_up.bat` [cite: 127]
2.  **Execution:**
    * [cite_start]Run `copy_files.bat` to generate agent folders (default: 16 folders)[cite: 111, 113, 136].
    * [cite_start]Run `open_and_run.bat` to launch the simulations[cite: 115, 137].
    * [cite_start]Run `clean_up.bat` after recording results to delete generated folders[cite: 139].

#### For macOS Users
[cite_start]The scripts are located in `benchmark_model/executables/Mac/scripts` and are provided as `.sh` files[cite: 129].
1.  **Grant execution permissions:**
    ```bash
    chmod +x *.sh
    ```
    [cite_start][cite: 131]
2.  **Execution:**
    * Run `./copy_files.sh` to generate agent folders.
    * Run `./open_and_run.sh` to launch the simulations.
    * Run `./clean_up.sh` to delete folders after testing.

### 3. Reporting Results

**Calculate Runtime:**
[cite_start]USG-T reports runtime in "Minutes, Seconds" (e.g., `6 Minutes, 6.767 Seconds`)[cite: 144]. Convert this to decimal minutes for consistency.
* [cite_start]*Calculation:* $6 + (6.767 / 60) = 6.1128$ minutes [cite: 146]
* [cite_start]*Precision:* Round to **4 decimal places**[cite: 147].

**Submit Data:**
1.  [cite_start]Open `Runtimes/ByscayneMode_Benchmarks.xlsx`[cite: 149].
2.  [cite_start]**Sheet 1 (Runtimes):** Enter your hardware details (CPU Type, Computer Name, Cores) and the runtime for each agent count (1–16)[cite: 153, 154, 155, 157].
3.  [cite_start]**Sheet 2 (Authors):** Add a row with your metadata (Name, Email, Date, Architecture type)[cite: 161].

## Key Findings & Visualization
The benchmark results reveal a significant efficiency paradox between consumer ARM chips and high-end x86 workstations.

### Runtime Heatmap
The following heatmap illustrates runtime performance (in minutes) across 16 different hardware configurations. Green indicates faster runtimes; red indicates slower runtimes. [cite_start]Note the "thermal throttling" shift occurs much earlier on x86 chips compared to Apple Silicon[cite: 64, 66].

![Runtime Heatmap](images/runtime_heatmap.png)
*(Figure 2 from the associated Technology Spotlight article)*

### Summary
* [cite_start]**Thermal Stability:** ARM-based chips maintained nearly flat runtime slopes under load, whereas x86 chips often exhibited steep linear degradation due to thermal throttling[cite: 60, 61].
* [cite_start]**Cost Efficiency:** A consumer-grade **M4 Mac Mini** (~$600) achieved parity with a 64-core **AMD Threadripper 3990X** (~$4,000+) in parallel throughput tests (avg runtimes: 8.94 min vs 8.93 min)[cite: 73, 75].

## Contributing
We encourage the community to contribute their own results to expand this industry database. [cite_start]Please submit your benchmark results via a **Pull Request** containing your updated `ByscayneMode_Benchmarks.xlsx`[cite: 164].

## References
* Panday, Sorab, et al. (2013). MODFLOW-USG version 1. USGS Techniques and Methods 6-A45.
* Apple Inc. (2020). [cite_start]Apple unleashes M1[cite: 102].
* USGS (2025). [cite_start][pymake](https://github.com/modflowpy/pymake)[cite: 103].