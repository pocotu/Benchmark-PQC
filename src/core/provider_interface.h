/**
 * @file provider_interface.h
 * @brief Provider abstraction for PQC algorithm implementations
 * @author Benchmarks-PQC Team
 * @date 2025-11-22
 * 
 * Defines an abstraction layer for PQC algorithm providers (e.g., liboqs).
 * This allows the benchmark system to work with different PQC libraries
 * without tight coupling to any specific implementation.
 */

#ifndef PQC_PROVIDER_INTERFACE_H
#define PQC_PROVIDER_INTERFACE_H

#include <stddef.h>
#include <stdbool.h>
#include "algorithm_interface.h"

// ============================================================================
// Forward Declarations
// ============================================================================

typedef struct PQCProvider PQCProvider;

// ============================================================================
// Provider Function Pointers
// ============================================================================

/**
 * @brief Provider initialization function
 * @param provider Provider instance
 * @return Opaque context pointer, or NULL on failure
 */
typedef void* (*pqc_provider_init_fn)(const PQCProvider *provider);

/**
 * @brief Provider cleanup function
 * @param provider Provider instance
 * @param context Context returned by init function
 */
typedef void (*pqc_provider_cleanup_fn)(const PQCProvider *provider, void *context);

/**
 * @brief Create algorithm instance
 * @param provider Provider instance
 * @param context Provider context
 * @param algorithm_name Name of algorithm to create (e.g., "mlkem512")
 * @return Pointer to algorithm instance, or NULL on failure
 * 
 * The returned algorithm must be freed using destroy_algorithm.
 */
typedef PQCAlgorithm* (*pqc_provider_create_algorithm_fn)(
    const PQCProvider *provider,
    void *context,
    const char *algorithm_name
);

/**
 * @brief Destroy algorithm instance
 * @param provider Provider instance
 * @param context Provider context
 * @param alg Algorithm to destroy
 */
typedef void (*pqc_provider_destroy_algorithm_fn)(
    const PQCProvider *provider,
    void *context,
    PQCAlgorithm *alg
);

/**
 * @brief List available algorithms
 * @param provider Provider instance
 * @param context Provider context
 * @param count Output: number of algorithms
 * @return Array of algorithm name strings (NULL-terminated)
 * 
 * The returned array is owned by the provider and should not be freed.
 * It remains valid until the provider is cleaned up.
 */
typedef const char** (*pqc_provider_list_algorithms_fn)(
    const PQCProvider *provider,
    void *context,
    int *count
);

/**
 * @brief Check if algorithm is supported
 * @param provider Provider instance
 * @param context Provider context
 * @param algorithm_name Name of algorithm to check
 * @return true if supported, false otherwise
 */
typedef bool (*pqc_provider_supports_algorithm_fn)(
    const PQCProvider *provider,
    void *context,
    const char *algorithm_name
);

// ============================================================================
// Provider Structure
// ============================================================================

/**
 * @brief PQC algorithm provider interface
 * 
 * Represents a provider of PQC algorithm implementations (e.g., liboqs).
 * Providers are responsible for creating and managing algorithm instances.
 */
struct PQCProvider {
    // Metadata
    const char *name;                ///< Provider name (e.g., "liboqs")
    const char *version;             ///< Provider version string
    
    // Lifecycle functions
    pqc_provider_init_fn init;       ///< Initialize provider (required)
    pqc_provider_cleanup_fn cleanup; ///< Cleanup provider (required)
    
    // Algorithm management
    pqc_provider_create_algorithm_fn create_algorithm;   ///< Create algorithm (required)
    pqc_provider_destroy_algorithm_fn destroy_algorithm; ///< Destroy algorithm (required)
    
    // Query functions
    pqc_provider_list_algorithms_fn list_algorithms;     ///< List algorithms (optional)
    pqc_provider_supports_algorithm_fn supports_algorithm; ///< Check support (optional)
    
    // Opaque provider-specific data
    void *provider_data;             ///< Provider-specific data (optional)
};

// ============================================================================
// Provider Interface Functions
// ============================================================================

/**
 * @brief Validate provider structure
 * @param provider Provider to validate
 * @return 0 if valid, negative error code otherwise
 * 
 * Checks that:
 * - Provider pointer is not NULL
 * - Name and version are not NULL
 * - Required function pointers are not NULL
 */
int pqc_provider_validate(const PQCProvider *provider);

/**
 * @brief Initialize a provider
 * @param provider Provider to initialize
 * @param context Output: provider context
 * @return 0 on success, negative error code on failure
 */
int pqc_provider_initialize(const PQCProvider *provider, void **context);

/**
 * @brief Cleanup a provider
 * @param provider Provider to cleanup
 * @param context Provider context from initialization
 */
void pqc_provider_finalize(const PQCProvider *provider, void *context);

/**
 * @brief Create an algorithm instance from a provider
 * @param provider Provider to use
 * @param context Provider context
 * @param algorithm_name Name of algorithm to create
 * @param alg Output: pointer to algorithm instance
 * @return 0 on success, negative error code on failure
 */
int pqc_provider_get_algorithm(const PQCProvider *provider,
                               void *context,
                               const char *algorithm_name,
                               PQCAlgorithm **alg);

/**
 * @brief Destroy an algorithm instance
 * @param provider Provider that created the algorithm
 * @param context Provider context
 * @param alg Algorithm to destroy
 */
void pqc_provider_release_algorithm(const PQCProvider *provider,
                                   void *context,
                                   PQCAlgorithm *alg);

/**
 * @brief Get list of supported algorithms
 * @param provider Provider to query
 * @param context Provider context
 * @param algorithms Output: array of algorithm names
 * @param count Output: number of algorithms
 * @return 0 on success, negative error code on failure
 */
int pqc_provider_get_algorithms(const PQCProvider *provider,
                               void *context,
                               const char ***algorithms,
                               int *count);

/**
 * @brief Check if provider supports an algorithm
 * @param provider Provider to query
 * @param context Provider context
 * @param algorithm_name Name of algorithm to check
 * @return 1 if supported, 0 if not supported, negative error code on failure
 */
int pqc_provider_check_support(const PQCProvider *provider,
                              void *context,
                              const char *algorithm_name);

// ============================================================================
// Provider Registry (Optional)
// ============================================================================

/**
 * @brief Register a provider globally
 * @param provider Provider to register
 * @return 0 on success, negative error code on failure
 * 
 * Allows providers to be looked up by name. Optional feature.
 */
int pqc_provider_register(const PQCProvider *provider);

/**
 * @brief Unregister a provider
 * @param name Name of provider to unregister
 * @return 0 on success, negative error code on failure
 */
int pqc_provider_unregister(const char *name);

/**
 * @brief Find a registered provider by name
 * @param name Name of provider to find
 * @return Pointer to provider, or NULL if not found
 */
const PQCProvider* pqc_provider_find(const char *name);

/**
 * @brief Get list of all registered providers
 * @param providers Output: array of provider pointers
 * @param count Output: number of providers
 * @return 0 on success, negative error code on failure
 */
int pqc_provider_list_all(const PQCProvider ***providers, int *count);

#endif // PQC_PROVIDER_INTERFACE_H
