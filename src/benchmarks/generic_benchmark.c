/**
 * @file generic_benchmark.c
 * @brief Generic benchmark engine implementation for PQC algorithms
 * @author Benchmarks-PQC Team
 * @date 2025-11-22
 * 
 * Implements a generic benchmark engine that works with any PQC algorithm
 * conforming to the PQCAlgorithm interface. Eliminates code duplication
 * between algorithm-specific benchmarks.
 */

#include "generic_benchmark.h"
#include "../core/benchmark_engine.h"
#include "../core/algorithm_interface.h"
#include "../core/error_codes.h"
#include "../utils/timing.h"
#include "../utils/stats.h"
#include "../utils/logger.h"
#include <stdlib.h>
#include <string.h>
#include <stdio.h>

// ============================================================================
// Configuration Functions
// ============================================================================

void pqc_benchmark_config_init(BenchmarkConfig *config) {
    if (config == NULL) {
        return;
    }
    
    config->num_iterations = 1000;
    config->warmup_iterations = 100;
    config->output_format = PQC_OUTPUT_FORMAT_JSON;
    config->output_path = "results";
    config->verbose = false;
    config->remove_outliers = false;
    config->outlier_threshold = 1.5;
}

int pqc_benchmark_config_validate(const BenchmarkConfig *config) {
    if (config == NULL) {
        LOG_ERROR("Config is NULL");
        return PQC_ERROR_NULL_POINTER;
    }
    
    if (config->num_iterations <= 0) {
        LOG_ERROR("Invalid num_iterations: %d", config->num_iterations);
        return PQC_ERROR_INVALID_PARAM;
    }
    
    if (config->warmup_iterations < 0) {
        LOG_ERROR("Invalid warmup_iterations: %d", config->warmup_iterations);
        return PQC_ERROR_INVALID_PARAM;
    }
    
    if (config->output_path == NULL) {
        LOG_ERROR("Output path is NULL");
        return PQC_ERROR_NULL_POINTER;
    }
    
    if (config->remove_outliers && config->outlier_threshold <= 0.0) {
        LOG_ERROR("Invalid outlier_threshold: %.2f", config->outlier_threshold);
        return PQC_ERROR_INVALID_PARAM;
    }
    
    return PQC_SUCCESS;
}

// ============================================================================
// Result Management Functions
// ============================================================================

BenchmarkResult* pqc_benchmark_result_alloc(const char *algorithm,
                                           const char *operation,
                                           const char *architecture,
                                           int num_samples) {
    if (algorithm == NULL || operation == NULL || architecture == NULL) {
        LOG_ERROR("NULL parameter in result_alloc");
        return NULL;
    }
    
    if (num_samples <= 0) {
        LOG_ERROR("Invalid num_samples: %d", num_samples);
        return NULL;
    }
    
    BenchmarkResult *result = (BenchmarkResult*)calloc(1, sizeof(BenchmarkResult));
    if (result == NULL) {
        LOG_ERROR("Failed to allocate BenchmarkResult");
        return NULL;
    }
    
    result->algorithm = strdup(algorithm);
    result->operation = strdup(operation);
    result->architecture = strdup(architecture);
    
    if (result->algorithm == NULL || result->operation == NULL || 
        result->architecture == NULL) {
        LOG_ERROR("Failed to duplicate strings");
        pqc_benchmark_result_free(result);
        return NULL;
    }
    
    result->samples = (uint64_t*)calloc(num_samples, sizeof(uint64_t));
    if (result->samples == NULL) {
        LOG_ERROR("Failed to allocate samples array");
        pqc_benchmark_result_free(result);
        return NULL;
    }
    
    result->num_samples = num_samples;
    
    return result;
}

void pqc_benchmark_result_free(BenchmarkResult *result) {
    if (result == NULL) {
        return;
    }
    
    free((void*)result->algorithm);
    free((void*)result->operation);
    free((void*)result->architecture);
    free(result->samples);
    free(result);
}

