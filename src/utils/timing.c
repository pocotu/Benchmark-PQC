/**
 * @file timing.c
 * @brief Implementation of high-precision timing utilities
 * @author Benchmarks-PQC Team
 * @date 2025-11-10
 */

#include "timing.h"
#include "logger.h"
#include <errno.h>
#include <string.h>

// ============================================================================
// Core Timing Functions
// ============================================================================

pqc_timestamp_t pqc_timestamp_now(void) {
    pqc_timestamp_t timestamp;
    
    if (clock_gettime(CLOCK_MONOTONIC, &timestamp.ts) != 0) {
        // Log error but continue with zeroed timestamp
        LOG_ERROR("clock_gettime failed: %s", strerror(errno));
        timestamp.ts.tv_sec = 0;
        timestamp.ts.tv_nsec = 0;
    }
    
    return timestamp;
}

pqc_time_ns_t pqc_timestamp_diff(pqc_timestamp_t start, pqc_timestamp_t end) {
    // Calculate difference in seconds and nanoseconds
    int64_t sec_diff = end.ts.tv_sec - start.ts.tv_sec;
    int64_t nsec_diff = end.ts.tv_nsec - start.ts.tv_nsec;
    
    // Convert to total nanoseconds
    pqc_time_ns_t total_ns = (pqc_time_ns_t)(sec_diff * 1000000000LL + nsec_diff);
    
    return total_ns;
}

// ============================================================================
// Benchmarking Utilities
// ============================================================================

void pqc_timing_warmup(int iterations, void (*operation)(void *), void *data) {
    if (operation == NULL) {
        LOG_WARN("pqc_timing_warmup: NULL operation provided");
        return;
    }
    
    if (iterations <= 0) {
        LOG_WARN("pqc_timing_warmup: invalid iterations (%d)", iterations);
        return;
    }
    
    LOG_DEBUG("Starting warmup: %d iterations", iterations);
    
    for (int i = 0; i < iterations; i++) {
        operation(data);
    }
    
    LOG_DEBUG("Warmup completed");
}

void pqc_timing_sleep_ns(pqc_time_ns_t ns) {
    struct timespec req;
    struct timespec rem;
    
    // Convert nanoseconds to timespec
    req.tv_sec = ns / 1000000000ULL;
    req.tv_nsec = ns % 1000000000ULL;
    
    // Handle interruptions
    while (nanosleep(&req, &rem) != 0) {
        if (errno == EINTR) {
            // Interrupted by signal, continue with remaining time
            req = rem;
        } else {
            LOG_ERROR("nanosleep failed: %s", strerror(errno));
            break;
        }
    }
}

pqc_time_ns_t pqc_timing_resolution(void) {
    struct timespec res;
    
    if (clock_getres(CLOCK_MONOTONIC, &res) != 0) {
        LOG_ERROR("clock_getres failed: %s", strerror(errno));
        return 1; // Assume 1ns resolution on error
    }
    
    pqc_time_ns_t resolution = (pqc_time_ns_t)(res.tv_sec * 1000000000ULL + res.tv_nsec);
    
    LOG_DEBUG("Timing resolution: %lu ns", resolution);
    
    return resolution;
}
