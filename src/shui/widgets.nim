import std/macros

import elements

macro button*(text: string, blk: untyped) =
  quote:
    elem:
      style = Style(
        fg: color(1.0, 1.0, 1.0, 1.0),
        bg: color(0.0, 0.0, 0.2, 1.0),
        border: color(1.0, 1.0, 1.0, 1.0),
        padding: 8,
        borderRadius: 0.4,
      )
      size = (w: Sizing(kind: Fit), h: Sizing(kind: Fit))
      dir = Row
      align = Center
      crossAlign = Center
      border = 2
      elem:
        text = `text`
        style = Style(fg: color(1.0, 1.0, 1.0, 1.0), bg: color(0.0, 0.0, 0.0, 1.0))
      `blk`