BenchmarkResultSet* pqc_benchmark_result_set_alloc(const char *algorithm,
                                                  const char *architecture,
                                                  int num_results) {
    if (algorithm == NULL || architecture == NULL) {
        LOG_ERROR("NULL parameter in result_set_alloc");
        return NULL;
    }
    
    if (num_results <= 0) {
        LOG_ERROR("Invalid num_results: %d", num_results);
        return NULL;
    }
    
    BenchmarkResultSet *result_set = (BenchmarkResultSet*)calloc(1, sizeof(BenchmarkResultSet));
    if (result_set == NULL) {
        LOG_ERROR("Failed to allocate BenchmarkResultSet");
        return NULL;
    }
    
    result_set->algorithm = strdup(algorithm);
    result_set->architecture = strdup(architecture);
    
    if (result_set->algorithm == NULL || result_set->architecture == NULL) {
        LOG_ERROR("Failed to duplicate strings");
        pqc_benchmark_result_set_free(result_set);
        return NULL;
    }
    
    result_set->results = (BenchmarkResult*)calloc(num_results, sizeof(BenchmarkResult));
    if (result_set->results == NULL) {
        LOG_ERROR("Failed to allocate results array");
        pqc_benchmark_result_set_free(result_set);
        return NULL;
    }
    
    result_set->num_results = num_results;
    
    return result_set;
}

void pqc_benchmark_result_set_free(BenchmarkResultSet *result_set) {
    if (result_set == NULL) {
        return;
    }
    
    if (result_set->results != NULL) {
        for (int i = 0; i < result_set->num_results; i++) {
            free((void*)result_set->results[i].algorithm);
            free((void*)result_set->results[i].operation);
            free((void*)result_set->results[i].architecture);
            free(result_set->results[i].samples);
        }
        free(result_set->results);
    }
    
    free((void*)result_set->algorithm);
    free((void*)result_set->architecture);
    free(result_set);
}

int pqc_benchmark_result_compute_stats(BenchmarkResult *result) {
    if (result == NULL) {
        LOG_ERROR("Result is NULL");
        return PQC_ERROR_NULL_POINTER;
    }
    
    if (result->samples == NULL || result->num_samples <= 0) {
        LOG_ERROR("Invalid samples array");
        return PQC_ERROR_INVALID_PARAM;
    }
    
    // Calculate statistics using stats utility
    pqc_stats_t stats = pqc_stats_calculate(result->samples, result->num_samples);
    
    // Convert from nanoseconds to microseconds
    result->mean = pqc_ns_to_us(stats.mean);
    result->median = pqc_ns_to_us(stats.median);
    result->std_dev = pqc_ns_to_us(stats.stddev);
    result->min = pqc_ns_to_us(stats.min);
    result->max = pqc_ns_to_us(stats.max);
    result->p95 = pqc_ns_to_us(stats.p95);
    result->p99 = pqc_ns_to_us(stats.p99);
    
    return PQC_SUCCESS;
}

// ============================================================================
// Benchmark Operation Helpers
// ============================================================================

/**
 * @brief Benchmark key generation operation
 */
static int benchmark_keygen(const PQCAlgorithm *alg, 
                           const BenchmarkConfig *config,
                           BenchmarkResult *result) {
    if (alg->keygen == NULL) {
        LOG_ERROR("Algorithm does not support keygen");
        return PQC_ERROR_NOT_SUPPORTED;
    }
    
    // Allocate buffers
    uint8_t *pk = (uint8_t*)malloc(alg->pk_len);
    uint8_t *sk = (uint8_t*)malloc(alg->sk_len);
    
    if (pk == NULL || sk == NULL) {
        LOG_ERROR("Failed to allocate key buffers");
        free(pk);
        free(sk);
        return PQC_ERROR_MEMORY_ALLOC;
    }
    
    // Warmup
    if (config->warmup_iterations > 0) {
        LOG_DEBUG("Warmup: %d iterations", config->warmup_iterations);
        for (int i = 0; i < config->warmup_iterations; i++) {
            alg->keygen(alg, pk, sk);
        }
    }
    
    // Benchmark iterations
    LOG_DEBUG("Benchmarking keygen: %d iterations", config->num_iterations);
    for (int i = 0; i < config->num_iterations; i++) {
        pqc_timestamp_t start = pqc_timestamp_now();
        int ret = alg->keygen(alg, pk, sk);
        pqc_timestamp_t end = pqc_timestamp_now();
        
        if (ret != 0) {
            LOG_ERROR("Keygen failed at iteration %d", i);
            free(pk);
            free(sk);
            return PQC_ERROR_OPERATION_FAILED;
        }
        
        result->samples[i] = pqc_timestamp_diff(start, end);
    }
    
    free(pk);
    free(sk);
    
    return PQC_SUCCESS;
}

