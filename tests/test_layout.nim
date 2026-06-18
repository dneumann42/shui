import std/[unittest, tables]
import uirelays/coords
import shui/[elements, widgets, layout_engine]

proc r(o: LayoutOutcome; id: string): Rect =
  check o.ok
  check id in o.rects
  o.rects[id]

suite "layout engine":
  test "vbox padding + spacing, stretched cross":
    var ui = initUi()
    layout("root"):
      vbox("root", boxOpts(padding = uniformSides(10), spacing = 5, align = AlignStretch)):
        discard ui.boxNode("root.a", prefSize = size(0, 20))
        discard ui.boxNode("root.b", prefSize = size(0, 20))
    let o = layoutInRect(ui, "root", rect(0, 0, 100, 100))
    check o.r("root.a") == rect(10, 10, 80, 20)
    check o.r("root.b") == rect(10, 35, 80, 20)
    check o.measured["root"] == size(20, 65)

  test "JustifyEnd respects bottom padding":
    var ui = initUi()
    layout("root"):
      vbox("root", boxOpts(padding = uniformSides(10), justify = JustifyEnd, align = AlignStretch)):
        discard ui.boxNode("root.a", prefSize = size(0, 20))
    let a = layoutInRect(ui, "root", rect(0, 0, 100, 100)).r("root.a")
    check a.y + a.h == 90

  test "hbox spacing":
    var ui = initUi()
    layout("root"):
      hbox("root", boxOpts(spacing = 10, align = AlignStretch)):
        discard ui.boxNode("root.a", prefSize = size(20, 0))
        discard ui.boxNode("root.b", prefSize = size(20, 0))
    let o = layoutInRect(ui, "root", rect(0, 0, 100, 50))
    check o.r("root.a") == rect(0, 0, 20, 50)
    check o.r("root.b") == rect(30, 0, 20, 50)

  test "flex children share extra space":
    var ui = initUi()
    layout("root"):
      hbox("root", boxOpts(align = AlignStretch)):
        discard ui.boxNode("root.a", prefSize = size(20, 0), expand = true, flex = 1)
        discard ui.boxNode("root.b", prefSize = size(20, 0), expand = true, flex = 1)
    let o = layoutInRect(ui, "root", rect(0, 0, 100, 50))
    check o.r("root.a").w == 50
    check o.r("root.b").w == 50
    check o.r("root.b").x == 50

  test "nested padding stacks":
    var ui = initUi()
    layout("root"):
      vbox("root", boxOpts(padding = uniformSides(10), align = AlignStretch)):
        vbox("root.inner", boxOpts(padding = uniformSides(5), align = AlignStretch)):
          discard ui.boxNode("root.inner.leaf", prefSize = size(0, 30))
    let o = layoutInRect(ui, "root", rect(0, 0, 100, 100))
    check o.r("root.inner") == rect(10, 10, 80, 40)
    let leaf = o.r("root.inner.leaf")
    check (leaf.x, leaf.y, leaf.w) == (15, 15, 70)

  test "margins offset a child":
    var ui = initUi()
    layout("root"):
      vbox("root", boxOpts(align = AlignStart)):
        discard ui.boxNode("root.a", prefSize = size(20, 20), margin = Sides(top: 5, left: 3))
    let a = layoutInRect(ui, "root", rect(0, 0, 100, 100)).r("root.a")
    check (a.x, a.y) == (3, 5)

  test "SpaceBetween pins children to edges":
    var ui = initUi()
    layout("root"):
      hbox("root", boxOpts(justify = SpaceBetween, align = AlignStretch)):
        discard ui.boxNode("root.a", prefSize = size(20, 0))
        discard ui.boxNode("root.b", prefSize = size(20, 0))
    let o = layoutInRect(ui, "root", rect(0, 0, 100, 50))
    check o.r("root.a").x == 0
    check o.r("root.b").x + o.r("root.b").w == 100

  test "relay cell card keeps body within bottom padding":
    var ui = initUi()
    layout("root"):
      relay("root", "| hero, 120px |\n| body, * |\n", boxOpts()):
        panel("root.hero", BorderedPanel, boxOpts(padding = uniformSides(10), spacing = 4, align = AlignStretch)):
          discard ui.boxNode("root.hero.head", prefSize = size(0, 30))
          discard ui.boxNode("root.hero.body", prefSize = size(0, 40))
        discard ui.boxNode("root.body", prefSize = size(0, 0))
    let o = layoutInRect(ui, "root", rect(0, 0, 400, 400))
    let hero = o.r("root.hero")
    check hero.h == 120
    let bd = o.r("root.hero.body")
    check bd.y + bd.h <= hero.y + hero.h - 10

suite "button label centering":
  proc heroBottoms(cellPx: int): tuple[cellBottom, bodyBottom: int] =
    var ui = initUi()
    layout("root"):
      relay("root", "| hero, " & $cellPx & "px |\n| rest, * |\n", boxOpts()):
        card("root.hero", BorderedPanel, boxOpts(spacing = 4, padding = uniformSides(10), align = AlignStretch)):
          cardHeader("root.hero.h"):
            discard ui.textLabel("root.hero.title", "Title", prefSize = size(520, 28), alignSelf = SelfCenter)
          cardBody("root.hero.b", boxOpts(spacing = 6, padding = uniformSides(4), align = AlignCenter)):
            discard ui.pushButton("root.hero.btn", "Button", parentId = "root.hero.b", prefSize = size(240, 40))
        discard ui.boxNode("root.rest", prefSize = size(0, 0))
    let o = layoutInRect(ui, "root", rect(0, 0, 400, 400))
    (o.r("root.hero").y + o.r("root.hero").h, o.r("root.hero.btn").y + o.r("root.hero.btn").h)

  test "a too-short cell overflows the bottom padding":
    let s = heroBottoms(96)
    check s.bodyBottom > s.cellBottom - 10

  test "a roomy cell keeps the bottom padding":
    let s = heroBottoms(120)
    check s.bodyBottom <= s.cellBottom - 10

  test "centered label fills the button width":
    var ui = initUi()
    layout("btn"):
      discard ui.pushButton("btn", "Hi", prefSize = size(100, 30))
    ui.setMeasure("btn.label", proc(mw, mh: int): Size = size(20, 16))
    let lbl = layoutInRect(ui, "btn", rect(0, 0, 100, 30)).r("btn.label")
    check (lbl.x, lbl.w) == (0, 100)

  test "centered label fills even without a measure":
    var ui = initUi()
    layout("btn"):
      discard ui.pushButton("btn", "Hi", prefSize = size(100, 30))
    let lbl = layoutInRect(ui, "btn", rect(0, 0, 100, 30)).r("btn.label")
    check (lbl.x, lbl.w) == (0, 100)

  test "left-aligned label fills and is tagged TextLeft":
    var ui = initUi()
    layout("btn"):
      discard ui.pushButton("btn", "Hi", prefSize = size(100, 30), labelAlign = LabelLeft)
    ui.setMeasure("btn.label", proc(mw, mh: int): Size = size(20, 16))
    let lbl = layoutInRect(ui, "btn", rect(0, 0, 100, 30)).r("btn.label")
    check (lbl.x, lbl.w) == (0, 100)
    check ui.elements["btn.label"].textAlign == TextLeft

  test "input field text is left-aligned and fills":
    var ui = initUi()
    layout("box"):
      discard ui.inputField("box", "ab", "ph", prefSize = size(280, 32))
    let t = layoutInRect(ui, "box", rect(0, 0, 280, 32)).r("box.text")
    check t.x == 8
    check ui.elements["box.text"].textAlign == TextLeft
