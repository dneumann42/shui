## Test suite for input handling
import unittest
import shui/elements

suite "BasicInput":
  test "can create BasicInput":
    let input = BasicInput(
      mousePosition: (x: 100, y: 200),
      actionPressed: true
    )

    check input.mousePosition.x == 100
    check input.mousePosition.y == 200
    check input.actionPressed == true

  test "action states are independent":
    let input = BasicInput(
      actionPressed: true,
      actionDown: false,
      dragPressed: false,
      dragDown: true
    )

    check input.actionPressed == true
    check input.actionDown == false
    check input.dragPressed == false
    check input.dragDown == true

  test "can track scroll":
    let input = BasicInput(scrollY: 100.0)
    check input.scrollY == 100.0

  test "can track text input":
    let input = BasicInput(textInput: "Hello")
    check input.textInput == "Hello"

  test "can track keyboard keys":
    let input = BasicInput(
      backspacePressed: true,
      enterPressed: false,
      tabPressed: true
    )

    check input.backspacePressed == true
    check input.enterPressed == false
    check input.tabPressed == true

suite "Mouse Input":
  test "mouse position updates":
    var input = BasicInput()
    input.mousePosition = (x: 50, y: 75)

    check input.mousePosition.x == 50
    check input.mousePosition.y == 75

  test "can detect mouse button press":
    var input = BasicInput()
    input.actionPressed = true

    check input.actionPressed == true

  test "can detect mouse button hold":
    var input = BasicInput()
    input.actionDown = true

    check input.actionDown == true

  test "pressed vs down distinction":
    var input = BasicInput()

    # Pressed = just clicked this frame
    input.actionPressed = true
    input.actionDown = false

    check input.actionPressed == true
    check input.actionDown == false

    # Next frame: held down
    input.actionPressed = false
    input.actionDown = true

    check input.actionPressed == false
    check input.actionDown == true

suite "Drag Input":
  test "can detect drag start":
    var input = BasicInput()
    input.dragPressed = true

    check input.dragPressed == true

  test "can detect drag hold":
    var input = BasicInput()
    input.dragDown = true

    check input.dragDown == true

  test "drag and action are independent":
    var input = BasicInput()
    input.actionPressed = true
    input.dragDown = true

    check input.actionPressed == true
    check input.dragDown == true

suite "Scroll Input":
  test "can scroll up":
    var input = BasicInput()
    input.scrollY = -10.0

    check input.scrollY < 0

  test "can scroll down":
    var input = BasicInput()
    input.scrollY = 10.0

    check input.scrollY > 0

  test "scroll accumulates":
    var input = BasicInput()
    input.scrollY = 5.0
    input.scrollY += 3.0

    check input.scrollY == 8.0

suite "Text Input":
  test "can receive text":
    var input = BasicInput()
    input.textInput = "abc"

    check input.textInput == "abc"

  test "text input can be empty":
    var input = BasicInput()
    input.textInput = ""

    check input.textInput == ""

  test "text input supports unicode":
    var input = BasicInput()
    input.textInput = "こんにちは"

    check input.textInput == "こんにちは"

suite "Keyboard Keys":
  test "can detect backspace":
    var input = BasicInput()
    input.backspacePressed = true

    check input.backspacePressed == true

  test "can detect enter":
    var input = BasicInput()
    input.enterPressed = true

    check input.enterPressed == true

  test "can detect tab":
    var input = BasicInput()
    input.tabPressed = true

    check input.tabPressed == true

  test "multiple keys can be pressed":
    var input = BasicInput()
    input.backspacePressed = true
    input.tabPressed = true

    check input.backspacePressed == true
    check input.tabPressed == true
