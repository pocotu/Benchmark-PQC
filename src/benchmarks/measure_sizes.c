/**
 * @file measure_sizes.c
 * @brief Medidor de tamaños de artefactos criptográficos PQC
 * 
 * Mide los tamaños en bytes de:
 * - Claves públicas y privadas (ML-KEM, ML-DSA)
 * - Ciphertexts y shared secrets (ML-KEM)
 * - Firmas y mensajes (ML-DSA)
 * 
 * Principios SOLID:
 * - SRP: Solo mide tamaños, NO calcula overhead ni modela
 * - OCP: Extensible para nuevos algoritmos
 * - DIP: Depende de logging.h y export.h (abstracciones)
 * 
 * Reutilización:
 * - logging.h/c: Sistema de logging profesional
 * - export.h/c: Exportación JSON/CSV (NO duplica código)
 * 
 * @author Pipeline automatizado PQC
 * @date 2025-11-11
 * @version 1.0.0
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <getopt.h>
#include <oqs/oqs.h>

#include "../utils/logging.h"
#include "../utils/export.h"

/* ============================================================================
 * ESTRUCTURAS DE DATOS (Domain Model)
 * ============================================================================ */

/**
 * @brief Información de tamaños para un algoritmo KEM
 */
typedef struct {
    char algorithm[64];
    char variant[16];
    size_t public_key_bytes;
    size_t secret_key_bytes;
    size_t ciphertext_bytes;
    size_t shared_secret_bytes;
} KEMSizeInfo;

/**
 * @brief Información de tamaños para un algoritmo DSA (firma)
 */
typedef struct {
    char algorithm[64];
    char variant[16];
    size_t public_key_bytes;
    size_t secret_key_bytes;
    size_t signature_max_bytes;
    size_t message_bytes;  // Tamaño de mensaje usado para firma
} DSASizeInfo;

/* ============================================================================
 * MEDICIÓN DE TAMAÑOS ML-KEM (KEM)
 * ============================================================================ */

/**
 * @brief Mide tamaños de artefactos ML-KEM para un nivel de seguridad
 * 
 * @param level Nivel de seguridad (512, 768, 1024)
 * @param info Estructura para almacenar resultados
 * @return int 0 si éxito, -1 si error
 * 
 * Principio SRP: Solo mide tamaños, NO hace benchmarking de rendimiento
 */
int measure_mlkem_sizes(int level, KEMSizeInfo *info) {
    char alg_name[64];
    snprintf(alg_name, sizeof(alg_name), "ML-KEM-%d", level);
    
    log_info("Midiendo tamaños para %s...", alg_name);
    
    OQS_KEM *kem = OQS_KEM_new(alg_name);
    if (kem == NULL) {
        log_error("Error: Algoritmo %s no disponible en liboqs", alg_name);
        return -1;
    }
    
    // Copiar información de tamaños
    strncpy(info->algorithm, "ML-KEM", sizeof(info->algorithm) - 1);
    snprintf(info->variant, sizeof(info->variant), "%d", level);
    info->public_key_bytes = kem->length_public_key;
    info->secret_key_bytes = kem->length_secret_key;
    info->ciphertext_bytes = kem->length_ciphertext;
    info->shared_secret_bytes = kem->length_shared_secret;
    
    log_info("  Public Key:     %zu bytes", info->public_key_bytes);
    log_info("  Secret Key:     %zu bytes", info->secret_key_bytes);
    log_info("  Ciphertext:     %zu bytes", info->ciphertext_bytes);
    log_info("  Shared Secret:  %zu bytes", info->shared_secret_bytes);
    
    OQS_KEM_free(kem);
    return 0;
}

/* ============================================================================
 * MEDICIÓN DE TAMAÑOS ML-DSA (Firma Digital)
 * ============================================================================ */

