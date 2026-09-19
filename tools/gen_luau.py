#!/usr/bin/env python3
"""Compatibility shim: the generator lives in tools/gen_luau_data.py.

Kept so the gate scripts can `from gen_luau import MODULES, DISPLAY_SCALE`
regardless of which name they were written against. There is exactly one
generator; this module adds nothing of its own.
"""
from gen_luau_data import MODULES, DISPLAY_SCALE, main  # noqa: F401

if __name__ == "__main__":
    import sys
    sys.exit(main())
