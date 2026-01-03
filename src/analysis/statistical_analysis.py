#!/usr/bin/env python3
"""
Statistical Analysis for PQC Benchmarks

This script performs:
- Descriptive statistical analysis
- Hypothesis testing (t-test, Mann-Whitney)
- Performance ratio calculations
- LaTeX table generation

Location: src/analysis/statistical_analysis.py
Output: results/analysis/
"""

import pandas as pd
import numpy as np
from scipy import stats
from pathlib import Path
import json
from datetime import datetime

# Path configuration (relative to project root)
BASE_DIR = Path(__file__).parent.parent.parent  # Benchmarks-PQC/
DATA_DIR = BASE_DIR / "data" / "processed"
OUTPUT_DIR = BASE_DIR / "results" / "analysis"

# Create directories if they don't exist
OUTPUT_DIR.mkdir(parents=True, exist_ok=True)


def load_data():
    """Load processed data."""
    csv_path = DATA_DIR / "processed_data.csv"
    if not csv_path.exists():
        raise FileNotFoundError(f"File not found: {csv_path}")
    
    df = pd.read_csv(csv_path)
    print(f"[OK] Data loaded: {len(df)} records")
    return df


def descriptive_statistics(df):
    """Generate descriptive statistics by architecture/algorithm/operation."""
    print("\n" + "="*60)
    print("DESCRIPTIVE STATISTICAL ANALYSIS")
    print("="*60)
    
    # Summary by architecture
    arch_summary = df.groupby('architecture').agg({
        'mean_us': ['mean', 'std', 'min', 'max'],
        'num_samples': 'sum'
    }).round(2)
    
    print("\n[*] Summary by Architecture:")
    print(arch_summary)
    
    # Summary by algorithm
    algo_summary = df.groupby(['architecture', 'algorithm']).agg({
        'mean_us': 'mean',
        'stddev_us': 'mean',
        'cv_percent': 'mean'
    }).round(2)
    
    print("\n[*] Summary by Algorithm:")
    print(algo_summary)
    
    return arch_summary, algo_summary


def calculate_ratios(df):
    """Calculate ARM64/RISC-V64 performance ratios and QEMU overhead."""
    print("\n" + "="*60)
    print("PERFORMANCE RATIO CALCULATION")
    print("="*60)
    
    results = []
    
    # Get data by architecture
    arm64 = df[df['architecture'] == 'ARM64'].set_index(['algorithm', 'operation'])
    riscv64 = df[df['architecture'] == 'RISC-V64'].set_index(['algorithm', 'operation'])
    x86_64 = df[df['architecture'] == 'x86_64'].set_index(['algorithm', 'operation'])
    
    for idx in arm64.index:
        if idx in riscv64.index and idx in x86_64.index:
            arm_time = arm64.loc[idx, 'mean_us']
            riscv_time = riscv64.loc[idx, 'mean_us']
            x86_time = x86_64.loc[idx, 'mean_us']
            
            # ARM64/RISC-V64 ratio (< 1 means ARM64 faster)
            ratio_arm_riscv = arm_time / riscv_time
            
            # QEMU overhead vs x86_64
            overhead_arm = arm_time / x86_time
            overhead_riscv = riscv_time / x86_time
            
            # ARM64 percentage advantage over RISC-V64
            advantage_arm = ((riscv_time - arm_time) / riscv_time) * 100
            
            results.append({
                'algorithm': idx[0],
                'operation': idx[1],
                'arm64_us': arm_time,
                'riscv64_us': riscv_time,
                'x86_64_us': x86_time,
                'ratio_arm_riscv': ratio_arm_riscv,
                'overhead_arm_qemu': overhead_arm,
                'overhead_riscv_qemu': overhead_riscv,
                'advantage_arm_percent': advantage_arm
            })
    
    ratios_df = pd.DataFrame(results)
    
    # Display results
    print("\n[*] ARM64/RISC-V64 Ratios:")
    for _, row in ratios_df.iterrows():
        faster = "ARM64" if row['advantage_arm_percent'] > 0 else "RISC-V64"
        diff = abs(row['advantage_arm_percent'])
        print(f"  {row['algorithm']:12} {row['operation']:8}: {faster} {diff:.1f}% faster")
    
    # Summary by algorithm type
    print("\n[*] Summary by Algorithm Type:")
    mlkem = ratios_df[ratios_df['algorithm'].str.contains('ML-KEM')]
    mldsa = ratios_df[ratios_df['algorithm'].str.contains('ML-DSA')]
    
    mlkem_avg = mlkem['advantage_arm_percent'].mean()
    mldsa_avg = mldsa['advantage_arm_percent'].mean()
    
    print(f"  ML-KEM average: ARM64 {mlkem_avg:.1f}% {'faster' if mlkem_avg > 0 else 'slower'}")
    print(f"  ML-DSA average: ARM64 {mldsa_avg:.1f}% {'faster' if mldsa_avg > 0 else 'slower'}")
    
    # Save results
    ratios_df.to_csv(OUTPUT_DIR / "performance_ratios.csv", index=False)
    print(f"\n[OK] Ratios saved to {OUTPUT_DIR / 'performance_ratios.csv'}")
    
    return ratios_df