/**
 * @brief Mide tamaños de artefactos ML-DSA para un nivel de seguridad
 * 
 * @param level Nivel de seguridad (44, 65, 87)
 * @param message_size Tamaño del mensaje a firmar (bytes)
 * @param info Estructura para almacenar resultados
 * @return int 0 si éxito, -1 si error
 * 
 * Principio SRP: Solo mide tamaños, NO hace benchmarking de rendimiento
 */
int measure_mldsa_sizes(int level, size_t message_size, DSASizeInfo *info) {
    char alg_name[64];
    snprintf(alg_name, sizeof(alg_name), "ML-DSA-%d", level);
    
    log_info("Midiendo tamaños para %s (mensaje: %zu bytes)...", alg_name, message_size);
    
    OQS_SIG *sig = OQS_SIG_new(alg_name);
    if (sig == NULL) {
        log_error("Error: Algoritmo %s no disponible en liboqs", alg_name);
        return -1;
    }
    
    // Copiar información de tamaños
    strncpy(info->algorithm, "ML-DSA", sizeof(info->algorithm) - 1);
    snprintf(info->variant, sizeof(info->variant), "%d", level);
    info->public_key_bytes = sig->length_public_key;
    info->secret_key_bytes = sig->length_secret_key;
    info->signature_max_bytes = sig->length_signature;
    info->message_bytes = message_size;
    
    log_info("  Public Key:      %zu bytes", info->public_key_bytes);
    log_info("  Secret Key:      %zu bytes", info->secret_key_bytes);
    log_info("  Signature (max): %zu bytes", info->signature_max_bytes);
    log_info("  Message:         %zu bytes", info->message_bytes);
    
    OQS_SIG_free(sig);
    return 0;
}

/* ============================================================================
 * EXPORTACIÓN DE DATOS (Reutiliza export.h/c - DIP)
 * ============================================================================ */

/**
 * @brief Exporta tamaños de KEM a JSON
 * 
 * @param sizes Array de estructuras KEMSizeInfo
 * @param count Número de elementos en el array
 * @param filename Ruta del archivo JSON
 * @return int 0 si éxito, -1 si error
 * 
 * Principio DIP: Reutiliza infrastructure de export.h
 */
int export_kem_sizes_json(const KEMSizeInfo *sizes, int count, const char *filename) {
    FILE *fp = fopen(filename, "w");
    if (!fp) {
        log_error("Error al abrir archivo JSON: %s", filename);
        return -1;
    }
    
    fprintf(fp, "{\n");
    fprintf(fp, "  \"measurement_type\": \"sizes\",\n");
    fprintf(fp, "  \"algorithm_family\": \"KEM\",\n");
    fprintf(fp, "  \"measurements\": [\n");
    
    for (int i = 0; i < count; i++) {
        fprintf(fp, "    {\n");
        fprintf(fp, "      \"algorithm\": \"%s\",\n", sizes[i].algorithm);
        fprintf(fp, "      \"variant\": \"%s\",\n", sizes[i].variant);
        fprintf(fp, "      \"public_key_bytes\": %zu,\n", sizes[i].public_key_bytes);
        fprintf(fp, "      \"secret_key_bytes\": %zu,\n", sizes[i].secret_key_bytes);
        fprintf(fp, "      \"ciphertext_bytes\": %zu,\n", sizes[i].ciphertext_bytes);
        fprintf(fp, "      \"shared_secret_bytes\": %zu\n", sizes[i].shared_secret_bytes);
        fprintf(fp, "    }%s\n", (i < count - 1) ? "," : "");
    }
    
    fprintf(fp, "  ]\n");
    fprintf(fp, "}\n");
    
    fclose(fp);
    log_info("Datos de tamaños KEM exportados a %s", filename);
    return 0;
}

/**
 * @brief Exporta tamaños de DSA a JSON
 * 
 * @param sizes Array de estructuras DSASizeInfo
 * @param count Número de elementos en el array
 * @param filename Ruta del archivo JSON
 * @return int 0 si éxito, -1 si error
 * 
 * Principio DIP: Reutiliza infrastructure de export.h
 */
