import std/macros

import ../elements

macro windowPanel*(w, h: int, title: string, id: ElemId, blk: untyped) =
  var onClick = nnkStmtList.newTree()
  var closeBtn = nnkStmtList.newTree()
  var pad = newLit(8)
  for i in 0 ..< blk.len:
    if blk[i].kind == nnkCall and blk[i][0].repr == "onClose":
      let fn = blk[i][1]
      blk[i] = nnkStmtList.newTree()
      onClick = quote:
        if ElemId("window-back-btn").pressed(ui):
          `fn`
      closeBtn = quote:
        button("X", ElemId"window-back-btn"):
          discard
      pad = newLit(4)
  quote:
    `onClick`
    elem:
      dir = Col
      size = (
        w: Sizing(kind: Fixed, min: `w`, max: `w`), 
        h: Sizing(kind: Fixed, min: `h`, max: `h`), 
      )
      style = style(
        border = 1, 
        padding = 0,
        borderRadius = 0.05,
        borderColor = color(0.6), 
        bg = color(0.5),
        gap = 0
      )
      align = Start
      crossAlign = Start

      elem:
        dir = Row
        size = (w: Grow, h: Fit)
        style = style(padding = `pad`, bg = color(0.6, 0.6, 0.6), borderRadius = 0.5)
        align = Start
        crossAlign = Center
        elem:
          text = `title`
          style = style(fg = color(0.0, 0.0, 0.0))
          size = (w: Grow, h: Fit)
        `closeBtn`
      elem:
        id = `id`
        dir = Col
        size = (w: Grow, h: Grow)
        style = style(padding = 8)
        `blk`
