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

widget Counter:
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
      text(state.title):
        prefSize = size(220, 22)
        alignSelf = SelfCenter
      text("Count: " & $state.count & "  (x2 = " & $(state.count * 2) & ")"):
        prefSize = size(220, 26)
        alignSelf = SelfCenter
      hbox(rootId & ".ops", boxOpts(spacing = 6, align = AlignStretch, justify = JustifyCenter)):
        button("-"):
          prefSize = size(48, 34)
          on Clicked, Decrement
        button("+"):
          prefSize = size(64, 34)
          leading = state.icon
          on Clicked, Increment
        button("Reset"):
          prefSize = size(84, 34)
          showBackground = false
          on Clicked, Reset
      text("Step = " & $state.step):
        prefSize = size(220, 18)
        alignSelf = SelfCenter
      hbox(rootId & ".steps", boxOpts(spacing = 6, align = AlignStretch, justify = JustifyCenter)):
        for sv in [1, 5, 10]:
          button("x" & $sv):
            key = sv
            prefSize = size(56, 28)
            on Clicked, SetStep(sv)

widget EventProbe:
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
      text("One button, five events"):
        prefSize = size(280, 22)
        alignSelf = SelfCenter
      button("Press / hover me"):
        prefSize = size(280, 48)
        alignSelf = SelfCenter
        on Clicked, Click
        on Pressed, Press
        on Released, Release
        on HoverIn, Enter
        on HoverOut, Leave
      text("clicks: " & $state.clicks):
        prefSize = size(280, 20)
      text("pressed: " & $state.presses & "   released: " & $state.releases):
        prefSize = size(280, 20)
      text("hover in: " & $state.enters & "   hover out: " & $state.leaves):
        prefSize = size(280, 20)

widget TextDemo:
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
      text("Text input (click, then type)"):
        prefSize = size(280, 18)
      input(state.value):
        placeholder = "type here..."
        prefSize = size(280, 32)
        onText Typed
        onKey KeyBackspace, Backspace
      hbox(rootId & ".row", boxOpts(spacing = 6, align = AlignStretch)):
        text("value: " & state.value):
          prefSize = size(200, 22)
          expand = true
          flex = 1
        button("Clear"):
          prefSize = size(72, 26)
          on Clicked, Clear

widget PickerDemo:
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
      text("Combo box: " & state.options[state.sel]):
        prefSize = size(280, 18)
      ui.comboBox(rootId & ".combo", state.options, selectedIndex = state.sel, width = 280, itemHeight = 28)
      on(comboBoxTriggerId(rootId & ".combo"), Clicked, Toggle)
      if state.open:
        ui.setVisible(comboBoxMenuId(rootId & ".combo"), true)
        for i in 0 ..< state.options.len:
          on(comboBoxOptionId(rootId & ".combo", i), Clicked, Pick(i))

widget StatTile:
  state:
    caption: string = ""
    value: string = ""
  view(rootId: string):
    panel(rootId, BorderedPanel, boxOpts(spacing = 2, padding = uniformSides(8), align = AlignCenter)):
      text(state.value):
        prefSize = size(280, 28)
        alignSelf = SelfCenter
      text(state.caption):
        prefSize = size(280, 16)
        alignSelf = SelfCenter

