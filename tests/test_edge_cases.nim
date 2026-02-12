## Test suite for edge cases and stress testing
import unittest
import shui/elements
import chroma
import strutils

suite "Empty States":
  test "empty UI":
    var ui = UI()
    check ui.elems.len == 0
    check ui.roots.len == 0

  test "layout with no elements":
    var ui = UI()
    ui.begin()
    ui.updateLayout((0, 0, 800, 600))
    # Should not crash

  test "draw with no elements":
    var ui = UI()
    ui.begin()
    # Draw should handle empty UI
    # (can't actually test drawing without a render backend)
    check ui.elems.len == 0

suite "Extreme Sizes":
  test "very large element":
    var ui = UI()
    ui.begin()

    let root = ui.beginElem(Elem(
      size: (w: Sizing(kind: Fixed, min: 10000, max: 10000),
             h: Sizing(kind: Fixed, min: 10000, max: 10000))
    ))

    ui.updateLayout((0, 0, 800, 600))

    check ui[root].box.w == 10000
    check ui[root].box.h == 10000

  test "very small element":
    var ui = UI()
    ui.begin()

    let root = ui.beginElem(Elem(
      size: (w: Sizing(kind: Fixed, min: 1, max: 1),
             h: Sizing(kind: Fixed, min: 1, max: 1))
    ))

    ui.updateLayout((0, 0, 800, 600))

    check ui[root].box.w == 1
    check ui[root].box.h == 1

  test "zero-sized element":
    var ui = UI()
    ui.begin()

    let root = ui.beginElem(Elem(
      size: (w: Sizing(kind: Fixed, min: 0, max: 0),
             h: Sizing(kind: Fixed, min: 0, max: 0))
    ))

    ui.updateLayout((0, 0, 800, 600))

    check ui[root].box.w == 0
    check ui[root].box.h == 0

suite "Many Elements":
  test "100 elements":
    var ui = UI()
    ui.begin()

    let root = ui.beginElem(Elem(
      size: (w: Sizing(kind: Grow), h: Sizing(kind: Grow)),
      dir: Col
    ))

    # Create 100 child elements
    for i in 0..<100:
      let child = ui.beginElem(Elem(
        size: (w: Sizing(kind: Fixed, min: 50, max: 50),
               h: Sizing(kind: Fixed, min: 10, max: 10))
      ), root)
      ui.add(root, child)

    ui.updateLayout((0, 0, 800, 600))

    check ui.elems.len == 101  # root + 100 children

  test "1000 elements":
    var ui = UI()
    ui.begin()

    let root = ui.beginElem(Elem(
      size: (w: Sizing(kind: Grow), h: Sizing(kind: Grow))
    ))

    # Create many children in a flat structure
    for i in 0..<1000:
      let child = ui.beginElem(Elem(
        size: (w: Sizing(kind: Fit), h: Sizing(kind: Fit))
      ), root)
      ui.add(root, child)

    ui.updateLayout((0, 0, 800, 600))

    check ui.elems.len == 1001

suite "Deep Nesting":
  test "10 levels deep":
    var ui = UI()
    ui.begin()

    var current = ui.beginElem(Elem(
      size: (w: Sizing(kind: Grow), h: Sizing(kind: Grow))
    ))

    for i in 0..<10:
      let child = ui.beginElem(Elem(
        size: (w: Sizing(kind: Grow), h: Sizing(kind: Grow))
      ), current)
      ui.add(current, child)
      current = child

    ui.updateLayout((0, 0, 800, 600))

    check ui.elems.len == 11

  test "50 levels deep":
    var ui = UI()
    ui.begin()

    var current = ui.beginElem(Elem(
      size: (w: Sizing(kind: Grow), h: Sizing(kind: Grow))
    ))

    for i in 0..<50:
      let child = ui.beginElem(Elem(
        size: (w: Sizing(kind: Fixed, min: 100, max: 100),
               h: Sizing(kind: Fixed, min: 100, max: 100))
      ), current)
      ui.add(current, child)
      current = child

    ui.updateLayout((0, 0, 800, 600))

    check ui.elems.len == 51

