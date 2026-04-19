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

proc extractConfig(node: NimNode): tuple[config: ButtonConfig, toggleExpr: NimNode] =
  result.config = ButtonConfig()
  result.toggleExpr = nil
  for child in node.items:
    if child.kind == nnkAsgn:
      if child[0].repr == "disabled":
        result.config.disabled = child[1].repr == "true"
      if child[0].repr == "toggle":
        # Check if it's a literal enum value or a runtime expression
        if child[1].kind in {nnkIdent, nnkSym}:
          # Compile-time literal like "On" or "Off"
          result.config.toggle = parseEnum[ButtonToggleState](child[1].repr)
        else:
          # Runtime expression like "state.debugShapes"
          result.toggleExpr = child[1]

proc toToggle*(bol: bool): ButtonToggleState = (if bol: On else: Off)

macro button*(text: string, id: ElemId, blk: untyped) =
  let (config, toggleExpr) = extractConfig(blk)
  var onClick = nnkStmtList.newTree()

  for i in 0 ..< blk.len:
    if blk[i].kind == nnkCall and blk[i][0].repr == "onClick":
      let fn = blk[i][1]
      blk[i] = nnkStmtList.newTree()
      onClick = quote:
        if `id`.clicked(ui):
          `fn`

  # Generate the toggle check expression
  let toggleCheck = if toggleExpr != nil:
    quote do:
      `toggleExpr` == On
  else:
    quote do:
      `config`.toggle == On

  quote:
    let config = `config`
    ui.registerWidget(`id`)
    `onClick`
    block:
      let theme = ui.theme.button
      var bgCol =
        if `id`.hot(ui) or `toggleCheck`:
          theme.hotBg
        else:
          theme.bg
      var fgCol = theme.fg
      var borderCol =
        if `id`.hot(ui) or `toggleCheck`:
          theme.hotBorder
        else:
          theme.border
      if `id`.down(ui):
        bgCol = theme.downBg
        borderCol = theme.downBorder
      if config.disabled:
        bgCol = theme.disabledBg
        fgCol = theme.disabledFg
        borderCol = theme.disabledBorder
      elem:
        id = `id`
        style = Style(
          fg: fgCol,
          bg: bgCol,
          borderColor: borderCol,
          border: theme.borderWidth,
          padding: theme.padding,
          borderRadius: theme.borderRadius,
        )
        size = (
          w: Sizing(kind: Fit, min: theme.minWidth, max: theme.maxWidth),
          h: Sizing(kind: Fixed, min: theme.height, max: theme.height)
        )
        dir = Row
        align = Center
        crossAlign = Center
        elem:
          text = `text`
          style = Style(fg: fgCol, bg: color(0.0, 0.0, 0.0, 0.0))

proc label*(ui: var UI, elemIndex: ElemIndex, text: string) {.inline.} =
  elem:
    text = text
    style = Style(fg: ui.theme.textFg, bg: color(0.0))
