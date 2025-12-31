/**
 * @file logger.h
 * @brief Sistema de logging estructurado para benchmarks PQC
 * @author Benchmarks-PQC Team
 * @date 2024-11-09
 * 
 * Sistema de logging con múltiples niveles, timestamps, colores y 
 * salida tanto a consola como a archivo.
 */

#ifndef PQC_LOGGER_H
#define PQC_LOGGER_H

#include <stdio.h>
#include <stdlib.h>
#include <stdarg.h>
#include <time.h>
#include <string.h>

// ============================================================================
// Niveles de Log
// ============================================================================

typedef enum {
    LOG_LEVEL_TRACE = 0,    ///< Información muy detallada para debugging
    LOG_LEVEL_DEBUG = 1,    ///< Información de debugging
    LOG_LEVEL_INFO = 2,     ///< Información general
    LOG_LEVEL_WARN = 3,     ///< Advertencias
    LOG_LEVEL_ERROR = 4,    ///< Errores
    LOG_LEVEL_FATAL = 5     ///< Errores fatales
} log_level_t;

// ============================================================================
// Colores ANSI para terminal
// ============================================================================

#define COLOR_RESET   "\033[0m"
#define COLOR_RED     "\033[0;31m"
#define COLOR_GREEN   "\033[0;32m"
#define COLOR_YELLOW  "\033[0;33m"
#define COLOR_BLUE    "\033[0;34m"
#define COLOR_MAGENTA "\033[0;35m"
#define COLOR_CYAN    "\033[0;36m"
#define COLOR_GRAY    "\033[0;90m"

// ============================================================================
// Configuración del Logger
// ============================================================================

typedef struct {
    log_level_t min_level;      ///< Nivel mínimo de log a mostrar
    FILE *file_output;          ///< Archivo de salida (NULL si solo consola)
    int use_colors;             ///< 1 para usar colores en consola, 0 para desactivar
    int include_timestamp;      ///< 1 para incluir timestamps
    int include_source_info;    ///< 1 para incluir archivo:línea
} logger_config_t;

// ============================================================================
// Logger Global
// ============================================================================

extern logger_config_t g_logger_config;

// ============================================================================
// Funciones Públicas
// ============================================================================

/**
 * @brief Inicializa el sistema de logging
 * @param config Configuración del logger
 */
void logger_init(logger_config_t config);

/**
 * @brief Cierra el sistema de logging
 */
void logger_close(void);

/**
 * @brief Establece el nivel mínimo de log
 * @param level Nuevo nivel mínimo
 */
void logger_set_level(log_level_t level);

/**
 * @brief Activa/desactiva salida a archivo
 * @param filename Nombre del archivo (NULL para desactivar)
 * @return 0 si éxito, -1 si error
 */
int logger_set_file(const char *filename);

/**
 * @brief Función principal de logging
 * @param level Nivel del mensaje
 * @param file Archivo fuente (__FILE__)
 * @param line Línea fuente (__LINE__)
 * @param func Función fuente (__func__)
 * @param format Formato printf-style
 * @param ... Argumentos variables
 */
void logger_log(log_level_t level, const char *file, int line, 
                const char *func, const char *format, ...);

/**
 * @brief Obtiene el timestamp actual en formato ISO 8601
 * @param buffer Buffer de salida (mínimo 32 bytes)
 * @param size Tamaño del buffer
 */
void logger_get_timestamp(char *buffer, size_t size);

/**
 * @brief Convierte nivel de log a string
 * @param level Nivel de log
 * @return String representando el nivel
 */
const char* logger_level_to_string(log_level_t level);

/**
 * @brief Obtiene el color ANSI para un nivel de log
 * @param level Nivel de log
 * @return String con código de color ANSI
 */
const char* logger_level_to_color(log_level_t level);

// ============================================================================
// Macros de Conveniencia
// ============================================================================

#define LOG_TRACE(...) \
    logger_log(LOG_LEVEL_TRACE, __FILE__, __LINE__, __func__, __VA_ARGS__)

#define LOG_DEBUG(...) \
    logger_log(LOG_LEVEL_DEBUG, __FILE__, __LINE__, __func__, __VA_ARGS__)

#define LOG_INFO(...) \
    logger_log(LOG_LEVEL_INFO, __FILE__, __LINE__, __func__, __VA_ARGS__)

#define LOG_WARN(...) \
    logger_log(LOG_LEVEL_WARN, __FILE__, __LINE__, __func__, __VA_ARGS__)

#define LOG_ERROR(...) \
    logger_log(LOG_LEVEL_ERROR, __FILE__, __LINE__, __func__, __VA_ARGS__)

#define LOG_FATAL(...) \
    logger_log(LOG_LEVEL_FATAL, __FILE__, __LINE__, __func__, __VA_ARGS__)

// ============================================================================
// Macros Especiales para Benchmarking
// ============================================================================

/**
 * @brief Log de inicio de benchmark
 */
#define LOG_BENCHMARK_START(algo, variant, arch) \
    LOG_INFO("Starting benchmark: %s-%s on %s", algo, variant, arch)

/**
 * @brief Log de finalización de benchmark
 */
#define LOG_BENCHMARK_END(algo, variant, arch, duration_ms) \
    LOG_INFO("Completed benchmark: %s-%s on %s (%.2f ms)", \
             algo, variant, arch, duration_ms)

/**
 * @brief Log de resultados de benchmark
 */
#define LOG_BENCHMARK_RESULT(operation, mean_us, median_us, stddev_us) \
    LOG_INFO("  %s: mean=%.2f µs, median=%.2f µs, stddev=%.2f µs", \
             operation, mean_us, median_us, stddev_us)

#endif // PQC_LOGGER_H
