/**
 * @file algorithm_interface.h
 * @brief Generic interface for PQC algorithms
 * @author Benchmarks-PQC Team
 * @date 2025-11-22
 * 
 * Defines a generic interface for post-quantum cryptographic algorithms,
 * supporting both KEM (Key Encapsulation Mechanism) and signature algorithms.
 * This abstraction allows the benchmark engine to work with any PQC algorithm
 * without knowing implementation details.
 */

#ifndef PQC_ALGORITHM_INTERFACE_H
#define PQC_ALGORITHM_INTERFACE_H

#include <stdint.h>
#include <stddef.h>

// ============================================================================
// Forward Declarations
// ============================================================================

typedef struct PQCAlgorithm PQCAlgorithm;

// ============================================================================
// Algorithm Types
// ============================================================================

/**
 * @brief Type of PQC algorithm
 */
typedef enum {
    PQC_ALG_TYPE_KEM,        ///< Key Encapsulation Mechanism
    PQC_ALG_TYPE_SIGNATURE   ///< Digital Signature
} pqc_algorithm_type_t;

// ============================================================================
// Algorithm Operations
// ============================================================================

/**
 * @brief Key generation function pointer
 * @param alg Algorithm instance
 * @param pk Public key output buffer
 * @param sk Secret key output buffer
 * @return 0 on success, negative error code on failure
 */
typedef int (*pqc_keygen_fn)(const PQCAlgorithm *alg, uint8_t *pk, uint8_t *sk);

/**
 * @brief Encapsulation function pointer (KEM only)
 * @param alg Algorithm instance
 * @param ct Ciphertext output buffer
 * @param ss Shared secret output buffer
 * @param pk Public key input
 * @return 0 on success, negative error code on failure
 */
typedef int (*pqc_encaps_fn)(const PQCAlgorithm *alg, uint8_t *ct, 
                             uint8_t *ss, const uint8_t *pk);

/**
 * @brief Decapsulation function pointer (KEM only)
 * @param alg Algorithm instance
 * @param ss Shared secret output buffer
 * @param ct Ciphertext input
 * @param sk Secret key input
 * @return 0 on success, negative error code on failure
 */
typedef int (*pqc_decaps_fn)(const PQCAlgorithm *alg, uint8_t *ss, 
                             const uint8_t *ct, const uint8_t *sk);

/**
 * @brief Signing function pointer (Signature only)
 * @param alg Algorithm instance
 * @param sig Signature output buffer
 * @param sig_len Signature length output
 * @param msg Message to sign
 * @param msg_len Message length
 * @param sk Secret key input
 * @return 0 on success, negative error code on failure
 */
typedef int (*pqc_sign_fn)(const PQCAlgorithm *alg, uint8_t *sig, 
                           size_t *sig_len, const uint8_t *msg, 
                           size_t msg_len, const uint8_t *sk);

/**
 * @brief Verification function pointer (Signature only)
 * @param alg Algorithm instance
 * @param msg Message that was signed
 * @param msg_len Message length
 * @param sig Signature to verify
 * @param sig_len Signature length
 * @param pk Public key input
 * @return 0 on success (valid signature), negative error code on failure
 */
typedef int (*pqc_verify_fn)(const PQCAlgorithm *alg, const uint8_t *msg, 
                             size_t msg_len, const uint8_t *sig, 
                             size_t sig_len, const uint8_t *pk);

/**
 * @brief Cleanup function pointer
 * @param alg Algorithm instance to cleanup
 */
typedef void (*pqc_cleanup_fn)(PQCAlgorithm *alg);

// ============================================================================
// Algorithm Structure
// ============================================================================

/**
 * @brief Generic PQC algorithm interface
 * 
 * This structure provides a uniform interface for all PQC algorithms,
 * regardless of their type (KEM or signature) or implementation library.
 * Function pointers may be NULL if not applicable to the algorithm type.
 */
struct PQCAlgorithm {
    // Metadata
    const char *name;              ///< Algorithm name (e.g., "mlkem512")
    const char *variant;           ///< Variant identifier (e.g., "512")
    pqc_algorithm_type_t type;     ///< Algorithm type (KEM or Signature)
    
    // Function pointers for operations
    pqc_keygen_fn keygen;          ///< Key generation (required)
    pqc_encaps_fn encaps;          ///< Encapsulation (KEM only, NULL for signatures)
    pqc_decaps_fn decaps;          ///< Decapsulation (KEM only, NULL for signatures)
    pqc_sign_fn sign;              ///< Signing (Signature only, NULL for KEM)
    pqc_verify_fn verify;          ///< Verification (Signature only, NULL for KEM)
    pqc_cleanup_fn cleanup;        ///< Cleanup (optional, may be NULL)
    
    // Size metadata (in bytes)
    size_t pk_len;                 ///< Public key length
    size_t sk_len;                 ///< Secret key length
    size_t ct_len;                 ///< Ciphertext length (KEM only, 0 for signatures)
    size_t sig_len;                ///< Signature length (Signature only, 0 for KEM)
    size_t ss_len;                 ///< Shared secret length (KEM only, 0 for signatures)
    
    // Opaque context pointer for implementation-specific data
    void *context;                 ///< Implementation-specific context (optional)
};

// ============================================================================
// Algorithm Interface Functions
// ============================================================================

/**
 * @brief Validate algorithm structure
 * @param alg Algorithm to validate
 * @return 0 if valid, negative error code otherwise
 * 
 * Checks that:
 * - Algorithm pointer is not NULL
 * - Name and variant are not NULL
 * - Required function pointers are not NULL
 * - Size fields are reasonable
 */
int pqc_algorithm_validate(const PQCAlgorithm *alg);

/**
 * @brief Check if algorithm is a KEM
 * @param alg Algorithm to check
 * @return 1 if KEM, 0 otherwise
 */
static inline int pqc_algorithm_is_kem(const PQCAlgorithm *alg) {
    return alg != NULL && alg->type == PQC_ALG_TYPE_KEM;
}

/**
 * @brief Check if algorithm is a signature scheme
 * @param alg Algorithm to check
 * @return 1 if signature, 0 otherwise
 */
static inline int pqc_algorithm_is_signature(const PQCAlgorithm *alg) {
    return alg != NULL && alg->type == PQC_ALG_TYPE_SIGNATURE;
}

/**
 * @brief Get algorithm type as string
 * @param type Algorithm type
 * @return Static string describing the type
 */
static inline const char* pqc_algorithm_type_string(pqc_algorithm_type_t type) {
    switch (type) {
        case PQC_ALG_TYPE_KEM:
            return "KEM";
        case PQC_ALG_TYPE_SIGNATURE:
            return "Signature";
        default:
            return "Unknown";
    }
}

#endif // PQC_ALGORITHM_INTERFACE_H
