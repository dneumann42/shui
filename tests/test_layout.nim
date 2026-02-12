## Test suite for layout system
import unittest
import shui/elements
import chroma

suite "Fixed Sizing":
  test "fixed size elements maintain size":
    var ui = UI()
    ui.begin()

    let root = ui.beginElem(Elem(
      size: (
        w: Sizing(kind: Fixed, min: 200, max: 200),
        h: Sizing(kind: Fixed, min: 100, max: 100)
      )
    ))

    ui.updateLayout((0, 0, 800, 600))

    check ui[root].box.w == 200
    check ui[root].box.h == 100

  test "fixed size respects min/max":
    var ui = UI()
    ui.begin()

    let root = ui.beginElem(Elem(
      size: (
        w: Sizing(kind: Fixed, min: 50, max: 150),
        h: Sizing(kind: Fixed, min: 25, max: 75)
      )
    ))

    ui.updateLayout((0, 0, 800, 600))

    # Should use the min value for fixed
    check ui[root].box.w >= 50
    check ui[root].box.h >= 25

suite "Fit Sizing":
  test "fit sizing with no children":
    var ui = UI()
    ui.begin()

    let root = ui.beginElem(Elem(
      size: (
        w: Sizing(kind: Fit),
        h: Sizing(kind: Fit)
      ),
      style: Style(padding: 10)
    ))

    ui.updateLayout((0, 0, 800, 600))

    # Fit with no content should be minimal (padding only)
    check ui[root].box.w >= 20  # padding * 2
    check ui[root].box.h >= 20

suite "Grow Sizing":
  test "grow fills available space":
    var ui = UI()
    ui.begin()

    let root = ui.beginElem(Elem(
      size: (
        w: Sizing(kind: Grow),
        h: Sizing(kind: Grow)
      )
    ))

    ui.updateLayout((0, 0, 800, 600))

    check ui[root].box.w == 800
    check ui[root].box.h == 600

  test "grow adapts to container":
    var ui = UI()
    ui.begin()

    let root = ui.beginElem(Elem(
      size: (
        w: Sizing(kind: Grow),
        h: Sizing(kind: Grow)
      )
    ))

    # Different container size
    ui.updateLayout((0, 0, 1024, 768))

    check ui[root].box.w == 1024
    check ui[root].box.h == 768

suite "Row Layout":
  test "row arranges children horizontally":
    var ui = UI()
    ui.begin()

    let root = ui.beginElem(Elem(
      size: (w: Sizing(kind: Fixed, min: 300, max: 300),
             h: Sizing(kind: Fixed, min: 100, max: 100)),
      dir: Row
    ))

    let child1 = ui.beginElem(Elem(
      size: (w: Sizing(kind: Fixed, min: 100, max: 100),
             h: Sizing(kind: Fixed, min: 50, max: 50))
    ), root)
    ui.add(root, child1)

    let child2 = ui.beginElem(Elem(
      size: (w: Sizing(kind: Fixed, min: 100, max: 100),
             h: Sizing(kind: Fixed, min: 50, max: 50))
    ), root)
    ui.add(root, child2)

    ui.updateLayout((0, 0, 800, 600))

    # Children should be side by side
    check ui[child2].box.x > ui[child1].box.x
    check ui[child1].box.y == ui[child2].box.y  # Same vertical position

suite "Column Layout":
  test "column arranges children vertically":
    var ui = UI()
    ui.begin()

    let root = ui.beginElem(Elem(
      size: (w: Sizing(kind: Fixed, min: 100, max: 100),
             h: Sizing(kind: Fixed, min: 300, max: 300)),
      dir: Col
    ))

    let child1 = ui.beginElem(Elem(
      size: (w: Sizing(kind: Fixed, min: 50, max: 50),
             h: Sizing(kind: Fixed, min: 100, max: 100))
    ), root)
    ui.add(root, child1)

    let child2 = ui.beginElem(Elem(
      size: (w: Sizing(kind: Fixed, min: 50, max: 50),
             h: Sizing(kind: Fixed, min: 100, max: 100))
    ), root)
    ui.add(root, child2)

    ui.updateLayout((0, 0, 800, 600))

    # Children should be stacked vertically
    check ui[child2].box.y > ui[child1].box.y
    check ui[child1].box.x == ui[child2].box.x  # Same horizontal position

