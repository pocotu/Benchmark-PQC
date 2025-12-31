/**
 * @file timing.h
 * @brief High-precision timing utilities for PQC benchmarks
 * @author Benchmarks-PQC Team
 * @date 2025-11-10
 * 
 * Provides nanosecond-precision timing for accurate performance measurement
 * of cryptographic operations.
 */

#ifndef PQC_TIMING_H
#define PQC_TIMING_H

#include <stdint.h>
#include <time.h>

// ============================================================================
// Data Types
// ============================================================================

/**
 * @brief Timestamp structure using CLOCK_MONOTONIC
 * 
 * Uses monotonic clock to avoid issues with system time adjustments.
 */
typedef struct {
    struct timespec ts;  ///< Internal timespec structure
} pqc_timestamp_t;

/**
 * @brief Time measurement result in nanoseconds
 */
typedef uint64_t pqc_time_ns_t;

// ============================================================================
// Timing Functions
// ============================================================================

/**
 * @brief Get current timestamp
 * @return Current timestamp
 * 
 * Uses CLOCK_MONOTONIC for reliable, high-resolution timing.
 */
pqc_timestamp_t pqc_timestamp_now(void);

/**
 * @brief Calculate elapsed time between two timestamps
 * @param start Start timestamp
 * @param end End timestamp
 * @return Elapsed time in nanoseconds
 * 
 * Assumes end >= start. If not, behavior is undefined.
 */
pqc_time_ns_t pqc_timestamp_diff(pqc_timestamp_t start, pqc_timestamp_t end);

/**
 * @brief Convert nanoseconds to microseconds
 * @param ns Time in nanoseconds
 * @return Time in microseconds
 */
static inline double pqc_ns_to_us(pqc_time_ns_t ns) {
    return (double)ns / 1000.0;
}

/**
 * @brief Convert nanoseconds to milliseconds
 * @param ns Time in nanoseconds
 * @return Time in milliseconds
 */
static inline double pqc_ns_to_ms(pqc_time_ns_t ns) {
    return (double)ns / 1000000.0;
}

/**
 * @brief Convert nanoseconds to seconds
 * @param ns Time in nanoseconds
 * @return Time in seconds
 */
static inline double pqc_ns_to_s(pqc_time_ns_t ns) {
    return (double)ns / 1000000000.0;
}

// ============================================================================
// Benchmarking Utilities
// ============================================================================

/**
 * @brief Warmup CPU caches and branch predictor
 * @param iterations Number of warmup iterations
 * @param operation Function pointer to operation to warmup
 * @param data Opaque data pointer passed to operation
 * 
 * Runs the operation multiple times to stabilize CPU state before
 * actual measurements. Recommended: 100-1000 iterations.
 */
void pqc_timing_warmup(int iterations, void (*operation)(void *), void *data);

/**
 * @brief Sleep for specified nanoseconds (best effort)
 * @param ns Nanoseconds to sleep
 * 
 * Uses nanosleep() for sub-millisecond delays.
 * Actual sleep time may vary due to scheduler granularity.
 */
void pqc_timing_sleep_ns(pqc_time_ns_t ns);

/**
 * @brief Get timing resolution of the system
 * @return Resolution in nanoseconds
 * 
 * Returns the resolution of CLOCK_MONOTONIC on the current system.
 * Typical values: 1ns (modern Linux), 100ns (older systems).
 */
pqc_time_ns_t pqc_timing_resolution(void);

// ============================================================================
// Benchmark Macros
// ============================================================================

/**
 * @brief Simple timing macro for single operation
 * 
 * Usage:
 * @code
 * pqc_time_ns_t elapsed;
 * PQC_TIME_OPERATION(elapsed, {
 *     // Code to measure
 *     crypto_operation();
 * });
 * @endcode
 */
#define PQC_TIME_OPERATION(elapsed_var, operation) \
    do { \
        pqc_timestamp_t _start = pqc_timestamp_now(); \
        operation; \
        pqc_timestamp_t _end = pqc_timestamp_now(); \
        elapsed_var = pqc_timestamp_diff(_start, _end); \
    } while(0)

#endif // PQC_TIMING_H