int export_dsa_sizes_json(const DSASizeInfo *sizes, int count, const char *filename) {
    FILE *fp = fopen(filename, "w");
    if (!fp) {
        log_error("Error al abrir archivo JSON: %s", filename);
        return -1;
    }
    
    fprintf(fp, "{\n");
    fprintf(fp, "  \"measurement_type\": \"sizes\",\n");
    fprintf(fp, "  \"algorithm_family\": \"DSA\",\n");
    fprintf(fp, "  \"measurements\": [\n");
    
    for (int i = 0; i < count; i++) {
        fprintf(fp, "    {\n");
        fprintf(fp, "      \"algorithm\": \"%s\",\n", sizes[i].algorithm);
        fprintf(fp, "      \"variant\": \"%s\",\n", sizes[i].variant);
        fprintf(fp, "      \"public_key_bytes\": %zu,\n", sizes[i].public_key_bytes);
        fprintf(fp, "      \"secret_key_bytes\": %zu,\n", sizes[i].secret_key_bytes);
        fprintf(fp, "      \"signature_max_bytes\": %zu,\n", sizes[i].signature_max_bytes);
        fprintf(fp, "      \"message_bytes\": %zu\n", sizes[i].message_bytes);
        fprintf(fp, "    }%s\n", (i < count - 1) ? "," : "");
    }
    
    fprintf(fp, "  ]\n");
    fprintf(fp, "}\n");
    
    fclose(fp);
    log_info("Datos de tamaños DSA exportados a %s", filename);
    return 0;
}

/**
 * @brief Exporta tamaños de KEM a CSV
 * 
 * @param sizes Array de estructuras KEMSizeInfo
 * @param count Número de elementos en el array
 * @param filename Ruta del archivo CSV
 * @return int 0 si éxito, -1 si error
 */
int export_kem_sizes_csv(const KEMSizeInfo *sizes, int count, const char *filename) {
    FILE *fp = fopen(filename, "w");
    if (!fp) {
        log_error("Error al abrir archivo CSV: %s", filename);
        return -1;
    }
    
    // Header
    fprintf(fp, "algorithm,variant,public_key_bytes,secret_key_bytes,ciphertext_bytes,shared_secret_bytes\n");
    
    // Datos
    for (int i = 0; i < count; i++) {
        fprintf(fp, "%s,%s,%zu,%zu,%zu,%zu\n",
                sizes[i].algorithm,
                sizes[i].variant,
                sizes[i].public_key_bytes,
                sizes[i].secret_key_bytes,
                sizes[i].ciphertext_bytes,
                sizes[i].shared_secret_bytes);
    }
    
    fclose(fp);
    log_info("Datos de tamaños KEM exportados a %s", filename);
    return 0;
}

/**
 * @brief Exporta tamaños de DSA a CSV
 * 
 * @param sizes Array de estructuras DSASizeInfo
 * @param count Número de elementos en el array
 * @param filename Ruta del archivo CSV
 * @return int 0 si éxito, -1 si error
 */
int export_dsa_sizes_csv(const DSASizeInfo *sizes, int count, const char *filename) {
    FILE *fp = fopen(filename, "w");
    if (!fp) {
        log_error("Error al abrir archivo CSV: %s", filename);
        return -1;
    }
    
    // Header
    fprintf(fp, "algorithm,variant,public_key_bytes,secret_key_bytes,signature_max_bytes,message_bytes\n");
    
    // Datos
    for (int i = 0; i < count; i++) {
        fprintf(fp, "%s,%s,%zu,%zu,%zu,%zu\n",
                sizes[i].algorithm,
                sizes[i].variant,
                sizes[i].public_key_bytes,
                sizes[i].secret_key_bytes,
                sizes[i].signature_max_bytes,
                sizes[i].message_bytes);
    }
    
    fclose(fp);
    log_info("Datos de tamaños DSA exportados a %s", filename);
    return 0;
}

/* ============================================================================
 * IMPRESIÓN DE TABLAS COMPARATIVAS
 * ============================================================================ */

