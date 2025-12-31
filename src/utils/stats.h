/**
 * @file stats.h
 * @brief Statistical analysis utilities for PQC benchmarks
 * @author Benchmarks-PQC Team
 * @date 2025-11-10
 * 
 * Provides statistical functions for analyzing benchmark results:
 * mean, median, standard deviation, percentiles, min/max.
 */

#ifndef PQC_STATS_H
#define PQC_STATS_H

#include <stdint.h>
#include <stddef.h>

// ============================================================================
// Data Types
// ============================================================================

/**
 * @brief Statistical summary of timing measurements
 */
typedef struct {
    uint64_t min;           ///< Minimum value
    uint64_t max;           ///< Maximum value
    double   mean;          ///< Arithmetic mean
    double   median;        ///< Median (50th percentile)
    double   stddev;        ///< Standard deviation
    double   p95;           ///< 95th percentile
    double   p99;           ///< 99th percentile
    size_t   n_samples;     ///< Number of samples
} pqc_stats_t;

// ============================================================================
// Statistical Functions
// ============================================================================

/**
 * @brief Calculate comprehensive statistics from array of measurements
 * @param data Array of timing measurements in nanoseconds
 * @param n Number of measurements
 * @return Statistical summary
 * 
 * Note: This function sorts the input array in-place for percentile calculations.
 * If you need to preserve the original order, pass a copy.
 * 
 * Returns zeroed structure if data is NULL or n == 0.
 */
pqc_stats_t pqc_stats_calculate(uint64_t *data, size_t n);

/**
 * @brief Calculate arithmetic mean
 * @param data Array of values
 * @param n Number of values
 * @return Mean value, or 0.0 if n == 0
 */
double pqc_stats_mean(const uint64_t *data, size_t n);

/**
 * @brief Calculate median (50th percentile)
 * @param data Array of values (will be sorted in-place)
 * @param n Number of values
 * @return Median value, or 0.0 if n == 0
 * 
 * Warning: Modifies the input array by sorting it.
 */
double pqc_stats_median(uint64_t *data, size_t n);

/**
 * @brief Calculate standard deviation
 * @param data Array of values
 * @param n Number of values
 * @param mean Pre-calculated mean (optional, pass 0.0 to auto-calculate)
 * @return Standard deviation, or 0.0 if n < 2
 * 
 * Uses sample standard deviation formula (n-1 denominator).
 */
double pqc_stats_stddev(const uint64_t *data, size_t n, double mean);

/**
 * @brief Calculate arbitrary percentile
 * @param data Array of values (will be sorted in-place)
 * @param n Number of values
 * @param percentile Percentile to calculate (0.0 to 100.0)
 * @return Percentile value, or 0.0 if n == 0 or percentile is invalid
 * 
 * Uses linear interpolation between nearest values.
 * Warning: Modifies the input array by sorting it.
 */
double pqc_stats_percentile(uint64_t *data, size_t n, double percentile);

/**
 * @brief Find minimum value
 * @param data Array of values
 * @param n Number of values
 * @return Minimum value, or 0 if n == 0
 */
uint64_t pqc_stats_min(const uint64_t *data, size_t n);

/**
 * @brief Find maximum value
 * @param data Array of values
 * @param n Number of values
 * @return Maximum value, or 0 if n == 0
 */
uint64_t pqc_stats_max(const uint64_t *data, size_t n);

// ============================================================================
// Outlier Detection
// ============================================================================

/**
 * @brief Remove outliers using IQR method
 * @param data Array of values (will be sorted in-place)
 * @param n Original number of values
 * @param multiplier IQR multiplier (typical: 1.5 for outliers, 3.0 for extreme)
 * @return Number of values after removing outliers
 * 
 * Removes values outside [Q1 - multiplier*IQR, Q3 + multiplier*IQR].
 * The array is compacted in-place, with valid values at the beginning.
 * Warning: Modifies the input array.
 */
size_t pqc_stats_remove_outliers(uint64_t *data, size_t n, double multiplier);

// ============================================================================
// Utility Functions
// ============================================================================

/**
 * @brief Print statistical summary to stdout
 * @param stats Statistical summary to print
 * @param label Optional label for the measurements (e.g., "KeyGen")
 * 
 * Prints in human-readable format with appropriate time units (ns/μs/ms).
 */
void pqc_stats_print(const pqc_stats_t *stats, const char *label);

/**
 * @brief Format statistics as JSON string
 * @param stats Statistical summary
 * @param buffer Output buffer
 * @param buffer_size Size of output buffer
 * @return Number of characters written (excluding null terminator)
 * 
 * Returns 0 on error or if buffer is too small.
 * JSON format: {"min": 123, "max": 456, "mean": 234.5, ...}
 */
size_t pqc_stats_to_json(const pqc_stats_t *stats, char *buffer, size_t buffer_size);

/**
 * @brief Format statistics as CSV row
 * @param stats Statistical summary
 * @param buffer Output buffer
 * @param buffer_size Size of output buffer
 * @return Number of characters written (excluding null terminator)
 * 
 * Returns 0 on error or if buffer is too small.
 * CSV format: min,max,mean,median,stddev,p95,p99,n_samples
 */
size_t pqc_stats_to_csv(const pqc_stats_t *stats, char *buffer, size_t buffer_size);

/**
 * @brief Get CSV header
 * @return Static string with CSV header
 * 
 * Header: "min,max,mean,median,stddev,p95,p99,n_samples"
 */
const char* pqc_stats_csv_header(void);

#endif // PQC_STATS_H
