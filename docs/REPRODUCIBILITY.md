# Reproducibility Documentation

This document provides complete information for reproducing the benchmark results.

---

## 1. Software Versions and Dependencies

### Operating System
- **OS:** Ubuntu 24.04 LTS (Noble Numbat)
- **Kernel:** Linux 6.8.0-49-generic
- **Architecture:** x86_64

### Core Tools
- **GCC:** 13.3.0
- **Clang:** 18.1.3
- **CMake:** 3.28.3
- **Make:** 4.3
- **Python:** 3.12.3

### QEMU Emulation
- **QEMU Version:** 8.2.2+ (user-mode emulation)
- **QEMU ARM64:** qemu-aarch64-static (user-mode)
- **QEMU RISC-V64:** qemu-riscv64-static (user-mode)

### Cryptographic Libraries
- **liboqs:** 0.15.0 (NIST PQC Final Standards - FIPS 203/204)
- **OpenSSL:** 3.0.13

### Python Packages
```
numpy==1.26.4
pandas==2.2.2
matplotlib==3.9.2
seaborn==0.13.2
scipy==1.14.1
statsmodels==0.14.4
hypothesis==6.148.2
pytest==9.0.1
pytest-cov==7.0.0
```

See `requirements.txt` for complete list.

### Cross-Compilation Toolchains
- **ARM64:** gcc-aarch64-linux-gnu 13.3.0
- **RISC-V64:** gcc-riscv64-linux-gnu 13.3.0

---

## 2. Compilation and Build Configuration

### Compiler Flags

**Optimization Level:**
```bash
-O3                    # Maximum optimization
-march=native          # Native architecture (x86_64 only)
-mtune=native          # Tune for native CPU (x86_64 only)
```

**Warning Flags:**
```bash
-Wall                  # All warnings
-Wextra                # Extra warnings
-Werror                # Treat warnings as errors
```

**Security Flags:**
```bash
-fstack-protector-strong    # Stack protection
-D_FORTIFY_SOURCE=2         # Buffer overflow detection
-fPIC                       # Position independent code
```

### Build Commands

**Complete Setup (Recommended):**
```bash
make setup-complete
```

This command will:
1. Build liboqs for native x86_64
2. Compile all benchmark programs
3. Run unit tests to verify correctness

**Manual Build Steps:**

**x86_64 Native Build:**
```bash
make build-native
```

**ARM64 Cross-Compilation:**
```bash
make build-arm
```

**RISC-V64 Cross-Compilation:**
```bash
make build-riscv
```

**Compile Benchmarks:**
```bash
make compile-benchmarks
```

### Build Dependencies

**Ubuntu/Debian:**
```bash
sudo apt-get update
sudo apt-get install -y \
    build-essential \
    cmake \
    gcc-aarch64-linux-gnu \
    gcc-riscv64-linux-gnu \
    qemu-user-static \
    libssl-dev \
    python3-dev \
    python3-pip \
    git
```

**Python Dependencies:**
```bash
python3 -m pip install -r requirements.txt
```

---

## 3. QEMU Emulation Parameters

### ARM64 Emulation

**CPU Model:** Cortex-A72
```bash
qemu-aarch64-static \
    -cpu cortex-a72 \
    -L /usr/aarch64-linux-gnu \
    ./build/bin/benchmark_mlkem_arm64
```

**CPU Features:**
- ARMv8-A architecture
- NEON SIMD support
- AES crypto extensions
- 64-bit addressing

**Memory Configuration:**
- Virtual memory: Unlimited
- Stack size: 8 MB (default)

### RISC-V64 Emulation

**CPU Model:** RV64GC (General + Compressed)
```bash
qemu-riscv64-static \
    -cpu rv64 \
    -L /usr/riscv64-linux-gnu \
    ./build/bin/benchmark_mlkem_riscv64
```

**CPU Features:**
- RV64I: Base integer instruction set
- RV64M: Integer multiplication/division
- RV64A: Atomic instructions
- RV64F: Single-precision floating-point
- RV64D: Double-precision floating-point
- RV64C: Compressed instructions

**Memory Configuration:**
- Virtual memory: Unlimited
- Stack size: 8 MB (default)

### Emulation Rationale

**Why QEMU:**
1. **Accessibility:** Native ARM64/RISC-V64 hardware not readily available
2. **Reproducibility:** Consistent environment across researchers
3. **Cost-Effectiveness:** No hardware purchase required
4. **Validation:** Overhead quantified at 6.5% (acceptable for comparative analysis)

**Emulation Limitations:**
- Simplified CPU models (no full microarchitecture simulation)
- Approximate timing (not cycle-accurate)
- Limited cache simulation
- No hardware prefetching

**Mitigation:**
- Overhead measured and reported
- Comparative analysis remains valid
- Results conservative (emulation typically slower)

---

## 4. Benchmark Execution

### Native x86_64 Benchmarks

**Run all benchmarks:**
```bash
make run-benchmarks
```

This will execute:
- ML-KEM benchmarks (512, 768, 1024)
- ML-DSA benchmarks (44, 65, 87)

