## Test suite for styling system
import unittest
import shui/elements
import chroma

suite "Style Properties":
  test "can set background color":
    let style = Style(bg: color(1.0, 0.0, 0.0))
    check style.bg.r > 0.99

  test "can set foreground color":
    let style = Style(fg: color(0.0, 1.0, 0.0))
    check style.fg.g > 0.99

  test "can set border color":
    let style = Style(borderColor: color(0.0, 0.0, 1.0))
    check style.borderColor.b > 0.99

  test "can set border width":
    let style = Style(border: 2)
    check style.border == 2

  test "can set padding":
    let style = Style(padding: 10)
    check style.padding == 10

  test "can set gap":
    let style = Style(gap: 5)
    check style.gap == 5

  test "can set border radius":
    let style = Style(borderRadius: 8.0)
    check style.borderRadius == 8.0

  test "can set rotation":
    let style = Style(rotation: 1.57)  # ~90 degrees
    check style.rotation > 1.5

suite "Default Style":
  test "style has default values":
    let style = Style()
    check style.border == 0
    check style.padding == 0
    check style.gap == 8
    check style.borderRadius == 0.0
    check style.rotation == 0.0

suite "Style Application":
  test "can apply style to element":
    var ui = UI()
    let idx = ui.createElem()

    ui[idx].style = Style(
      bg: color(1.0, 0.0, 0.0),
      padding: 15,
      gap: 10
    )

    check ui[idx].style.padding == 15
    check ui[idx].style.gap == 10

  test "can update individual style properties":
    var ui = UI()
    let idx = ui.createElem()

    ui[idx].style.padding = 5
    check ui[idx].style.padding == 5

    ui[idx].style.padding = 20
    check ui[idx].style.padding == 20

  test "multiple elements can have different styles":
    var ui = UI()
    let idx1 = ui.createElem()
    let idx2 = ui.createElem()

    ui[idx1].style.padding = 10
    ui[idx2].style.padding = 20

    check ui[idx1].style.padding == 10
    check ui[idx2].style.padding == 20

suite "Color Handling":
  test "can create RGB colors":
    let c = color(0.5, 0.5, 0.5)
    check c.r == 0.5
    check c.g == 0.5
    check c.b == 0.5

  test "can create RGBA colors":
    let c = color(1.0, 0.0, 0.0, 0.5)
    check c.r == 1.0
    check c.a == 0.5

  test "colors in style work correctly":
    let style = Style(
      bg: color(1.0, 0.0, 0.0, 1.0),
      fg: color(0.0, 1.0, 0.0, 1.0)
    )

    check style.bg.r > 0.9
    check style.fg.g > 0.9

suite "Border and Radius":
  test "border width affects layout":
    # Border is a visual property but might affect layout calculations
    let style = Style(border: 5)
    check style.border == 5

  test "border radius for rounded corners":
    let style = Style(borderRadius: 10.0)
    check style.borderRadius == 10.0

  test "can have different border and radius":
    let style = Style(border: 2, borderRadius: 5.0)
    check style.border == 2
    check style.borderRadius == 5.0

suite "Rotation":
  test "rotation in radians":
    let style = Style(rotation: 3.14159)  # 180 degrees
    check style.rotation > 3.0

  test "zero rotation by default":
    let style = Style()
    check style.rotation == 0.0

  test "can rotate elements":
    var ui = UI()
    let idx = ui.createElem()
    ui[idx].style.rotation = 1.57  # 90 degrees
    check ui[idx].style.rotation > 1.5

suite "Spacing":
  test "padding creates inner space":
    let style = Style(padding: 20)
    check style.padding == 20

  test "gap creates space between children":
    let style = Style(gap: 15)
    check style.gap == 15

  test "padding and gap are independent":
    let style = Style(padding: 10, gap: 5)
    check style.padding == 10
    check style.gap == 5

  test "zero padding is valid":
    let style = Style(padding: 0)
    check style.padding == 0

  test "large padding values work":
    let style = Style(padding: 100)
    check style.padding == 100
