/**
 * @file algorithm_interface.c
 * @brief Implementation of algorithm interface helper functions
 * @author Benchmarks-PQC Team
 * @date 2025-11-22
 */

#include "algorithm_interface.h"
#include "error_codes.h"

// ============================================================================
// Algorithm Validation
// ============================================================================

int pqc_algorithm_validate(const PQCAlgorithm *alg) {
    if (!alg) {
        return PQC_ERROR_NULL_POINTER;
    }
    
    // Check required fields
    if (!alg->name || !alg->variant) {
        return PQC_ERROR_INVALID_PARAM;
    }
    
    // Check that keygen is always present
    if (!alg->keygen) {
        return PQC_ERROR_INVALID_PARAM;
    }
    
    // Validate based on algorithm type
    if (alg->type == PQC_ALG_TYPE_KEM) {
        // KEM must have encaps and decaps
        if (!alg->encaps || !alg->decaps) {
            return PQC_ERROR_INVALID_PARAM;
        }
        
        // KEM must have valid sizes
        if (alg->pk_len == 0 || alg->sk_len == 0 || 
            alg->ct_len == 0 || alg->ss_len == 0) {
            return PQC_ERROR_INVALID_PARAM;
        }
        
        // KEM should not have signature operations
        if (alg->sign || alg->verify || alg->sig_len != 0) {
            return PQC_ERROR_INVALID_PARAM;
        }
    } else if (alg->type == PQC_ALG_TYPE_SIGNATURE) {
        // Signature must have sign and verify
        if (!alg->sign || !alg->verify) {
            return PQC_ERROR_INVALID_PARAM;
        }
        
        // Signature must have valid sizes
        if (alg->pk_len == 0 || alg->sk_len == 0 || alg->sig_len == 0) {
            return PQC_ERROR_INVALID_PARAM;
        }
        
        // Signature should not have KEM operations
        if (alg->encaps || alg->decaps || alg->ct_len != 0 || alg->ss_len != 0) {
            return PQC_ERROR_INVALID_PARAM;
        }
    } else {
        return PQC_ERROR_INVALID_PARAM;
    }
    
    return PQC_SUCCESS;
}
