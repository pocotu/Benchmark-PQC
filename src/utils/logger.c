/**
 * @file logger.c
 * @brief Implementación del sistema de logging estructurado
 */

#include "logger.h"
#include <sys/time.h>
#include <unistd.h>

// ============================================================================
// Variables Globales
// ============================================================================

logger_config_t g_logger_config = {
    .min_level = LOG_LEVEL_INFO,
    .file_output = NULL,
    .use_colors = 1,  // Por defecto activado si es TTY
    .include_timestamp = 1,
    .include_source_info = 0
};

// ============================================================================
// Implementaciones
// ============================================================================

void logger_init(logger_config_t config) {
    g_logger_config = config;
    
    // Detectar si stdout es un TTY para colores
    if (config.use_colors == -1) {
        g_logger_config.use_colors = isatty(fileno(stdout));
    }
    
    if (config.file_output != NULL && config.include_timestamp) {
        char timestamp[64];
        logger_get_timestamp(timestamp, sizeof(timestamp));
        fprintf(config.file_output, "\n=== Log started at %s ===\n\n", timestamp);
        fflush(config.file_output);
    }
}

void logger_close(void) {
    if (g_logger_config.file_output != NULL) {
        char timestamp[64];
        logger_get_timestamp(timestamp, sizeof(timestamp));
        fprintf(g_logger_config.file_output, 
                "\n=== Log ended at %s ===\n", timestamp);
        fclose(g_logger_config.file_output);
        g_logger_config.file_output = NULL;
    }
}

void logger_set_level(log_level_t level) {
    g_logger_config.min_level = level;
}

int logger_set_file(const char *filename) {
    // Cerrar archivo anterior si existe
    if (g_logger_config.file_output != NULL) {
        fclose(g_logger_config.file_output);
        g_logger_config.file_output = NULL;
    }
    
    // Abrir nuevo archivo si se proporciona
    if (filename != NULL) {
        g_logger_config.file_output = fopen(filename, "a");
        if (g_logger_config.file_output == NULL) {
            return -1;
        }
        
        // Escribir encabezado
        char timestamp[64];
        logger_get_timestamp(timestamp, sizeof(timestamp));
        fprintf(g_logger_config.file_output, 
                "\n=== Log started at %s ===\n\n", timestamp);
        fflush(g_logger_config.file_output);
    }
    
    return 0;
}

void logger_get_timestamp(char *buffer, size_t size) {
    struct timeval tv;
    gettimeofday(&tv, NULL);
    
    struct tm *tm_info = localtime(&tv.tv_sec);
    
    // Formato ISO 8601 con milisegundos
    strftime(buffer, size, "%Y-%m-%d %H:%M:%S", tm_info);
    snprintf(buffer + strlen(buffer), size - strlen(buffer), 
             ".%03ld", tv.tv_usec / 1000);
}

const char* logger_level_to_string(log_level_t level) {
    switch (level) {
        case LOG_LEVEL_TRACE: return "TRACE";
        case LOG_LEVEL_DEBUG: return "DEBUG";
        case LOG_LEVEL_INFO:  return "INFO ";
        case LOG_LEVEL_WARN:  return "WARN ";
        case LOG_LEVEL_ERROR: return "ERROR";
        case LOG_LEVEL_FATAL: return "FATAL";
        default:              return "?????";
    }
}

const char* logger_level_to_color(log_level_t level) {
    switch (level) {
        case LOG_LEVEL_TRACE: return COLOR_GRAY;
        case LOG_LEVEL_DEBUG: return COLOR_CYAN;
        case LOG_LEVEL_INFO:  return COLOR_GREEN;
        case LOG_LEVEL_WARN:  return COLOR_YELLOW;
        case LOG_LEVEL_ERROR: return COLOR_RED;
        case LOG_LEVEL_FATAL: return COLOR_MAGENTA;
        default:              return COLOR_RESET;
    }
}

void logger_log(log_level_t level, const char *file, int line, 
                const char *func, const char *format, ...) {
    
    // Filtrar por nivel mínimo
    if (level < g_logger_config.min_level) {
        return;
    }
    
    // Preparar timestamp
    char timestamp[64] = "";
    if (g_logger_config.include_timestamp) {
        logger_get_timestamp(timestamp, sizeof(timestamp));
    }
    
    // Preparar mensaje
    char message[4096];
    va_list args;
    va_start(args, format);
    vsnprintf(message, sizeof(message), format, args);
    va_end(args);
    
    // Extraer solo nombre de archivo (sin path completo)
    const char *filename = strrchr(file, '/');
    filename = (filename != NULL) ? filename + 1 : file;
    
    // ========================================================================
    // Salida a Consola
    // ========================================================================
    
    if (g_logger_config.use_colors) {
        // Con colores
        fprintf(stdout, "%s[%s]%s ", 
                logger_level_to_color(level),
                logger_level_to_string(level),
                COLOR_RESET);
        
        if (g_logger_config.include_timestamp) {
            fprintf(stdout, "%s%s%s ", COLOR_GRAY, timestamp, COLOR_RESET);
        }
        
        if (g_logger_config.include_source_info) {
            fprintf(stdout, "%s%s:%d%s ", 
                    COLOR_GRAY, filename, line, COLOR_RESET);
        }
        
        fprintf(stdout, "%s\n", message);
    } else {
        // Sin colores
        fprintf(stdout, "[%s] ", logger_level_to_string(level));
        
        if (g_logger_config.include_timestamp) {
            fprintf(stdout, "%s ", timestamp);
        }
        
        if (g_logger_config.include_source_info) {
            fprintf(stdout, "%s:%d ", filename, line);
        }
        
        fprintf(stdout, "%s\n", message);
    }
    
    fflush(stdout);
    
    // ========================================================================
    // Salida a Archivo (sin colores)
    // ========================================================================
    
    if (g_logger_config.file_output != NULL) {
        fprintf(g_logger_config.file_output, "[%s] ", 
                logger_level_to_string(level));
        
        if (g_logger_config.include_timestamp) {
            fprintf(g_logger_config.file_output, "%s ", timestamp);
        }
        
        if (g_logger_config.include_source_info) {
            fprintf(g_logger_config.file_output, "%s:%d [%s] ", 
                    filename, line, func);
        }
        
        fprintf(g_logger_config.file_output, "%s\n", message);
        fflush(g_logger_config.file_output);
    }
    
    // Terminar programa si es FATAL
    if (level == LOG_LEVEL_FATAL) {
        fprintf(stderr, "\n%sFATAL ERROR - Program terminated%s\n", 
                COLOR_RED, COLOR_RESET);
        logger_close();
        exit(EXIT_FAILURE);
    }
}
