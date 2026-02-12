## Test suite for core element functionality
import unittest
import shui/elements
import chroma

suite "Element Creation":
  test "can create UI instance":
    var ui = UI()
    check ui.elems.len == 0

  test "can create elements":
    var ui = UI()
    let idx = ui.createElem()
    check ui.elems.len == 1
    check idx == ElemIndex(0)

  test "elements have unique IDs":
    var ui = UI()
    let idx1 = ui.createElem()
    let idx2 = ui.createElem()
    check ui[idx1].id != ui[idx2].id

  test "can access elements by index":
    var ui = UI()
    let idx = ui.createElem()
    ui[idx].text = "test"
    check ui[idx].text == "test"

suite "Element Properties":
  test "default element state":
    var ui = UI()
    let idx = ui.createElem()
    let elem = ui[idx]
    check elem.floating == false
    check elem.absolute == false
    check elem.clipOverflow == false
    check elem.state == Visible

  test "can set element size":
    var ui = UI()
    let idx = ui.createElem()
    ui[idx].size = (
      w: Sizing(kind: Fixed, min: 100, max: 100),
      h: Sizing(kind: Fixed, min: 50, max: 50)
    )
    check ui[idx].size.w.kind == Fixed
    check ui[idx].size.w.min == 100

  test "can set element text":
    var ui = UI()
    let idx = ui.createElem()
    ui[idx].text = "Hello World"
    check ui[idx].text == "Hello World"

  test "can set element style":
    var ui = UI()
    let idx = ui.createElem()
    ui[idx].style.bg = color(1.0, 0.0, 0.0)
    ui[idx].style.padding = 10
    ui[idx].style.gap = 5
    check ui[idx].style.padding == 10
    check ui[idx].style.gap == 5

  test "can set element direction":
    var ui = UI()
    let idx = ui.createElem()
    ui[idx].dir = Row
    check ui[idx].dir == Row
    ui[idx].dir = Col
    check ui[idx].dir == Col

  test "can set element alignment":
    var ui = UI()
    let idx = ui.createElem()
    ui[idx].align = Center
    ui[idx].crossAlign = End
    check ui[idx].align == Center
    check ui[idx].crossAlign == End

suite "Multiple Roots":
  test "can create multiple roots":
    var ui = UI()
    ui.begin()

    let root1 = ui.beginElem(Elem(), ElemIndex(-1))
    let root2 = ui.beginElem(Elem(), ElemIndex(-1))

    check ui.roots.len == 2
    check ui.roots[0] == root1
    check ui.roots[1] == root2

  test "roots are cleared on begin":
    var ui = UI()
    ui.begin()
    discard ui.beginElem(Elem(), ElemIndex(-1))
    check ui.roots.len == 1

    ui.begin()
    check ui.roots.len == 0

  test "can iterate over all roots":
    var ui = UI()
    ui.begin()

    let root1 = ui.beginElem(Elem(), ElemIndex(-1))
    ui[root1].text = "root1"
    let root2 = ui.beginElem(Elem(), ElemIndex(-1))
    ui[root2].text = "root2"

    var count = 0
    for root in ui.roots:
      count += 1
    check count == 2

suite "Element Hierarchy":
  test "can add children to elements":
    var ui = UI()
    let parent = ui.createElem()
    let child = ui.createElem()

    ui.add(parent, child)
    check ui[parent].children.len == 1
    check ui[parent].children[0] == child

  test "can add multiple children":
    var ui = UI()
    let parent = ui.createElem()
    let child1 = ui.createElem()
    let child2 = ui.createElem()
    let child3 = ui.createElem()

    ui.add(parent, child1)
    ui.add(parent, child2)
    ui.add(parent, child3)

    check ui[parent].children.len == 3

  test "can iterate over children":
    var ui = UI()
    let parent = ui.createElem()
    let child1 = ui.createElem()
    let child2 = ui.createElem()

    ui.add(parent, child1)
    ui.add(parent, child2)

    var count = 0
    for child in ui.items(parent):
      count += 1
    check count == 2

suite "Absolute Positioning":
  test "can set absolute position":
    var ui = UI()
    let idx = ui.createElem()
    ui[idx].absolute = true
    ui[idx].pos = (x: 100, y: 50)

    check ui[idx].absolute == true
    check ui[idx].pos.x == 100
    check ui[idx].pos.y == 50

  test "absolute elements have correct flag":
    var ui = UI()
    let normal = ui.createElem()
    let absolute = ui.createElem()

    ui[absolute].absolute = true

    check ui[normal].absolute == false
    check ui[absolute].absolute == true

suite "Floating Elements":
  test "can mark elements as floating":
    var ui = UI()
    let idx = ui.createElem()
    ui[idx].floating = true

    check ui[idx].floating == true

  test "floating flag is independent of absolute":
    var ui = UI()
    let idx = ui.createElem()
    ui[idx].floating = true
    ui[idx].absolute = true

    check ui[idx].floating == true
    check ui[idx].absolute == true

suite "ElemIndex":
  test "ElemIndex equality works":
    let idx1 = ElemIndex(5)
    let idx2 = ElemIndex(5)
    let idx3 = ElemIndex(10)

    check idx1 == idx2
    check idx1 != idx3

  test "can convert ElemIndex to int":
    let idx = ElemIndex(42)
    check idx.int == 42

suite "UI Begin/Reset":
  test "begin clears elements":
    var ui = UI()
    discard ui.createElem()
    discard ui.createElem()
    check ui.elems.len == 2

    ui.begin()
    check ui.elems.len == 0

  test "begin clears roots":
    var ui = UI()
    ui.begin()
    discard ui.beginElem(Elem(), ElemIndex(-1))
    check ui.roots.len == 1

    ui.begin()
    check ui.roots.len == 0

  test "can start fresh after begin":
    var ui = UI()
    ui.begin()
    discard ui.createElem()
    check ui.elems.len == 1

    ui.begin()
    discard ui.createElem()
    discard ui.createElem()
    check ui.elems.len == 2