/**
 * @brief Benchmark encapsulation operation (KEM only)
 */
static int benchmark_encaps(const PQCAlgorithm *alg,
                           const BenchmarkConfig *config,
                           BenchmarkResult *result) {
    if (alg->encaps == NULL) {
        LOG_ERROR("Algorithm does not support encaps");
        return PQC_ERROR_NOT_SUPPORTED;
    }
    
    // Allocate buffers
    uint8_t *pk = (uint8_t*)malloc(alg->pk_len);
    uint8_t *sk = (uint8_t*)malloc(alg->sk_len);
    uint8_t *ct = (uint8_t*)malloc(alg->ct_len);
    uint8_t *ss = (uint8_t*)malloc(alg->ss_len);
    
    if (pk == NULL || sk == NULL || ct == NULL || ss == NULL) {
        LOG_ERROR("Failed to allocate buffers");
        free(pk); free(sk); free(ct); free(ss);
        return PQC_ERROR_MEMORY_ALLOC;
    }
    
    // Generate keypair for testing
    if (alg->keygen(alg, pk, sk) != 0) {
        LOG_ERROR("Keygen failed during encaps setup");
        free(pk); free(sk); free(ct); free(ss);
        return PQC_ERROR_OPERATION_FAILED;
    }
    
    // Warmup
    if (config->warmup_iterations > 0) {
        LOG_DEBUG("Warmup: %d iterations", config->warmup_iterations);
        for (int i = 0; i < config->warmup_iterations; i++) {
            alg->encaps(alg, ct, ss, pk);
        }
    }
    
    // Benchmark iterations
    LOG_DEBUG("Benchmarking encaps: %d iterations", config->num_iterations);
    for (int i = 0; i < config->num_iterations; i++) {
        pqc_timestamp_t start = pqc_timestamp_now();
        int ret = alg->encaps(alg, ct, ss, pk);
        pqc_timestamp_t end = pqc_timestamp_now();
        
        if (ret != 0) {
            LOG_ERROR("Encaps failed at iteration %d", i);
            free(pk); free(sk); free(ct); free(ss);
            return PQC_ERROR_OPERATION_FAILED;
        }
        
        result->samples[i] = pqc_timestamp_diff(start, end);
    }
    
    free(pk); free(sk); free(ct); free(ss);
    
    return PQC_SUCCESS;
}

/**
 * @brief Benchmark decapsulation operation (KEM only)
 */
static int benchmark_decaps(const PQCAlgorithm *alg,
                           const BenchmarkConfig *config,
                           BenchmarkResult *result) {
    if (alg->decaps == NULL) {
        LOG_ERROR("Algorithm does not support decaps");
        return PQC_ERROR_NOT_SUPPORTED;
    }
    
    // Allocate buffers
    uint8_t *pk = (uint8_t*)malloc(alg->pk_len);
    uint8_t *sk = (uint8_t*)malloc(alg->sk_len);
    uint8_t *ct = (uint8_t*)malloc(alg->ct_len);
    uint8_t *ss = (uint8_t*)malloc(alg->ss_len);
    uint8_t *ss_dec = (uint8_t*)malloc(alg->ss_len);
    
    if (pk == NULL || sk == NULL || ct == NULL || ss == NULL || ss_dec == NULL) {
        LOG_ERROR("Failed to allocate buffers");
        free(pk); free(sk); free(ct); free(ss); free(ss_dec);
        return PQC_ERROR_MEMORY_ALLOC;
    }
    
    // Generate keypair and ciphertext for testing
    if (alg->keygen(alg, pk, sk) != 0) {
        LOG_ERROR("Keygen failed during decaps setup");
        free(pk); free(sk); free(ct); free(ss); free(ss_dec);
        return PQC_ERROR_OPERATION_FAILED;
    }
    
    if (alg->encaps(alg, ct, ss, pk) != 0) {
        LOG_ERROR("Encaps failed during decaps setup");
        free(pk); free(sk); free(ct); free(ss); free(ss_dec);
        return PQC_ERROR_OPERATION_FAILED;
    }
    
    // Warmup
    if (config->warmup_iterations > 0) {
        LOG_DEBUG("Warmup: %d iterations", config->warmup_iterations);
        for (int i = 0; i < config->warmup_iterations; i++) {
            alg->decaps(alg, ss_dec, ct, sk);
        }
    }
    
    // Benchmark iterations
    LOG_DEBUG("Benchmarking decaps: %d iterations", config->num_iterations);
    for (int i = 0; i < config->num_iterations; i++) {
        pqc_timestamp_t start = pqc_timestamp_now();
        int ret = alg->decaps(alg, ss_dec, ct, sk);
        pqc_timestamp_t end = pqc_timestamp_now();
        
        if (ret != 0) {
            LOG_ERROR("Decaps failed at iteration %d", i);
            free(pk); free(sk); free(ct); free(ss); free(ss_dec);
            return PQC_ERROR_OPERATION_FAILED;
        }
        
        result->samples[i] = pqc_timestamp_diff(start, end);
    }
    
    free(pk); free(sk); free(ct); free(ss); free(ss_dec);
    
    return PQC_SUCCESS;
}

