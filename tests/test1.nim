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

test "self center overrides cross-axis only in vbox flow":
  var ui = initUi()
  ui.layout("root"):
    ui.vbox("root", boxOpts(spacing = 0, align = AlignStart)):
      discard ui.text("centered", "C", prefSize = size(10, 4), alignSelf = SelfCenter, justifySelf = SelfCenter)

  let resultLayout = layoutInRect(ui, "root", rect(0, 0, 100, 40))
  check resultLayout.ok
  check resultLayout.rects["centered"].x == 45
  check resultLayout.rects["centered"].y == 0

test "space evenly distributes children in hbox":
  var ui = initUi()
  ui.setRoot("root")
  ui.addElement(Element(
    id: "root",
    kind: HBox,
    justify: SpaceEvenly,
    align: AlignStart,
    minSize: size(0, 0),
    maxSize: size(0, 0),
  ))
  ui.addElement(Element(id: "a", kind: Box, minSize: size(0, 0), maxSize: size(0, 0)))
  ui.addElement(Element(id: "b", kind: Box, minSize: size(0, 0), maxSize: size(0, 0)))
  ui.setMeasure("a", leafFixed(10, 2))
  ui.setMeasure("b", leafFixed(10, 2))
  ui.addChild("root", "a")
  ui.addChild("root", "b")

  let resultLayout = layoutInRect(ui, "root", rect(0, 0, 50, 10))
  check resultLayout.ok
  # free=30, each=10 -> starts at x=10, gap=10
  check resultLayout.rects["a"].x == 10
  check resultLayout.rects["b"].x == 30

test "flex weights distribute remaining space":
  var ui = initUi()
  ui.layout("root"):
    ui.hbox("root", boxOpts(spacing = 0, align = AlignStretch)):
      discard ui.box("a", prefSize = size(10, 4), measure = leafFixed(10, 4), expand = true, flex = 1)
      discard ui.box("b", prefSize = size(10, 4), measure = leafFixed(10, 4), expand = true, flex = 3)

  let resultLayout = layoutInRect(ui, "root", rect(0, 0, 80, 10))
  check resultLayout.ok
  # base=20, extra=60 -> +15 and +45
  check resultLayout.rects["a"].w == 25
  check resultLayout.rects["b"].w == 55

test "align self end overrides parent align":
  var ui = initUi()
  ui.layout("root"):
    ui.vbox("root", boxOpts(align = AlignStart)):
      discard ui.box("child", measure = leafFixed(10, 2), alignSelf = SelfEnd)

  let resultLayout = layoutInRect(ui, "root", rect(0, 0, 100, 20))
  check resultLayout.ok
  check resultLayout.rects["child"].x == 90

test "debug logging captures measure and arrange":
  var ui = initUi()
  ui.layout("root"):
    ui.vbox("root", boxOpts(spacing = 1)):
      discard ui.box("a", measure = leafFixed(4, 3))

  let resultLayout = layoutInRect(ui, "root", rect(0, 0, 20, 10), debugLog = true)
  check resultLayout.ok
  check resultLayout.logs.len > 0
  check resultLayout.logs.join("\n").contains("measure container id=root")
  check resultLayout.logs.join("\n").contains("arrange child id=a parent=root")

test "debug logging captures validation failure":
  var ui = initUi()
  ui.setRoot("root")
  ui.addElement(Element(id: "root", kind: VBox, minSize: size(0, 0), maxSize: size(0, 0)))
  ui.addChild("root", "missing")

  let resultLayout = layoutInRect(ui, "root", rect(0, 0, 10, 10), debugLog = true)
  check not resultLayout.ok
  check resultLayout.logs.join("\n").contains("layout validate error")

test "button widget measures and lays out as leaf":
  var ui = initUi()
  ui.layout("root"):
    ui.vbox("root", boxOpts(spacing = 0)):
      discard ui.button("ok", "OK", measure = leafFixed(12, 4))

  let resultLayout = layoutInRect(ui, "root", rect(0, 0, 100, 20))
  check resultLayout.ok
  check resultLayout.measured["ok"] == size(12, 4)
  check resultLayout.rects["ok"].w == 12
  check ui.elements["ok"].kind == Text
  check ui.elements["ok"].interactivity == ControlElement

test "card helpers set expected surface styles":
  var ui = initUi()
  ui.layout("root"):
    ui.card("card1", BorderedPanel, boxOpts()):
      ui.cardHeader("card1.header", boxOpts()):
        discard ui.text("h", "Header", prefSize = size(80, 20))
      ui.cardBody("card1.body", boxOpts()):
        discard ui.text("b", "Body", prefSize = size(80, 20))
      ui.cardFooter("card1.footer", boxOpts()):
        discard ui.button("ok", "OK", prefSize = size(60, 20))

  check ui.elements["card1"].surfaceStyle == SurfaceBordered
  check ui.elements["card1.header"].surfaceStyle == SurfaceFilled
  check ui.elements["card1.body"].surfaceStyle == SurfaceAuto
  check ui.elements["card1.footer"].surfaceStyle == SurfaceFilled

test "card footer lays out children horizontally":
  var ui = initUi()
  ui.layout("root"):
    ui.card("card1", BorderedPanel, boxOpts()):
      ui.cardFooter("footer", boxOpts(justify = SpaceBetween, align = AlignCenter)):
        discard ui.text("left", "L", prefSize = size(20, 10))
        discard ui.text("right", "R", prefSize = size(20, 10))

  let resultLayout = layoutInRect(ui, "root", rect(0, 0, 200, 80))
  check resultLayout.ok
  check resultLayout.rects["right"].x > resultLayout.rects["left"].x
  check resultLayout.rects["right"].y == resultLayout.rects["left"].y

test "floating anchor positions container below trigger":
  var ui = initUi()
  ui.layout("root"):
    ui.vbox("root", boxOpts(spacing = 0, align = AlignStart)):
      discard ui.box("trigger", prefSize = size(100, 20))
      discard ui.box("menu", prefSize = size(80, 30))
  ui.setFloating("menu", anchor = AnchorBottomLeft, anchorToId = "trigger", offsetY = 2)

  let resultLayout = layoutInRect(ui, "root", rect(0, 0, 300, 200))
  check resultLayout.ok
  check resultLayout.rects["menu"].x == resultLayout.rects["trigger"].x
  check resultLayout.rects["menu"].y == resultLayout.rects["trigger"].y + resultLayout.rects["trigger"].h + 2

test "combobox widget toggles and selects option":
  var ui = initUi()
  ui.layout("root"):
    ui.vbox("root", boxOpts()):
      discard ui.comboBox("combo", @["A", "B", "C"], selectedIndex = 0, width = 120, itemHeight = 24)

  check "combo.menu" in ui.elements
  check ui.elements["combo.menu"].positionMode == FloatingPosition
  check not ui.elements["combo.menu"].visible
  check ui.elements["combo.indicator"].text == "v"

  ui.clickedId = "combo.trigger"
  check ui.comboBoxHandleClick("combo")
  check ui.elements["combo.menu"].visible
  check ui.elements["combo.indicator"].text == "^"

  ui.clickedId = "combo.opt.2"
  check ui.comboBoxHandleClick("combo")
  check not ui.elements["combo.menu"].visible
  check ui.elements["combo.trigger"].text == "C"
  check ui.elements["combo.indicator"].text == "v"
