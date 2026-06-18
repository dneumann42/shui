import std/os
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
      discard ui.text(rootId & ".count", "Count: " & $state.count & "  (x2 = " & $(state.count * 2) & ")", prefSize = size(220, 26), alignSelf = SelfCenter)
      hbox(rootId & ".ops", boxOpts(spacing = 6, align = AlignStretch, justify = JustifyCenter)):
        discard ui.pushButton(rootId & ".dec", "-", parentId = rootId & ".ops", prefSize = size(48, 34))
        on(rootId & ".dec", Clicked, Decrement)
        discard ui.pushButton(rootId & ".inc", "+", parentId = rootId & ".ops", prefSize = size(64, 34), leading = state.icon)
        on(rootId & ".inc", Clicked, Increment)
        discard ui.pushButton(rootId & ".reset", "Reset", parentId = rootId & ".ops", prefSize = size(84, 34), showBackground = false)
        on(rootId & ".reset", Clicked, Reset)
      discard ui.text(rootId & ".steplabel", "Step = " & $state.step, prefSize = size(220, 18), alignSelf = SelfCenter)
      hbox(rootId & ".steps", boxOpts(spacing = 6, align = AlignStretch, justify = JustifyCenter)):
        for sv in [1, 5, 10]:
          let bid = rootId & ".s" & $sv
          discard ui.pushButton(bid, "x" & $sv, parentId = rootId & ".steps", prefSize = size(56, 28))
          on(bid, Clicked, SetStep(sv))

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
      discard ui.text(rootId & ".title", "One button, five events", prefSize = size(280, 22), alignSelf = SelfCenter)
      discard ui.pushButton(rootId & ".btn", "Press / hover me", prefSize = size(280, 48), alignSelf = SelfCenter)
      on(rootId & ".btn", Clicked, Click)
      on(rootId & ".btn", Pressed, Press)
      on(rootId & ".btn", Released, Release)
      on(rootId & ".btn", HoverIn, Enter)
      on(rootId & ".btn", HoverOut, Leave)
      discard ui.text(rootId & ".c", "clicks: " & $state.clicks, prefSize = size(280, 20))
      discard ui.text(rootId & ".pr", "pressed: " & $state.presses & "   released: " & $state.releases, prefSize = size(280, 20))
      discard ui.text(rootId & ".hv", "hover in: " & $state.enters & "   hover out: " & $state.leaves, prefSize = size(280, 20))

component TextDemo:
  state:
    value: string = ""
  msg:
    Typed(ch: string)
    Backspace
    Clear
  update(m: Msg):
    case m
    of Typed: state.value.add m.ch
    of Backspace:
      if state.value.len > 0: state.value.setLen(state.value.len - 1)
    of Clear: state.value = ""
  view(rootId: string):
    vbox(rootId, boxOpts(spacing = 6, align = AlignStretch)):
      discard ui.text(rootId & ".label", "Text input (click, then type)", prefSize = size(280, 18))
      discard ui.inputField(rootId & ".box", state.value, "type here...", parentId = rootId, prefSize = size(280, 32))
      onText(rootId & ".box", Typed)
      onKey(rootId & ".box", KeyBackspace, Backspace)
      hbox(rootId & ".row", boxOpts(spacing = 6, align = AlignStretch)):
        discard ui.text(rootId & ".echo", "value: " & state.value, parentId = rootId & ".row", prefSize = size(200, 22), expand = true, flex = 1)
        discard ui.pushButton(rootId & ".clear", "Clear", parentId = rootId & ".row", prefSize = size(72, 26))
        on(rootId & ".clear", Clicked, Clear)

component PickerDemo:
  state:
    open: bool = false
    sel: int = 0
    options: seq[string] = @["Red", "Green", "Blue", "Amber"]
  msg:
    Toggle
    Pick(index: int)
  update(m: Msg):
    case m
    of Toggle: state.open = not state.open
    of Pick:
      state.sel = m.index
      state.open = false
  view(rootId: string):
    vbox(rootId, boxOpts(spacing = 6, align = AlignStretch)):
      discard ui.text(rootId & ".label", "Combo box: " & state.options[state.sel], prefSize = size(280, 18))
      discard ui.comboBox(rootId & ".combo", state.options, selectedIndex = state.sel, width = 280, itemHeight = 28)
      on(comboBoxTriggerId(rootId & ".combo"), Clicked, Toggle)
      if state.open:
        ui.setVisible(comboBoxMenuId(rootId & ".combo"), true)
        for i in 0 ..< state.options.len:
          on(comboBoxOptionId(rootId & ".combo", i), Clicked, Pick(i))