suite "Gaps and Padding":
  test "gap creates space between children in row":
    var ui = UI()
    ui.begin()

    let root = ui.beginElem(Elem(
      size: (w: Sizing(kind: Fixed, min: 300, max: 300),
             h: Sizing(kind: Fixed, min: 100, max: 100)),
      dir: Row,
      style: Style(gap: 20)
    ))

    let child1 = ui.beginElem(Elem(
      size: (w: Sizing(kind: Fixed, min: 50, max: 50),
             h: Sizing(kind: Fixed, min: 50, max: 50))
    ), root)
    ui.add(root, child1)

    let child2 = ui.beginElem(Elem(
      size: (w: Sizing(kind: Fixed, min: 50, max: 50),
             h: Sizing(kind: Fixed, min: 50, max: 50))
    ), root)
    ui.add(root, child2)

    ui.updateLayout((0, 0, 800, 600))

    # Gap should be 20 pixels
    let gap = ui[child2].box.x - (ui[child1].box.x + ui[child1].box.w)
    check gap == 20

  test "padding creates space inside container":
    var ui = UI()
    ui.begin()

    let root = ui.beginElem(Elem(
      size: (w: Sizing(kind: Fixed, min: 200, max: 200),
             h: Sizing(kind: Fixed, min: 200, max: 200)),
      style: Style(padding: 10)
    ))

    let child = ui.beginElem(Elem(
      size: (w: Sizing(kind: Fixed, min: 50, max: 50),
             h: Sizing(kind: Fixed, min: 50, max: 50))
    ), root)
    ui.add(root, child)

    ui.updateLayout((0, 0, 800, 600))

    # Child should be inset by padding
    check ui[child].box.x >= 10
    check ui[child].box.y >= 10

suite "Alignment":
  test "align start in row":
    var ui = UI()
    ui.begin()

    let root = ui.beginElem(Elem(
      size: (w: Sizing(kind: Fixed, min: 300, max: 300),
             h: Sizing(kind: Fixed, min: 100, max: 100)),
      dir: Row,
      align: Start
    ))

    let child = ui.beginElem(Elem(
      size: (w: Sizing(kind: Fixed, min: 50, max: 50),
             h: Sizing(kind: Fixed, min: 50, max: 50))
    ), root)
    ui.add(root, child)

    ui.updateLayout((0, 0, 800, 600))

    # Child should be at the start (left)
    check ui[child].box.x == 0

  test "align center in row":
    var ui = UI()
    ui.begin()

    let root = ui.beginElem(Elem(
      size: (w: Sizing(kind: Fixed, min: 300, max: 300),
             h: Sizing(kind: Fixed, min: 100, max: 100)),
      dir: Row,
      align: Center
    ))

    let child = ui.beginElem(Elem(
      size: (w: Sizing(kind: Fixed, min: 50, max: 50),
             h: Sizing(kind: Fixed, min: 50, max: 50))
    ), root)
    ui.add(root, child)

    ui.updateLayout((0, 0, 800, 600))

    # Child should be centered horizontally
    # (300 - 50) / 2 = 125
    check ui[child].box.x >= 100
    check ui[child].box.x <= 150

