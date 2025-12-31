/**
 * @file liboqs_adapter.c
 * @brief liboqs adapter implementation
 * @author Benchmarks-PQC Team
 * @date 2025-11-22
 */

#include "liboqs_adapter.h"
#include "../core/error_codes.h"
#include "../utils/logger.h"
#include <oqs/oqs.h>
#include <stdlib.h>
#include <string.h>

// ============================================================================
// Internal Context Structure
// ============================================================================

typedef struct {
    int initialized;
    // Future: could add caching, statistics, etc.
} liboqs_context_t;

// ============================================================================
// Internal Algorithm Context
// ============================================================================

typedef struct {
    OQS_KEM *kem;      // Non-NULL for KEM algorithms
    OQS_SIG *sig;      // Non-NULL for signature algorithms
} liboqs_alg_context_t;

// ============================================================================
// Supported Algorithms
// ============================================================================

static const char* SUPPORTED_ALGORITHMS[] = {
    "mlkem512",
    "mlkem768",
    "mlkem1024",
    "mldsa44",
    "mldsa65",
    "mldsa87",
    NULL  // Sentinel
};

// ============================================================================
// Algorithm Name Mapping
// ============================================================================

/**
 * @brief Map our algorithm names to liboqs names
 */
static const char* map_algorithm_name(const char *name) {
    if (strcmp(name, "mlkem512") == 0) return "ML-KEM-512";
    if (strcmp(name, "mlkem768") == 0) return "ML-KEM-768";
    if (strcmp(name, "mlkem1024") == 0) return "ML-KEM-1024";
    if (strcmp(name, "mldsa44") == 0) return "ML-DSA-44";
    if (strcmp(name, "mldsa65") == 0) return "ML-DSA-65";
    if (strcmp(name, "mldsa87") == 0) return "ML-DSA-87";
    return NULL;
}

/**
 * @brief Check if algorithm is a KEM
 */
static int is_kem_algorithm(const char *name) {
    return strncmp(name, "mlkem", 5) == 0;
}

/**
 * @brief Check if algorithm is a signature scheme
 */
static int is_sig_algorithm(const char *name) {
    return strncmp(name, "mldsa", 5) == 0;
}

// ============================================================================
// KEM Operation Wrappers
// ============================================================================

static int liboqs_kem_keygen(const PQCAlgorithm *alg, uint8_t *pk, uint8_t *sk) {
    if (!alg || !alg->context || !pk || !sk) {
        return PQC_ERROR_NULL_POINTER;
    }
    
    liboqs_alg_context_t *ctx = (liboqs_alg_context_t*)alg->context;
    if (!ctx->kem) {
        LOG_ERROR("KEM context is NULL");
        return PQC_ERROR_INVALID_STATE;
    }
    
    OQS_STATUS status = OQS_KEM_keypair(ctx->kem, pk, sk);
    if (status != OQS_SUCCESS) {
        LOG_ERROR("OQS_KEM_keypair failed for %s", alg->name);
        return PQC_ERROR_OPERATION_FAILED;
    }
    
    return PQC_SUCCESS;
}

static int liboqs_kem_encaps(const PQCAlgorithm *alg, uint8_t *ct, 
                             uint8_t *ss, const uint8_t *pk) {
    if (!alg || !alg->context || !ct || !ss || !pk) {
        return PQC_ERROR_NULL_POINTER;
    }
    
    liboqs_alg_context_t *ctx = (liboqs_alg_context_t*)alg->context;
    if (!ctx->kem) {
        LOG_ERROR("KEM context is NULL");
        return PQC_ERROR_INVALID_STATE;
    }
    
    OQS_STATUS status = OQS_KEM_encaps(ctx->kem, ct, ss, pk);
    if (status != OQS_SUCCESS) {
        LOG_ERROR("OQS_KEM_encaps failed for %s", alg->name);
        return PQC_ERROR_OPERATION_FAILED;
    }
    
    return PQC_SUCCESS;
}

static int liboqs_kem_decaps(const PQCAlgorithm *alg, uint8_t *ss, 
                             const uint8_t *ct, const uint8_t *sk) {
    if (!alg || !alg->context || !ss || !ct || !sk) {
        return PQC_ERROR_NULL_POINTER;
    }
    
    liboqs_alg_context_t *ctx = (liboqs_alg_context_t*)alg->context;
    if (!ctx->kem) {
        LOG_ERROR("KEM context is NULL");
        return PQC_ERROR_INVALID_STATE;
    }
    
    OQS_STATUS status = OQS_KEM_decaps(ctx->kem, ss, ct, sk);
    if (status != OQS_SUCCESS) {
        LOG_ERROR("OQS_KEM_decaps failed for %s", alg->name);
        return PQC_ERROR_OPERATION_FAILED;
    }
    
    return PQC_SUCCESS;
}

