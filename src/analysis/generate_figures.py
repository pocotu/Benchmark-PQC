#!/usr/bin/env python3
"""
Figure Generation for PQC Thesis
Phase 5.7: Visualizations

This script generates:
- Comparative bar charts
- Distribution box plots
- Performance heatmaps
- Security level scaling charts
"""

import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
import matplotlib.patches as mpatches
from pathlib import Path
from datetime import datetime

# Path configuration (relative to project root)
BASE_DIR = Path(__file__).parent.parent.parent  # Benchmarks-PQC/
DATA_DIR = BASE_DIR / "data" / "processed"
OUTPUT_DIR = BASE_DIR / "results" / "figures"
THESIS_DIR = BASE_DIR.parent / "docs-PQC" / "tesis" / "figures"

# Create directories
OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
THESIS_DIR.mkdir(parents=True, exist_ok=True)

# Style configuration
plt.style.use('seaborn-v0_8-whitegrid')
plt.rcParams['figure.figsize'] = (10, 6)
plt.rcParams['font.size'] = 11
plt.rcParams['axes.titlesize'] = 14
plt.rcParams['axes.labelsize'] = 12
plt.rcParams['legend.fontsize'] = 10
plt.rcParams['figure.dpi'] = 150

# Colors for architectures
COLORS = {
    'x86_64': '#2ecc71',    # Verde
    'ARM64': '#3498db',      # Azul
    'RISC-V64': '#e74c3c'    # Rojo
}


def load_data():
    """Load processed data."""
    csv_path = DATA_DIR / "processed_data.csv"
    df = pd.read_csv(csv_path)
    print(f" Data loaded: {len(df)} records")
    return df


def plot_mlkem_comparison(df):
    """Generate comparative chart de ML-KEM por arquitectura."""
    print("\n Generating chart ML-KEM...")
    
    fig, axes = plt.subplots(1, 3, figsize=(14, 5))
    
    operations = ['keygen', 'encaps', 'decaps']
    op_titles = ['KeyGen', 'Encaps', 'Decaps']
    algorithms = ['ML-KEM-512', 'ML-KEM-768', 'ML-KEM-1024']
    architectures = ['x86_64', 'ARM64', 'RISC-V64']
    
    x = np.arange(len(algorithms))
    width = 0.25
    
    for ax_idx, (op, title) in enumerate(zip(operations, op_titles)):
        ax = axes[ax_idx]
        
        for i, arch in enumerate(architectures):
            values = []
            for algo in algorithms:
                val = df[(df['architecture'] == arch) & 
                        (df['algorithm'] == algo) & 
                        (df['operation'] == op)]['mean_us'].values
                values.append(val[0] if len(val) > 0 else 0)
            
            bars = ax.bar(x + i*width, values, width, label=arch, color=COLORS[arch])
            
            # Add values sobre las barras
            for bar, val in zip(bars, values):
                if val > 0:
                    ax.annotate(f'{val:.1f}',
                               xy=(bar.get_x() + bar.get_width()/2, bar.get_height()),
                               xytext=(0, 3), textcoords="offset points",
                               ha='center', va='bottom', fontsize=8, rotation=45)
        
        ax.set_xlabel('Algorithm')
        ax.set_ylabel('Time (µs)')
        ax.set_title(f'ML-KEM {title}')
        ax.set_xticks(x + width)
        ax.set_xticklabels(['512', '768', '1024'])
        ax.legend()
        ax.set_yscale('log')
    
    plt.suptitle('Performance Comparison ML-KEM by Architecture', fontsize=14, fontweight='bold')
    plt.tight_layout()
    
    # Guardar
    for fmt in ['png', 'pdf']:
        fig.savefig(OUTPUT_DIR / f'mlkem_comparison.{fmt}', dpi=300, bbox_inches='tight')
        fig.savefig(THESIS_DIR / f'mlkem_comparison.{fmt}', dpi=300, bbox_inches='tight')
    
    plt.close()
    print(f"   Saved: mlkem_comparison.png/pdf")


