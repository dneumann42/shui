## Test suite for sizing constraints
import unittest
import shui/elements

suite "Sizing Types":
  test "can create Fixed sizing":
    let sizing = Sizing(kind: Fixed, min: 100, max: 100)
    check sizing.kind == Fixed
    check sizing.min == 100
    check sizing.max == 100

  test "can create Fit sizing":
    let sizing = Sizing(kind: Fit)
    check sizing.kind == Fit

  test "can create Grow sizing":
    let sizing = Sizing(kind: Grow)
    check sizing.kind == Grow

  test "Fixed can have range":
    let sizing = Sizing(kind: Fixed, min: 50, max: 200)
    check sizing.min == 50
    check sizing.max == 200

suite "Sizing Combinations":
  test "can mix Fixed and Grow":
    let widthSizing = Sizing(kind: Fixed, min: 100, max: 100)
    let heightSizing = Sizing(kind: Grow)

    check widthSizing.kind == Fixed
    check heightSizing.kind == Grow

  test "can mix Fit and Fixed":
    let widthSizing = Sizing(kind: Fit)
    let heightSizing = Sizing(kind: Fixed, min: 50, max: 50)

    check widthSizing.kind == Fit
    check heightSizing.kind == Fixed

  test "both dimensions can be Grow":
    let widthSizing = Sizing(kind: Grow)
    let heightSizing = Sizing(kind: Grow)

    check widthSizing.kind == Grow
    check heightSizing.kind == Grow

  test "both dimensions can be Fit":
    let widthSizing = Sizing(kind: Fit)
    let heightSizing = Sizing(kind: Fit)

    check widthSizing.kind == Fit
    check heightSizing.kind == Fit

suite "Element Size Constraints":
  test "can set element size constraints":
    var ui = UI()
    let idx = ui.createElem()

    ui[idx].size = (
      w: Sizing(kind: Fixed, min: 200, max: 200),
      h: Sizing(kind: Grow)
    )

    check ui[idx].size.w.kind == Fixed
    check ui[idx].size.h.kind == Grow

  test "default element sizing":
    var ui = UI()
    let idx = ui.createElem()

    # Check what the default is (should be defined)
    check ui[idx].size.w.kind in [Fixed, Fit, Grow]
    check ui[idx].size.h.kind in [Fixed, Fit, Grow]

suite "Min/Max Constraints":
  test "min equals max for exact size":
    let sizing = Sizing(kind: Fixed, min: 100, max: 100)
    check sizing.min == sizing.max

  test "min less than max for flexible size":
    let sizing = Sizing(kind: Fixed, min: 50, max: 200)
    check sizing.min < sizing.max

  test "can have zero min":
    let sizing = Sizing(kind: Fixed, min: 0, max: 100)
    check sizing.min == 0

  test "can have large max":
    let sizing = Sizing(kind: Fixed, min: 0, max: 10000)
    check sizing.max == 10000
