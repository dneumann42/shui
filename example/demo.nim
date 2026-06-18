import std/[tables, os]
import shui
import uirelays/screen
import ./assets

const assetsDir = currentSourcePath().parentDir / "assets"

var imageCache: Table[string, screen.Image]

proc drawImageHook(spec: ButtonImageSpec; dst: Rect): bool {.nimcall.} =
  if spec.resourceId.len == 0:
    return false
  if spec.resourceId notin imageCache:
    imageCache[spec.resourceId] = loadImage(spec.resourceId)
  let img = imageCache[spec.resourceId]
  if img == screen.Image(0):
    return false
  drawImage(img, spec.normalizedSource(), dst)
  true

component Counter:
  state:
    title: string = "Counter"
    count: int = 0
    step: int = 1
    icon: ButtonImageSpec = ButtonImageSpec()
  msg:
    Increment
    Decrement
    Reset
    SetStep(value: int)
  update(m: Msg):
    case m
    of Increment: state.count += state.step
    of Decrement: state.count -= state.step
    of Reset: state.count = 0
    of SetStep: state.step = m.value
  view(rootId: string):
    card(rootId, FilledPanel, boxOpts(spacing = 6, padding = uniformSides(10), align = AlignStretch)):
      discard ui.text(rootId & ".title", state.title, prefSize = size(220, 22), alignSelf = SelfCenter)
      discard ui.text(rootId & ".count", "Count: " & $state.count, prefSize = size(220, 30), alignSelf = SelfCenter)
      discard ui.text(rootId & ".doubled", "Doubled: " & $(state.count * 2), prefSize = size(220, 18), alignSelf = SelfCenter)
      hbox(rootId & ".ops", boxOpts(spacing = 6, align = AlignStretch, justify = JustifyCenter)):
        emit(rootId & ".dec", Decrement):
          discard ui.pushButton(rootId & ".dec", "-", parentId = rootId & ".ops", prefSize = size(48, 34))
        emit(rootId & ".inc", Increment):
          discard ui.pushButton(rootId & ".inc", "+", parentId = rootId & ".ops", prefSize = size(64, 34), leading = state.icon)
        emit(rootId & ".reset", Reset):
          discard ui.pushButton(rootId & ".reset", "Reset", parentId = rootId & ".ops", prefSize = size(80, 34), showBackground = false)
      discard ui.text(rootId & ".steplabel", "Step = " & $state.step, prefSize = size(220, 18), alignSelf = SelfCenter)
      hbox(rootId & ".steps", boxOpts(spacing = 6, align = AlignStretch, justify = JustifyCenter)):
        emit(rootId & ".s1", SetStep(value: 1)):
          discard ui.pushButton(rootId & ".s1", "x1", parentId = rootId & ".steps", prefSize = size(56, 28))
        emit(rootId & ".s5", SetStep(value: 5)):
          discard ui.pushButton(rootId & ".s5", "x5", parentId = rootId & ".steps", prefSize = size(56, 28))
        emit(rootId & ".s10", SetStep(value: 10)):
          discard ui.pushButton(rootId & ".s10", "x10", parentId = rootId & ".steps", prefSize = size(56, 28))

component EventProbe:
  state:
    clicks: int = 0
    presses: int = 0
    releases: int = 0
    enters: int = 0
    leaves: int = 0
  msg:
    Click
    Press
    Release
    Enter
    Leave
  update(m: Msg):
    case m
    of Click: inc state.clicks
    of Press: inc state.presses
    of Release: inc state.releases
    of Enter: inc state.enters
    of Leave: inc state.leaves
  view(rootId: string):
    card(rootId, FilledPanel, boxOpts(spacing = 6, padding = uniformSides(10), align = AlignStretch)):
      discard ui.text(rootId & ".title", "One button, five events", prefSize = size(260, 22), alignSelf = SelfCenter)
      discard ui.pushButton(rootId & ".btn", "Press / hover me", prefSize = size(260, 48), alignSelf = SelfCenter)
      on(rootId & ".btn", Clicked, Click)
      on(rootId & ".btn", Pressed, Press)
      on(rootId & ".btn", Released, Release)
      on(rootId & ".btn", HoverIn, Enter)
      on(rootId & ".btn", HoverOut, Leave)
      discard ui.text(rootId & ".clicks", "clicks: " & $state.clicks, prefSize = size(260, 20))
      discard ui.text(rootId & ".pr", "pressed: " & $state.presses & "   released: " & $state.releases, prefSize = size(260, 20))
      discard ui.text(rootId & ".hv", "hover in: " & $state.enters & "   hover out: " & $state.leaves, prefSize = size(260, 20))