def plot_mldsa_comparison(df):
    """Generate comparative chart de ML-DSA por arquitectura."""
    print("\n Generating chart ML-DSA...")
    
    fig, axes = plt.subplots(1, 3, figsize=(14, 5))
    
    operations = ['keygen', 'sign', 'verify']
    op_titles = ['KeyGen', 'Sign', 'Verify']
    algorithms = ['ML-DSA-44', 'ML-DSA-65', 'ML-DSA-87']
    architectures = ['x86_64', 'ARM64', 'RISC-V64']
    
    x = np.arange(len(algorithms))
    width = 0.25
    
    for ax_idx, (op, title) in enumerate(zip(operations, op_titles)):
        ax = axes[ax_idx]
        
        for i, arch in enumerate(architectures):
            values = []
            for algo in algorithms:
                val = df[(df['architecture'] == arch) & 
                        (df['algorithm'] == algo) & 
                        (df['operation'] == op)]['mean_us'].values
                values.append(val[0] if len(val) > 0 else 0)
            
            bars = ax.bar(x + i*width, values, width, label=arch, color=COLORS[arch])
            
            # Add values sobre las barras
            for bar, val in zip(bars, values):
                if val > 0:
                    ax.annotate(f'{val:.0f}',
                               xy=(bar.get_x() + bar.get_width()/2, bar.get_height()),
                               xytext=(0, 3), textcoords="offset points",
                               ha='center', va='bottom', fontsize=8, rotation=45)
        
        ax.set_xlabel('Algorithm')
        ax.set_ylabel('Time (µs)')
        ax.set_title(f'ML-DSA {title}')
        ax.set_xticks(x + width)
        ax.set_xticklabels(['44', '65', '87'])
        ax.legend()
        ax.set_yscale('log')
    
    plt.suptitle('Performance Comparison ML-DSA by Architecture', fontsize=14, fontweight='bold')
    plt.tight_layout()
    
    # Guardar
    for fmt in ['png', 'pdf']:
        fig.savefig(OUTPUT_DIR / f'mldsa_comparison.{fmt}', dpi=300, bbox_inches='tight')
        fig.savefig(THESIS_DIR / f'mldsa_comparison.{fmt}', dpi=300, bbox_inches='tight')
    
    plt.close()
    print(f"   Saved: mldsa_comparison.png/pdf")


