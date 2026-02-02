import std/[macros, strutils]

import ../elements

type 
  ButtonToggleState* = enum
    None
    Off
    On
  ButtonConfig* = object
    disabled* = false
    toggle*: ButtonToggleState

proc extractConfig(node: NimNode): ButtonConfig =
  result = ButtonConfig()
  for child in node.items:
    if child.kind == nnkAsgn:
      if child[0].repr == "disabled":
        result.disabled = child[1].repr == "true"
      if child[0].repr == "toggle":
        result.toggle = parseEnum[ButtonToggleState](child[1].repr)

proc toToggle*(bol: bool): ButtonToggleState = (if bol: On else: Off)

macro button*(text: string, id: ElemId, blk: untyped) =
  let config = extractConfig(blk)
  var onClick = nnkStmtList.newTree()

  for i in 0 ..< blk.len:
    if blk[i].kind == nnkCall and blk[i][0].repr == "onClick":
      let fn = blk[i][1]
      blk[i] = nnkStmtList.newTree()
      onClick = quote:
        if `id`.pressed(ui):
          `fn`

  quote:
    let config = `config`
    ui.widget(`id`)
    `onClick`
    block:
      var bgCol =
        if `id`.hot(ui) or config.toggle == On:
          color(0.35, 0.34, 0.7)
        else:
          color(0.1, 0.1, 0.3)
      var fgCol = color(1.0)
      if `id`.down(ui):
        bgCol = color(0.6, 0.5, 0.9)
      if config.disabled:
        bgCol = color(0.1, 0.1, 0.2)
        fgCol = color(0.7)
      elem:
        id = `id`
        style = Style(
          fg: fgCol,
          bg: bgCol,
          borderColor: color(0.6, 0.6, 0.6),
          border: 1,
          padding: 4,
          borderRadius: 0.4,
        )
        size = (w: Fit, h: Fit)
        dir = Row
        align = Center
        crossAlign = Center
        elem:
          text = `text`
          style = Style(fg: fgCol, bg: color(0.0))

proc label*(ui: var UI, elemIndex: ElemIndex, text: string) {.inline.} =
  elem:
    text = text
    style = Style(fg: color(1.0), bg: color(0.0))