component StatTile:
  state:
    caption: string = ""
    value: string = ""
  view(rootId: string):
    panel(rootId, BorderedPanel, boxOpts(spacing = 2, padding = uniformSides(8), align = AlignCenter)):
      discard ui.text(rootId & ".value", state.value, prefSize = size(280, 28), alignSelf = SelfCenter)
      discard ui.text(rootId & ".caption", state.caption, prefSize = size(280, 16), alignSelf = SelfCenter)

component App:
  state:
    left: Counter = Counter()
    right: Counter = Counter()
    probe: EventProbe = EventProbe()
    text: TextDemo = TextDemo()
    picker: PickerDemo = PickerDemo()
    showDialog: bool = false
    selected: int = 0
    banner: ButtonImageSpec = ButtonImageSpec()
    glyph: ButtonImageSpec = ButtonImageSpec()
  msg:
    LeftMsg(m: Counter.Msg)
    RightMsg(m: Counter.Msg)
    ProbeMsg(m: EventProbe.Msg)
    TextMsg(m: TextDemo.Msg)
    PickerMsg(m: PickerDemo.Msg)
    ToggleDialog
    SelectItem(index: int)
  update(m: Msg):
    case m
    of LeftMsg: update(state.left, m.m)
    of RightMsg: update(state.right, m.m)
    of ProbeMsg: update(state.probe, m.m)
    of TextMsg: update(state.text, m.m)
    of PickerMsg: update(state.picker, m.m)
    of ToggleDialog: state.showDialog = not state.showDialog
    of SelectItem: state.selected = m.index
  view(rootId: string):
    relay("root", """
| hero, 120px |
| left, 300px | middle, * | right, 340px |
| footer, 44px |
""", boxOpts()):
      card("root.hero", BorderedPanel, boxOpts(spacing = 4, padding = uniformSides(10), align = AlignStretch)):
        cardHeader("root.hero.h"):
          discard ui.text("root.hero.title", "Shui MVU Demo", prefSize = size(520, 28), alignSelf = SelfCenter)
        cardBody("root.hero.b", boxOpts(spacing = 6, padding = uniformSides(4), align = AlignCenter)):
          discard ui.pushButton("root.hero.banner", "Image-backed button", parentId = "root.hero.b", prefSize = size(260, 40), background = state.banner)
          on("root.hero.banner", Clicked, ToggleDialog)

      card("root.left", FilledPanel, boxOpts(spacing = 10, padding = uniformSides(10), align = AlignStretch)):
        child(state.left, "root.left.a", LeftMsg)
        child(state.right, "root.left.b", RightMsg)

      card("root.middle", BorderedPanel, boxOpts(spacing = 8, padding = uniformSides(10), align = AlignStretch)):
        cardHeader("root.middle.h"):
          discard ui.text("root.middle.title", "Widget showcase", prefSize = size(280, 22), alignSelf = SelfCenter)
        block:
          var total = StatTile(caption: "Combined total (left + right)",
                               value: $(state.left.count + state.right.count))
          mount(total, "root.middle.total")
        hbox("root.middle.aligns", boxOpts(spacing = 6, align = AlignStretch)):
          discard ui.pushButton("root.middle.al", "Left", parentId = "root.middle.aligns", prefSize = size(80, 30), expand = true, flex = 1, labelAlign = LabelLeft)
          discard ui.pushButton("root.middle.ac", "Center", parentId = "root.middle.aligns", prefSize = size(80, 30), expand = true, flex = 1, labelAlign = LabelCenter)
          discard ui.pushButton("root.middle.ar", "Right", parentId = "root.middle.aligns", prefSize = size(80, 30), expand = true, flex = 1, labelAlign = LabelRight)
        discard ui.pushButton("root.middle.icon", "Leading image", parentId = "root.middle", prefSize = size(280, 32), leading = state.glyph)
        on("root.middle.icon", Clicked, ToggleDialog)
        child(state.text, "root.middle.text", TextMsg)
        child(state.picker, "root.middle.picker", PickerMsg)
        panel("root.middle.listpanel", BorderedPanel, boxOpts(spacing = 4, padding = uniformSides(6), align = AlignStretch, expand = true, flex = 1)):
          discard ui.text("root.middle.listtitle", "Scroll wheel + selectable list", prefSize = size(280, 18))
          scrollV("root.middle.list", viewportOpts = boxOpts(expand = true, flex = 1, align = AlignStretch), contentOpts = boxOpts(spacing = 4, padding = uniformSides(4), align = AlignStretch)):
            for i in 0 ..< 24:
              let iid = "root.middle.item." & $i
              discard ui.pushButton(iid, "Item " & $(i + 1) & (if state.selected == i: "   <" else: ""), prefSize = size(240, 26))
              on(iid, Clicked, SelectItem(i))
        discard ui.text("root.middle.sel", "Selected: item " & $(state.selected + 1), prefSize = size(280, 20))

      child(state.probe, "root.right", ProbeMsg)

      card("root.footer", BorderedPanel, boxOpts(spacing = 4, padding = uniformSides(8), align = AlignStretch)):
        cardFooter("root.footer.row", boxOpts(justify = SpaceBetween, align = AlignCenter, padding = uniformSides(4))):
          discard ui.text("root.footer.l", "MVU - events - text input - combobox - scroll - dialog", prefSize = size(640, 18))
          discard ui.text("root.footer.r", "SDL3", prefSize = size(60, 18))

      if state.showDialog:
        dialog("root.dialog", title = "Dialog (model-driven)", showHeader = true, showClose = true, opts = boxOpts(prefSize = size(480, 200), spacing = 8, padding = uniformSides(10), align = AlignStretch)):
          discard ui.text("root.dialog.l1", "Open because App.showDialog is true.", prefSize = size(440, 24))
          discard ui.box("root.dialog.spacer", expand = true, flex = 1)
          dialogFooter("root.dialog.footer", boxOpts(justify = SpaceBetween, align = AlignCenter, padding = uniformSides(6))):
            discard ui.text("root.dialog.state", "Modal while open", prefSize = size(300, 22))
            discard ui.pushButton("root.dialog.ok", "Close", parentId = "root.dialog.footer", prefSize = size(100, 30))
            on("root.dialog.ok", Clicked, ToggleDialog)
        on(dialogCloseId("root.dialog"), Clicked, ToggleDialog)
        ui.showDialog("root.dialog")

