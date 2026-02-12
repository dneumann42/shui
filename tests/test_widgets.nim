## Test suite for widget box API
import unittest
import shui/elements

suite "Widget Box API":
  test "can get and set widget box":
    var ui = UI()
    let id = ElemId("my-widget")

    ui.setBox(id, 10, 20, 100, 50)
    let box = ui.getBox(id)

    check box.x == 10
    check box.y == 20
    check box.w == 100
    check box.h == 50

  test "can set box with tuple":
    var ui = UI()
    let id = ElemId("widget")

    ui.setBox(id, (x: 5, y: 15, w: 80, h: 60))
    let box = ui.getBox(id)

    check box.w == 80
    check box.h == 60

  test "can update widget box":
    var ui = UI()
    let id = ElemId("movable")

    ui.setBox(id, 0, 0, 50, 50)
    check ui.getBox(id).x == 0

    ui.setBox(id, 100, 100, 50, 50)
    check ui.getBox(id).x == 100

  test "hasBox returns true for existing box":
    var ui = UI()
    let id = ElemId("exists")

    ui.setBox(id, 0, 0, 10, 10)
    check ui.hasBox(id) == true

  test "hasBox returns false for non-existent box":
    var ui = UI()
    let id = ElemId("missing")

    check ui.hasBox(id) == false

  test "getBox returns zero for missing box":
    var ui = UI()
    let id = ElemId("missing")

    let box = ui.getBox(id)
    check box.x == 0
    check box.y == 0
    check box.w == 0
    check box.h == 0

  test "can remove widget box":
    var ui = UI()
    let id = ElemId("removable")

    ui.setBox(id, 10, 10, 20, 20)
    check ui.hasBox(id) == true

    ui.removeBox(id)
    check ui.hasBox(id) == false

  test "multiple widgets have independent boxes":
    var ui = UI()
    let id1 = ElemId("widget1")
    let id2 = ElemId("widget2")

    ui.setBox(id1, 10, 10, 50, 50)
    ui.setBox(id2, 100, 100, 80, 80)

    check ui.getBox(id1).w == 50
    check ui.getBox(id2).w == 80

suite "ElemId":
  test "can create ElemId from string":
    let id = ElemId("my-element")
    check string(id) == "my-element"

  test "ElemIds with same string are equal":
    let id1 = ElemId("same")
    let id2 = ElemId("same")
    check id1 == id2

  test "ElemIds with different strings are not equal":
    let id1 = ElemId("one")
    let id2 = ElemId("two")
    check id1 != id2
