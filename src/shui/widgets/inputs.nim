import std/[macros]

import ../elements

type
  LineInputConfig* = object
    placeholder: string

proc extractConfig*(node: NimNode): LineInputConfig =
  result = LineInputConfig()
  for i in 0 ..< node.len:
    if node[i].kind == nnkAsgn:
      if node[i][0].repr == "placeholder":
        result.placeholder = node[i][1].strVal

macro lineInput*(text: var string, id: ElemId, blk: untyped) =
  let config = extractConfig(blk)
  quote:
    ui.registerWidget(`id`)
    let focused = `id`.focused(ui)
    let config = `config`
    if focused:
      if ui.input.textInput.len > 0:
        `text` &= ui.input.textInput
        ui.input.textInput = ""
      if ui.input.backspacePressed and `text`.len > 0:
        `text` = `text`[0..^2]
      if `id`.clicked(ui) or ui.input.enterPressed or ui.input.tabPressed:
        `id`.unfocus(ui)
      if not `id`.hot(ui) and ui.input.actionPressed:
        `id`.unfocus(ui)
    else:
      if `id`.clicked(ui):
        `id`.focus(ui)
    block:
      let theme = ui.theme.input
      var bgCol =
        if `id`.hot(ui) or focused:
          theme.hotBg
        else:
          theme.bg
      if `id`.down(ui):
        bgCol = theme.downBg
      elem:
        id = `id`
        style = Style(
          fg: theme.fg,
          bg: bgCol,
          borderColor: theme.border,
          border: theme.borderWidth,
          padding: theme.padding,
          borderRadius: theme.borderRadius,
          gap: 2
        )
        size = (
          w: Sizing(kind: Fit, min: theme.minWidth, max: theme.maxWidth),
          h: Sizing(kind: Fit, min: theme.minHeight, max: theme.maxHeight)
        )
        dir = Row
        align = Start
        crossAlign = Center
        elem:
          text = `text`
          style = Style(fg: theme.fg, bg: color(0.0))
        if focused:
          elem:
            size = (w: Sizing(kind: Fit, min: 2, max: 2), h: Grow)
            style = Style(
              bg: (if ui.blinkTicker mod 2 == 0: theme.caretFg else: color(0.0, 0.0, 0.0, 0.0))
            )
        elif `text`.len == 0 and config.placeholder.len > 0:
          elem:
            text = config.placeholder
            style = Style(fg: theme.placeholderFg, bg: color(0.0))

type
  ComboBoxState* = object
    open*: bool
    search*: string

  ComboBoxConfig* = object
    disabled = false

macro comboBox*(value {.inject.}: var string, id {.inject.}: ElemId, blk: untyped) =
  quote:
    let config = ComboBoxConfig()
    let focused = `id`.focused(ui)
    
    ui.registerWidget(`id`)

    if focused:
      if `id`.clicked(ui) or ui.input.enterPressed or ui.input.tabPressed:
        `id`.unfocus(ui)
    else:
      if `id`.clicked(ui):
        `id`.focus(ui)

    block:
      let theme = ui.theme.input
      var bgCol =
        if `id`.hot(ui) or focused:
          theme.hotBg
        else:
          theme.bg
      var fgCol = theme.fg
      if `id`.down(ui):
        bgCol = theme.downBg
      if config.disabled:
        bgCol = theme.disabledBg
        fgCol = theme.disabledFg
      elem:
        dir = Col
        elem:
          id = `id`
          style = Style(
            fg: fgCol,
            bg: bgCol,
            borderColor: theme.border,
            border: theme.borderWidth,
            padding: theme.padding,
            borderRadius: theme.borderRadius,
            gap: 4
          )
          size = (w: Fit, h: Fit)
          dir = Col
          align = Start
          crossAlign = Start
          elem:
            dir = Row
            align = Center
            crossAlign = Center
            size = (w: Fit, h: Fit)
            style = Style(
              fg: fgCol,
              bg: color(0.0)
            )
            elem:
              text = `value`
              style = Style(fg: fgCol, bg: color(0.0))
            elem:
              text = "[-]"
              style = Style(fg: fgCol, bg: color(0.0))

        if `id`.focused(ui):
          let comboBoxId {.inject.} = `id`
          var value {.inject.} = `value`
          elem:
            floating = true
            dir = Col
            style = Style(
              fg: fgCol,
              bg: bgCol,
              borderColor: theme.border,
              border: theme.borderWidth,
              padding: theme.padding,
              borderRadius: theme.borderRadius,
              gap: 4
            )
            size = (w: Sizing(kind: Fit, min: 200, max: 400), h: Fit)
            `blk`
          `value` = value

macro keyValueOption*(key, descr: string) =
  quote:
    let key = ElemId(`key`)
    if key.clicked(ui):
      value = `key`
      comboBoxId.unfocus(ui)
    ui.registerWidget(key)
    block:
      let theme = ui.theme.input
      var bgCol =
        if key.hot(ui):
          theme.hotBg
        else:
          theme.bg
      var fgCol = theme.fg
      if key.down(ui):
        bgCol = theme.downBg
      elem:
        id = key
        style = Style(
          fg: fgCol,
          bg: bgCol,
          padding: theme.padding,
          borderRadius: theme.borderRadius,
        )
        size = (w: Grow, h: Fit)
        dir = Row
        elem:
          text = `descr`
          style = Style(fg: fgCol, bg: color(0.0))