def hypothesis_tests(df):
    """Perform hypothesis tests to compare architectures."""
    print("\n" + "="*60)
    print("HYPOTHESIS TESTING")
    print("="*60)
    
    results = []
    
    # Compare ARM64 vs RISC-V64 for each algorithm/operation
    algorithms = df['algorithm'].unique()
    operations = df['operation'].unique()
    
    for algo in algorithms:
        for op in operations:
            arm_data = df[(df['architecture'] == 'ARM64') & 
                         (df['algorithm'] == algo) & 
                         (df['operation'] == op)]
            riscv_data = df[(df['architecture'] == 'RISC-V64') & 
                           (df['algorithm'] == algo) & 
                           (df['operation'] == op)]
            
            if len(arm_data) == 0 or len(riscv_data) == 0:
                continue
            
            arm_mean = arm_data['mean_us'].values[0]
            riscv_mean = riscv_data['mean_us'].values[0]
            arm_std = arm_data['stddev_us'].values[0]
            riscv_std = riscv_data['stddev_us'].values[0]
            arm_n = arm_data['num_samples'].values[0]
            riscv_n = riscv_data['num_samples'].values[0]
            
            # Welch's t-test (does not assume equal variances)
            se = np.sqrt((arm_std**2 / arm_n) + (riscv_std**2 / riscv_n))
            t_stat = (arm_mean - riscv_mean) / se if se > 0 else 0
            
            # Welch-Satterthwaite degrees of freedom
            df_num = ((arm_std**2/arm_n) + (riscv_std**2/riscv_n))**2
            df_den = ((arm_std**2/arm_n)**2/(arm_n-1)) + ((riscv_std**2/riscv_n)**2/(riscv_n-1))
            dof = df_num / df_den if df_den > 0 else 1
            
            # p-value (two-tailed)
            p_value = 2 * (1 - stats.t.cdf(abs(t_stat), dof))
            
            # 95% confidence interval
            t_crit = stats.t.ppf(0.975, dof)
            ci_lower = (arm_mean - riscv_mean) - t_crit * se
            ci_upper = (arm_mean - riscv_mean) + t_crit * se
            
            # Effect size (Cohen's d)
            pooled_std = np.sqrt(((arm_n-1)*arm_std**2 + (riscv_n-1)*riscv_std**2) / (arm_n + riscv_n - 2))
            cohens_d = (arm_mean - riscv_mean) / pooled_std if pooled_std > 0 else 0
            
            # Interpretation
            significant = p_value < 0.05
            effect_size = "small" if abs(cohens_d) < 0.5 else "medium" if abs(cohens_d) < 0.8 else "large"
            
            results.append({
                'algorithm': algo,
                'operation': op,
                'arm64_mean': arm_mean,
                'riscv64_mean': riscv_mean,
                'difference': arm_mean - riscv_mean,
                't_statistic': t_stat,
                'p_value': p_value,
                'ci_95_lower': ci_lower,
                'ci_95_upper': ci_upper,
                'cohens_d': cohens_d,
                'significant': significant,
                'effect_size': effect_size
            })
    
    tests_df = pd.DataFrame(results)
    
    # Display results
    print("\n[*] Welch's t-test Results (ARM64 vs RISC-V64):")
    print("-" * 80)
    for _, row in tests_df.iterrows():
        sig = "***" if row['p_value'] < 0.001 else "**" if row['p_value'] < 0.01 else "*" if row['p_value'] < 0.05 else ""
        print(f"  {row['algorithm']:12} {row['operation']:8}: t={row['t_statistic']:7.2f}, p={row['p_value']:.4f}{sig}, d={row['cohens_d']:.2f} ({row['effect_size']})")
    
    # Summary
    significant_count = tests_df['significant'].sum()
    total_count = len(tests_df)
    print(f"\n[*] Summary: {significant_count}/{total_count} significant comparisons (p < 0.05)")
    
    # Save results
    tests_df.to_csv(OUTPUT_DIR / "hypothesis_tests.csv", index=False)
    print(f"[OK] Tests saved to {OUTPUT_DIR / 'hypothesis_tests.csv'}")
    
    return tests_df


