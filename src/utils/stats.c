/**
 * @file stats.c
 * @brief Implementation of statistical analysis utilities
 * @author Benchmarks-PQC Team
 * @date 2025-11-10
 */

#include "stats.h"
#include "logger.h"
#include <math.h>
#include <stdio.h>
#include <string.h>
#include <stdlib.h>

// ============================================================================
// Helper Functions
// ============================================================================

/**
 * @brief Comparison function for qsort
 */
static int compare_uint64(const void *a, const void *b) {
    uint64_t val_a = *(const uint64_t *)a;
    uint64_t val_b = *(const uint64_t *)b;
    
    if (val_a < val_b) return -1;
    if (val_a > val_b) return 1;
    return 0;
}

/**
 * @brief Sort array in-place
 */
static void sort_array(uint64_t *data, size_t n) {
    if (data != NULL && n > 0) {
        qsort(data, n, sizeof(uint64_t), compare_uint64);
    }
}

// ============================================================================
// Statistical Functions
// ============================================================================

pqc_stats_t pqc_stats_calculate(uint64_t *data, size_t n) {
    pqc_stats_t stats = {0};
    
    if (data == NULL || n == 0) {
        LOG_WARN("pqc_stats_calculate: invalid input (data=%p, n=%zu)", 
                    (void*)data, n);
        return stats;
    }
    
    stats.n_samples = n;
    
    // Calculate mean first (needed for stddev)
    stats.mean = pqc_stats_mean(data, n);
    
    // Calculate min/max
    stats.min = pqc_stats_min(data, n);
    stats.max = pqc_stats_max(data, n);
    
    // Calculate standard deviation
    stats.stddev = pqc_stats_stddev(data, n, stats.mean);
    
    // Sort for percentile calculations (modifies array!)
    sort_array(data, n);
    
    // Calculate percentiles
    stats.median = pqc_stats_percentile(data, n, 50.0);
    stats.p95 = pqc_stats_percentile(data, n, 95.0);
    stats.p99 = pqc_stats_percentile(data, n, 99.0);
    
    return stats;
}

double pqc_stats_mean(const uint64_t *data, size_t n) {
    if (data == NULL || n == 0) {
        return 0.0;
    }
    
    double sum = 0.0;
    for (size_t i = 0; i < n; i++) {
        sum += (double)data[i];
    }
    
    return sum / (double)n;
}

double pqc_stats_median(uint64_t *data, size_t n) {
    if (data == NULL || n == 0) {
        return 0.0;
    }
    
    // Ensure array is sorted
    sort_array(data, n);
    
    if (n % 2 == 0) {
        // Even number of elements: average of two middle values
        return ((double)data[n/2 - 1] + (double)data[n/2]) / 2.0;
    } else {
        // Odd number of elements: middle value
        return (double)data[n/2];
    }
}

double pqc_stats_stddev(const uint64_t *data, size_t n, double mean) {
    if (data == NULL || n < 2) {
        return 0.0;
    }
    
    // Auto-calculate mean if not provided
    if (mean == 0.0) {
        mean = pqc_stats_mean(data, n);
    }
    
    double sum_squared_diff = 0.0;
    for (size_t i = 0; i < n; i++) {
        double diff = (double)data[i] - mean;
        sum_squared_diff += diff * diff;
    }
    
    // Sample standard deviation (n-1)
    double variance = sum_squared_diff / (double)(n - 1);
    return sqrt(variance);
}

double pqc_stats_percentile(uint64_t *data, size_t n, double percentile) {
    if (data == NULL || n == 0) {
        return 0.0;
    }
    
    if (percentile < 0.0 || percentile > 100.0) {
        LOG_WARN("Invalid percentile: %.2f (must be 0-100)", percentile);
        return 0.0;
    }
    
    // Ensure array is sorted
    sort_array(data, n);
    
    if (n == 1) {
        return (double)data[0];
    }
    
    // Linear interpolation method
    double rank = (percentile / 100.0) * (double)(n - 1);
    size_t lower_index = (size_t)floor(rank);
    size_t upper_index = (size_t)ceil(rank);
    
    if (lower_index == upper_index) {
        return (double)data[lower_index];
    }
    
    // Interpolate between lower and upper values
    double fraction = rank - (double)lower_index;
    double lower_value = (double)data[lower_index];
    double upper_value = (double)data[upper_index];
    
    return lower_value + fraction * (upper_value - lower_value);
}

uint64_t pqc_stats_min(const uint64_t *data, size_t n) {
    if (data == NULL || n == 0) {
        return 0;
    }
    
    uint64_t min_val = data[0];
    for (size_t i = 1; i < n; i++) {
        if (data[i] < min_val) {
            min_val = data[i];
        }
    }
    
    return min_val;
}