/**
 * @brief Benchmark signing operation (Signature only)
 */
static int benchmark_sign(const PQCAlgorithm *alg,
                         const BenchmarkConfig *config,
                         BenchmarkResult *result) {
    if (alg->sign == NULL) {
        LOG_ERROR("Algorithm does not support sign");
        return PQC_ERROR_NOT_SUPPORTED;
    }
    
    // Allocate buffers
    uint8_t *pk = (uint8_t*)malloc(alg->pk_len);
    uint8_t *sk = (uint8_t*)malloc(alg->sk_len);
    uint8_t *sig = (uint8_t*)malloc(alg->sig_len);
    
    // Test message
    const char *msg = "Test message for signing";
    size_t msg_len = strlen(msg);
    
    if (pk == NULL || sk == NULL || sig == NULL) {
        LOG_ERROR("Failed to allocate buffers");
        free(pk); free(sk); free(sig);
        return PQC_ERROR_MEMORY_ALLOC;
    }
    
    // Generate keypair for testing
    if (alg->keygen(alg, pk, sk) != 0) {
        LOG_ERROR("Keygen failed during sign setup");
        free(pk); free(sk); free(sig);
        return PQC_ERROR_OPERATION_FAILED;
    }
    
    // Warmup
    if (config->warmup_iterations > 0) {
        LOG_DEBUG("Warmup: %d iterations", config->warmup_iterations);
        for (int i = 0; i < config->warmup_iterations; i++) {
            size_t sig_len = alg->sig_len;
            alg->sign(alg, sig, &sig_len, (const uint8_t*)msg, msg_len, sk);
        }
    }
    
    // Benchmark iterations
    LOG_DEBUG("Benchmarking sign: %d iterations", config->num_iterations);
    for (int i = 0; i < config->num_iterations; i++) {
        size_t sig_len = alg->sig_len;
        
        pqc_timestamp_t start = pqc_timestamp_now();
        int ret = alg->sign(alg, sig, &sig_len, (const uint8_t*)msg, msg_len, sk);
        pqc_timestamp_t end = pqc_timestamp_now();
        
        if (ret != 0) {
            LOG_ERROR("Sign failed at iteration %d", i);
            free(pk); free(sk); free(sig);
            return PQC_ERROR_OPERATION_FAILED;
        }
        
        result->samples[i] = pqc_timestamp_diff(start, end);
    }
    
    free(pk); free(sk); free(sig);
    
    return PQC_SUCCESS;
}

/**
 * @brief Benchmark verification operation (Signature only)
 */
