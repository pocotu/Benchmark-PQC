/**
 * @file error_codes.h
 * @brief Standard error codes for PQC benchmark system
 * @author Benchmarks-PQC Team
 * @date 2025-11-22
 * 
 * Defines standard error codes used throughout the benchmark system.
 * All functions return int status codes where 0 indicates success.
 */

#ifndef PQC_ERROR_CODES_H
#define PQC_ERROR_CODES_H

// ============================================================================
// Error Codes
// ============================================================================

/**
 * @brief Success code
 */
#define PQC_SUCCESS 0

/**
 * @brief Invalid parameter passed to function
 */
#define PQC_ERROR_INVALID_PARAM -1

/**
 * @brief Memory allocation failed
 */
#define PQC_ERROR_MEMORY_ALLOC -2

/**
 * @brief Provider initialization failed
 */
#define PQC_ERROR_PROVIDER_INIT -3

/**
 * @brief Algorithm not found or not supported
 */
#define PQC_ERROR_ALGORITHM_NOT_FOUND -4

/**
 * @brief Cryptographic operation failed
 */
#define PQC_ERROR_OPERATION_FAILED -5

/**
 * @brief I/O operation failed (file read/write)
 */
#define PQC_ERROR_IO -6

/**
 * @brief Null pointer encountered
 */
#define PQC_ERROR_NULL_POINTER -7

/**
 * @brief Buffer too small for operation
 */
#define PQC_ERROR_BUFFER_TOO_SMALL -8

/**
 * @brief Invalid state for operation
 */
#define PQC_ERROR_INVALID_STATE -9

/**
 * @brief Operation not supported
 */
#define PQC_ERROR_NOT_SUPPORTED -10

// ============================================================================
// Error Handling Utilities
// ============================================================================

/**
 * @brief Convert error code to human-readable string
 * @param error_code Error code to convert
 * @return Static string describing the error
 */
static inline const char* pqc_error_string(int error_code) {
    switch (error_code) {
        case PQC_SUCCESS:
            return "Success";
        case PQC_ERROR_INVALID_PARAM:
            return "Invalid parameter";
        case PQC_ERROR_MEMORY_ALLOC:
            return "Memory allocation failed";
        case PQC_ERROR_PROVIDER_INIT:
            return "Provider initialization failed";
        case PQC_ERROR_ALGORITHM_NOT_FOUND:
            return "Algorithm not found";
        case PQC_ERROR_OPERATION_FAILED:
            return "Operation failed";
        case PQC_ERROR_IO:
            return "I/O error";
        case PQC_ERROR_NULL_POINTER:
            return "Null pointer";
        case PQC_ERROR_BUFFER_TOO_SMALL:
            return "Buffer too small";
        case PQC_ERROR_INVALID_STATE:
            return "Invalid state";
        case PQC_ERROR_NOT_SUPPORTED:
            return "Operation not supported";
        default:
            return "Unknown error";
    }
}

/**
 * @brief Check if error code indicates success
 * @param error_code Error code to check
 * @return 1 if success, 0 otherwise
 */
static inline int pqc_is_success(int error_code) {
    return error_code == PQC_SUCCESS;
}

/**
 * @brief Check if error code indicates failure
 * @param error_code Error code to check
 * @return 1 if failure, 0 otherwise
 */
static inline int pqc_is_error(int error_code) {
    return error_code != PQC_SUCCESS;
}

#endif // PQC_ERROR_CODES_H