def plot_architecture_overhead(df):
    """Genera gráfica de overhead de emulación QEMU."""
    print("\n Generating chart de overhead QEMU...")
    
    fig, axes = plt.subplots(1, 2, figsize=(12, 5))
    
    # ML-KEM
    ax = axes[0]
    algorithms = ['ML-KEM-512', 'ML-KEM-768', 'ML-KEM-1024']
    x = np.arange(len(algorithms))
    width = 0.35
    
    arm_overhead = []
    riscv_overhead = []
    
    for algo in algorithms:
        x86_mean = df[(df['architecture'] == 'x86_64') & (df['algorithm'] == algo)]['mean_us'].mean()
        arm_mean = df[(df['architecture'] == 'ARM64') & (df['algorithm'] == algo)]['mean_us'].mean()
        riscv_mean = df[(df['architecture'] == 'RISC-V64') & (df['algorithm'] == algo)]['mean_us'].mean()
        
        arm_overhead.append(arm_mean / x86_mean)
        riscv_overhead.append(riscv_mean / x86_mean)
    
    bars1 = ax.bar(x - width/2, arm_overhead, width, label='ARM64', color=COLORS['ARM64'])
    bars2 = ax.bar(x + width/2, riscv_overhead, width, label='RISC-V64', color=COLORS['RISC-V64'])
    
    ax.set_xlabel('Algorithm')
    ax.set_ylabel('Overhead (× vs x86_64)')
    ax.set_title('ML-KEM: QEMU Emulation Overhead')
    ax.set_xticks(x)
    ax.set_xticklabels(['512', '768', '1024'])
    ax.legend()
    ax.axhline(y=1, color='gray', linestyle='--', alpha=0.5)
    
    # Add values
    for bar in bars1:
        ax.annotate(f'{bar.get_height():.1f}×',
                   xy=(bar.get_x() + bar.get_width()/2, bar.get_height()),
                   xytext=(0, 3), textcoords="offset points",
                   ha='center', va='bottom', fontsize=9)
    for bar in bars2:
        ax.annotate(f'{bar.get_height():.1f}×',
                   xy=(bar.get_x() + bar.get_width()/2, bar.get_height()),
                   xytext=(0, 3), textcoords="offset points",
                   ha='center', va='bottom', fontsize=9)
    
    # ML-DSA
    ax = axes[1]
    algorithms = ['ML-DSA-44', 'ML-DSA-65', 'ML-DSA-87']
    x = np.arange(len(algorithms))
    
    arm_overhead = []
    riscv_overhead = []
    
    for algo in algorithms:
        x86_mean = df[(df['architecture'] == 'x86_64') & (df['algorithm'] == algo)]['mean_us'].mean()
        arm_mean = df[(df['architecture'] == 'ARM64') & (df['algorithm'] == algo)]['mean_us'].mean()
        riscv_mean = df[(df['architecture'] == 'RISC-V64') & (df['algorithm'] == algo)]['mean_us'].mean()
        
        arm_overhead.append(arm_mean / x86_mean)
        riscv_overhead.append(riscv_mean / x86_mean)
    
    bars1 = ax.bar(x - width/2, arm_overhead, width, label='ARM64', color=COLORS['ARM64'])
    bars2 = ax.bar(x + width/2, riscv_overhead, width, label='RISC-V64', color=COLORS['RISC-V64'])
    
    ax.set_xlabel('Algorithm')
    ax.set_ylabel('Overhead (× vs x86_64)')
    ax.set_title('ML-DSA: QEMU Emulation Overhead')
    ax.set_xticks(x)
    ax.set_xticklabels(['44', '65', '87'])
    ax.legend()
    ax.axhline(y=1, color='gray', linestyle='--', alpha=0.5)
    
    # Add values
    for bar in bars1:
        ax.annotate(f'{bar.get_height():.1f}×',
                   xy=(bar.get_x() + bar.get_width()/2, bar.get_height()),
                   xytext=(0, 3), textcoords="offset points",
                   ha='center', va='bottom', fontsize=9)
    for bar in bars2:
        ax.annotate(f'{bar.get_height():.1f}×',
                   xy=(bar.get_x() + bar.get_width()/2, bar.get_height()),
                   xytext=(0, 3), textcoords="offset points",
                   ha='center', va='bottom', fontsize=9)
    
    plt.suptitle('QEMU Emulation Overhead vs Native x86_64', fontsize=14, fontweight='bold')
    plt.tight_layout()
    
    # Guardar
    for fmt in ['png', 'pdf']:
        fig.savefig(OUTPUT_DIR / f'qemu_overhead.{fmt}', dpi=300, bbox_inches='tight')
        fig.savefig(THESIS_DIR / f'qemu_overhead.{fmt}', dpi=300, bbox_inches='tight')
    
    plt.close()
    print(f"   Saved: qemu_overhead.png/pdf")


