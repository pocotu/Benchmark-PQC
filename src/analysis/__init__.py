"""
Analysis module for PQC benchmarking (SOLID: Single Responsibility Principle).

Consolidated analysis structure following QA best practices:

Structure:
- core/: Reusable analysis components (classes, utilities)
- pipelines/: Analysis pipelines (orchestration scripts)
- processing/: Data loading and processing
- visualization/: Figure generation

This organization follows SOLID principles:
- Single Responsibility: Each module has one clear purpose
- Open/Closed: Easy to extend without modifying existing code
- Dependency Inversion: Pipelines depend on core abstractions
"""

# Import core components for backward compatibility (SOLID: Open/Closed Principle)
from .core.statistical_analyzer import (
    StatisticalAnalyzer,
    ANOVAResult,
    PostHocResult,
    ConfidenceInterval,
    EffectSize,
    OverheadAnalysis,
    StatisticalReport,
)
from .core.coverage_reporter import CoverageReporter

__all__ = [
    "StatisticalAnalyzer",
    "ANOVAResult",
    "PostHocResult",
    "ConfidenceInterval",
    "EffectSize",
    "OverheadAnalysis",
    "StatisticalReport",
    "CoverageReporter",
    "core",
    "pipelines",
    "processing",
    "visualization",
]
