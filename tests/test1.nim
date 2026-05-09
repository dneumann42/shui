import std/[unittest, tables, strutils]
import shui

proc leafFixed(w, h: int): IntrinsicMeasureProc =
  result = proc(maxW, maxH: int): Size =
    discard maxW
    discard maxH
    size(w, h)

test "validation fails on cycles":
  var ui = initUi()
  ui.setRoot("a")

  ui.addElement(Element(
    id: "a",
    kind: VBox,
    minSize: size(0, 0),
    maxSize: size(0, 0),
  ))
  ui.addElement(Element(
    id: "b",
    kind: VBox,
    minSize: size(0, 0),
    maxSize: size(0, 0),
  ))
  ui.addChild("a", "b")
  ui.addChild("b", "a")

  let err = validate(ui)
  check err.msg.contains("cycle")

test "vbox measure includes padding spacing and margins":
  var ui = initUi()
  ui.setRoot("root")

  ui.addElement(Element(
    id: "root",
    kind: VBox,
    spacing: 5,
    padding: uniformSides(2),
    justify: JustifyStart,
    align: AlignStart,
    minSize: size(0, 0),
    maxSize: size(0, 0),
  ))

  ui.addElement(Element(
    id: "a",
    kind: Box,
    margin: Sides(top: 1, right: 2, bottom: 3, left: 4),
    minSize: size(0, 0),
    maxSize: size(0, 0),
  ))
  ui.setMeasure("a", leafFixed(10, 20))

  ui.addElement(Element(
    id: "b",
    kind: Box,
    margin: Sides(top: 0, right: 1, bottom: 1, left: 1),
    minSize: size(0, 0),
    maxSize: size(0, 0),
  ))
  ui.setMeasure("b", leafFixed(8, 12))
  ui.addChild("root", "a")
  ui.addChild("root", "b")

  let resultLayout = layoutInRect(ui, "root", rect(0, 0, 100, 80))
  check resultLayout.ok

  # content width = max((10+4+2),(8+1+1)) = 16
  # content height = (20+1+3)+(12+0+1)+spacing(5) = 42
  # root measured adds padding (2 each side): (20,46)
  check resultLayout.measured["root"].w == 20
  check resultLayout.measured["root"].h == 46

test "hbox expand child gets remaining main-axis space":
  var ui = initUi()
  ui.setRoot("root")

  ui.addElement(Element(
    id: "root",
    kind: HBox,
    spacing: 2,
    justify: JustifyStart,
    align: AlignStretch,
    minSize: size(0, 0),
    maxSize: size(0, 0),
  ))

  ui.addElement(Element(
    id: "fixed",
    kind: Box,
    minSize: size(0, 0),
    maxSize: size(0, 0),
  ))
  ui.setMeasure("fixed", leafFixed(10, 10))

  ui.addElement(Element(
    id: "fill",
    kind: Box,
    expand: true,
    flex: 1,
    minSize: size(0, 0),
    maxSize: size(0, 0),
  ))
  ui.setMeasure("fill", leafFixed(10, 8))
  ui.addChild("root", "fixed")
  ui.addChild("root", "fill")

  let resultLayout = layoutInRect(ui, "root", rect(0, 0, 40, 20))
  check resultLayout.ok
  check resultLayout.rects["fixed"].w == 10
  check resultLayout.rects["fill"].w == 28
  check resultLayout.rects["fill"].h == 20

test "uirelays cell binding maps root rects":
  var ui = initUi()

  ui.addElement(Element(
    id: "toolbarRoot",
    kind: VBox,
    minSize: size(0, 0),
    maxSize: size(0, 0),
  ))

  ui.addElement(Element(
    id: "bodyRoot",
    kind: VBox,
    minSize: size(0, 0),
    maxSize: size(0, 0),
  ))

  ui.regionBindings["toolbar"] = "toolbarRoot"
  ui.regionBindings["body"] = "bodyRoot"

  let src = "| toolbar, 10px |\n| body, * |"
  let resultLayout = layoutWithUirelays(ui, src, 100, 60)
  check resultLayout.ok
  check resultLayout.rects["toolbarRoot"].h == 10
  check resultLayout.rects["bodyRoot"].h == 50