def plot_arm_vs_riscv(df):
    """Genera gráfica de comparación ARM64 vs RISC-V64."""
    print("\n Generating chart ARM64 vs RISC-V64...")
    
    fig, axes = plt.subplots(1, 2, figsize=(12, 5))
    
    # ML-KEM
    ax = axes[0]
    algorithms = ['ML-KEM-512', 'ML-KEM-768', 'ML-KEM-1024']
    operations = ['keygen', 'encaps', 'decaps']
    
    x = np.arange(len(algorithms))
    width = 0.25
    
    for i, op in enumerate(operations):
        advantages = []
        for algo in algorithms:
            arm_val = df[(df['architecture'] == 'ARM64') & 
                        (df['algorithm'] == algo) & 
                        (df['operation'] == op)]['mean_us'].values[0]
            riscv_val = df[(df['architecture'] == 'RISC-V64') & 
                          (df['algorithm'] == algo) & 
                          (df['operation'] == op)]['mean_us'].values[0]
            # Positivo = ARM64 más rápido
            advantage = ((riscv_val - arm_val) / riscv_val) * 100
            advantages.append(advantage)
        
        bars = ax.bar(x + i*width, advantages, width, label=op.capitalize())
    
    ax.set_xlabel('Algorithm')
    ax.set_ylabel('ARM64 Advantage (%)')
    ax.set_title('ML-KEM: ARM64 Advantage over RISC-V64')
    ax.set_xticks(x + width)
    ax.set_xticklabels(['512', '768', '1024'])
    ax.legend()
    ax.axhline(y=0, color='black', linestyle='-', linewidth=0.5)
    ax.set_ylim(-30, 30)
    
    # ML-DSA
    ax = axes[1]
    algorithms = ['ML-DSA-44', 'ML-DSA-65', 'ML-DSA-87']
    operations = ['keygen', 'sign', 'verify']
    
    x = np.arange(len(algorithms))
    
    for i, op in enumerate(operations):
        advantages = []
        for algo in algorithms:
            arm_val = df[(df['architecture'] == 'ARM64') & 
                        (df['algorithm'] == algo) & 
                        (df['operation'] == op)]['mean_us'].values[0]
            riscv_val = df[(df['architecture'] == 'RISC-V64') & 
                          (df['algorithm'] == algo) & 
                          (df['operation'] == op)]['mean_us'].values[0]
            advantage = ((riscv_val - arm_val) / riscv_val) * 100
            advantages.append(advantage)
        
        bars = ax.bar(x + i*width, advantages, width, label=op.capitalize())
    
    ax.set_xlabel('Algorithm')
    ax.set_ylabel('ARM64 Advantage (%)')
    ax.set_title('ML-DSA: ARM64 Advantage over RISC-V64')
    ax.set_xticks(x + width)
    ax.set_xticklabels(['44', '65', '87'])
    ax.legend()
    ax.axhline(y=0, color='black', linestyle='-', linewidth=0.5)
    ax.set_ylim(-30, 30)
    
    plt.suptitle('Comparación ARM64 vs RISC-V64 (under QEMU)', fontsize=14, fontweight='bold')
    plt.tight_layout()
    
    # Guardar
    for fmt in ['png', 'pdf']:
        fig.savefig(OUTPUT_DIR / f'arm_vs_riscv.{fmt}', dpi=300, bbox_inches='tight')
        fig.savefig(THESIS_DIR / f'arm_vs_riscv.{fmt}', dpi=300, bbox_inches='tight')
    
    plt.close()
    print(f"   Saved: arm_vs_riscv.png/pdf")


def plot_security_level_scaling(df):
    """Genera gráfica de escalamiento por nivel de seguridad."""
    print("\n Generating chart de escalamiento...")
    
    fig, axes = plt.subplots(1, 2, figsize=(12, 5))
    
    # ML-KEM
    ax = axes[0]
    levels = [512, 768, 1024]
    
    for arch in ['x86_64', 'ARM64', 'RISC-V64']:
        means = []
        for level in levels:
            algo = f'ML-KEM-{level}'
            mean = df[(df['architecture'] == arch) & (df['algorithm'] == algo)]['mean_us'].mean()
            means.append(mean)
        
        ax.plot(levels, means, 'o-', label=arch, color=COLORS[arch], linewidth=2, markersize=8)
    
    ax.set_xlabel('Security Level (ML-KEM)')
    ax.set_ylabel('Time Promedio (µs)')
    ax.set_title('ML-KEM: Scaling by Level')
    ax.legend()
    ax.set_yscale('log')
    ax.set_xticks(levels)
    
    # ML-DSA
    ax = axes[1]
    levels = [44, 65, 87]
    
    for arch in ['x86_64', 'ARM64', 'RISC-V64']:
        means = []
        for level in levels:
            algo = f'ML-DSA-{level}'
            mean = df[(df['architecture'] == arch) & (df['algorithm'] == algo)]['mean_us'].mean()
            means.append(mean)
        
        ax.plot(levels, means, 'o-', label=arch, color=COLORS[arch], linewidth=2, markersize=8)
    
    ax.set_xlabel('Security Level (ML-DSA)')
    ax.set_ylabel('Time Promedio (µs)')
    ax.set_title('ML-DSA: Scaling by Level')
    ax.legend()
    ax.set_yscale('log')
    ax.set_xticks(levels)
    
    plt.suptitle('Escalamiento del Time de Ejecución por Security Level', fontsize=14, fontweight='bold')
    plt.tight_layout()
    
    # Guardar
    for fmt in ['png', 'pdf']:
        fig.savefig(OUTPUT_DIR / f'security_scaling.{fmt}', dpi=300, bbox_inches='tight')
        fig.savefig(THESIS_DIR / f'security_scaling.{fmt}', dpi=300, bbox_inches='tight')
    
    plt.close()
    print(f"   Saved: security_scaling.png/pdf")


