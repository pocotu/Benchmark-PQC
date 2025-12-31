/**
 * @file provider_interface.c
 * @brief Implementation of provider interface helper functions
 * @author Benchmarks-PQC Team
 * @date 2025-11-22
 */

#include "provider_interface.h"
#include "error_codes.h"
#include <string.h>

// ============================================================================
// Provider Validation
// ============================================================================

int pqc_provider_validate(const PQCProvider *provider) {
    if (!provider) {
        return PQC_ERROR_NULL_POINTER;
    }
    
    if (!provider->name || !provider->version) {
        return PQC_ERROR_INVALID_PARAM;
    }
    
    if (!provider->init || !provider->cleanup) {
        return PQC_ERROR_INVALID_PARAM;
    }
    
    if (!provider->create_algorithm || !provider->destroy_algorithm) {
        return PQC_ERROR_INVALID_PARAM;
    }
    
    return PQC_SUCCESS;
}

// ============================================================================
// Provider Lifecycle
// ============================================================================

int pqc_provider_initialize(const PQCProvider *provider, void **context) {
    if (!provider || !context) {
        return PQC_ERROR_NULL_POINTER;
    }
    
    int result = pqc_provider_validate(provider);
    if (result != PQC_SUCCESS) {
        return result;
    }
    
    *context = provider->init(provider);
    if (!*context) {
        return PQC_ERROR_PROVIDER_INIT;
    }
    
    return PQC_SUCCESS;
}

void pqc_provider_finalize(const PQCProvider *provider, void *context) {
    if (!provider || !context) {
        return;
    }
    
    if (provider->cleanup) {
        provider->cleanup(provider, context);
    }
}

// ============================================================================
// Algorithm Management
// ============================================================================

int pqc_provider_get_algorithm(const PQCProvider *provider,
                               void *context,
                               const char *algorithm_name,
                               PQCAlgorithm **alg) {
    if (!provider || !context || !algorithm_name || !alg) {
        return PQC_ERROR_NULL_POINTER;
    }
    
    if (!provider->create_algorithm) {
        return PQC_ERROR_NOT_SUPPORTED;
    }
    
    *alg = provider->create_algorithm(provider, context, algorithm_name);
    if (!*alg) {
        return PQC_ERROR_ALGORITHM_NOT_FOUND;
    }
    
    return PQC_SUCCESS;
}

void pqc_provider_release_algorithm(const PQCProvider *provider,
                                   void *context,
                                   PQCAlgorithm *alg) {
    if (!provider || !alg) {
        return;
    }
    
    if (provider->destroy_algorithm) {
        provider->destroy_algorithm(provider, context, alg);
    }
}

// ============================================================================
// Query Functions
// ============================================================================

int pqc_provider_get_algorithms(const PQCProvider *provider,
                               void *context,
                               const char ***algorithms,
                               int *count) {
    if (!provider || !context || !algorithms || !count) {
        return PQC_ERROR_NULL_POINTER;
    }
    
    if (!provider->list_algorithms) {
        return PQC_ERROR_NOT_SUPPORTED;
    }
    
    *algorithms = provider->list_algorithms(provider, context, count);
    if (!*algorithms) {
        return PQC_ERROR_OPERATION_FAILED;
    }
    
    return PQC_SUCCESS;
}

int pqc_provider_check_support(const PQCProvider *provider,
                              void *context,
                              const char *algorithm_name) {
    if (!provider || !context || !algorithm_name) {
        return PQC_ERROR_NULL_POINTER;
    }
    
    if (!provider->supports_algorithm) {
        // If no supports_algorithm function, try to create the algorithm
        PQCAlgorithm *alg = NULL;
        int result = pqc_provider_get_algorithm(provider, context, algorithm_name, &alg);
        if (result == PQC_SUCCESS && alg) {
            pqc_provider_release_algorithm(provider, context, alg);
            return 1;  // Supported
        }
        return 0;  // Not supported
    }
    
    return provider->supports_algorithm(provider, context, algorithm_name) ? 1 : 0;
}

// ============================================================================
// Provider Registry (Optional - Simple Implementation)
// ============================================================================

#define MAX_PROVIDERS 16

static const PQCProvider *g_registered_providers[MAX_PROVIDERS] = {NULL};
static int g_provider_count = 0;

int pqc_provider_register(const PQCProvider *provider) {
    if (!provider) {
        return PQC_ERROR_NULL_POINTER;
    }
    
    int result = pqc_provider_validate(provider);
    if (result != PQC_SUCCESS) {
        return result;
    }
    
    // Check if already registered
    for (int i = 0; i < g_provider_count; i++) {
        if (g_registered_providers[i] == provider ||
            strcmp(g_registered_providers[i]->name, provider->name) == 0) {
            return PQC_SUCCESS;  // Already registered
        }
    }
    
    // Check capacity
    if (g_provider_count >= MAX_PROVIDERS) {
        return PQC_ERROR_BUFFER_TOO_SMALL;
    }
    
    g_registered_providers[g_provider_count++] = provider;
    return PQC_SUCCESS;
}

int pqc_provider_unregister(const char *name) {
    if (!name) {
        return PQC_ERROR_NULL_POINTER;
    }
    
    for (int i = 0; i < g_provider_count; i++) {
        if (strcmp(g_registered_providers[i]->name, name) == 0) {
            // Shift remaining providers
            for (int j = i; j < g_provider_count - 1; j++) {
                g_registered_providers[j] = g_registered_providers[j + 1];
            }
            g_registered_providers[--g_provider_count] = NULL;
            return PQC_SUCCESS;
        }
    }
    
    return PQC_ERROR_ALGORITHM_NOT_FOUND;
}

const PQCProvider* pqc_provider_find(const char *name) {
    if (!name) {
        return NULL;
    }
    
    for (int i = 0; i < g_provider_count; i++) {
        if (strcmp(g_registered_providers[i]->name, name) == 0) {
            return g_registered_providers[i];
        }
    }
    
    return NULL;
}

int pqc_provider_list_all(const PQCProvider ***providers, int *count) {
    if (!providers || !count) {
        return PQC_ERROR_NULL_POINTER;
    }
    
    *providers = g_registered_providers;
    *count = g_provider_count;
    
    return PQC_SUCCESS;
}