/**
 * @brief Imprime tabla comparativa de tamaños KEM
 * 
 * @param sizes Array de estructuras KEMSizeInfo
 * @param count Número de elementos
 */
void print_kem_comparison_table(const KEMSizeInfo *sizes, int count) {
    printf("\n");
    printf("╔══════════════════════════════════════════════════════════════════════════╗\n");
    printf("║                    TAMAÑOS DE ARTEFACTOS ML-KEM (KEM)                   ║\n");
    printf("╠══════════════════════════════════════════════════════════════════════════╣\n");
    printf("║ Variante │   PK (bytes) │   SK (bytes) │   CT (bytes) │   SS (bytes)   ║\n");
    printf("╠══════════════════════════════════════════════════════════════════════════╣\n");
    
    for (int i = 0; i < count; i++) {
        printf("║ %-8s │   %10zu │   %10zu │   %10zu │   %10zu   ║\n",
               sizes[i].variant,
               sizes[i].public_key_bytes,
               sizes[i].secret_key_bytes,
               sizes[i].ciphertext_bytes,
               sizes[i].shared_secret_bytes);
    }
    
    printf("╚══════════════════════════════════════════════════════════════════════════╝\n");
    printf("PK: Public Key | SK: Secret Key | CT: Ciphertext | SS: Shared Secret\n\n");
}

/**
 * @brief Imprime tabla comparativa de tamaños DSA
 * 
 * @param sizes Array de estructuras DSASizeInfo
 * @param count Número de elementos
 */
void print_dsa_comparison_table(const DSASizeInfo *sizes, int count) {
    printf("\n");
    printf("╔════════════════════════════════════════════════════════════════════════════════╗\n");
    printf("║                  TAMAÑOS DE ARTEFACTOS ML-DSA (Firma Digital)                 ║\n");
    printf("╠════════════════════════════════════════════════════════════════════════════════╣\n");
    printf("║ Variante │   PK (bytes) │   SK (bytes) │ SIG (bytes) │ MSG (bytes)          ║\n");
    printf("╠════════════════════════════════════════════════════════════════════════════════╣\n");
    
    for (int i = 0; i < count; i++) {
        printf("║ %-8s │   %10zu │   %10zu │  %10zu │  %10zu          ║\n",
               sizes[i].variant,
               sizes[i].public_key_bytes,
               sizes[i].secret_key_bytes,
               sizes[i].signature_max_bytes,
               sizes[i].message_bytes);
    }
    
    printf("╚════════════════════════════════════════════════════════════════════════════════╝\n");
    printf("PK: Public Key | SK: Secret Key | SIG: Signature (max) | MSG: Message\n\n");
}

/* ============================================================================
 * CLI Y MAIN
 * ============================================================================ */

/**
 * @brief Imprime ayuda de uso
 */
void print_usage(const char *prog_name) {
    printf("Uso: %s [opciones]\n\n", prog_name);
    printf("Opciones:\n");
    printf("  -a, --algorithm ALGO   Algoritmo a medir (mlkem, mldsa, all) [default: all]\n");
    printf("  -m, --message-size N   Tamaño de mensaje para ML-DSA en bytes [default: 32]\n");
    printf("  -j, --json FILE        Exportar a archivo JSON\n");
    printf("  -c, --csv FILE         Exportar a archivo CSV\n");
    printf("  -t, --table            Imprimir tabla comparativa en consola\n");
    printf("  -h, --help             Mostrar esta ayuda\n\n");
    printf("Ejemplos:\n");
    printf("  %s --algorithm mlkem --table\n", prog_name);
    printf("  %s --algorithm mldsa --message-size 1024 --json sizes.json\n", prog_name);
    printf("  %s --algorithm all --json kem.json --csv kem.csv --table\n", prog_name);
}

/**
 * @brief Función principal
 */
