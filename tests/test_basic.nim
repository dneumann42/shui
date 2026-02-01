import unittest
import ../src/shui
import cssgrid/[numberTypes, constraints]

suite "Basic Layout Tests":
  test "Row with fixed width children":
    # Create test widgets (since we don't have Button yet, use Widget directly)
    let child1 = Widget(sizing: Fixed, width: csFixed(100), height: csFixed(50))
    let child2 = Widget(sizing: Fixed, width: csFixed(200), height: csFixed(50))
    let child3 = Widget(sizing: Fixed, width: csFixed(100), height: csFixed(50))

    let row = Row()
      .add(child1)
      .add(child2)
      .add(child3)

    # Set up frame for root
    row.frame = Frame(windowSize: uiBox(0, 0, 1000, 600))

    # Compute layout
    layout(row, uiBox(0, 0, 1000, 600))

    # Verify children have correct widths
    check child1.box.w.float == 100.0
    check child2.box.w.float == 200.0
    check child3.box.w.float == 100.0

    # Verify children are positioned horizontally
    check child1.box.x.float == 0.0
    check child2.box.x.float > child1.box.x.float
    check child3.box.x.float > child2.box.x.float

  test "Column with fixed height children":
    let child1 = Widget(sizing: Fixed, width: csFixed(100), height: csFixed(50))
    let child2 = Widget(sizing: Fixed, width: csFixed(100), height: csFixed(100))
    let child3 = Widget(sizing: Fixed, width: csFixed(100), height: csFixed(75))

    let col = Column()
      .add(child1)
      .add(child2)
      .add(child3)

    col.frame = Frame(windowSize: uiBox(0, 0, 600, 1000))

    layout(col, uiBox(0, 0, 600, 1000))

    # Verify children have correct heights
    check child1.box.h.float == 50.0
    check child2.box.h.float == 100.0
    check child3.box.h.float == 75.0

    # Verify children are positioned vertically
    check child1.box.y.float == 0.0
    check child2.box.y.float > child1.box.y.float
    check child3.box.y.float > child2.box.y.float

  test "Spacer fills remaining space":
    let left = Widget(sizing: Fixed, width: csFixed(100), height: csFixed(50))
    let spacer = newSpacer()
    let right = Widget(sizing: Fixed, width: csFixed(100), height: csFixed(50))

    let row = Row()
      .add(left)
      .add(spacer)
      .add(right)

    row.frame = Frame(windowSize: uiBox(0, 0, 1000, 600))

    layout(row, uiBox(0, 0, 1000, 600))

    # Spacer should fill remaining width (1000 - 100 - 100 = 800)
    check spacer.box.w.float == 800.0

  test "Grow factors work correctly":
    let panel1 = Widget(sizing: Grow, growFactor: 1.0)
    let panel2 = Widget(sizing: Grow, growFactor: 2.0)
    let panel3 = Widget(sizing: Grow, growFactor: 1.0)

    let row = Row()
      .add(panel1)
      .add(panel2)
      .add(panel3)

    row.frame = Frame(windowSize: uiBox(0, 0, 1000, 600))

    layout(row, uiBox(0, 0, 1000, 600))

    # Should split in 1:2:1 ratio (250:500:250)
    check abs(panel1.box.w.float - 250.0) < 1.0
    check abs(panel2.box.w.float - 500.0) < 1.0
    check abs(panel3.box.w.float - 250.0) < 1.0

  test "Gap between children":
    let child1 = Widget(sizing: Fixed, width: csFixed(100), height: csFixed(50))
    let child2 = Widget(sizing: Fixed, width: csFixed(100), height: csFixed(50))

    let row = Row()
      .gap(20)
      .add(child1)
      .add(child2)

    row.frame = Frame(windowSize: uiBox(0, 0, 1000, 600))

    layout(row, uiBox(0, 0, 1000, 600))

    # Second child should be offset by first child width + gap
    let expectedX = child1.box.w.float + 20.0
    check abs(child2.box.x.float - expectedX) < 1.0

  test "Method chaining works":
    let row = Row()
      .gap(8)
      .justify(Center)
      .align(Center)
      .add(Widget(sizing: Fit))
      .add(Widget(sizing: Fit))

    check row.gap == 8
    check row.justify == Center
    check row.align == Center
    check row.children.len == 2
