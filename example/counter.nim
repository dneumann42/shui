import std/tables
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
    ui.vbox("root", boxOpts(spacing = 12, padding = uniformSides(24), align = AlignCenter)):
      discard ui.text("title", "Shui Counter", prefSize = size(220, 30), alignSelf = SelfCenter)
      discard ui.text("value", "0", prefSize = size(220, 42))
      ui.hbox("buttons", boxOpts(spacing = 8, align = AlignStretch)):
        discard ui.text("dec", "-", prefSize = size(70, 36), measure = fixed(70, 36))
        discard ui.text("reset", "reset", prefSize = size(90, 36), measure = fixed(90, 36))
        discard ui.text("inc", "+", prefSize = size(70, 36), measure = fixed(70, 36))

  var cfg = defaultRuntimeConfig()
  cfg.title = "Shui Counter"
  cfg.width = 520
  cfg.height = 320
  cfg.targetFps = 60
  cfg.containerColor = color(46, 46, 56)
  cfg.boxColor = color(70, 90, 120)
  cfg.textBgColor = color(70, 90, 120)
  cfg.textColor = color(242, 246, 255)
  cfg.background = color(28, 28, 34)
  # Fedora dejavu-sans-fonts package path.
  cfg.fontPath = "/usr/share/fonts/dejavu-sans-fonts/DejaVuSans.ttf"
  cfg.fontSize = 18

  var count = 0
  var screenW = cfg.width
  var screenH = cfg.height

  proc syncValue() =
    setText(ui, "value", $count)

  syncValue()

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
            inc count
            syncValue()
          elif "dec" in frame.rects and frame.rects["dec"].contains(point(ev.x, ev.y)):
            dec count
            syncValue()
          elif "reset" in frame.rects and frame.rects["reset"].contains(point(ev.x, ev.y)):
            count = 0
            syncValue()
    else:
      discard
  )