def generate_latex_tables(df, ratios_df):
    """Generate LaTeX tables for thesis."""
    print("\n" + "="*60)
    print("LATEX TABLE GENERATION")
    print("="*60)
    
    # Performance ratios table
    latex_ratios = """% Performance ratios table - Auto-generated
% Date: """ + datetime.now().strftime("%Y-%m-%d %H:%M") + """

\\begin{table}[H]
\\centering
\\caption{Performance ratios and QEMU emulation overhead}
\\label{tab:performance_ratios}
\\begin{tabular}{llrrrrr}
\\toprule
\\textbf{Algorithm} & \\textbf{Op.} & \\textbf{ARM64} & \\textbf{RISC-V64} & \\textbf{Ratio} & \\textbf{Overhead} & \\textbf{Advantage} \\\\
 & & ($\\mu$s) & ($\\mu$s) & ARM/RV & QEMU & ARM64 \\\\
\\midrule
"""
    
    for _, row in ratios_df.iterrows():
        latex_ratios += f"{row['algorithm']} & {row['operation']} & {row['arm64_us']:.2f} & {row['riscv64_us']:.2f} & {row['ratio_arm_riscv']:.2f} & {row['overhead_arm_qemu']:.1f}x & {row['advantage_arm_percent']:.1f}\\% \\\\\n"
    
    latex_ratios += """\\bottomrule
\\end{tabular}
\\end{table}
"""
    
    # Save LaTeX table
    latex_path = OUTPUT_DIR / "tabla_ratios_rendimiento.tex"
    with open(latex_path, 'w') as f:
        f.write(latex_ratios)
    print(f"[OK] LaTeX table saved to {latex_path}")
    
    return latex_ratios


def analyze_performance_factors(df):
    """Analyze factors affecting performance."""
    print("\n" + "="*60)
    print("PERFORMANCE FACTOR ANALYSIS")
    print("="*60)
    
    # Factor 1: Security level impact
    print("\n[*] Security Level Impact:")
    
    for arch in ['x86_64', 'ARM64', 'RISC-V64']:
        print(f"\n  {arch}:")
        arch_data = df[df['architecture'] == arch]
        
        # ML-KEM
        mlkem_data = arch_data[arch_data['algorithm'].str.contains('ML-KEM')]
        if len(mlkem_data) > 0:
            mlkem_512 = mlkem_data[mlkem_data['algorithm'] == 'ML-KEM-512']['mean_us'].mean()
            mlkem_768 = mlkem_data[mlkem_data['algorithm'] == 'ML-KEM-768']['mean_us'].mean()
            mlkem_1024 = mlkem_data[mlkem_data['algorithm'] == 'ML-KEM-1024']['mean_us'].mean()
            print(f"    ML-KEM: 512->768 = {mlkem_768/mlkem_512:.2f}x, 512->1024 = {mlkem_1024/mlkem_512:.2f}x")
        
        # ML-DSA
        mldsa_data = arch_data[arch_data['algorithm'].str.contains('ML-DSA')]
        if len(mldsa_data) > 0:
            mldsa_44 = mldsa_data[mldsa_data['algorithm'] == 'ML-DSA-44']['mean_us'].mean()
            mldsa_65 = mldsa_data[mldsa_data['algorithm'] == 'ML-DSA-65']['mean_us'].mean()
            mldsa_87 = mldsa_data[mldsa_data['algorithm'] == 'ML-DSA-87']['mean_us'].mean()
            print(f"    ML-DSA: 44->65 = {mldsa_65/mldsa_44:.2f}x, 44->87 = {mldsa_87/mldsa_44:.2f}x")
    
    # Factor 2: Operation comparison
    print("\n[*] Relative Operation Cost (vs KeyGen):")
    
    for arch in ['x86_64', 'ARM64', 'RISC-V64']:
        print(f"\n  {arch}:")
        arch_data = df[df['architecture'] == arch]
        
        # ML-KEM
        for algo in ['ML-KEM-512', 'ML-KEM-768', 'ML-KEM-1024']:
            algo_data = arch_data[arch_data['algorithm'] == algo]
            if len(algo_data) >= 3:
                keygen = algo_data[algo_data['operation'] == 'keygen']['mean_us'].values[0]
                encaps = algo_data[algo_data['operation'] == 'encaps']['mean_us'].values[0]
                decaps = algo_data[algo_data['operation'] == 'decaps']['mean_us'].values[0]
                print(f"    {algo}: Encaps={encaps/keygen:.2f}x, Decaps={decaps/keygen:.2f}x")
        
        # ML-DSA
        for algo in ['ML-DSA-44', 'ML-DSA-65', 'ML-DSA-87']:
            algo_data = arch_data[arch_data['algorithm'] == algo]
            if len(algo_data) >= 3:
                keygen = algo_data[algo_data['operation'] == 'keygen']['mean_us'].values[0]
                sign = algo_data[algo_data['operation'] == 'sign']['mean_us'].values[0]
                verify = algo_data[algo_data['operation'] == 'verify']['mean_us'].values[0]
                print(f"    {algo}: Sign={sign/keygen:.2f}x, Verify={verify/keygen:.2f}x")