static int benchmark_verify(const PQCAlgorithm *alg,
                           const BenchmarkConfig *config,
                           BenchmarkResult *result) {
    if (alg->verify == NULL) {
        LOG_ERROR("Algorithm does not support verify");
        return PQC_ERROR_NOT_SUPPORTED;
    }
    
    // Allocate buffers
    uint8_t *pk = (uint8_t*)malloc(alg->pk_len);
    uint8_t *sk = (uint8_t*)malloc(alg->sk_len);
    uint8_t *sig = (uint8_t*)malloc(alg->sig_len);
    
    // Test message
    const char *msg = "Test message for signing";
    size_t msg_len = strlen(msg);
    size_t sig_len = alg->sig_len;
    
    if (pk == NULL || sk == NULL || sig == NULL) {
        LOG_ERROR("Failed to allocate buffers");
        free(pk); free(sk); free(sig);
        return PQC_ERROR_MEMORY_ALLOC;
    }
    
    // Generate keypair and signature for testing
    if (alg->keygen(alg, pk, sk) != 0) {
        LOG_ERROR("Keygen failed during verify setup");
        free(pk); free(sk); free(sig);
        return PQC_ERROR_OPERATION_FAILED;
    }
    
    if (alg->sign(alg, sig, &sig_len, (const uint8_t*)msg, msg_len, sk) != 0) {
        LOG_ERROR("Sign failed during verify setup");
        free(pk); free(sk); free(sig);
        return PQC_ERROR_OPERATION_FAILED;
    }
    
    // Warmup
    if (config->warmup_iterations > 0) {
        LOG_DEBUG("Warmup: %d iterations", config->warmup_iterations);
        for (int i = 0; i < config->warmup_iterations; i++) {
            alg->verify(alg, (const uint8_t*)msg, msg_len, sig, sig_len, pk);
        }
    }
    
    // Benchmark iterations
    LOG_DEBUG("Benchmarking verify: %d iterations", config->num_iterations);
    for (int i = 0; i < config->num_iterations; i++) {
        pqc_timestamp_t start = pqc_timestamp_now();
        int ret = alg->verify(alg, (const uint8_t*)msg, msg_len, sig, sig_len, pk);
        pqc_timestamp_t end = pqc_timestamp_now();
        
        if (ret != 0) {
            LOG_ERROR("Verify failed at iteration %d", i);
            free(pk); free(sk); free(sig);
            return PQC_ERROR_OPERATION_FAILED;
        }
        
        result->samples[i] = pqc_timestamp_diff(start, end);
    }
    
    free(pk); free(sk); free(sig);
    
    return PQC_SUCCESS;
}

// ============================================================================
// Main Benchmark Functions
// ============================================================================

int pqc_benchmark_operation(const PQCAlgorithm *alg,
                           const char *operation,
                           const BenchmarkConfig *config,
                           BenchmarkResult **result) {
    if (alg == NULL || operation == NULL || config == NULL || result == NULL) {
        LOG_ERROR("NULL parameter in benchmark_operation");
        return PQC_ERROR_NULL_POINTER;
    }
    
    // Validate algorithm
    int ret = pqc_algorithm_validate(alg);
    if (ret != PQC_SUCCESS) {
        LOG_ERROR("Algorithm validation failed");
        return ret;
    }
    
    // Validate config
    ret = pqc_benchmark_config_validate(config);
    if (ret != PQC_SUCCESS) {
        LOG_ERROR("Config validation failed");
        return ret;
    }
    
    // Get architecture
    const char *arch = pqc_benchmark_get_architecture();
    
    // Allocate result
    *result = pqc_benchmark_result_alloc(alg->name, operation, arch, 
                                        config->num_iterations);
    if (*result == NULL) {
        LOG_ERROR("Failed to allocate result");
        return PQC_ERROR_MEMORY_ALLOC;
    }
    
    // Dispatch to appropriate benchmark function
    if (strcmp(operation, "keygen") == 0) {
        ret = benchmark_keygen(alg, config, *result);
    } else if (strcmp(operation, "encaps") == 0) {
        ret = benchmark_encaps(alg, config, *result);
    } else if (strcmp(operation, "decaps") == 0) {
        ret = benchmark_decaps(alg, config, *result);
    } else if (strcmp(operation, "sign") == 0) {
        ret = benchmark_sign(alg, config, *result);
    } else if (strcmp(operation, "verify") == 0) {
        ret = benchmark_verify(alg, config, *result);
    } else {
        LOG_ERROR("Unknown operation: %s", operation);
        pqc_benchmark_result_free(*result);
        *result = NULL;
        return PQC_ERROR_INVALID_PARAM;
    }
    
    if (ret != PQC_SUCCESS) {
        LOG_ERROR("Benchmark operation failed");
        pqc_benchmark_result_free(*result);
        *result = NULL;
        return ret;
    }
    
    // Remove outliers if requested
    if (config->remove_outliers) {
        size_t original_count = (*result)->num_samples;
        size_t new_count = pqc_stats_remove_outliers((*result)->samples, 
                                                     original_count,
                                                     config->outlier_threshold);
        (*result)->num_samples = new_count;
        LOG_INFO("Removed %zu outliers from %s", 
                 original_count - new_count, operation);
    }
    
    // Compute statistics
    ret = pqc_benchmark_result_compute_stats(*result);
    if (ret != PQC_SUCCESS) {
        LOG_ERROR("Failed to compute statistics");
        pqc_benchmark_result_free(*result);
        *result = NULL;
        return ret;
    }
    
    if (config->verbose) {
        LOG_INFO("%s %s: mean=%.2f µs, median=%.2f µs, stddev=%.2f µs",
                 alg->name, operation, (*result)->mean, (*result)->median, 
                 (*result)->std_dev);
    }
    
    return PQC_SUCCESS;
}

