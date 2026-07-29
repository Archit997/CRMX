"""Backward-compatible import for older CRMX modules.

New code should import AppLogger from ``utils.logging``.
"""

from utils.logging import AppLogger

__all__ = ["AppLogger"]
