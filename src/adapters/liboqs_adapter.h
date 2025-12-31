/**
 * @file liboqs_adapter.h
 * @brief liboqs adapter implementation for PQC provider interface
 * @author Benchmarks-PQC Team
 * @date 2025-11-22
 * 
 * Provides a concrete implementation of the PQCProvider interface using liboqs.
 * This adapter wraps liboqs-specific calls and translates between the generic
 * PQCAlgorithm interface and OQS_KEM/OQS_SIG structures.
 */

#ifndef LIBOQS_ADAPTER_H
#define LIBOQS_ADAPTER_H

#include "../core/provider_interface.h"
#include "../core/algorithm_interface.h"

// ============================================================================
// Factory Function
// ============================================================================

/**
 * @brief Create a liboqs provider instance
 * @return Pointer to PQCProvider structure, or NULL on failure
 * 
 * The returned provider must be freed using destroy_liboqs_provider().
 * The provider is statically allocated and does not need to be freed,
 * but the context returned by init() must be cleaned up.
 */
PQCProvider* create_liboqs_provider(void);

/**
 * @brief Destroy a liboqs provider instance
 * @param provider Provider to destroy (currently no-op as provider is static)
 * 
 * Note: This function is provided for API completeness but currently does
 * nothing as the provider structure is statically allocated.
 */
void destroy_liboqs_provider(PQCProvider *provider);

// ============================================================================
// Helper Functions
// ============================================================================

/**
 * @brief Create a KEM algorithm instance
 * @param name Algorithm name (e.g., "mlkem512", "mlkem768", "mlkem1024")
 * @return Pointer to PQCAlgorithm, or NULL on failure
 * 
 * Supported algorithms:
 * - mlkem512 (ML-KEM-512)
 * - mlkem768 (ML-KEM-768)
 * - mlkem1024 (ML-KEM-1024)
 */
PQCAlgorithm* liboqs_create_kem_algorithm(const char *name);

/**
 * @brief Create a signature algorithm instance
 * @param name Algorithm name (e.g., "mldsa44", "mldsa65", "mldsa87")
 * @return Pointer to PQCAlgorithm, or NULL on failure
 * 
 * Supported algorithms:
 * - mldsa44 (ML-DSA-44)
 * - mldsa65 (ML-DSA-65)
 * - mldsa87 (ML-DSA-87)
 */
PQCAlgorithm* liboqs_create_sig_algorithm(const char *name);

/**
 * @brief Destroy an algorithm instance created by liboqs adapter
 * @param alg Algorithm to destroy
 */
void liboqs_destroy_algorithm(PQCAlgorithm *alg);

/**
 * @brief Check if an algorithm name is supported by liboqs
 * @param name Algorithm name to check
 * @return 1 if supported, 0 otherwise
 */
int liboqs_supports_algorithm(const char *name);

/**
 * @brief Get list of all supported algorithms
 * @param count Output: number of algorithms
 * @return Array of algorithm name strings (static, do not free)
 */
const char** liboqs_list_algorithms(int *count);

#endif // LIBOQS_ADAPTER_H