def plot_operation_comparison(df):
    """Genera gráfica de comparación de operaciones."""
    print("\n Generating chart de operaciones...")
    
    fig, axes = plt.subplots(1, 2, figsize=(12, 5))
    
    # ML-KEM - Costo relativo vs KeyGen
    ax = axes[0]
    algorithms = ['ML-KEM-512', 'ML-KEM-768', 'ML-KEM-1024']
    x = np.arange(len(algorithms))
    width = 0.25
    
    for i, arch in enumerate(['x86_64', 'ARM64', 'RISC-V64']):
        encaps_ratios = []
        decaps_ratios = []
        
        for algo in algorithms:
            arch_data = df[(df['architecture'] == arch) & (df['algorithm'] == algo)]
            keygen = arch_data[arch_data['operation'] == 'keygen']['mean_us'].values[0]
            encaps = arch_data[arch_data['operation'] == 'encaps']['mean_us'].values[0]
            decaps = arch_data[arch_data['operation'] == 'decaps']['mean_us'].values[0]
            
            encaps_ratios.append(encaps / keygen)
            decaps_ratios.append(decaps / keygen)
        
        ax.bar(x + i*width - width, encaps_ratios, width/2, label=f'{arch} Encaps', alpha=0.7)
        ax.bar(x + i*width - width/2, decaps_ratios, width/2, label=f'{arch} Decaps', alpha=0.7)
    
    ax.set_xlabel('Algorithm')
    ax.set_ylabel('Ratio vs KeyGen')
    ax.set_title('ML-KEM: Relative Operation Cost')
    ax.set_xticks(x)
    ax.set_xticklabels(['512', '768', '1024'])
    ax.axhline(y=1, color='gray', linestyle='--', alpha=0.5)
    ax.legend(loc='upper left', fontsize=8)
    
    # ML-DSA - Costo relativo vs KeyGen
    ax = axes[1]
    algorithms = ['ML-DSA-44', 'ML-DSA-65', 'ML-DSA-87']
    x = np.arange(len(algorithms))
    
    for i, arch in enumerate(['x86_64', 'ARM64', 'RISC-V64']):
        sign_ratios = []
        verify_ratios = []
        
        for algo in algorithms:
            arch_data = df[(df['architecture'] == arch) & (df['algorithm'] == algo)]
            keygen = arch_data[arch_data['operation'] == 'keygen']['mean_us'].values[0]
            sign = arch_data[arch_data['operation'] == 'sign']['mean_us'].values[0]
            verify = arch_data[arch_data['operation'] == 'verify']['mean_us'].values[0]
            
            sign_ratios.append(sign / keygen)
            verify_ratios.append(verify / keygen)
        
        ax.bar(x + i*width - width, sign_ratios, width/2, label=f'{arch} Sign', alpha=0.7)
        ax.bar(x + i*width - width/2, verify_ratios, width/2, label=f'{arch} Verify', alpha=0.7)
    
    ax.set_xlabel('Algorithm')
    ax.set_ylabel('Ratio vs KeyGen')
    ax.set_title('ML-DSA: Relative Operation Cost')
    ax.set_xticks(x)
    ax.set_xticklabels(['44', '65', '87'])
    ax.axhline(y=1, color='gray', linestyle='--', alpha=0.5)
    ax.legend(loc='upper left', fontsize=8)
    
    plt.suptitle('Relative Operation Cost (vs KeyGen = 1.0)', fontsize=14, fontweight='bold')
    plt.tight_layout()
    
    # Guardar
    for fmt in ['png', 'pdf']:
        fig.savefig(OUTPUT_DIR / f'operation_comparison.{fmt}', dpi=300, bbox_inches='tight')
        fig.savefig(THESIS_DIR / f'operation_comparison.{fmt}', dpi=300, bbox_inches='tight')
    
    plt.close()
    print(f"   Saved: operation_comparison.png/pdf")