component StatTile:
  state:
    caption: string = ""
    value: string = ""
  view(rootId: string):
    panel(rootId, BorderedPanel, boxOpts(spacing = 2, padding = uniformSides(8), align = AlignCenter)):
      discard ui.text(rootId & ".value", state.value, prefSize = size(260, 30), alignSelf = SelfCenter)
      discard ui.text(rootId & ".caption", state.caption, prefSize = size(260, 16), alignSelf = SelfCenter)

component App:
  state:
    left: Counter = Counter()
    right: Counter = Counter()
    probe: EventProbe = EventProbe()
    showDialog: bool = false
    selected: int = 0
    banner: ButtonImageSpec = ButtonImageSpec()
    glyph: ButtonImageSpec = ButtonImageSpec()
  msg:
    LeftMsg(m: Counter.Msg)
    RightMsg(m: Counter.Msg)
    ProbeMsg(m: EventProbe.Msg)
    ToggleDialog
    SelectItem(index: int)
  update(m: Msg):
    case m
    of LeftMsg: update(state.left, m.m)
    of RightMsg: update(state.right, m.m)
    of ProbeMsg: update(state.probe, m.m)
    of ToggleDialog: state.showDialog = not state.showDialog
    of SelectItem: state.selected = m.index
  view(rootId: string):
    relay("root", """
| hero, 96px |
| left, 300px | middle, * | right, 320px |
| footer, 44px |
""", boxOpts()):
      card("root.hero", BorderedPanel, boxOpts(spacing = 4, padding = uniformSides(10), align = AlignStretch)):
        cardHeader("root.hero.h"):
          discard ui.text("root.hero.title", "Shui MVU Demo", prefSize = size(520, 28), alignSelf = SelfCenter)
        cardBody("root.hero.b", boxOpts(spacing = 6, padding = uniformSides(4), align = AlignCenter, justify = JustifyCenter)):
          emit("root.hero.banner", ToggleDialog):
            discard ui.pushButton("root.hero.banner", "Image-backed button", parentId = "root.hero.b", prefSize = size(240, 40), background = state.banner)

      card("root.left", FilledPanel, boxOpts(spacing = 10, padding = uniformSides(10), align = AlignStretch)):
        child(state.left, "root.left.a", LeftMsg)
        child(state.right, "root.left.b", RightMsg)

      card("root.middle", BorderedPanel, boxOpts(spacing = 8, padding = uniformSides(10), align = AlignStretch)):
        cardHeader("root.middle.h"):
          discard ui.text("root.middle.title", "Widget showcase", prefSize = size(260, 22), alignSelf = SelfCenter)
        block:
          var total = StatTile(caption: "Combined total (left + right)",
                               value: $(state.left.count + state.right.count))
          mount(total, "root.middle.total")
        hbox("root.middle.aligns", boxOpts(spacing = 6, align = AlignStretch)):
          discard ui.pushButton("root.middle.al", "Left", parentId = "root.middle.aligns", prefSize = size(80, 30), expand = true, flex = 1, labelAlign = LabelLeft)
          discard ui.pushButton("root.middle.ac", "Center", parentId = "root.middle.aligns", prefSize = size(80, 30), expand = true, flex = 1, labelAlign = LabelCenter)
          discard ui.pushButton("root.middle.ar", "Right", parentId = "root.middle.aligns", prefSize = size(80, 30), expand = true, flex = 1, labelAlign = LabelRight)
        emit("root.middle.adorn", ToggleDialog):
          discard ui.pushButton("root.middle.adorn", "Adornments", parentId = "root.middle", prefSize = size(260, 34),
            startAdorn = proc(ui: var UI; pid: string) =
              discard ui.box(pid & ".dot", prefSize = size(12, 12), alignSelf = SelfCenter),
            endAdorn = proc(ui: var UI; pid: string) =
              discard ui.text(pid & ".x", ">", prefSize = size(14, 18), alignSelf = SelfCenter))
        emit("root.middle.icon", ToggleDialog):
          discard ui.pushButton("root.middle.icon", "Leading image", parentId = "root.middle", prefSize = size(260, 34), leading = state.glyph)
        discard ui.pushButton("root.middle.quiet", "No background", parentId = "root.middle", prefSize = size(260, 30), showBackground = false)
        panel("root.middle.listpanel", BorderedPanel, boxOpts(spacing = 4, padding = uniformSides(6), prefSize = size(0, 150), align = AlignStretch, expand = true, flex = 1)):
          discard ui.text("root.middle.listtitle", "Scrollable, selectable list", prefSize = size(260, 18))
          scrollV("root.middle.list", viewportOpts = boxOpts(prefSize = size(0, 110), expand = true, flex = 1, align = AlignStretch), contentOpts = boxOpts(spacing = 4, padding = uniformSides(4), align = AlignStretch)):
            for i in 0 ..< 18:
              emit("root.middle.item." & $i, SelectItem(index: i)):
                discard ui.pushButton("root.middle.item." & $i, "Item " & $(i + 1) & (if state.selected == i: "   <" else: ""), prefSize = size(220, 26))
        discard ui.text("root.middle.sel", "Selected: item " & $(state.selected + 1), prefSize = size(260, 20))
        emit("root.middle.opendlg", ToggleDialog):
          discard ui.pushButton("root.middle.opendlg", "Open dialog", parentId = "root.middle", prefSize = size(260, 34))

      child(state.probe, "root.right", ProbeMsg)

      card("root.footer", BorderedPanel, boxOpts(spacing = 4, padding = uniformSides(8), align = AlignStretch)):
        cardFooter("root.footer.row", boxOpts(justify = SpaceBetween, align = AlignCenter, padding = uniformSides(4))):
          discard ui.text("root.footer.l", "MVU components - events - nesting - image buttons - dialog - scroll", prefSize = size(620, 18))
          discard ui.text("root.footer.r", "SDL3", prefSize = size(60, 18))

      if state.showDialog:
        dialog("root.dialog", title = "Dialog (driven by model state)", showHeader = true, showClose = true, opts = boxOpts(prefSize = size(480, 220), spacing = 8, padding = uniformSides(10), align = AlignStretch)):
          discard ui.text("root.dialog.l1", "This dialog is open because App.showDialog is true.", prefSize = size(440, 24))
          discard ui.text("root.dialog.l2", "Closing it sends ToggleDialog through update.", prefSize = size(440, 24))
          discard ui.box("root.dialog.spacer", expand = true, flex = 1)
          dialogFooter("root.dialog.footer", boxOpts(justify = SpaceBetween, align = AlignCenter, padding = uniformSides(6))):
            discard ui.text("root.dialog.state", "Modal: other controls are inert", prefSize = size(300, 22))
            emit("root.dialog.ok", ToggleDialog):
              discard ui.pushButton("root.dialog.ok", "Close", parentId = "root.dialog.footer", prefSize = size(100, 30))
        on(dialogCloseId("root.dialog"), Clicked, ToggleDialog)
        ui.showDialog("root.dialog")