// ============================================================================
// Signature Operation Wrappers
// ============================================================================

static int liboqs_sig_keygen(const PQCAlgorithm *alg, uint8_t *pk, uint8_t *sk) {
    if (!alg || !alg->context || !pk || !sk) {
        return PQC_ERROR_NULL_POINTER;
    }
    
    liboqs_alg_context_t *ctx = (liboqs_alg_context_t*)alg->context;
    if (!ctx->sig) {
        LOG_ERROR("Signature context is NULL");
        return PQC_ERROR_INVALID_STATE;
    }
    
    OQS_STATUS status = OQS_SIG_keypair(ctx->sig, pk, sk);
    if (status != OQS_SUCCESS) {
        LOG_ERROR("OQS_SIG_keypair failed for %s", alg->name);
        return PQC_ERROR_OPERATION_FAILED;
    }
    
    return PQC_SUCCESS;
}

static int liboqs_sig_sign(const PQCAlgorithm *alg, uint8_t *sig, 
                           size_t *sig_len, const uint8_t *msg, 
                           size_t msg_len, const uint8_t *sk) {
    if (!alg || !alg->context || !sig || !sig_len || !msg || !sk) {
        return PQC_ERROR_NULL_POINTER;
    }
    
    liboqs_alg_context_t *ctx = (liboqs_alg_context_t*)alg->context;
    if (!ctx->sig) {
        LOG_ERROR("Signature context is NULL");
        return PQC_ERROR_INVALID_STATE;
    }
    
    OQS_STATUS status = OQS_SIG_sign(ctx->sig, sig, sig_len, msg, msg_len, sk);
    if (status != OQS_SUCCESS) {
        LOG_ERROR("OQS_SIG_sign failed for %s", alg->name);
        return PQC_ERROR_OPERATION_FAILED;
    }
    
    return PQC_SUCCESS;
}

static int liboqs_sig_verify(const PQCAlgorithm *alg, const uint8_t *msg, 
                             size_t msg_len, const uint8_t *sig, 
                             size_t sig_len, const uint8_t *pk) {
    if (!alg || !alg->context || !msg || !sig || !pk) {
        return PQC_ERROR_NULL_POINTER;
    }
    
    liboqs_alg_context_t *ctx = (liboqs_alg_context_t*)alg->context;
    if (!ctx->sig) {
        LOG_ERROR("Signature context is NULL");
        return PQC_ERROR_INVALID_STATE;
    }
    
    OQS_STATUS status = OQS_SIG_verify(ctx->sig, msg, msg_len, sig, sig_len, pk);
    if (status != OQS_SUCCESS) {
        LOG_ERROR("OQS_SIG_verify failed for %s", alg->name);
        return PQC_ERROR_OPERATION_FAILED;
    }
    
    return PQC_SUCCESS;
}

// ============================================================================
// Algorithm Cleanup
// ============================================================================

static void liboqs_algorithm_cleanup(PQCAlgorithm *alg) {
    if (!alg) return;
    
    if (alg->context) {
        liboqs_alg_context_t *ctx = (liboqs_alg_context_t*)alg->context;
        
        if (ctx->kem) {
            OQS_KEM_free(ctx->kem);
            ctx->kem = NULL;
        }
        
        if (ctx->sig) {
            OQS_SIG_free(ctx->sig);
            ctx->sig = NULL;
        }
        
        free(ctx);
        alg->context = NULL;
    }
    
    free(alg);
}

// ============================================================================
// Helper Functions Implementation
// ============================================================================

