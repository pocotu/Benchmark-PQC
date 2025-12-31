/**
 * @file benchmark_engine.h
 * @brief Generic benchmark engine for PQC algorithms
 * @author Benchmarks-PQC Team
 * @date 2025-11-22
 * 
 * Provides a generic benchmark engine that can measure the performance
 * of any PQC algorithm conforming to the PQCAlgorithm interface.
 * Eliminates code duplication between algorithm-specific benchmarks.
 */

#ifndef PQC_BENCHMARK_ENGINE_H
#define PQC_BENCHMARK_ENGINE_H

#include <stdint.h>
#include <stddef.h>
#include <stdbool.h>
#include "algorithm_interface.h"

// ============================================================================
// Benchmark Configuration
// ============================================================================

/**
 * @brief Output format for benchmark results
 */
typedef enum {
    PQC_OUTPUT_FORMAT_JSON,    ///< JSON format
    PQC_OUTPUT_FORMAT_CSV,     ///< CSV format
    PQC_OUTPUT_FORMAT_BOTH     ///< Both JSON and CSV
} pqc_output_format_t;

/**
 * @brief Benchmark configuration
 * 
 * Controls how benchmarks are executed and results are reported.
 */
typedef struct {
    int num_iterations;              ///< Number of measurement iterations
    int warmup_iterations;           ///< Number of warmup iterations
    pqc_output_format_t output_format; ///< Output format
    const char *output_path;         ///< Base path for output files
    bool verbose;                    ///< Enable verbose logging
    bool remove_outliers;            ///< Remove statistical outliers
    double outlier_threshold;        ///< IQR multiplier for outlier detection (default: 1.5)
} BenchmarkConfig;

// ============================================================================
// Benchmark Results
// ============================================================================

/**
 * @brief Result from a single benchmark operation
 * 
 * Contains timing samples and computed statistics for one operation
 * (e.g., keygen, encaps, decaps, sign, verify).
 */
typedef struct {
    const char *algorithm;           ///< Algorithm name
    const char *operation;           ///< Operation name
    const char *architecture;        ///< Target architecture (e.g., "native", "arm64")
    
    // Raw timing data
    uint64_t *samples;               ///< Array of timing samples in nanoseconds
    int num_samples;                 ///< Number of samples
    
    // Computed statistics
    double mean;                     ///< Mean time in microseconds
    double median;                   ///< Median time in microseconds
    double std_dev;                  ///< Standard deviation in microseconds
    double min;                      ///< Minimum time in microseconds
    double max;                      ///< Maximum time in microseconds
    double p95;                      ///< 95th percentile in microseconds
    double p99;                      ///< 99th percentile in microseconds
} BenchmarkResult;

/**
 * @brief Collection of benchmark results
 * 
 * Contains results for all operations of an algorithm.
 */
typedef struct {
    BenchmarkResult *results;        ///< Array of results
    int num_results;                 ///< Number of results
    const char *algorithm;           ///< Algorithm name
    const char *architecture;        ///< Target architecture
} BenchmarkResultSet;

// ============================================================================
// Benchmark Engine Functions
// ============================================================================

/**
 * @brief Initialize benchmark configuration with defaults
 * @param config Configuration structure to initialize
 * 
 * Default values:
 * - num_iterations: 1000
 * - warmup_iterations: 100
 * - output_format: JSON
 * - output_path: "results"
 * - verbose: false
 * - remove_outliers: false
 * - outlier_threshold: 1.5
 */
void pqc_benchmark_config_init(BenchmarkConfig *config);

/**
 * @brief Validate benchmark configuration
 * @param config Configuration to validate
 * @return 0 if valid, negative error code otherwise
 */
int pqc_benchmark_config_validate(const BenchmarkConfig *config);

/**
 * @brief Benchmark a single algorithm
 * @param alg Algorithm to benchmark
 * @param config Benchmark configuration
 * @param results Output: pointer to result set (caller must free)
 * @return 0 on success, negative error code on failure
 * 
 * Benchmarks all applicable operations for the algorithm:
 * - KEM: keygen, encaps, decaps
 * - Signature: keygen, sign, verify
 * 
 * The caller is responsible for freeing the result set using
 * pqc_benchmark_result_set_free().
 */