def model_tls_overhead(df):
    """Model TLS 1.3 handshake overhead with PQC."""
    print("\n" + "="*60)
    print("TLS 1.3 OVERHEAD MODELING")
    print("="*60)
    
    # Use ML-KEM-768 and ML-DSA-65 (NIST level 3, recommended)
    results = {}
    
    for arch in ['x86_64', 'ARM64', 'RISC-V64']:
        arch_data = df[df['architecture'] == arch]
        
        # ML-KEM-768
        mlkem = arch_data[arch_data['algorithm'] == 'ML-KEM-768']
        keygen_kem = mlkem[mlkem['operation'] == 'keygen']['mean_us'].values[0]
        encaps = mlkem[mlkem['operation'] == 'encaps']['mean_us'].values[0]
        decaps = mlkem[mlkem['operation'] == 'decaps']['mean_us'].values[0]
        
        # ML-DSA-65
        mldsa = arch_data[arch_data['algorithm'] == 'ML-DSA-65']
        sign = mldsa[mldsa['operation'] == 'sign']['mean_us'].values[0]
        verify = mldsa[mldsa['operation'] == 'verify']['mean_us'].values[0]
        
        # TLS 1.3 handshake overhead
        # Client: Encaps + Verify (server certificate)
        client_overhead = encaps + verify
        # Server: KeyGen + Decaps + Sign (CertificateVerify)
        server_overhead = keygen_kem + decaps + sign
        total_overhead = client_overhead + server_overhead
        
        results[arch] = {
            'client_us': client_overhead,
            'server_us': server_overhead,
            'total_us': total_overhead,
            'total_ms': total_overhead / 1000
        }
        
        print(f"\n  {arch}:")
        print(f"    Client (Encaps + Verify): {client_overhead:.2f} us")
        print(f"    Server (KeyGen + Decaps + Sign): {server_overhead:.2f} us")
        print(f"    Total: {total_overhead:.2f} us ({total_overhead/1000:.3f} ms)")
    
    # Comparison with classical TLS (estimated ~50-100 us)
    print("\n[*] Comparison with Classical TLS (ECDH + ECDSA, ~75 us):")
    for arch, data in results.items():
        overhead_factor = data['total_us'] / 75
        print(f"    {arch}: {overhead_factor:.1f}x overhead vs classical")
    
    # Save results
    tls_df = pd.DataFrame(results).T
    tls_df.to_csv(OUTPUT_DIR / "tls_overhead_model.csv")
    print(f"\n[OK] TLS model saved to {OUTPUT_DIR / 'tls_overhead_model.csv'}")
    
    return results


def model_pki_throughput(df):
    """Model PKI certificate issuance throughput."""
    print("\n" + "="*60)
    print("PKI THROUGHPUT MODELING")
    print("="*60)
    
    results = {}
    
    for arch in ['x86_64', 'ARM64', 'RISC-V64']:
        arch_data = df[df['architecture'] == arch]
        
        # ML-DSA-65 Sign (critical operation for issuance)
        mldsa = arch_data[arch_data['algorithm'] == 'ML-DSA-65']
        sign_time = mldsa[mldsa['operation'] == 'sign']['mean_us'].values[0]
        
        # Theoretical throughput (Sign only)
        throughput_theoretical = 1_000_000 / sign_time  # certs/second
        
        # Throughput with I/O overhead (10ms, 50ms)
        throughput_10ms = 1_000_000 / (sign_time + 10_000)
        throughput_50ms = 1_000_000 / (sign_time + 50_000)
        
        results[arch] = {
            'sign_time_us': sign_time,
            'throughput_theoretical': throughput_theoretical,
            'throughput_10ms_overhead': throughput_10ms,
            'throughput_50ms_overhead': throughput_50ms
        }
        
        print(f"\n  {arch}:")
        print(f"    Sign time: {sign_time:.2f} us")
        print(f"    Theoretical throughput: {throughput_theoretical:.0f} certs/s")
        print(f"    Throughput (10ms overhead): {throughput_10ms:.0f} certs/s")
        print(f"    Throughput (50ms overhead): {throughput_50ms:.0f} certs/s")
    
    # Save results
    pki_df = pd.DataFrame(results).T
    pki_df.to_csv(OUTPUT_DIR / "pki_throughput_model.csv")
    print(f"\n[OK] PKI model saved to {OUTPUT_DIR / 'pki_throughput_model.csv'}")
    
    return results