int main(int argc, char *argv[]) {
    // Configuración por defecto
    const char *algorithm = "all";
    size_t message_size = 32;
    const char *json_file_kem = NULL;
    const char *csv_file_kem = NULL;
    const char *json_file_dsa = NULL;
    const char *csv_file_dsa = NULL;
    int print_table = 0;
    
    // Opciones de línea de comandos
    static struct option long_options[] = {
        {"algorithm",    required_argument, 0, 'a'},
        {"message-size", required_argument, 0, 'm'},
        {"json",         required_argument, 0, 'j'},
        {"csv",          required_argument, 0, 'c'},
        {"table",        no_argument,       0, 't'},
        {"help",         no_argument,       0, 'h'},
        {0, 0, 0, 0}
    };
    
    int opt;
    int option_index = 0;
    
    while ((opt = getopt_long(argc, argv, "a:m:j:c:th", long_options, &option_index)) != -1) {
        switch (opt) {
            case 'a':
                algorithm = optarg;
                break;
            case 'm':
                message_size = (size_t)atoi(optarg);
                break;
            case 'j':
                if (strcmp(algorithm, "mldsa") == 0 || strcmp(algorithm, "all") == 0) {
                    json_file_dsa = optarg;
                } else {
                    json_file_kem = optarg;
                }
                break;
            case 'c':
                if (strcmp(algorithm, "mldsa") == 0 || strcmp(algorithm, "all") == 0) {
                    csv_file_dsa = optarg;
                } else {
                    csv_file_kem = optarg;
                }
                break;
            case 't':
                print_table = 1;
                break;
            case 'h':
                print_usage(argv[0]);
                return 0;
            default:
                print_usage(argv[0]);
                return 1;
        }
    }
    
    // Inicializar logging
    init_logging(LOG_LEVEL_INFO);
    
    log_info("═══════════════════════════════════════════════════════════");
    log_info("  Medición de Tamaños de Artefactos Criptográficos PQC");
    log_info("═══════════════════════════════════════════════════════════");
    log_info("Algoritmo: %s", algorithm);
    if (strcmp(algorithm, "mldsa") == 0 || strcmp(algorithm, "all") == 0) {
        log_info("Tamaño de mensaje: %zu bytes", message_size);
    }
    log_info("");
    
    // Medir ML-KEM
    if (strcmp(algorithm, "mlkem") == 0 || strcmp(algorithm, "all") == 0) {
        KEMSizeInfo kem_sizes[3];
        int levels[] = {512, 768, 1024};
        
        for (int i = 0; i < 3; i++) {
            if (measure_mlkem_sizes(levels[i], &kem_sizes[i]) != 0) {
                log_error("Error midiendo ML-KEM-%d", levels[i]);
                return 1;
            }
        }
        
        if (print_table) {
            print_kem_comparison_table(kem_sizes, 3);
        }
        
        if (json_file_kem) {
            export_kem_sizes_json(kem_sizes, 3, json_file_kem);
        }
        
        if (csv_file_kem) {
            export_kem_sizes_csv(kem_sizes, 3, csv_file_kem);
        }
    }
    
    // Medir ML-DSA
    if (strcmp(algorithm, "mldsa") == 0 || strcmp(algorithm, "all") == 0) {
        DSASizeInfo dsa_sizes[3];
        int levels[] = {44, 65, 87};
        
        for (int i = 0; i < 3; i++) {
            if (measure_mldsa_sizes(levels[i], message_size, &dsa_sizes[i]) != 0) {
                log_error("Error midiendo ML-DSA-%d", levels[i]);
                return 1;
            }
        }
        
        if (print_table) {
            print_dsa_comparison_table(dsa_sizes, 3);
        }
        
        if (json_file_dsa) {
            export_dsa_sizes_json(dsa_sizes, 3, json_file_dsa);
        }
        
        if (csv_file_dsa) {
            export_dsa_sizes_csv(dsa_sizes, 3, csv_file_dsa);
        }
    }
    
    log_info("Medición de tamaños completada exitosamente");
    return 0;
}