int pqc_benchmark_algorithm(const PQCAlgorithm *alg,
                           const BenchmarkConfig *config,
                           BenchmarkResultSet **results) {
    if (alg == NULL || config == NULL || results == NULL) {
        LOG_ERROR("NULL parameter in benchmark_algorithm");
        return PQC_ERROR_NULL_POINTER;
    }
    
    // Validate algorithm
    int ret = pqc_algorithm_validate(alg);
    if (ret != PQC_SUCCESS) {
        LOG_ERROR("Algorithm validation failed");
        return ret;
    }
    
    // Validate config
    ret = pqc_benchmark_config_validate(config);
    if (ret != PQC_SUCCESS) {
        LOG_ERROR("Config validation failed");
        return ret;
    }
    
    // Determine operations to benchmark based on algorithm type
    const char *operations[5];
    int num_operations = 0;
    
    if (pqc_algorithm_is_kem(alg)) {
        operations[num_operations++] = "keygen";
        operations[num_operations++] = "encaps";
        operations[num_operations++] = "decaps";
    } else if (pqc_algorithm_is_signature(alg)) {
        operations[num_operations++] = "keygen";
        operations[num_operations++] = "sign";
        operations[num_operations++] = "verify";
    } else {
        LOG_ERROR("Unknown algorithm type");
        return PQC_ERROR_INVALID_PARAM;
    }
    
    // Get architecture
    const char *arch = pqc_benchmark_get_architecture();
    
    // Allocate result set
    *results = pqc_benchmark_result_set_alloc(alg->name, arch, num_operations);
    if (*results == NULL) {
        LOG_ERROR("Failed to allocate result set");
        return PQC_ERROR_MEMORY_ALLOC;
    }
    
    // Benchmark each operation
    LOG_INFO("Benchmarking %s (%s)", alg->name, pqc_algorithm_type_string(alg->type));
    
    for (int i = 0; i < num_operations; i++) {
        BenchmarkResult *result = NULL;
        ret = pqc_benchmark_operation(alg, operations[i], config, &result);
        
        if (ret != PQC_SUCCESS) {
            LOG_ERROR("Failed to benchmark %s", operations[i]);
            pqc_benchmark_result_set_free(*results);
            *results = NULL;
            return ret;
        }
        
        // Copy result into result set
        (*results)->results[i] = *result;
        free(result); // Free the container, but not the contents
    }
    
    return PQC_SUCCESS;
}

// ============================================================================
// Output Functions
// ============================================================================

