import shui/widgets

import pixie

when isMainModule:
  var ui = UI()

  var image = newImage(640, 480)
  image.fill(color(0.0, 0.0, 0.0, 1.0))

  var ctx = newContext(image)
  ctx.font = "Inter-Regular.ttf"
  ctx.fontSize = 12

  # ctx.fillStyle = color(0.0, 1.0, 0.0)
  # ctx.fillRect(rect(vec2(0, 24), vec2(32, 32)))

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
      # NOTE: need to add the height of the line to the 'y',
      # since the text origin is at the bottom of the line.
      ctx.fillText(w.text, w.box.x.toFloat, w.box.y.toFloat + 12)

  ui.onMeasureText = proc(text: string): tuple[w, h: int] =
    let metrics = ctx.measureText(text)
    result = (w: metrics.width.int, h: 12)

  widget:
    size = (w: Sizing(kind: Grow), h: Sizing(kind: Grow))
    style = Style(bg: color(0.3, 0.3, 0.3, 1.0))
    dir = Col
    align = Center
    widget:
      size = (w: Sizing(kind: Grow), h: Sizing(kind: Grow))
      dir = Row
      align = Center
      widget:
        text = "Hello"
        style = Style(fg: color(1.0, 1.0, 1.0, 1.0))
      widget:
        text = "World"
        style = Style(fg: color(1.0, 1.0, 1.0, 1.0))
      widget:
        text = "Test"
        style = Style(fg: color(1.0, 1.0, 1.0, 1.0))

  ui.updateLayout((0, 0, 640, 480))
  ui.draw()

  image.writeFile("out.png")
