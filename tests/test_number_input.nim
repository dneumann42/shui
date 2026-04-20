import std/[options, unittest]

import shui/elements
import shui/widgets/inputs

template drawNumber(ui: var UI; value: var float; id: ElemId; decimals: static[int] = 0; step: float = 1.0) =
  ui.begin()
  numberInput(value, id, -10.0, 10.0, decimals, step)

suite "NumberInput helpers":
  test "clamps and rounds integer values":
    check clampNumberValue(10.8, -10.0, 10.0, 0) == 10.0
    check clampNumberValue(2.6, -10.0, 10.0, 0) == 3.0

  test "filters number text":
    check acceptsNumberText("-1.25", -10.0, 2)
    check not acceptsNumberText("--1", -10.0, 2)
    check not acceptsNumberText("1.2.3", -10.0, 2)
    check not acceptsNumberText("-1", 0.0, 2)
    check not acceptsNumberText("1.2", -10.0, 0)

suite "NumberInput interactions":
  test "increment and decrement buttons adjust value":
    var ui = UI()
    var value = 1.0
    let id = ElemId("number")

    ui.clickedElemId = some(ElemId("number.inc"))
    drawNumber(ui, value, id)
    check value == 2.0

    ui.clickedElemId = some(ElemId("number.dec"))
    drawNumber(ui, value, id)
    check value == 1.0

  test "shift increments by five steps":
    var ui = UI()
    var value = 1.0
    let id = ElemId("number")

    ui.input.shiftDown = true
    ui.clickedElemId = some(ElemId("number.inc"))
    drawNumber(ui, value, id)
    check value == 6.0

  test "buttons clamp at bounds":
    var ui = UI()
    var value = 9.0
    let id = ElemId("number")

    ui.input.shiftDown = true
    ui.clickedElemId = some(ElemId("number.inc"))
    drawNumber(ui, value, id)
    check value == 10.0

  test "typed valid input updates value":
    var ui = UI()
    var value = 1.0
    let id = ElemId("number")
    let fieldId = ElemId("number.field")

    drawNumber(ui, value, id)
    fieldId.focus(ui)
    ui.setState(id, NumberInputState(editText: ""))
    ui.input.textInput = "3"
    drawNumber(ui, value, id)

    check value == 3.0

  test "typed invalid characters are ignored":
    var ui = UI()
    var value = 1.0
    let id = ElemId("number")
    let fieldId = ElemId("number.field")

    drawNumber(ui, value, id)
    fieldId.focus(ui)
    ui.setState(id, NumberInputState(editText: "1"))
    ui.input.textInput = "x"
    drawNumber(ui, value, id)

    check value == 1.0
    check ui.getState(id, NumberInputState).editText == "1"

  test "partial edit text never invalidates value":
    var ui = UI()
    var value = 4.0
    let id = ElemId("number")
    let fieldId = ElemId("number.field")

    drawNumber(ui, value, id)
    fieldId.focus(ui)
    ui.setState(id, NumberInputState(editText: "4"))
    ui.input.backspacePressed = true
    drawNumber(ui, value, id)

    check value == 4.0
    check ui.getState(id, NumberInputState).editText == ""

  test "enter commits and unfocuses":
    var ui = UI()
    var value = 4.0
    let id = ElemId("number")
    let fieldId = ElemId("number.field")

    drawNumber(ui, value, id)
    fieldId.focus(ui)
    ui.setState(id, NumberInputState(editText: "5"))
    ui.input.enterPressed = true
    drawNumber(ui, value, id)

    check not fieldId.focused(ui)
    check ui.getState(id, NumberInputState).editText == "4"

  test "horizontal drag changes value when not focused":
    var ui = UI()
    var value = 1.0
    let id = ElemId("number")
    let fieldId = ElemId("number.field")

    drawNumber(ui, value, id)
    ui.activeElemId = some(fieldId)
    ui.input.actionDown = true
    ui.input.actionPressed = true
    ui.input.mousePosition = (x: 0, y: 0)
    drawNumber(ui, value, id)

    ui.input.actionPressed = false
    ui.input.mousePosition = (x: 16, y: 0)
    drawNumber(ui, value, id)

    check value == 3.0