int pqc_benchmark_write_json(const BenchmarkResultSet *result_set,
                            const char *path) {
    if (result_set == NULL || path == NULL) {
        LOG_ERROR("NULL parameter in write_json");
        return PQC_ERROR_NULL_POINTER;
    }
    
    FILE *fp = fopen(path, "w");
    if (fp == NULL) {
        LOG_ERROR("Failed to open file: %s", path);
        return PQC_ERROR_IO;
    }
    
    fprintf(fp, "{\n");
    fprintf(fp, "  \"algorithm\": \"%s\",\n", result_set->algorithm);
    fprintf(fp, "  \"architecture\": \"%s\",\n", result_set->architecture);
    fprintf(fp, "  \"results\": [\n");
    
    for (int i = 0; i < result_set->num_results; i++) {
        const BenchmarkResult *r = &result_set->results[i];
        
        fprintf(fp, "    {\n");
        fprintf(fp, "      \"operation\": \"%s\",\n", r->operation);
        fprintf(fp, "      \"num_samples\": %d,\n", r->num_samples);
        fprintf(fp, "      \"mean_us\": %.2f,\n", r->mean);
        fprintf(fp, "      \"median_us\": %.2f,\n", r->median);
        fprintf(fp, "      \"stddev_us\": %.2f,\n", r->std_dev);
        fprintf(fp, "      \"min_us\": %.2f,\n", r->min);
        fprintf(fp, "      \"max_us\": %.2f,\n", r->max);
        fprintf(fp, "      \"p95_us\": %.2f,\n", r->p95);
        fprintf(fp, "      \"p99_us\": %.2f\n", r->p99);
        fprintf(fp, "    }%s\n", (i < result_set->num_results - 1) ? "," : "");
    }
    
    fprintf(fp, "  ]\n");
    fprintf(fp, "}\n");
    
    fclose(fp);
    
    LOG_INFO("Wrote JSON results to %s", path);
    
    return PQC_SUCCESS;
}

int pqc_benchmark_write_csv(const BenchmarkResultSet *result_set,
                           const char *path) {
    if (result_set == NULL || path == NULL) {
        LOG_ERROR("NULL parameter in write_csv");
        return PQC_ERROR_NULL_POINTER;
    }
    
    FILE *fp = fopen(path, "w");
    if (fp == NULL) {
        LOG_ERROR("Failed to open file: %s", path);
        return PQC_ERROR_IO;
    }
    
    // Write header
    fprintf(fp, "algorithm,architecture,operation,num_samples,");
    fprintf(fp, "mean_us,median_us,stddev_us,min_us,max_us,p95_us,p99_us\n");
    
    // Write data rows
    for (int i = 0; i < result_set->num_results; i++) {
        const BenchmarkResult *r = &result_set->results[i];
        
        fprintf(fp, "%s,%s,%s,%d,%.2f,%.2f,%.2f,%.2f,%.2f,%.2f,%.2f\n",
                result_set->algorithm,
                result_set->architecture,
                r->operation,
                r->num_samples,
                r->mean,
                r->median,
                r->std_dev,
                r->min,
                r->max,
                r->p95,
                r->p99);
    }
    
    fclose(fp);
    
    LOG_INFO("Wrote CSV results to %s", path);
    
    return PQC_SUCCESS;
}

void pqc_benchmark_print_results(const BenchmarkResultSet *result_set) {
    if (result_set == NULL) {
        return;
    }
    
    printf("\n");
    printf("========================================\n");
    printf("Benchmark Results: %s\n", result_set->algorithm);
    printf("Architecture: %s\n", result_set->architecture);
    printf("========================================\n\n");
    
    for (int i = 0; i < result_set->num_results; i++) {
        const BenchmarkResult *r = &result_set->results[i];
        
        printf("Operation: %s\n", r->operation);
        printf("  Samples:  %d\n", r->num_samples);
        printf("  Mean:     %.2f µs\n", r->mean);
        printf("  Median:   %.2f µs\n", r->median);
        printf("  Std Dev:  %.2f µs\n", r->std_dev);
        printf("  Min:      %.2f µs\n", r->min);
        printf("  Max:      %.2f µs\n", r->max);
        printf("  P95:      %.2f µs\n", r->p95);
        printf("  P99:      %.2f µs\n", r->p99);
        printf("\n");
    }
    
    printf("========================================\n\n");
}

// ============================================================================
// Utility Functions
// ============================================================================

const char* pqc_benchmark_get_architecture(void) {
#if defined(__aarch64__) || defined(__arm64__)
    return "arm64";
#elif defined(__riscv) && (__riscv_xlen == 64)
    return "riscv64";
#elif defined(__x86_64__) || defined(__amd64__) || defined(_M_X64)
    return "native";
#else
    return "unknown";
#endif
}
