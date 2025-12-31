/**
 * @file benchmark_mldsa.c
 * @brief ML-DSA (FIPS 204) benchmarking suite - Refactored
 * @author Benchmarks-PQC Team
 * @date 2025-11-22
 * 
 * Benchmarks ML-DSA key generation, signing, and verification
 * across all three security levels (44, 65, 87).
 * 
 * REFACTORED: Now uses generic benchmark engine to eliminate code duplication.
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#include "generic_benchmark.h"
#include "../adapters/liboqs_adapter.h"
#include "../utils/logger.h"

// ============================================================================
// Configuration
// ============================================================================

#define DEFAULT_ITERATIONS 1000
#define DEFAULT_WARMUP_ITERATIONS 100
#define OUTLIER_MULTIPLIER 1.5

// ML-DSA algorithm names
static const char *MLDSA_ALGORITHMS[] = {
    "mldsa44",
    "mldsa65",
    "mldsa87"
};

static const int NUM_ALGORITHMS = sizeof(MLDSA_ALGORITHMS) / sizeof(MLDSA_ALGORITHMS[0]);

// ============================================================================
// Command-line Interface
// ============================================================================

typedef struct {
    int iterations;
    int warmup;
    int remove_outliers;
    int verbose;
    const char *output_json;
    const char *output_csv;
} cli_config_t;

static void print_usage(const char *program_name) {
    printf("Usage: %s [options]\n", program_name);
    printf("\nOptions:\n");
    printf("  -i <num>    Number of iterations (default: %d)\n", DEFAULT_ITERATIONS);
    printf("  -w <num>    Warmup iterations (default: %d)\n", DEFAULT_WARMUP_ITERATIONS);
    printf("  -r          Remove outliers using IQR method\n");
    printf("  -v          Verbose output\n");
    printf("  -j <file>   Save results to JSON file\n");
    printf("  -c <file>   Save results to CSV file\n");
    printf("  -h          Show this help message\n");
    printf("\n");
}

static void parse_args(int argc, char *argv[], cli_config_t *config) {
    // Initialize defaults
    config->iterations = DEFAULT_ITERATIONS;
    config->warmup = DEFAULT_WARMUP_ITERATIONS;
    config->remove_outliers = 0;
    config->verbose = 0;
    config->output_json = NULL;
    config->output_csv = NULL;
    
    // Parse arguments
    int opt;
    while ((opt = getopt(argc, argv, "i:w:rvj:c:h")) != -1) {
        switch (opt) {
            case 'i':
                config->iterations = atoi(optarg);
                break;
            case 'w':
                config->warmup = atoi(optarg);
                break;
            case 'r':
                config->remove_outliers = 1;
                break;
            case 'v':
                config->verbose = 1;
                break;
            case 'j':
                config->output_json = optarg;
                break;
            case 'c':
                config->output_csv = optarg;
                break;
            case 'h':
                print_usage(argv[0]);
                exit(0);
            default:
                print_usage(argv[0]);
                exit(1);
        }
    }
}

// ============================================================================
// Main
// ============================================================================

int main(int argc, char *argv[]) {
    // Parse command-line arguments
    cli_config_t cli_config;
    parse_args(argc, argv, &cli_config);
    
    // Initialize logger
    logger_config_t logger_config = {
        .min_level = cli_config.verbose ? LOG_LEVEL_DEBUG : LOG_LEVEL_INFO,
        .file_output = NULL,
        .use_colors = 1,
        .include_timestamp = 1,
        .include_source_info = 0
    };
    logger_init(logger_config);
    
    // Print configuration
    LOG_INFO("=== ML-DSA Benchmark Configuration ===");
    LOG_INFO("Iterations: %d", cli_config.iterations);
    LOG_INFO("Warmup iterations: %d", cli_config.warmup);
    LOG_INFO("Remove outliers: %s", cli_config.remove_outliers ? "yes" : "no");
    LOG_INFO("======================================");
    
    // Create liboqs provider
    PQCProvider *provider = create_liboqs_provider();
    if (!provider) {
        LOG_ERROR("Failed to create liboqs provider");
        logger_close();
        return 1;
    }
    
    // Initialize provider
    void *provider_ctx = provider->init(provider);
    if (!provider_ctx) {
        LOG_ERROR("Failed to initialize provider");
        logger_close();
        return 1;
    }
    
    // Configure benchmark engine
    BenchmarkConfig bench_config;
    pqc_benchmark_config_init(&bench_config);
    bench_config.num_iterations = cli_config.iterations;
    bench_config.warmup_iterations = cli_config.warmup;
    bench_config.verbose = cli_config.verbose;
    bench_config.remove_outliers = cli_config.remove_outliers;
    bench_config.outlier_threshold = OUTLIER_MULTIPLIER;
    
    // Run benchmarks
    int total_benchmarks = 0;
    int failed_benchmarks = 0;
    
    for (int i = 0; i < NUM_ALGORITHMS; i++) {
        const char *alg_name = MLDSA_ALGORITHMS[i];
        total_benchmarks++;
        
        LOG_INFO("===========================================");
        LOG_INFO("Starting benchmark: %s", alg_name);
        LOG_INFO("===========================================");
        
        // Create algorithm instance
        PQCAlgorithm *alg = provider->create_algorithm(provider, provider_ctx, alg_name);
        if (!alg) {
            LOG_ERROR("Failed to create algorithm: %s", alg_name);
            failed_benchmarks++;
            continue;
        }
        
        // Log algorithm details
        LOG_INFO("Algorithm: %s", alg->name);
        LOG_INFO("Public key size: %zu bytes", alg->pk_len);
        LOG_INFO("Secret key size: %zu bytes", alg->sk_len);
        LOG_INFO("Signature size: %zu bytes", alg->sig_len);
        
        // Benchmark the algorithm
        BenchmarkResultSet *results = NULL;
        int ret = pqc_benchmark_algorithm(alg, &bench_config, &results);
        
        if (ret != 0 || !results) {
            LOG_ERROR("Benchmark failed for %s", alg_name);
            provider->destroy_algorithm(provider, provider_ctx, alg);
            failed_benchmarks++;
            continue;
        }
        
        // Print results
        printf("\n");
        pqc_benchmark_print_results(results);
        
        // Save results if requested
        if (cli_config.output_json) {
            char json_path[512];
            // Generate unique filename per algorithm
            const char *base_path = cli_config.output_json;
            const char *last_slash = strrchr(base_path, '/');
            const char *last_dot = strrchr(base_path, '.');
            
            if (last_slash && last_dot && last_dot > last_slash) {
                // Extract directory, base name, and extension
                size_t dir_len = last_slash - base_path + 1;
                size_t base_len = last_dot - last_slash - 1;
                
                char dir[256];
                char base[128];
                const char *ext = last_dot;
                
                strncpy(dir, base_path, dir_len);
                dir[dir_len] = '\0';
                
                strncpy(base, last_slash + 1, base_len);
                base[base_len] = '\0';
                
                snprintf(json_path, sizeof(json_path), "%s%s_%s%s", dir, alg_name, base, ext);
            } else {
                // Fallback: prepend algorithm name
                snprintf(json_path, sizeof(json_path), "%s_%s", alg_name, base_path);
            }
            
            ret = pqc_benchmark_write_json(results, json_path);
            if (ret != 0) {
                LOG_ERROR("Failed to write JSON results");
            } else {
                LOG_INFO("Wrote JSON results to %s", json_path);
            }
        }
        
        if (cli_config.output_csv) {
            char csv_path[512];
            // Generate unique filename per algorithm
            const char *base_path = cli_config.output_csv;
            const char *last_slash = strrchr(base_path, '/');
            const char *last_dot = strrchr(base_path, '.');
            
            if (last_slash && last_dot && last_dot > last_slash) {
                // Extract directory, base name, and extension
                size_t dir_len = last_slash - base_path + 1;
                size_t base_len = last_dot - last_slash - 1;
                
                char dir[256];
                char base[128];
                const char *ext = last_dot;
                
                strncpy(dir, base_path, dir_len);
                dir[dir_len] = '\0';
                
                strncpy(base, last_slash + 1, base_len);
                base[base_len] = '\0';
                
                snprintf(csv_path, sizeof(csv_path), "%s%s_%s%s", dir, alg_name, base, ext);
            } else {
                // Fallback: prepend algorithm name
                snprintf(csv_path, sizeof(csv_path), "%s_%s", alg_name, base_path);
            }
            
            ret = pqc_benchmark_write_csv(results, csv_path);
            if (ret != 0) {
                LOG_ERROR("Failed to write CSV results");
            } else {
                LOG_INFO("Wrote CSV results to %s", csv_path);
            }
        }
        
        // Cleanup
        pqc_benchmark_result_set_free(results);
        provider->destroy_algorithm(provider, provider_ctx, alg);
    }
    
    // Cleanup provider
    provider->cleanup(provider, provider_ctx);
    
    // Print summary
    printf("\n");
    if (failed_benchmarks == 0) {
        LOG_INFO("All benchmarks completed successfully");
    } else {
        LOG_ERROR("%d/%d benchmarks failed", failed_benchmarks, total_benchmarks);
    }
    
    logger_close();
    return (failed_benchmarks == 0) ? 0 : 1;
}