PQCAlgorithm* liboqs_create_kem_algorithm(const char *name) {
    if (!name) {
        LOG_ERROR("Algorithm name is NULL");
        return NULL;
    }
    
    const char *oqs_name = map_algorithm_name(name);
    if (!oqs_name) {
        LOG_ERROR("Unknown algorithm: %s", name);
        return NULL;
    }
    
    // Check if algorithm is enabled in liboqs
    if (!OQS_KEM_alg_is_enabled(oqs_name)) {
        LOG_ERROR("Algorithm %s is not enabled in liboqs", oqs_name);
        return NULL;
    }
    
    // Create OQS_KEM instance
    OQS_KEM *kem = OQS_KEM_new(oqs_name);
    if (!kem) {
        LOG_ERROR("Failed to create OQS_KEM for %s", oqs_name);
        return NULL;
    }
    
    // Allocate algorithm structure
    PQCAlgorithm *alg = (PQCAlgorithm*)calloc(1, sizeof(PQCAlgorithm));
    if (!alg) {
        LOG_ERROR("Failed to allocate PQCAlgorithm");
        OQS_KEM_free(kem);
        return NULL;
    }
    
    // Allocate context
    liboqs_alg_context_t *ctx = (liboqs_alg_context_t*)calloc(1, sizeof(liboqs_alg_context_t));
    if (!ctx) {
        LOG_ERROR("Failed to allocate algorithm context");
        OQS_KEM_free(kem);
        free(alg);
        return NULL;
    }
    
    ctx->kem = kem;
    ctx->sig = NULL;
    
    // Extract variant from name (e.g., "mlkem512" -> "512")
    const char *variant = name + 5;  // Skip "mlkem"
    
    // Fill in algorithm structure
    alg->name = name;
    alg->variant = variant;
    alg->type = PQC_ALG_TYPE_KEM;
    alg->keygen = liboqs_kem_keygen;
    alg->encaps = liboqs_kem_encaps;
    alg->decaps = liboqs_kem_decaps;
    alg->sign = NULL;
    alg->verify = NULL;
    alg->cleanup = liboqs_algorithm_cleanup;
    alg->pk_len = kem->length_public_key;
    alg->sk_len = kem->length_secret_key;
    alg->ct_len = kem->length_ciphertext;
    alg->sig_len = 0;
    alg->ss_len = kem->length_shared_secret;
    alg->context = ctx;
    
    LOG_DEBUG("Created KEM algorithm: %s (pk=%zu, sk=%zu, ct=%zu, ss=%zu)",
              name, alg->pk_len, alg->sk_len, alg->ct_len, alg->ss_len);
    
    return alg;
}

PQCAlgorithm* liboqs_create_sig_algorithm(const char *name) {
    if (!name) {
        LOG_ERROR("Algorithm name is NULL");
        return NULL;
    }
    
    const char *oqs_name = map_algorithm_name(name);
    if (!oqs_name) {
        LOG_ERROR("Unknown algorithm: %s", name);
        return NULL;
    }
    
    // Check if algorithm is enabled in liboqs
    if (!OQS_SIG_alg_is_enabled(oqs_name)) {
        LOG_ERROR("Algorithm %s is not enabled in liboqs", oqs_name);
        return NULL;
    }
    
    // Create OQS_SIG instance
    OQS_SIG *sig = OQS_SIG_new(oqs_name);
    if (!sig) {
        LOG_ERROR("Failed to create OQS_SIG for %s", oqs_name);
        return NULL;
    }
    
    // Allocate algorithm structure
    PQCAlgorithm *alg = (PQCAlgorithm*)calloc(1, sizeof(PQCAlgorithm));
    if (!alg) {
        LOG_ERROR("Failed to allocate PQCAlgorithm");
        OQS_SIG_free(sig);
        return NULL;
    }
    
    // Allocate context
    liboqs_alg_context_t *ctx = (liboqs_alg_context_t*)calloc(1, sizeof(liboqs_alg_context_t));
    if (!ctx) {
        LOG_ERROR("Failed to allocate algorithm context");
        OQS_SIG_free(sig);
        free(alg);
        return NULL;
    }
    
    ctx->kem = NULL;
    ctx->sig = sig;
    
    // Extract variant from name (e.g., "mldsa44" -> "44")
    const char *variant = name + 5;  // Skip "mldsa"
    
    // Fill in algorithm structure
    alg->name = name;
    alg->variant = variant;
    alg->type = PQC_ALG_TYPE_SIGNATURE;
    alg->keygen = liboqs_sig_keygen;
    alg->encaps = NULL;
    alg->decaps = NULL;
    alg->sign = liboqs_sig_sign;
    alg->verify = liboqs_sig_verify;
    alg->cleanup = liboqs_algorithm_cleanup;
    alg->pk_len = sig->length_public_key;
    alg->sk_len = sig->length_secret_key;
    alg->ct_len = 0;
    alg->sig_len = sig->length_signature;
    alg->ss_len = 0;
    alg->context = ctx;
    
    LOG_DEBUG("Created signature algorithm: %s (pk=%zu, sk=%zu, sig=%zu)",
              name, alg->pk_len, alg->sk_len, alg->sig_len);
    
    return alg;
}