proc selfTest() =
  var app = App()

  update(app, LeftMsg(Increment()))
  doAssert app.left.count == 1
  update(app, ProbeMsg(Press()))
  update(app, ProbeMsg(Enter()))
  doAssert app.probe.presses == 1 and app.probe.enters == 1
  update(app, TextMsg(Typed("a")))
  update(app, TextMsg(Typed("b")))
  doAssert app.text.value == "ab"
  update(app, TextMsg(Backspace()))
  doAssert app.text.value == "a"
  update(app, PickerMsg(Toggle()))
  doAssert app.picker.open
  update(app, PickerMsg(Pick(2)))
  doAssert app.picker.sel == 2 and not app.picker.open
  update(app, ToggleDialog())
  doAssert app.showDialog
  update(app, SelectItem(7))
  doAssert app.selected == 7

  var ui = initUi()
  beginFrame(ui)
  var ev = initTable[(string, UiEvent), AppMsg]()
  var tx = initTable[string, proc(ch: string): AppMsg]()
  var ky = initTable[(string, KeyCode), AppMsg]()
  let disp = Dispatcher[AppMsg](
    event: proc(id: string; e: UiEvent; m: AppMsg) = ev[(id, e)] = m,
    text: proc(id: string; make: proc(ch: string): AppMsg) = tx[id] = make,
    key: proc(id: string; code: KeyCode; m: AppMsg) = ky[(id, code)] = m)
  view(app, ui, "root", disp)
  doAssert ("root.left.a.inc", Clicked) in ev
  doAssert ("root.right.btn", HoverIn) in ev
  doAssert "root.middle.text.box" in tx
  doAssert ("root.middle.text.box", KeyBackspace) in ky
  let n = app.text.value.len
  update(app, tx["root.middle.text.box"]("z"))
  doAssert app.text.value.len == n + 1
  echo "demo self-test passed"

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
  cfg.width = 1200
  cfg.height = 820
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
