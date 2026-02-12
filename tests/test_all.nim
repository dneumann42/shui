## Comprehensive test suite runner for Shui
## Run with: nim c -r tests/test_all.nim
## Or with debug: nim c -r -d:shuiDebug tests/test_all.nim

import unittest
import shui/elements  # For shuiDebug constant

# Import all test suites
import test_elements
import test_layout
import test_widgets
import test_input
import test_sizing
import test_style
import test_edge_cases

echo "\n"
echo "======================================"
echo "  Shui UI Library - Test Suite"
echo "======================================"
echo ""
echo "Running comprehensive tests..."
echo ""

when shuiDebug:
  echo "[DEBUG MODE ENABLED]"
  echo ""
