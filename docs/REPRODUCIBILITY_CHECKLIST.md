# Reproducibility Checklist

Use this checklist to verify that you have everything needed to reproduce the benchmark results.

---

## Prerequisites

### Hardware Requirements
- [ ] x86_64 processor (Intel or AMD, 4+ cores recommended)
- [ ] 8 GB RAM minimum (16 GB recommended)
- [ ] 20 GB free disk space
- [ ] Internet connection for downloading dependencies

### Software Requirements (see REPRODUCIBILITY.md §1)
- [ ] Ubuntu 24.04 LTS (Noble Numbat)
- [ ] GCC 13.3+ installed
- [ ] Python 3.12+ installed
- [ ] Git installed
- [ ] sudo/root access for installing packages

---

## Environment Setup

### System Dependencies (see REPRODUCIBILITY.md §2)
- [ ] All required packages installed (build-essential, cmake, cross-compilers, QEMU, etc.)

**Verification Command:**
```bash
make check-env
```

**Expected:** All checks pass with `[OK]` status

### Python Environment (see REPRODUCIBILITY.md §6)
- [ ] Python dependencies installed

**Verification Command:**
```bash
make install-analysis-deps
python3 -c "import numpy, scipy, matplotlib; print('✓ All dependencies OK')"
```

**Expected:** `✓ All dependencies OK`

---

## Source Code

### Repository
- [ ] Repository cloned from GitHub
- [ ] Correct branch checked out (main/master)
- [ ] Git commit hash recorded

**Verification Command:**
```bash
git log -1 --oneline
git status
```

**Expected:** Clean working directory, commit hash visible

### liboqs Library (see REPRODUCIBILITY.md §2)
- [ ] liboqs version 0.15.0 built for all architectures

**Verification Command:**
```bash
ls -lh build/liboqs/build-*/lib/liboqs.so* 2>/dev/null | wc -l
```

**Expected:** 3 or more files (one per architecture)

---

## Build Process

### Compilation (see REPRODUCIBILITY.md §2 for build commands)
- [ ] x86_64 benchmarks compiled successfully
- [ ] No compilation errors or warnings

**Verification Command:**
```bash
make setup-complete
```

**Expected:** Build completes with `[OK]` status and tests pass

### Cross-Compilation (Optional - for QEMU benchmarks)
- [ ] ARM64 benchmarks cross-compiled
- [ ] RISC-V64 benchmarks cross-compiled

**Verification Command:**
```bash
make build-arm build-riscv
./scripts/compile_cross_benchmarks.sh
```

**Expected:** Cross-compilation completes successfully

### Build Configuration (see REPRODUCIBILITY.md §2)
- [ ] Optimization level: -O3 verified
- [ ] liboqs built successfully

**Verification Command:**
```bash
ls -lh build/liboqs/build-native/lib/liboqs.so*
```

**Expected:** liboqs library files present

---

## Benchmark Execution

### Native Benchmarks (see REPRODUCIBILITY.md §4)
- [ ] x86_64 benchmarks executed successfully
- [ ] Results saved to `results/` directory

**Verification Command:**
```bash
make run-benchmarks
```

**Expected:** Benchmarks complete with timing results displayed

### QEMU Benchmarks (Optional - see REPRODUCIBILITY.md §4)
- [ ] ARM64 benchmarks executed (with QEMU)
- [ ] RISC-V64 benchmarks executed (with QEMU)

**Verification Command:**
```bash
./scripts/run_all_qemu_benchmarks.sh
```

**Expected:** QEMU benchmarks complete (requires cross-compilation first)

### Results Verification
- [ ] All benchmark result files present
- [ ] JSON and CSV formats generated

**Verification Command:**
```bash
ls -lh results/*.json results/*.csv
```

**Expected:** 12+ files (6 algorithms × 2 formats)

---

## Data Validation

### Data Integrity
- [ ] Checksums verified
- [ ] No corrupted files

**Verification Command:**
```bash
python3 verify_checksums.py
```

**Expected:** `✓ All files verified successfully!`

### Data Completeness (Optional - for full analysis)
- [ ] Complete experimental data from all architectures
- [ ] Analysis results present

**Verification Command:**
```bash
ls -lh results/analysis/*.json results/analysis/*.csv 2>/dev/null | wc -l
```

**Expected:** 6+ analysis files (if full analysis has been run)

---

## Analysis

### Statistical Analysis (Optional - see REPRODUCIBILITY.md §5)
- [ ] Python analysis dependencies installed
- [ ] Statistical analysis scripts available

**Verification Command:**
```bash
make install-analysis-deps
ls -lh src/analysis/*.py
```

