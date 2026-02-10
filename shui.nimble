# Package

version       = "0.1.0"
author        = "dneumann42"
description   = "A new awesome nimble package"
license       = "GPL-2.0-or-later"
srcDir        = "src"


# Dependencies

requires "nim >= 2.2.6"
requires "chroma"
requires "sigils"

# Tasks

task test, "Run widget macro tests":
  exec "nim c -r tests/twidgets.nim"