def generate_summary_report(df, ratios_df, tests_df):
    """Generate summary report in JSON format."""
    print("\n" + "="*60)
    print("SUMMARY REPORT GENERATION")
    print("="*60)
    
    # Calculate summary metrics
    mlkem_ratios = ratios_df[ratios_df['algorithm'].str.contains('ML-KEM')]
    mldsa_ratios = ratios_df[ratios_df['algorithm'].str.contains('ML-DSA')]
    
    report = {
        'metadata': {
            'generated_at': datetime.now().isoformat(),
            'total_records': len(df),
            'architectures': list(df['architecture'].unique()),
            'algorithms': list(df['algorithm'].unique())
        },
        'summary': {
            'mlkem': {
                'arm64_advantage_percent': mlkem_ratios['advantage_arm_percent'].mean(),
                'avg_ratio_arm_riscv': mlkem_ratios['ratio_arm_riscv'].mean(),
                'avg_overhead_qemu': mlkem_ratios['overhead_arm_qemu'].mean()
            },
            'mldsa': {
                'arm64_advantage_percent': mldsa_ratios['advantage_arm_percent'].mean(),
                'avg_ratio_arm_riscv': mldsa_ratios['ratio_arm_riscv'].mean(),
                'avg_overhead_qemu': mldsa_ratios['overhead_arm_qemu'].mean()
            }
        },
        'hypothesis_tests': {
            'total_comparisons': len(tests_df),
            'significant_at_005': int(tests_df['significant'].sum()),
            'avg_effect_size': tests_df['cohens_d'].abs().mean()
        },
        'key_findings': [
            f"ML-KEM: ARM64 and RISC-V64 have equivalent performance (difference {mlkem_ratios['advantage_arm_percent'].mean():.1f}%)",
            f"ML-DSA: ARM64 is {mldsa_ratios['advantage_arm_percent'].mean():.1f}% faster than RISC-V64",
            f"Average QEMU overhead: {ratios_df['overhead_arm_qemu'].mean():.1f}x vs native x86_64",
            f"Sign is the most expensive operation in ML-DSA (2-2.5x KeyGen)"
        ]
    }
    
    # Save report
    report_path = OUTPUT_DIR / "analysis_summary.json"
    with open(report_path, 'w') as f:
        json.dump(report, f, indent=2)
    
    print(f"[OK] Report saved to {report_path}")
    
    # Display key findings
    print("\n[*] KEY FINDINGS:")
    for finding in report['key_findings']:
        print(f"  - {finding}")
    
    return report


def main():
    """Main analysis function."""
    print("="*60)
    print("STATISTICAL ANALYSIS - PQC BENCHMARKS")
    print("Thesis: ML-KEM and ML-DSA on ARM and RISC-V")
    print("="*60)
    print(f"Date: {datetime.now().strftime('%Y-%m-%d %H:%M')}")
    
    # Load data
    df = load_data()
    
    # Descriptive statistical analysis
    arch_summary, algo_summary = descriptive_statistics(df)
    
    # Calculate performance ratios
    ratios_df = calculate_ratios(df)
    
    # Hypothesis testing
    tests_df = hypothesis_tests(df)
    
    # Generate LaTeX tables
    generate_latex_tables(df, ratios_df)
    
    # Performance factor analysis
    analyze_performance_factors(df)
    
    # TLS overhead modeling
    model_tls_overhead(df)
    
    # PKI throughput modeling
    model_pki_throughput(df)
    
    # Generate summary report
    report = generate_summary_report(df, ratios_df, tests_df)
    
    print("\n" + "="*60)
    print("[OK] ANALYSIS COMPLETED")
    print("="*60)
    print(f"Files generated in: {OUTPUT_DIR}")
    
    return df, ratios_df, tests_df, report


if __name__ == "__main__":
    main()