**Expected:** Analysis scripts present (statistical_analysis.py, generate_figures.py)

### Expected Analysis Outputs (with complete data)
- [ ] Statistical summaries generated
- [ ] Performance comparisons calculated

**Note:** Full analysis requires complete experimental data from all architectures (x86_64, ARM64, RISC-V64)

---

## Visualization

### Figure Generation (Optional - see REPRODUCIBILITY.md §5)
- [ ] Visualization scripts available

**Verification Command:**
```bash
ls -lh src/analysis/generate_figures.py
```

**Expected:** Script present

**Note:** Figure generation requires complete experimental data from all architectures

---

## Documentation

### Core Documentation
- [ ] `README.md` present and up-to-date
- [ ] `REPRODUCIBILITY.md` complete
- [ ] `CHECKSUMS.json` present
- [ ] `requirements.txt` present

**Verification Command:**
```bash
ls -1 README.md docs/REPRODUCIBILITY.md CHECKSUMS.json requirements.txt 2>/dev/null | wc -l
```

**Expected:** 4 files present

---

## Testing

### Unit Tests (Optional - see REPRODUCIBILITY.md §7)
- [ ] Core functionality tests available

**Note:** Unit tests are run automatically during `make setup-complete`

**Manual Test Execution:**
```bash
make test-all
```

**Expected:** Tests pass (if test files are present)

---

## Version Control

### Git Status
- [ ] All changes committed
- [ ] Commit hash recorded for reproducibility

**Verification Command:**
```bash
git log -1 --format="%H %s" > COMMIT_HASH.txt
cat COMMIT_HASH.txt
```

**Expected:** Commit hash saved to file

---

## Final Verification

### Results Validation (see REPRODUCIBILITY.md §8)
- [ ] Benchmark results generated
- [ ] Data integrity verified
- [ ] No errors during execution

**Verification Command:**
```bash
python3 verify_checksums.py
ls -lh results/*.json
```

**Expected:** Checksums pass, result files present

### Reproducibility Test
- [ ] Clean environment setup successful
- [ ] Benchmarks run without errors
- [ ] Results consistent with expected format

**Full Pipeline Test:**
```bash
make clean
make setup-complete
make run-benchmarks
python3 verify_checksums.py
```

**Expected:** Complete pipeline executes successfully

---

## Expected Outputs Summary

### Benchmark Results (see REPRODUCIBILITY.md §8)
```
results/           - Benchmark JSON and CSV files
results/analysis/  - Statistical analysis results (with complete data)
```

**Quick Check:**
```bash
echo "Benchmark files: $(ls results/*.json 2>/dev/null | wc -l)"
echo "Analysis files: $(ls results/analysis/*.json 2>/dev/null | wc -l)"
```

---

## Troubleshooting

### Common Issues (see REPRODUCIBILITY.md §9 for detailed solutions)

**Issue:** Compilation fails
- [ ] Verify GCC version: `gcc --version` (≥ 13.3)
- [ ] Check cross-compilers: `dpkg -l | grep gcc-aarch64`
- [ ] Review build logs: `cat build/logs/build-*.log`

**Issue:** QEMU execution fails
- [ ] Verify QEMU installed: `qemu-aarch64-static --version`
- [ ] Check cross-compilation: `make build-arm build-riscv`
- [ ] Run compile script: `./scripts/compile_cross_benchmarks.sh`

**Issue:** Python import errors
- [ ] Install dependencies: `make install-analysis-deps`
- [ ] Check Python version: `python3 --version` (≥ 3.10)
- [ ] Reinstall if needed: `pip3 install --user numpy scipy matplotlib`

**Issue:** Missing data files
- [ ] Check disk space: `df -h`
- [ ] Verify permissions: `ls -ld results/`
- [ ] Re-run benchmarks: `make run-benchmarks`

---

## Completion Criteria

### Minimum Requirements for Reproducibility
- [ ] Native x86_64 benchmarks completed
- [ ] Benchmark result files generated (JSON + CSV)
- [ ] Data integrity verified (checksums pass)
- [ ] Documentation complete

### Full Reproduction Success (Optional)
- [ ] Cross-architecture benchmarks completed (ARM64, RISC-V64)
- [ ] Statistical analysis completed
- [ ] All validation checks passed
- [ ] Commit hash recorded

---

## Sign-Off

**Reproduced By:** ___________________________  
**Date:** ___________________________  
**Commit Hash:** ___________________________  
**Environment:** Ubuntu _____ / GCC _____ / Python _____  
**Notes:** ___________________________

---

