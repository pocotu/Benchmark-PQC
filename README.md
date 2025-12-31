# Benchmarks PQC: ML-KEM and ML-DSA Performance Analysis

[![liboqs](https://img.shields.io/badge/liboqs-0.15.0-blue.svg)](https://github.com/open-quantum-safe/liboqs)
[![FIPS 203](https://img.shields.io/badge/FIPS%20203-ML--KEM-purple.svg)](https://csrc.nist.gov/pubs/fips/203/final)
[![FIPS 204](https://img.shields.io/badge/FIPS%20204-ML--DSA-purple.svg)](https://csrc.nist.gov/pubs/fips/204/final)

Comparative performance analysis of NIST post-quantum cryptography standards (ML-KEM and ML-DSA) across ARM64 and RISC-V64 architectures under QEMU emulation, with application to academic PKI design.

## Key Findings

| Metric | ML-KEM | ML-DSA |
|--------|--------|--------|
| ARM64 vs RISC-V64 | -2.1% (equivalent) | +9.1% (ARM64 faster) |
| QEMU Overhead | 12.6x | 31.9x |
| Statistical Significance | 18/18 tests (p < 0.05) | |

## Quick Start

### Prerequisites

```bash
# Ubuntu/Debian
sudo apt update
sudo apt install build-essential cmake git python3 python3-pip \
    qemu-user-static gcc-aarch64-linux-gnu gcc-riscv64-linux-gnu
```

### Installation

```bash
git clone https://github.com/pocotu/Benchmarks-PQC.git
cd Benchmarks-PQC

# Build liboqs and benchmarks
make setup-complete
```

### Running Benchmarks

```bash
# Native x86_64 benchmarks
make run-benchmarks

# QEMU benchmarks (ARM64 + RISC-V64) - requires cross-compilation first
make build-arm build-riscv
./scripts/compile_cross_benchmarks.sh
./scripts/run_all_qemu_benchmarks.sh

# Verify data integrity
python3 verify_checksums.py
```

## Repository Structure

```
Benchmarks-PQC/
├── src/
│   ├── benchmarks/      # C benchmark implementations for ML-KEM/ML-DSA
│   ├── core/            # Benchmark engine and interfaces
│   ├── utils/           # Timing, statistics, logging utilities
│   ├── adapters/        # liboqs adapter layer
│   └── analysis/        # Python statistical analysis scripts
├── scripts/             # Automation and orchestration scripts
├── build/               # liboqs compilation scripts
├── data/
│   ├── raw/             # Experimental data (ARM64, RISC-V64, x86_64)
│   └── processed/       # Consolidated datasets
├── results/
│   ├── analysis/        # Statistical summaries and models
│   └── figures/         # Publication-ready figures (PDF/PNG)
├── docs/                # Reproducibility documentation
└── setup/               # Environment setup scripts
```

## Experimental Dataset

The repository includes complete experimental data:

- 18 JSON/CSV files with benchmark measurements
- Approximately 160,000 valid measurements
- 3 architectures: x86_64, ARM64, RISC-V64
- 6 algorithm variants: ML-KEM-512/768/1024, ML-DSA-44/65/87

### Data Integrity Verification

```bash
python3 verify_checksums.py
```

### Analysis Tools

The repository includes Python scripts for statistical analysis and visualization:

```bash
# Install analysis dependencies
make install-analysis-deps

# Generate statistical analysis (requires experimental data)
python3 src/analysis/statistical_analysis.py --help

# Generate figures and visualizations
python3 src/analysis/generate_figures.py --help
```

Note: Full analysis pipeline requires complete experimental data from all architectures.

## Technology Stack

| Component | Version | Purpose |
|-----------|---------|---------|
| liboqs | 0.15.0 | ML-KEM/ML-DSA implementations |
| QEMU | 8.2.2+ | ARM64/RISC-V64 emulation |
| GCC | 13.3.0 | Native and cross-compilation |
| Python | 3.10+ | Statistical analysis |

## Reproducibility

1. **Fixed versions**: liboqs 0.15.0, QEMU 8.2.2, GCC 13.3.0
2. **Automated pipeline**: Complete workflow from compilation to analysis
3. **Checksums**: SHA-256 verification for all data files
4. **Documentation**: See `docs/REPRODUCIBILITY.md` for detailed instructions

## License

This project is released under an open source license. See [LICENSE](LICENSE) for details.

## References

- [NIST FIPS 203](https://csrc.nist.gov/pubs/fips/203/final) - Module-Lattice-Based Key-Encapsulation Mechanism Standard
- [NIST FIPS 204](https://csrc.nist.gov/pubs/fips/204/final) - Module-Lattice-Based Digital Signature Standard
- [liboqs](https://github.com/open-quantum-safe/liboqs) - Open Quantum Safe Project