suite "Absolute Positioning in Layout":
  test "absolute elements use pos field":
    var ui = UI()
    ui.begin()

    let root = ui.beginElem(Elem(
      size: (w: Sizing(kind: Grow), h: Sizing(kind: Grow))
    ))

    let absolute = ui.beginElem(Elem(
      size: (w: Sizing(kind: Fixed, min: 50, max: 50),
             h: Sizing(kind: Fixed, min: 50, max: 50)),
      absolute: true,
      pos: (x: 100, y: 200)
    ), root)
    ui.add(root, absolute)

    ui.updateLayout((0, 0, 800, 600))

    check ui[absolute].box.x == 100
    check ui[absolute].box.y == 200

  test "absolute elements don't affect flow layout":
    var ui = UI()
    ui.begin()

    let root = ui.beginElem(Elem(
      size: (w: Sizing(kind: Fixed, min: 300, max: 300),
             h: Sizing(kind: Fixed, min: 100, max: 100)),
      dir: Row
    ))

    let child1 = ui.beginElem(Elem(
      size: (w: Sizing(kind: Fixed, min: 50, max: 50),
             h: Sizing(kind: Fixed, min: 50, max: 50))
    ), root)
    ui.add(root, child1)

    let absolute = ui.beginElem(Elem(
      size: (w: Sizing(kind: Fixed, min: 100, max: 100),
             h: Sizing(kind: Fixed, min: 50, max: 50)),
      absolute: true,
      pos: (x: 500, y: 500)
    ), root)
    ui.add(root, absolute)

    let child2 = ui.beginElem(Elem(
      size: (w: Sizing(kind: Fixed, min: 50, max: 50),
             h: Sizing(kind: Fixed, min: 50, max: 50))
    ), root)
    ui.add(root, child2)

    ui.updateLayout((0, 0, 800, 600))

    # child2 should be positioned right after child1, not affected by absolute
    check ui[child2].box.x > ui[child1].box.x
    check ui[child2].box.x < 200  # Should be close to child1

suite "Deep Nesting":
  test "can layout deeply nested elements":
    var ui = UI()
    ui.begin()

    var current = ui.beginElem(Elem(
      size: (w: Sizing(kind: Grow), h: Sizing(kind: Grow))
    ))

    # Create 10 levels of nesting
    for i in 0..<10:
      let child = ui.beginElem(Elem(
        size: (w: Sizing(kind: Fixed, min: 100, max: 100),
               h: Sizing(kind: Fixed, min: 100, max: 100)),
        dir: Col
      ), current)
      ui.add(current, child)
      current = child

    ui.updateLayout((0, 0, 800, 600))

    # Should complete without error
    check ui.elems.len == 11  # root + 10 nested

suite "Edge Cases":
  test "empty container":
    var ui = UI()
    ui.begin()

    let root = ui.beginElem(Elem(
      size: (w: Sizing(kind: Fit), h: Sizing(kind: Fit))
    ))

    ui.updateLayout((0, 0, 800, 600))

    # Should have some minimum size
    check ui[root].box.w >= 0
    check ui[root].box.h >= 0

  test "zero-sized container":
    var ui = UI()
    ui.begin()

    let root = ui.beginElem(Elem(
      size: (w: Sizing(kind: Fixed, min: 0, max: 0),
             h: Sizing(kind: Fixed, min: 0, max: 0))
    ))

    ui.updateLayout((0, 0, 800, 600))

    check ui[root].box.w == 0
    check ui[root].box.h == 0

  test "container smaller than children":
    var ui = UI()
    ui.begin()

    let root = ui.beginElem(Elem(
      size: (w: Sizing(kind: Fixed, min: 100, max: 100),
             h: Sizing(kind: Fixed, min: 100, max: 100)),
      dir: Row
    ))

    # Children total 400px wide in a 100px container
    for i in 0..<4:
      let child = ui.beginElem(Elem(
        size: (w: Sizing(kind: Fixed, min: 100, max: 100),
               h: Sizing(kind: Fixed, min: 50, max: 50))
      ), root)
      ui.add(root, child)

    ui.updateLayout((0, 0, 800, 600))

    # Should layout without crashing (overflow is acceptable)
    check ui[root].children.len == 4