Results are saved to:
- `results/mlkem*_results.json`
- `results/mlkem*_results.csv`
- `results/mldsa*_results.json`
- `results/mldsa*_results.csv`

### QEMU Benchmarks (ARM64 + RISC-V64)

**Prerequisites:**
```bash
# Build cross-compiled binaries
make build-arm build-riscv
./scripts/compile_cross_benchmarks.sh
```

**Run QEMU benchmarks:**
```bash
./scripts/run_all_qemu_benchmarks.sh
```

### Individual Benchmark Execution

**ML-KEM only:**
```bash
make benchmark-mlkem
```

**ML-DSA only:**
```bash
make benchmark-mldsa
```

---

## 5. Data Analysis

### Data Integrity Verification

```bash
python3 verify_checksums.py
```

### Statistical Analysis

**Install dependencies:**
```bash
make install-analysis-deps
```

**Run statistical analysis:**
```bash
python3 src/analysis/statistical_analysis.py \
    --data-file data/processed/processed_data.json \
    --output-dir results/analysis
```

### Visualization Generation

```bash
python3 src/analysis/generate_figures.py \
    --data-file data/processed/processed_data.json \
    --output-dir results/figures
```

**Note:** Full analysis pipeline requires complete experimental data from all architectures (x86_64, ARM64, RISC-V64).

---

## 6. Environment Setup

### Quick Setup

```bash
# Clone repository
git clone https://github.com/pocotu/Benchmarks-PQC.git
cd Benchmarks-PQC

# Check environment
make check-env

# Complete setup (build + compile + test)
make setup-complete

# Run benchmarks
make run-benchmarks
```

### Complete Setup Script

```bash
#!/bin/bash
# setup_environment.sh

# Install system dependencies
sudo apt-get update
sudo apt-get install -y \
    build-essential cmake \
    gcc-aarch64-linux-gnu gcc-riscv64-linux-gnu \
    qemu-user-static libssl-dev \
    python3-dev python3-pip git

# Clone repository
git clone https://github.com/pocotu/Benchmarks-PQC.git
cd Benchmarks-PQC

# Install Python dependencies
make install-analysis-deps

# Build and test
make setup-complete

# Run native benchmarks
make run-benchmarks

# Verify data integrity
python3 verify_checksums.py

echo "Setup complete! Results in results/ directory"
```

---

## 7. Verification

### Verify Build

```bash
# Check liboqs libraries
ls -lh build/liboqs/build-native/lib/liboqs.so*

# Check benchmark binaries
ls -lh build/bin/benchmark_*

# Verify binary architecture
file build/bin/benchmark_mlkem
# Expected: ELF 64-bit LSB executable, x86-64
```

### Verify Execution

```bash
# Run native benchmarks
make run-benchmarks

# Check results
ls -lh results/*.json results/*.csv
```

### Verify Data Integrity

```bash
# Verify checksums
python3 verify_checksums.py

# Expected output:
# Verifying 6 files...
# ✓ analysis/analysis_summary.json
# ✓ analysis/hypothesis_tests.csv
# ...
# Results: 6/6 verified
# ✓ All files verified successfully!
```

---

## 8. Expected Outputs

### Benchmark Results (Native x86_64)
- `results/mlkem512_mlkem_results.json` - ML-KEM-512 benchmark data
- `results/mlkem768_mlkem_results.json` - ML-KEM-768 benchmark data
- `results/mlkem1024_mlkem_results.json` - ML-KEM-1024 benchmark data
- `results/mldsa44_mldsa_results.json` - ML-DSA-44 benchmark data
- `results/mldsa65_mldsa_results.json` - ML-DSA-65 benchmark data
- `results/mldsa87_mldsa_results.json` - ML-DSA-87 benchmark data
- Corresponding CSV files for each algorithm

### Analysis Results (with complete data)
- `results/analysis/analysis_summary.json` - Statistical summaries
- `results/analysis/hypothesis_tests.csv` - Statistical test results
- `results/analysis/performance_ratios.csv` - Architecture comparisons
- `results/analysis/summary_table.csv` - Summary statistics

### Performance Metrics
Each benchmark file contains:
- Mean execution time (microseconds)
- Standard deviation
- Minimum/Maximum values
- Sample count
- Algorithm parameters (key sizes, signature sizes, etc.)

---

## 9. Troubleshooting

### Common Issues

**Issue:** QEMU not found
```bash
# Solution: Install QEMU
sudo apt-get install qemu-user-static
```

**Issue:** Cross-compiler not found
```bash
# Solution: Install cross-compilation toolchains
sudo apt-get install gcc-aarch64-linux-gnu gcc-riscv64-linux-gnu
```

**Issue:** Python module not found
```bash
# Solution: Install Python dependencies
pip install -r requirements.txt
```

**Issue:** Permission denied
```bash
# Solution: Make scripts executable
chmod +x pqc-bench.sh scripts/*.py
```

---

## 10. Contact and Support

**Repository:** https://github.com/pocotu/Benchmarks-PQC  
**Issues:** https://github.com/pocotu/Benchmarks-PQC/issues

---
