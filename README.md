# Emerging Architectures: Groundwater Modeling Benchmark Suite

**A Performance Benchmark of Apple ARM Silicon vs. x86 Architectures for Groundwater Model Calibration**

## Overview
This repository contains the benchmarking suite, automation scripts, and results database associated with the *Groundwater* journal Technology Spotlight article: *"Emerging Architectures: A Performance Benchmark of Apple ARM Silicon for Groundwater Modeling."*

As groundwater modeling enters the "ensemble era" (PESTPP-IES, PEST_HP), computational bottlenecks have shifted from single-run times to the throughput of thousands of realizations. This project benchmarks consumer-grade ARM-based hardware (specifically Apple Silicon) against traditional x86 workstations to evaluate viability, cost-efficiency, and thermal stability for high-throughput PEST workflows.

## Repository Contents

* **`benchmark_model/`**: Contains the model files and necessary executables.
    * `MODFLOW_files/`: The Biscayne Bay MODFLOW-USG dataset (compressed as `files.7z`).
    * `executables/`: Pre-compiled USG-TRANSPORT 1.8 binaries and automation scripts for Mac and Windows.
* **`Runtimes/`**: Contains the master results spreadsheet (`ByscayneMode_Benchmarks.xlsx`).
* **`Scripts/`**: Python notebooks for post-processing and generating the plots/statistics found in the article.
* **`images/`**: Figures used in the publication.

## Benchmarking Methodology
The protocol mimics the workload of a PEST parallel calibration agent using **USG-TRANSPORT 1.8**. The model is executed repeatedly, systematically increasing the number of simultaneous agents from 1 to 16 per machine.

* **Metric:** "Maximum Runtime"—the time required for the *slowest* realization in the batch to complete.
* **Constraint:** All agents simulate identical model realizations to maintain strictly controlled hardware throughput comparison.

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
The scripts are located in `benchmark_model/executables/Win/scripts`. They are provided as `.txt` files to avoid antivirus deletion.
1.  **Rename the scripts:**
    * `copy_files.txt` → `copy_files.bat`
    * `open_and_run.txt` → `open_and_run.bat`
    * `clean_up.txt` → `clean_up.bat`
2.  **Execution:**
    * Run `copy_files.bat` to generate agent folders (default: 16 folders).
    * Run `open_and_run.bat` to launch the simulations.
    * Run `clean_up.bat` after recording results to delete generated folders.

#### For macOS Users
The scripts are located in `benchmark_model/executables/Mac/scripts` and are provided as `.sh` files.
1.  **Grant execution permissions:**
    ```bash
    chmod +x *.sh
    ```
2.  **Execution:**
    * Run `./copy_files.sh` to generate agent folders.
    * Run `./open_and_run.sh` to launch the simulations.
    * Run `./clean_up.sh` to delete folders after testing.

### 3. Reporting Results

**Calculate Runtime:**
USG-T reports runtime in "Minutes, Seconds" (e.g., `6 Minutes, 6.767 Seconds`). Convert this to decimal minutes for consistency.
* *Calculation:* 6 + (6.767 / 60) = 6.1128 minutes
* *Precision:* Round to **4 decimal places**.

**Submit Data:**
1.  Open `Runtimes/ByscayneMode_Benchmarks.xlsx`.
2.  **Sheet 1 (Runtimes):** Enter your hardware details (CPU Type, Computer Name, Cores) and the runtime for each agent count (1–16).
3.  **Sheet 2 (Authors):** Add a row with your metadata (Name, Email, Date, Architecture type).

## Key Findings & Visualization
The benchmark results reveal a significant efficiency paradox between consumer ARM chips and high-end x86 workstations.

### Runtime Heatmap
The following heatmap illustrates runtime performance (in minutes) across 16 different hardware configurations. Green indicates faster runtimes; red indicates slower runtimes. Note the "thermal throttling" shift occurs much earlier on x86 chips compared to Apple Silicon.

![Runtime Heatmap](images/runtime_heatmap.png)
*(Figure 2 from the associated Technology Spotlight article)*

### Runtime Statistics
Detailed statistical breakdown of runtime performance for all tested configurations.

![Runtime Statistics](images/runtime_statistics.png)
*(Table 1 from the associated Technology Spotlight article)*

### Summary
* **Thermal Stability:** ARM-based chips maintained nearly flat runtime slopes under load, whereas x86 chips often exhibited steep linear degradation due to thermal throttling.
* **Cost Efficiency:** A consumer-grade **M4 Mac Mini** (~$600) achieved parity with a 64-core **AMD Threadripper 3990X** (~$4,000+) in parallel throughput tests (avg runtimes: 8.94 min vs 8.93 min).

## Contributing
We encourage the community to contribute their own results to expand this industry database. Please submit your benchmark results via a **Pull Request** containing your updated `ByscayneMode_Benchmarks.xlsx`.

## References
* Apple Inc. (2020). Apple unleashes M1. Apple Newsroom. [https://www.apple.com/newsroom/2020/11/apple-unleashes-m1/](https://www.apple.com/newsroom/2020/11/apple-unleashes-m1/) (last accessed on Dec 18th 2025).
* Doherty, J., 2024, PEST_HP Pest for Highly Parallelized Computing Environments. Watermark Numerical Computing, March 2024. PEST_HP version 18. [https://pesthomepage.org](https://pesthomepage.org) (last accessed on Dec 18th 2025).
* Panday, Sorab, Langevin, C.D., Niswonger, R.G., Ibaraki, Motomu, and Hughes, J.D., 2013, MODFLOW-USG version 1: An unstructured grid version of MODFLOW for simulating groundwater flow and tightly coupled processes using a control volume finite-difference formulation: U.S. Geological Survey Techniques and Methods, book 6, chap. A45, 66 p., [https://doi.org/10.3133/tm6A45](https://doi.org/10.3133/tm6A45)
* Panday, S. (2025). USG-Transport 2.6.0: Transport and other enhancements to MODFLOW-USG. [https://www.gsienv.com/software/modflow-usg/modflow-usg/](https://www.gsienv.com/software/modflow-usg/modflow-usg/) (last accessed on Dec 18th 2025).
* USGS (2025a). pymake. Python package for building MODFLOW-based programs from source files. [https://github.com/modflowpy/pymake](https://github.com/modflowpy/pymake) (last accessed on Dec 18th 2025).
* USGS (2025b). MODFLOW executables GitHub Repo. [https://github.com/MODFLOW-ORG/executables](https://github.com/MODFLOW-ORG/executables) (last accessed on Dec 18th 2025).
* White, J.T., Hunt, R.J., Fienen, M.N., and Doherty, J.E., 2020, Approaches to Highly Parameterized Inversion: PEST++ Version 5, a Software Suite for Parameter Estimation, Uncertainty Analysis, Management Optimization and Sensitivity Analysis: U.S. Geological Survey Techniques and Methods 7C26, 52 p., [https://doi.org/10.3133/tm7C26](https://doi.org/10.3133/tm7C26) (last accessed on Dec 18th 2025).

