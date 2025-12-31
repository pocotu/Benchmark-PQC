/**
 * @file benchmark_mlkem.c
 * @brief ML-KEM (FIPS 203) benchmarking suite - Refactored
 * @author Benchmarks-PQC Team
 * @date 2025-11-22
 * 
 * Benchmarks ML-KEM key generation, encapsulation, and decapsulation
 * across all three security levels (512, 768, 1024).
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

// ML-KEM algorithm names
static const char *MLKEM_ALGORITHMS[] = {
    "mlkem512",
    "mlkem768",
    "mlkem1024"
};

static const int NUM_ALGORITHMS = sizeof(MLKEM_ALGORITHMS) / sizeof(MLKEM_ALGORITHMS[0]);

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

static void print_usage(const char *prog_name) {
    printf("Usage: %s [OPTIONS]\n", prog_name);
    printf("\nOptions:\n");
    printf("  -i, --iterations N    Number of iterations (default: %d)\n", DEFAULT_ITERATIONS);
    printf("  -w, --warmup N        Number of warmup iterations (default: %d)\n", DEFAULT_WARMUP_ITERATIONS);
    printf("  -r, --remove-outliers Remove statistical outliers\n");
    printf("  -v, --verbose         Verbose logging\n");
    printf("  -j, --json FILE       Save results to JSON file\n");
    printf("  -c, --csv FILE        Save results to CSV file\n");
    printf("  -h, --help            Show this help message\n");
    printf("\nExamples:\n");
    printf("  %s -i 10000 -r\n", prog_name);
    printf("  %s --iterations 5000 --json results.json --csv results.csv\n", prog_name);
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
    for (int i = 1; i < argc; i++) {
        if (strcmp(argv[i], "-i") == 0 || strcmp(argv[i], "--iterations") == 0) {
            if (++i < argc) {
                config->iterations = atoi(argv[i]);
            }
        } else if (strcmp(argv[i], "-w") == 0 || strcmp(argv[i], "--warmup") == 0) {
            if (++i < argc) {
                config->warmup = atoi(argv[i]);
            }
        } else if (strcmp(argv[i], "-r") == 0 || strcmp(argv[i], "--remove-outliers") == 0) {
            config->remove_outliers = 1;
        } else if (strcmp(argv[i], "-v") == 0 || strcmp(argv[i], "--verbose") == 0) {
            config->verbose = 1;
        } else if (strcmp(argv[i], "-j") == 0 || strcmp(argv[i], "--json") == 0) {
            if (++i < argc) {
                config->output_json = argv[i];
            }
        } else if (strcmp(argv[i], "-c") == 0 || strcmp(argv[i], "--csv") == 0) {
            if (++i < argc) {
                config->output_csv = argv[i];
            }
        } else if (strcmp(argv[i], "-h") == 0 || strcmp(argv[i], "--help") == 0) {
            print_usage(argv[0]);
            exit(0);
        }
    }
}

// ============================================================================
// Main
// ============================================================================

int main(int argc, char *argv[]) {
    // Initialize logger
    logger_config_t log_config = {
        .min_level = LOG_LEVEL_INFO,
        .file_output = NULL,
        .use_colors = 1,
        .include_timestamp = 1,
        .include_source_info = 0
    };
    logger_init(log_config);
    
    // Parse command-line arguments
    cli_config_t cli_config;
    parse_args(argc, argv, &cli_config);
    
    if (cli_config.verbose) {
        logger_set_level(LOG_LEVEL_DEBUG);
    }
    
    // Log configuration
    LOG_INFO("=== ML-KEM Benchmark Configuration ===");
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
    
    // Run benchmarks for all algorithms
    int failures = 0;
    for (int i = 0; i < NUM_ALGORITHMS; i++) {
        const char *alg_name = MLKEM_ALGORITHMS[i];
        
        LOG_INFO("===========================================");
        LOG_INFO("Starting benchmark: %s", alg_name);
        LOG_INFO("===========================================");
        
        // Create algorithm instance
        PQCAlgorithm *alg = provider->create_algorithm(provider, provider_ctx, alg_name);
        if (!alg) {
            LOG_ERROR("Failed to create algorithm: %s", alg_name);
            failures++;
            continue;
        }
        
        // Log algorithm details
        LOG_INFO("Algorithm: %s", alg->name);
        LOG_INFO("Public key size: %zu bytes", alg->pk_len);
        LOG_INFO("Secret key size: %zu bytes", alg->sk_len);
        LOG_INFO("Ciphertext size: %zu bytes", alg->ct_len);
        LOG_INFO("Shared secret size: %zu bytes", alg->ss_len);
        
        // Benchmark the algorithm
        BenchmarkResultSet *results = NULL;
        int ret = pqc_benchmark_algorithm(alg, &bench_config, &results);
        
        if (ret != 0 || !results) {
            LOG_ERROR("Benchmark failed for %s", alg_name);
            provider->destroy_algorithm(provider, provider_ctx, alg);
            failures++;
            continue;
        }
        
        // Print results
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
        
        printf("\n");
    }
    
    // Cleanup provider
    provider->cleanup(provider, provider_ctx);
    
    // Summary
    if (failures == 0) {
        LOG_INFO("All benchmarks completed successfully");
        logger_close();
        return 0;
    } else {
        LOG_ERROR("%d benchmark(s) failed", failures);
        logger_close();
        return 1;
    }
}