def plot_summary_heatmap(df):
    """Generate performance summary heatmap."""
    print("\n Generating performance heatmap...")
    
    # Create data matrix
    algorithms = ['ML-KEM-512', 'ML-KEM-768', 'ML-KEM-1024', 
                  'ML-DSA-44', 'ML-DSA-65', 'ML-DSA-87']
    architectures = ['x86_64', 'ARM64', 'RISC-V64']
    
    data = np.zeros((len(algorithms), len(architectures)))
    
    for i, algo in enumerate(algorithms):
        for j, arch in enumerate(architectures):
            mean = df[(df['architecture'] == arch) & (df['algorithm'] == algo)]['mean_us'].mean()
            data[i, j] = mean
    
    # Normalize by row (algoritmo)
    data_norm = data / data[:, 0:1]  # Normalizar vs x86_64
    
    fig, ax = plt.subplots(figsize=(8, 6))
    
    im = ax.imshow(data_norm, cmap='RdYlGn_r', aspect='auto')
    
    # Labels
    ax.set_xticks(np.arange(len(architectures)))
    ax.set_yticks(np.arange(len(algorithms)))
    ax.set_xticklabels(architectures)
    ax.set_yticklabels(algorithms)
    
    # Rotate labels
    plt.setp(ax.get_xticklabels(), rotation=45, ha="right", rotation_mode="anchor")
    
    # Add values
    for i in range(len(algorithms)):
        for j in range(len(architectures)):
            text = ax.text(j, i, f'{data_norm[i, j]:.1f}×',
                          ha="center", va="center", color="black", fontsize=10)
    
    ax.set_title('Overhead Relativo vs Native x86_64\n(1.0× = equal performance)', fontsize=12)
    
    # Colorbar
    cbar = ax.figure.colorbar(im, ax=ax)
    cbar.ax.set_ylabel('Overhead (×)', rotation=-90, va="bottom")
    
    plt.tight_layout()
    
    # Guardar
    for fmt in ['png', 'pdf']:
        fig.savefig(OUTPUT_DIR / f'performance_heatmap.{fmt}', dpi=300, bbox_inches='tight')
        fig.savefig(THESIS_DIR / f'performance_heatmap.{fmt}', dpi=300, bbox_inches='tight')
    
    plt.close()
    print(f"   Saved: performance_heatmap.png/pdf")


def main():
    """Main function."""
    print("="*60)
    print("FIGURE GENERATION - PQC THESIS")
    print("="*60)
    print(f"Date: {datetime.now().strftime('%Y-%m-%d %H:%M')}")
    
    # Load data
    df = load_data()
    
    # Generate figures
    plot_mlkem_comparison(df)
    plot_mldsa_comparison(df)
    plot_architecture_overhead(df)
    plot_arm_vs_riscv(df)
    plot_security_level_scaling(df)
    plot_operation_comparison(df)
    plot_summary_heatmap(df)
    
    print("\n" + "="*60)
    print(" FIGURES GENERATED")
    print("="*60)
    print(f"Output directory: {OUTPUT_DIR}")
    print(f"Thesis directory: {THESIS_DIR}")
    
    # Listar archivos generados
    print("\n Generated files:")
    for f in sorted(OUTPUT_DIR.glob('*.png')):
        print(f"  • {f.name}")


if __name__ == "__main__":
    main()