suite "Wide Trees":
  test "10 roots":
    var ui = UI()
    ui.begin()

    for i in 0..<10:
      discard ui.beginElem(Elem(
        size: (w: Sizing(kind: Grow), h: Sizing(kind: Grow))
      ), ElemIndex(-1))

    check ui.roots.len == 10

  test "100 siblings":
    var ui = UI()
    ui.begin()

    let root = ui.beginElem(Elem(
      size: (w: Sizing(kind: Grow), h: Sizing(kind: Grow)),
      dir: Row
    ))

    for i in 0..<100:
      let child = ui.beginElem(Elem(
        size: (w: Sizing(kind: Fixed, min: 10, max: 10),
               h: Sizing(kind: Fixed, min: 10, max: 10))
      ), root)
      ui.add(root, child)

    ui.updateLayout((0, 0, 10000, 600))

    check ui[root].children.len == 100

suite "Text Edge Cases":
  test "empty text":
    var ui = UI()
    let idx = ui.createElem()
    ui[idx].text = ""
    check ui[idx].text == ""

  test "very long text":
    var ui = UI()
    let idx = ui.createElem()
    let longText = "a".repeat(10000)
    ui[idx].text = longText
    check ui[idx].text.len == 10000

  test "unicode text":
    var ui = UI()
    let idx = ui.createElem()
    ui[idx].text = "Hello 世界 🌍"
    check ui[idx].text.len > 0

  test "text with newlines":
    var ui = UI()
    let idx = ui.createElem()
    ui[idx].text = "Line 1\nLine 2\nLine 3"
    check "\n" in ui[idx].text

suite "State Edge Cases":
  test "element with all states":
    var ui = UI()
    let idx = ui.createElem()

    # Try all possible states
    ui[idx].state = Dead
    check ui[idx].state == Dead

    ui[idx].state = Visible
    check ui[idx].state == Visible

    ui[idx].state = Disabled
    check ui[idx].state == Disabled

  test "element with all flags enabled":
    var ui = UI()
    let idx = ui.createElem()

    ui[idx].floating = true
    ui[idx].absolute = true
    ui[idx].clipOverflow = true
    ui[idx].scrollable = true
    ui[idx].stopClip = true

    check ui[idx].floating == true
    check ui[idx].absolute == true
    check ui[idx].clipOverflow == true
    check ui[idx].scrollable == true
    check ui[idx].stopClip == true

suite "Multiple Frames":
  test "can create UI across multiple frames":
    var ui = UI()

    # Frame 1
    ui.begin()
    let root1 = ui.beginElem(Elem())
    check ui.elems.len == 1

    # Frame 2
    ui.begin()
    let root2 = ui.beginElem(Elem())
    check ui.elems.len == 1
    check root2 == ElemIndex(0)  # Should reuse index

  test "widget state persists across frames":
    var ui = UI()
    let id = ElemId("persistent")

    type MyState = ref object
      value: int

    # Frame 1
    ui.setState(id, MyState(value: 42))

    # Frame 2
    ui.begin()
    discard ui.createElem()

    # State should still exist
    check ui.hasState(id)
    check ui.getState(id, MyState).value == 42

suite "Container Overflow":
  test "children overflow container":
    var ui = UI()
    ui.begin()

    let root = ui.beginElem(Elem(
      size: (w: Sizing(kind: Fixed, min: 100, max: 100),
             h: Sizing(kind: Fixed, min: 100, max: 100)),
      dir: Col
    ))

    # Add children that exceed container height
    for i in 0..<20:
      let child = ui.beginElem(Elem(
        size: (w: Sizing(kind: Fixed, min: 50, max: 50),
               h: Sizing(kind: Fixed, min: 20, max: 20))
      ), root)
      ui.add(root, child)

    ui.updateLayout((0, 0, 800, 600))

    # Should layout without crashing
    check ui[root].children.len == 20

  test "negative coordinates":
    var ui = UI()
    ui.begin()

    let root = ui.beginElem(Elem(
      size: (w: Sizing(kind: Grow), h: Sizing(kind: Grow))
    ))

    let absolute = ui.beginElem(Elem(
      size: (w: Sizing(kind: Fixed, min: 50, max: 50),
             h: Sizing(kind: Fixed, min: 50, max: 50)),
      absolute: true,
      pos: (x: -100, y: -100)
    ), root)
    ui.add(root, absolute)

    ui.updateLayout((0, 0, 800, 600))

    # Negative positions should be preserved
    check ui[absolute].box.x == -100
    check ui[absolute].box.y == -100