void liboqs_destroy_algorithm(PQCAlgorithm *alg) {
    if (alg && alg->cleanup) {
        alg->cleanup(alg);
    }
}

int liboqs_supports_algorithm(const char *name) {
    if (!name) return 0;
    
    for (int i = 0; SUPPORTED_ALGORITHMS[i] != NULL; i++) {
        if (strcmp(name, SUPPORTED_ALGORITHMS[i]) == 0) {
            return 1;
        }
    }
    
    return 0;
}

const char** liboqs_list_algorithms(int *count) {
    if (count) {
        *count = 0;
        for (int i = 0; SUPPORTED_ALGORITHMS[i] != NULL; i++) {
            (*count)++;
        }
    }
    
    return SUPPORTED_ALGORITHMS;
}

// ============================================================================
// Provider Interface Implementation
// ============================================================================

static void* liboqs_provider_init(const PQCProvider *provider) {
    (void)provider;  // Unused
    
    liboqs_context_t *ctx = (liboqs_context_t*)calloc(1, sizeof(liboqs_context_t));
    if (!ctx) {
        LOG_ERROR("Failed to allocate provider context");
        return NULL;
    }
    
    ctx->initialized = 1;
    LOG_INFO("liboqs provider initialized");
    
    return ctx;
}

static void liboqs_provider_cleanup(const PQCProvider *provider, void *context) {
    (void)provider;  // Unused
    
    if (context) {
        liboqs_context_t *ctx = (liboqs_context_t*)context;
        ctx->initialized = 0;
        free(ctx);
        LOG_INFO("liboqs provider cleaned up");
    }
}

static PQCAlgorithm* liboqs_provider_create_algorithm(const PQCProvider *provider,
                                                       void *context,
                                                       const char *algorithm_name) {
    (void)provider;  // Unused
    
    if (!context) {
        LOG_ERROR("Provider context is NULL");
        return NULL;
    }
    
    liboqs_context_t *ctx = (liboqs_context_t*)context;
    if (!ctx->initialized) {
        LOG_ERROR("Provider not initialized");
        return NULL;
    }
    
    if (!algorithm_name) {
        LOG_ERROR("Algorithm name is NULL");
        return NULL;
    }
    
    // Determine algorithm type and create appropriate instance
    if (is_kem_algorithm(algorithm_name)) {
        return liboqs_create_kem_algorithm(algorithm_name);
    } else if (is_sig_algorithm(algorithm_name)) {
        return liboqs_create_sig_algorithm(algorithm_name);
    } else {
        LOG_ERROR("Unknown algorithm type: %s", algorithm_name);
        return NULL;
    }
}

static void liboqs_provider_destroy_algorithm(const PQCProvider *provider,
                                              void *context,
                                              PQCAlgorithm *alg) {
    (void)provider;  // Unused
    (void)context;   // Unused
    
    liboqs_destroy_algorithm(alg);
}

static const char** liboqs_provider_list_algorithms(const PQCProvider *provider,
                                                     void *context,
                                                     int *count) {
    (void)provider;  // Unused
    (void)context;   // Unused
    
    return liboqs_list_algorithms(count);
}

static bool liboqs_provider_supports_algorithm(const PQCProvider *provider,
                                               void *context,
                                               const char *algorithm_name) {
    (void)provider;  // Unused
    (void)context;   // Unused
    
    return liboqs_supports_algorithm(algorithm_name) != 0;
}

// ============================================================================
// Factory Function
// ============================================================================

static PQCProvider g_liboqs_provider = {
    .name = "liboqs",
    .version = "0.10.0",
    .init = liboqs_provider_init,
    .cleanup = liboqs_provider_cleanup,
    .create_algorithm = liboqs_provider_create_algorithm,
    .destroy_algorithm = liboqs_provider_destroy_algorithm,
    .list_algorithms = liboqs_provider_list_algorithms,
    .supports_algorithm = liboqs_provider_supports_algorithm,
    .provider_data = NULL
};

PQCProvider* create_liboqs_provider(void) {
    return &g_liboqs_provider;
}

void destroy_liboqs_provider(PQCProvider *provider) {
    // Provider is statically allocated, nothing to free
    (void)provider;
}
