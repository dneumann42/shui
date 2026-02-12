# Package

version       = "0.1.0"
author        = "Shui Contributors"
description   = "Immediate mode UI library with flexbox-style layout"
license       = "MIT"
srcDir        = "src"

# Dependencies

requires "nim >= 2.0.0"
requires "chroma >= 0.2.7"

# Tasks

task test, "Run the test suite":
  exec "nim c -r tests/test_all.nim"

task testDebug, "Run tests with debug mode enabled":
  exec "nim c -r -d:shuiDebug tests/test_all.nim"

task testOne, "Run a single test file":
  # Usage: nimble testOne test_elements
  let testFile = if paramCount() > 0: paramStr(paramCount()) else: "test_elements"
  exec "nim c -r tests/" & testFile & ".nim"
