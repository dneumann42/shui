import std/macros

import elements

macro button*(text: string, id: ElemId, blk: untyped) =
  quote:
    ui.widget(`id`)

    block:
      var bgCol = 
        if `id`.hot(ui):
          color(0.4, 0.4, 0.7, 1.0)
        else:
          color(0.1, 0.1, 0.3, 1.0)

      if `id`.down(ui):
        bgCol = color(0.4, 0.4, 0.9, 1.0)
          
      elem:
        id = `id`
        style = Style(
          fg: color(1.0, 1.0, 1.0, 1.0),
          bg: bgCol,
          border: color(0.6, 0.6, 0.6, 1.0),
          padding: 6,
          borderRadius: 0.4,
        )
        size = (w: Sizing(kind: Fit), h: Sizing(kind: Fit))
        dir = Row
        align = Center
        crossAlign = Center
        border = 1
        elem:
          text = `text`
          style = Style(fg: color(1.0, 1.0, 1.0, 1.0), bg: color(0.0, 0.0, 0.0, 0.0))
        `blk`