test "validation fails on missing child":
  var ui = initUi()
  ui.setRoot("root")
  ui.addElement(Element(
    id: "root",
    kind: VBox,
    minSize: size(0, 0),
    maxSize: size(0, 0),
  ))
  ui.addChild("root", "missing")

  let err = validate(ui)
  check err.msg.contains("missing child id")

test "validation fails on parent mismatch":
  var ui = initUi()
  ui.setRoot("root")
  ui.addElement(Element(
    id: "root",
    kind: VBox,
    minSize: size(0, 0),
    maxSize: size(0, 0),
  ))
  ui.addElement(Element(
    id: "c",
    kind: Box,
    minSize: size(0, 0),
    maxSize: size(0, 0),
  ))
  ui.setMeasure("c", leafFixed(4, 4))
  ui.addChild("root", "c")
  ui.parentById["c"] = "other"

  let err = validate(ui)
  check err.msg.contains("parent mismatch")

test "justify end shifts children on main axis":
  var ui = initUi()
  ui.setRoot("root")
  ui.addElement(Element(
    id: "root",
    kind: HBox,
    spacing: 2,
    justify: JustifyEnd,
    align: AlignStart,
    minSize: size(0, 0),
    maxSize: size(0, 0),
  ))
  ui.addElement(Element(
    id: "a",
    kind: Box,
    minSize: size(0, 0),
    maxSize: size(0, 0),
  ))
  ui.setMeasure("a", leafFixed(10, 5))
  ui.addElement(Element(
    id: "b",
    kind: Box,
    minSize: size(0, 0),
    maxSize: size(0, 0),
  ))
  ui.setMeasure("b", leafFixed(8, 5))
  ui.addChild("root", "a")
  ui.addChild("root", "b")

  let resultLayout = layoutInRect(ui, "root", rect(0, 0, 40, 10))
  check resultLayout.ok
  # used = 10 + 2 + 8 = 20, free = 20, so start x=20
  check resultLayout.rects["a"].x == 20
  check resultLayout.rects["b"].x == 32

test "align end positions child at cross-axis end":
  var ui = initUi()
  ui.setRoot("root")
  ui.addElement(Element(
    id: "root",
    kind: VBox,
    justify: JustifyStart,
    align: AlignEnd,
    minSize: size(0, 0),
    maxSize: size(0, 0),
  ))
  ui.addElement(Element(
    id: "a",
    kind: Box,
    minSize: size(0, 0),
    maxSize: size(0, 0),
  ))
  ui.setMeasure("a", leafFixed(10, 6))
  ui.addChild("root", "a")

  let resultLayout = layoutInRect(ui, "root", rect(0, 0, 50, 20))
  check resultLayout.ok
  check resultLayout.rects["a"].x == 40

test "dsl hbox vbox constructors build tree and layout":
  var ui = initUi()
  ui.layout("root"):
    ui.vbox("root", boxOpts(spacing = 2, padding = uniformSides(1), align = AlignStretch)):
      ui.hbox("row", boxOpts(spacing = 1, align = AlignStretch)):
        discard ui.box("a", measure = leafFixed(5, 3))
        discard ui.text("b", "hello", measure = leafFixed(7, 4), expand = true, flex = 1)

  let resultLayout = layoutInRect(ui, "root", rect(0, 0, 30, 12))
  check resultLayout.ok
  check ui.parentById["row"] == "root"
  check ui.parentById["a"] == "row"
  check ui.parentById["b"] == "row"
  check resultLayout.rects["row"].w == 28
  check resultLayout.rects["b"].w > resultLayout.rects["a"].w

test "text uses ui measure callback and falls back to pref size":
  var ui = initUi()
  ui.layout("root"):
    ui.vbox("root", boxOpts(spacing = 1)):
      discard ui.text("title", "Title", prefSize = size(3, 2))
      discard ui.box("avatar", prefSize = size(1, 1), measure = leafFixed(6, 4))

  let resultLayout = layoutInRect(ui, "root", rect(0, 0, 20, 20))
  check resultLayout.ok
  # title has no UI callback -> prefSize
  check resultLayout.measured["title"] == size(3, 2)
  # avatar is measured by UI callback
  check resultLayout.measured["avatar"] == size(6, 4)
