import shui/widgets

import pixie

when isMainModule:
  var ui = UI()

  var image = newImage(640, 480)
  image.fill(color(0.0, 0.0, 0.0, 1.0))

  var ctx = newContext(image)
  ctx.font = "Inter-Regular.ttf"
  ctx.fontSize = 12

  ctx.fillStyle = color(1.0, 0.0, 0.0)
  ctx.fillText("HELLO WORLD 123", 100.0, 100.0)

  ui.onDraw = proc(w: Widget) =
    ctx.fillStyle = w.style.bg
    ctx.fillRect(
      rect(
        vec2(w.box.x.toFloat, w.box.y.toFloat), #
        vec2(w.box.w.toFloat, w.box.h.toFloat),
      )
    )
    if w.text.len > 0:
      ctx.fillStyle = w.style.fg
      ctx.fillText(w.text, w.box.x.toFloat, w.box.h.toFloat)

  ui.onMeasureText = proc(text: string): tuple[w, h: int] =
    let metrics = ctx.measureText(text)
    result = (w: metrics.width.int, h: 12)

  widget:
    size = (w: Sizing(kind: Fit), h: Sizing(kind: Fit))
    style = Style(bg: color(0.3, 0.3, 0.3, 1.0))
    dir = Col
    widget:
      style = Style(fg: color(1.0, 0.0, 1.0, 1.0))
      text = "Hello"
    widget:
      style = Style(fg: color(1.0, 0.0, 1.0, 1.0))
      text = "World"

  ui.updateLayout()
  ui.draw()

  image.writeFile("out.png")