uint64_t pqc_stats_max(const uint64_t *data, size_t n) {
    if (data == NULL || n == 0) {
        return 0;
    }
    
    uint64_t max_val = data[0];
    for (size_t i = 1; i < n; i++) {
        if (data[i] > max_val) {
            max_val = data[i];
        }
    }
    
    return max_val;
}

// ============================================================================
// Outlier Detection
// ============================================================================

size_t pqc_stats_remove_outliers(uint64_t *data, size_t n, double multiplier) {
    if (data == NULL || n < 4) {
        // Need at least 4 points for meaningful IQR calculation
        return n;
    }
    
    // Sort array
    sort_array(data, n);
    
    // Calculate Q1 (25th percentile) and Q3 (75th percentile)
    double q1 = pqc_stats_percentile(data, n, 25.0);
    double q3 = pqc_stats_percentile(data, n, 75.0);
    double iqr = q3 - q1;
    
    // Calculate bounds
    double lower_bound = q1 - multiplier * iqr;
    double upper_bound = q3 + multiplier * iqr;
    
    LOG_DEBUG("IQR outlier detection: Q1=%.2f, Q3=%.2f, IQR=%.2f, "
              "bounds=[%.2f, %.2f]", q1, q3, iqr, lower_bound, upper_bound);
    
    // Compact array, keeping only non-outliers
    size_t write_idx = 0;
    size_t outliers_removed = 0;
    
    for (size_t read_idx = 0; read_idx < n; read_idx++) {
        double val = (double)data[read_idx];
        if (val >= lower_bound && val <= upper_bound) {
            if (write_idx != read_idx) {
                data[write_idx] = data[read_idx];
            }
            write_idx++;
        } else {
            outliers_removed++;
        }
    }
    
    LOG_INFO("Removed %zu outliers (%.1f%%), kept %zu values", 
             outliers_removed, 
             (double)outliers_removed / (double)n * 100.0,
             write_idx);
    
    return write_idx;
}

// ============================================================================
// Utility Functions
// ============================================================================

void pqc_stats_print(const pqc_stats_t *stats, const char *label) {
    if (stats == NULL) {
        return;
    }
    
    const char *title = (label != NULL) ? label : "Statistics";
    
    printf("\n=== %s ===\n", title);
    printf("Samples:  %zu\n", stats->n_samples);
    printf("Min:      %lu ns (%.3f μs)\n", stats->min, (double)stats->min / 1000.0);
    printf("Max:      %lu ns (%.3f μs)\n", stats->max, (double)stats->max / 1000.0);
    printf("Mean:     %.2f ns (%.3f μs)\n", stats->mean, stats->mean / 1000.0);
    printf("Median:   %.2f ns (%.3f μs)\n", stats->median, stats->median / 1000.0);
    printf("Std Dev:  %.2f ns (%.3f μs)\n", stats->stddev, stats->stddev / 1000.0);
    printf("P95:      %.2f ns (%.3f μs)\n", stats->p95, stats->p95 / 1000.0);
    printf("P99:      %.2f ns (%.3f μs)\n", stats->p99, stats->p99 / 1000.0);
    printf("================\n\n");
}

size_t pqc_stats_to_json(const pqc_stats_t *stats, char *buffer, size_t buffer_size) {
    if (stats == NULL || buffer == NULL || buffer_size == 0) {
        return 0;
    }
    
    int written = snprintf(buffer, buffer_size,
        "{\"min\":%lu,\"max\":%lu,\"mean\":%.2f,\"median\":%.2f,"
        "\"stddev\":%.2f,\"p95\":%.2f,\"p99\":%.2f,\"n_samples\":%zu}",
        stats->min, stats->max, stats->mean, stats->median,
        stats->stddev, stats->p95, stats->p99, stats->n_samples);
    
    if (written < 0 || (size_t)written >= buffer_size) {
        LOG_ERROR("JSON buffer too small (need %d, have %zu)", written, buffer_size);
        return 0;
    }
    
    return (size_t)written;
}

size_t pqc_stats_to_csv(const pqc_stats_t *stats, char *buffer, size_t buffer_size) {
    if (stats == NULL || buffer == NULL || buffer_size == 0) {
        return 0;
    }
    
    int written = snprintf(buffer, buffer_size,
        "%lu,%lu,%.2f,%.2f,%.2f,%.2f,%.2f,%zu",
        stats->min, stats->max, stats->mean, stats->median,
        stats->stddev, stats->p95, stats->p99, stats->n_samples);
    
    if (written < 0 || (size_t)written >= buffer_size) {
        LOG_ERROR("CSV buffer too small (need %d, have %zu)", written, buffer_size);
        return 0;
    }
    
    return (size_t)written;
}

const char* pqc_stats_csv_header(void) {
    return "min,max,mean,median,stddev,p95,p99,n_samples";
}
