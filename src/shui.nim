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

  widget: #0
    size = (w: Sizing(kind: Fit), h: Sizing(kind: Fit))
    style = Style(bg: color(0.3, 0.3, 0.3, 1.0))
    dir = Col
    widget: #1
      style = Style(fg: color(1.0, 0.0, 1.0, 1.0))
      text = "Hello"
    widget: #2
      style = Style(fg: color(1.0, 0.0, 1.0, 1.0))
      text = "World"
    widget: #3
      size = (w: Sizing(kind: Fit), h: Sizing(kind: Fit))
      style = Style(bg: color(0.3, 0.0, 0.3, 1.0))
      dir = Row
      widget: #4
        style = Style(fg: color(1.0, 0.0, 1.0, 1.0))
        text = "Left"
      widget: #5
        style = Style(fg: color(1.0, 0.0, 1.0, 1.0))
        text = "Right"
    widget: #6
      style = Style(fg: color(1.0, 0.0, 1.0, 1.0))
      text = "Ahhhhhh"

  ui.updateLayout()
  ui.draw()

  image.writeFile("out.png")