widget App:
  state:
    left: Counter = Counter()
    right: Counter = Counter()
    probe: EventProbe = EventProbe()
    editor: TextDemo = TextDemo()
    picker: PickerDemo = PickerDemo()
    showDialog: bool = false
    selected: int = 0
    banner: ButtonImageSpec = ButtonImageSpec()
    glyph: ButtonImageSpec = ButtonImageSpec()
  msg:
    ToggleDialog
    SelectItem(index: int)
  update(m: Msg):
    case m
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
          text("Shui MVU Demo"):
            prefSize = size(520, 28)
            alignSelf = SelfCenter
        cardBody("root.hero.b", boxOpts(spacing = 6, padding = uniformSides(4), align = AlignCenter)):
          button("Image-backed button"):
            prefSize = size(260, 40)
            background = state.banner
            on Clicked, ToggleDialog

      # The left column drives its children with a layout string instead of
      # plain flex: the two counters land in named cells `a`/`b`. A child whose
      # id named no cell would fall back to flex flow rather than vanish (see the
      # "flex-flows leftovers" test in tests/test_layout.nim).
      card("root.left", FilledPanel, boxOpts(spacing = 10, padding = uniformSides(10), align = AlignStretch,
          relayLayout = "| a, * |\n| b, * |")):
        child(left, "root.left.a")
        child(right, "root.left.b"):
          if m.kind == Reset:
            state.left.count = 0

      card("root.middle", BorderedPanel, boxOpts(spacing = 8, padding = uniformSides(10), align = AlignStretch)):
        cardHeader("root.middle.h"):
          text("Widget showcase"):
            prefSize = size(280, 22)
            alignSelf = SelfCenter
        block:
          var total = StatTile(caption: "Combined total (left + right)",
                               value: $(state.left.count + state.right.count))
          mount(total, "root.middle.total")
        hbox("root.middle.aligns", boxOpts(spacing = 6, align = AlignStretch)):
          button("Left"):
            prefSize = size(80, 30)
            expand = true
            flex = 1
            labelAlign = LabelLeft
          button("Center"):
            prefSize = size(80, 30)
            expand = true
            flex = 1
            labelAlign = LabelCenter
          button("Right"):
            prefSize = size(80, 30)
            expand = true
            flex = 1
            labelAlign = LabelRight
        button("Leading image"):
          prefSize = size(280, 32)
          leading = state.glyph
          on Clicked, ToggleDialog
        child(editor, "root.middle.text")
        child(picker, "root.middle.picker")
        panel("root.middle.listpanel", BorderedPanel, boxOpts(spacing = 4, padding = uniformSides(6), align = AlignStretch, expand = true, flex = 1)):
          text("Scroll wheel + selectable list"):
            prefSize = size(280, 18)
          scrollV("root.middle.list", viewportOpts = boxOpts(expand = true, flex = 1, align = AlignStretch), contentOpts = boxOpts(spacing = 4, padding = uniformSides(4), align = AlignStretch)):
            for i in 0 ..< 24:
              button("Item " & $(i + 1) & (if state.selected == i: "   <" else: "")):
                key = i
                prefSize = size(240, 26)
                on Clicked, SelectItem(i)
        text("Selected: item " & $(state.selected + 1)):
          prefSize = size(280, 20)

      child(probe, "root.right")

      card("root.footer", BorderedPanel, boxOpts(spacing = 4, padding = uniformSides(8), align = AlignStretch)):
        cardFooter("root.footer.row", boxOpts(justify = SpaceBetween, align = AlignCenter, padding = uniformSides(4))):
          text("MVU - events - text input - combobox - scroll - dialog"):
            prefSize = size(640, 18)
          text("SDL3"):
            prefSize = size(60, 18)

      if state.showDialog:
        dialog("root.dialog", title = "Dialog (model-driven)", showHeader = true, showClose = true, opts = boxOpts(prefSize = size(480, 200), spacing = 8, padding = uniformSides(10), align = AlignStretch)):
          text("Open because App.showDialog is true."):
            prefSize = size(440, 24)
          box:
            expand = true
            flex = 1
          dialogFooter("root.dialog.footer", boxOpts(justify = SpaceBetween, align = AlignCenter, padding = uniformSides(6))):
            text("Modal while open"):
              prefSize = size(300, 22)
            button("Close"):
              prefSize = size(100, 30)
              on Clicked, ToggleDialog
        on(dialogCloseId("root.dialog"), Clicked, ToggleDialog)
        ui.showDialog("root.dialog")

proc selfTest() =
  var app = App()
  update(app, ToggleDialog())
  doAssert app.showDialog
  update(app, SelectItem(7))
  doAssert app.selected == 7

  update(app, command(proc(p: var App) = update(p.left, Increment())))
  doAssert app.left.count == app.left.step

  app.picker.open = true
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
  doAssert ev.len > 0
  doAssert tx.len == 1
  doAssert ky.len == 1
  let n = app.editor.value.len
  for id, make in tx:
    update(app, make("z"))
  doAssert app.editor.value.len == n + 1
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