proc selfTest() =
  var app = App(left: Counter(step: 1), right: Counter(step: 5))

  update(app, LeftMsg(Increment()))
  doAssert app.left.count == 1
  update(app, RightMsg(SetStep(5)))
  update(app, RightMsg(Increment()))
  doAssert app.right.count == 5
  update(app, ProbeMsg(Press()))
  update(app, ProbeMsg(Press()))
  update(app, ProbeMsg(Enter()))
  doAssert app.probe.presses == 2
  doAssert app.probe.enters == 1
  update(app, ToggleDialog())
  doAssert app.showDialog
  update(app, SelectItem(7))
  doAssert app.selected == 7

  var ui = initUi()
  beginFrame(ui)
  var binds = initTable[(string, UiEvent), AppMsg]()
  proc sink(id: string; ev: UiEvent; m: AppMsg) = binds[(id, ev)] = m
  view(app, ui, "root", sink)
  doAssert ("root.left.a.inc", Clicked) in binds
  doAssert ("root.right.btn", Pressed) in binds
  doAssert ("root.right.btn", HoverIn) in binds
  doAssert ("root.right.btn", HoverOut) in binds
  doAssert ("root.middle.item.3", Clicked) in binds
  let before = app.left.count
  update(app, binds[("root.left.a.inc", Clicked)])
  doAssert app.left.count == before + app.left.step
  echo "MVU self-test passed (left=", app.left.count, " right=", app.right.count,
       " probe.presses=", app.probe.presses, " selected=", app.selected,
       " bindings=", binds.len, ")"

proc guiMain() =
  generateAssets(assetsDir)
  buttonImageDrawHook = cast[pointer](drawImageHook)

  let
    glyph = buttonImage(assetsDir / "glyph.bmp", size(28, 28))
    banner = buttonImage(assetsDir / "banner.bmp", size(200, 44))

  var app = App(
    left: Counter(title: "Left counter", step: 1, icon: glyph),
    right: Counter(title: "Right counter", step: 5, icon: glyph),
    banner: banner,
    glyph: glyph)

  var cfg = defaultRuntimeConfig()
  cfg.title = "Shui MVU Demo"
  cfg.width = 1180
  cfg.height = 760
  cfg.targetFps = 60
  cfg.background = color(22, 24, 30)
  cfg.containerColor = color(36, 40, 50)
  cfg.boxColor = color(96, 126, 176)
  cfg.buttonColor = color(66, 92, 136)
  cfg.buttonHoverColor = color(92, 126, 186)
  cfg.buttonPressedColor = color(120, 150, 210)
  cfg.panelFillColor = color(54, 60, 78)
  cfg.panelInnerColor = color(30, 34, 44)
  cfg.panelBorderColor = color(126, 146, 186)
  cfg.textColor = color(236, 242, 255)

  runProgram(app, "root", cfg)

when isMainModule:
  when defined(mvuTest):
    selfTest()
  else:
    guiMain()
