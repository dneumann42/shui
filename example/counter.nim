import std/[tables, strutils]
import shui
import shui/uirelay_runtime
import uirelays/input
import uirelays/screen

proc fixed(w, h: int): IntrinsicMeasureProc =
  result = proc(maxW, maxH: int): Size =
    discard maxW
    discard maxH
    size(w, h)

proc setText(ui: var UI; id, value: string) =
  if id notin ui.elements:
    return
  var el = ui.elements[id]
  if el.kind != Text:
    return
  el.text = value
  ui.elements[id] = el

when isMainModule:
  var ui = initUi()

  ui.layout("root"):
    ui.relay("root", """
| hero, 110px |
| left, 260px | middle, * | right, 300px |
| footer, 64px |
""", boxOpts()):
      ui.card("root.hero", BorderedPanel, boxOpts(spacing = 4, padding = uniformSides(10), align = AlignStretch)):
        ui.cardHeader("root.hero.header"):
          discard ui.text("title", "Shui Counter Dashboard", prefSize = size(480, 30), alignSelf = SelfCenter)
        ui.cardBody("root.hero.body", boxOpts(spacing = 4, padding = uniformSides(6), align = AlignCenter)):
          discard ui.text("subtitle", "Control element hover + card layout stress test", prefSize = size(480, 24), alignSelf = SelfCenter)

      ui.card("root.left", FilledPanel, boxOpts(spacing = 8, padding = uniformSides(10), align = AlignStretch)):
        ui.cardHeader("left.controls.header"):
          discard ui.text("controls.title", "Controls", prefSize = size(180, 24))
        ui.cardBody("left.controls.body", boxOpts(spacing = 6, padding = uniformSides(6), align = AlignStretch)):
          discard ui.button("inc", "Increment", prefSize = size(180, 36), measure = fixed(180, 36))
          discard ui.button("dec", "Decrement", prefSize = size(180, 36), measure = fixed(180, 36))
          discard ui.button("reset", "Reset", prefSize = size(180, 36), measure = fixed(180, 36))
          discard ui.comboBox("step.combo", @["1", "2", "5", "10", "20", "40", "80", "160"], selectedIndex = 0, width = 180, itemHeight = 30)
        ui.cardFooter("left.controls.footer"):
          discard ui.text("step.label", "Step", prefSize = size(60, 22))
          discard ui.text("step.value", "1", prefSize = size(40, 22), alignSelf = SelfEnd)

      ui.card("root.middle", BorderedPanel, boxOpts(spacing = 8, padding = uniformSides(10), align = AlignStretch)):
        ui.cardHeader("middle.metrics.header"):
          discard ui.text("metrics.title", "Metrics", prefSize = size(220, 24), alignSelf = SelfCenter)
        ui.cardBody("middle.metrics.body", boxOpts(spacing = 10, padding = uniformSides(8), align = AlignStretch, expand = true, flex = 1)):
          ui.panel("counter.panel", FilledPanel, boxOpts(spacing = 4, padding = uniformSides(10), align = AlignCenter)):
            discard ui.text("count.value", "0", prefSize = size(180, 54), alignSelf = SelfCenter)
            discard ui.text("count.hint", "Current Count", prefSize = size(180, 20), alignSelf = SelfCenter)

          ui.hbox("derived.row", boxOpts(spacing = 8, align = AlignStretch)):
            ui.panel("double.panel", BorderedPanel, boxOpts(spacing = 4, padding = uniformSides(8), prefSize = size(180, 120), expand = true, flex = 1)):
              discard ui.text("double.label", "Double", prefSize = size(80, 18))
              discard ui.text("double.value", "0", prefSize = size(80, 28))
            ui.panel("square.panel", BorderedPanel, boxOpts(spacing = 4, padding = uniformSides(8), prefSize = size(180, 120), expand = true, flex = 1)):
              discard ui.text("square.label", "Square", prefSize = size(80, 18))
              discard ui.text("square.value", "0", prefSize = size(80, 28))

          ui.panel("vscroll.panel", BorderedPanel, boxOpts(spacing = 4, padding = uniformSides(6), prefSize = size(0, 180), align = AlignStretch, expand = true, flex = 1)):
            discard ui.text("vscroll.title", "Vertical Scroll List", prefSize = size(200, 20))
            ui.scrollV("vscroll.list", viewportOpts = boxOpts(prefSize = size(0, 140), expand = true, flex = 1, align = AlignStretch), contentOpts = boxOpts(spacing = 4, padding = uniformSides(4), align = AlignStretch)):
              for i in 0 .. 24:
                discard ui.button("v.item." & $i, "Item " & $(i + 1), prefSize = size(180, 26))

          ui.panel("hscroll.panel", BorderedPanel, boxOpts(spacing = 4, padding = uniformSides(6), prefSize = size(0, 160), align = AlignStretch)):
            discard ui.text("hscroll.title", "Horizontal Scroll List", prefSize = size(220, 20))
            ui.scrollH("hscroll.list", viewportOpts = boxOpts(prefSize = size(0, 112), align = AlignStretch), contentOpts = boxOpts(spacing = 6, padding = uniformSides(4), align = AlignCenter)):
              for i in 0 .. 15:
                discard ui.button("h.item." & $i, "Card " & $(i + 1), prefSize = size(120, 72))

      ui.card("root.right", FilledPanel, boxOpts(spacing = 8, padding = uniformSides(10), align = AlignStretch)):
        ui.cardHeader("right.activity.header"):
          discard ui.text("activity.title", "Activity", prefSize = size(180, 24))
        ui.cardBody("right.activity.body", boxOpts(spacing = 6, padding = uniformSides(6), align = AlignStretch)):
          discard ui.text("activity.1", "- Waiting for input")
          discard ui.text("activity.2", "- Hover buttons for highlight")
          discard ui.text("activity.3", "- Click controls to mutate")

      ui.card("root.footer", BorderedPanel, boxOpts(spacing = 4, padding = uniformSides(8), align = AlignStretch)):
        ui.cardFooter("root.footer.row", boxOpts(justify = SpaceBetween, align = AlignCenter, padding = uniformSides(4))):
          discard ui.text("footer.left", "Layout: cards + header/body/footer + panels", prefSize = size(420, 20))
          discard ui.text("footer.right", "SDL3 Runtime", prefSize = size(120, 20))

  var cfg = defaultRuntimeConfig()
  cfg.title = "Shui Counter Cards"
  cfg.width = 1100
  cfg.height = 720
  cfg.targetFps = 60

  cfg.background = color(22, 24, 30)
  cfg.containerColor = color(36, 40, 50)
  cfg.boxColor = color(64, 76, 96)
  cfg.textBgColor = color(58, 66, 84)
  cfg.buttonColor = color(66, 92, 136)
  cfg.buttonHoverColor = color(92, 126, 186)
  cfg.panelFillColor = color(54, 60, 78)
  cfg.panelInnerColor = color(30, 34, 44)
  cfg.panelBorderColor = color(126, 146, 186)
  cfg.textColor = color(236, 242, 255)

  cfg.fontPath = "/usr/share/fonts/dejavu-sans-fonts/DejaVuSans.ttf"
  cfg.fontSize = 18

  var count = 0
  var step = 1
  var screenW = cfg.width
  var screenH = cfg.height

  proc syncValues() =
    setText(ui, "count.value", $count)
    setText(ui, "double.value", $(count * 2))
    setText(ui, "square.value", $(count * count))
    setText(ui, "step.value", $step)

  proc note(text: string) =
    setText(ui, "activity.1", text)

  syncValues()

  runUirelayRuntime(ui, "root", cfg, proc(ev: Event; ui: var UI; running: var bool) =
    discard running
    case ev.kind
    of WindowResizeEvent:
      screenW = ev.x
      screenH = ev.y
    of MouseDownEvent:
      if ev.button == LeftButton:
        let frame = layoutInRect(ui, "root", rect(0, 0, screenW, screenH))
        if frame.ok:
          if "inc" in frame.rects and frame.rects["inc"].contains(point(ev.x, ev.y)):
            count += step
            note("- Increment pressed")
          elif "dec" in frame.rects and frame.rects["dec"].contains(point(ev.x, ev.y)):
            count -= step
            note("- Decrement pressed")
          elif "reset" in frame.rects and frame.rects["reset"].contains(point(ev.x, ev.y)):
            count = 0
            note("- Reset pressed")
          elif comboBoxTriggerId("step.combo") in frame.rects and frame.rects[comboBoxTriggerId("step.combo")].contains(point(ev.x, ev.y)):
            discard ui.comboBoxToggle("step.combo")
            note("- Step menu toggled")
          else:
            for i in 0 .. 8:
              let oid = comboBoxOptionId("step.combo", i)
              if oid in frame.rects and frame.rects[oid].contains(point(ev.x, ev.y)):
                if ui.comboBoxSelect("step.combo", i):
                  if comboBoxTriggerId("step.combo") in ui.elements and ui.elements[comboBoxTriggerId("step.combo")].kind == Text:
                    step = parseInt(ui.elements[comboBoxTriggerId("step.combo")].text)
                    note("- Step changed")
                break
          syncValues()
    else:
      discard
  )