int pqc_benchmark_algorithm(const PQCAlgorithm *alg, 
                           const BenchmarkConfig *config,
                           BenchmarkResultSet **results);

/**
 * @brief Benchmark a specific operation
 * @param alg Algorithm to benchmark
 * @param operation Operation name ("keygen", "encaps", "decaps", "sign", "verify")
 * @param config Benchmark configuration
 * @param result Output: pointer to result (caller must free)
 * @return 0 on success, negative error code on failure
 * 
 * Benchmarks a single operation. The caller is responsible for freeing
 * the result using pqc_benchmark_result_free().
 */
int pqc_benchmark_operation(const PQCAlgorithm *alg,
                           const char *operation,
                           const BenchmarkConfig *config,
                           BenchmarkResult **result);

// ============================================================================
// Result Management
// ============================================================================

/**
 * @brief Allocate a new benchmark result
 * @param algorithm Algorithm name
 * @param operation Operation name
 * @param architecture Target architecture
 * @param num_samples Number of samples to allocate
 * @return Pointer to allocated result, or NULL on failure
 * 
 * The caller must free the result using pqc_benchmark_result_free().
 */
BenchmarkResult* pqc_benchmark_result_alloc(const char *algorithm,
                                           const char *operation,
                                           const char *architecture,
                                           int num_samples);

/**
 * @brief Free a benchmark result
 * @param result Result to free (may be NULL)
 */
void pqc_benchmark_result_free(BenchmarkResult *result);

/**
 * @brief Allocate a new result set
 * @param algorithm Algorithm name
 * @param architecture Target architecture
 * @param num_results Number of results to allocate
 * @return Pointer to allocated result set, or NULL on failure
 * 
 * The caller must free the result set using pqc_benchmark_result_set_free().
 */
BenchmarkResultSet* pqc_benchmark_result_set_alloc(const char *algorithm,
                                                  const char *architecture,
                                                  int num_results);

/**
 * @brief Free a result set
 * @param result_set Result set to free (may be NULL)
 */
void pqc_benchmark_result_set_free(BenchmarkResultSet *result_set);

/**
 * @brief Compute statistics for a benchmark result
 * @param result Result to compute statistics for
 * @return 0 on success, negative error code on failure
 * 
 * Computes mean, median, std_dev, min, max, p95, p99 from samples.
 * Modifies the result in-place.
 */
int pqc_benchmark_result_compute_stats(BenchmarkResult *result);

// ============================================================================
// Output Functions
// ============================================================================

/**
 * @brief Write results to JSON file
 * @param result_set Result set to write
 * @param path Output file path
 * @return 0 on success, negative error code on failure
 */
int pqc_benchmark_write_json(const BenchmarkResultSet *result_set, 
                            const char *path);

/**
 * @brief Write results to CSV file
 * @param result_set Result set to write
 * @param path Output file path
 * @return 0 on success, negative error code on failure
 */
int pqc_benchmark_write_csv(const BenchmarkResultSet *result_set, 
                           const char *path);

/**
 * @brief Print results to stdout
 * @param result_set Result set to print
 */
void pqc_benchmark_print_results(const BenchmarkResultSet *result_set);

// ============================================================================
// Utility Functions
// ============================================================================

/**
 * @brief Get architecture string for current platform
 * @return Static string with architecture name
 * 
 * Returns "native", "arm64", "riscv64", or "unknown".
 */
const char* pqc_benchmark_get_architecture(void);

/**
 * @brief Convert output format enum to string
 * @param format Output format
 * @return Static string describing the format
 */
static inline const char* pqc_output_format_string(pqc_output_format_t format) {
    switch (format) {
        case PQC_OUTPUT_FORMAT_JSON:
            return "JSON";
        case PQC_OUTPUT_FORMAT_CSV:
            return "CSV";
        case PQC_OUTPUT_FORMAT_BOTH:
            return "JSON+CSV";
        default:
            return "Unknown";
    }
}

#endif // PQC_BENCHMARK_ENGINE_H
