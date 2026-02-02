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
    ui.widget(`id`)
    let focused = `id`.focused(ui)
    let config = `config`
    if focused:
      if ui.input.textInput.len > 0:
        `text` &= ui.input.textInput
        ui.input.textInput = ""
      if ui.input.backspacePressed and `text`.len > 0:
        `text` = `text`[0..^2]
      if `id`.pressed(ui) or ui.input.enterPressed or ui.input.tabPressed:
        `id`.unfocus(ui)
      if not `id`.hot(ui) and ui.input.actionPressed:
        `id`.unfocus(ui)
    else:
      if `id`.pressed(ui):
        `id`.focus(ui)
    block:
      var bgCol =
        if `id`.hot(ui) or focused:
          color(0.35, 0.34, 0.7)
        else:
          color(0.1, 0.1, 0.3)
      if `id`.down(ui):
        bgCol = color(0.6, 0.5, 0.9)
      elem:
        id = `id`
        style = Style(
          fg: color(1.0),
          bg: bgCol,
          borderColor: color(0.6, 0.6, 0.6),
          border: 1,
          padding: 4,
          borderRadius: 0.4,
          gap: 2
        )
        size = (
          w: Sizing(kind: Fit, min: 100, max: 1000), 
          h: Sizing(kind: Fit, min: 28, max: 28)
        )
        dir = Row
        align = Start
        crossAlign = Center
        elem:
          text = `text`
          style = Style(fg: color(1.0), bg: color(0.0))
        if focused:
          elem:
            size = (w: Sizing(kind: Fit, min: 2, max: 2), h: Grow)
            style = Style(
              bg: (if ui.blinkTicker mod 2 == 0: color(0.0, 0.0, 0.0, 1.0) else: color(0.0, 0.0, 0.0, 0.0))
            )
        elif `text`.len == 0 and config.placeholder.len > 0:
          elem:
            text = config.placeholder
            style = Style(fg: color(0.7), bg: color(0.0))

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
    
    ui.widget(`id`)

    if focused:
      if `id`.pressed(ui) or ui.input.enterPressed or ui.input.tabPressed:
        `id`.unfocus(ui)
    else:
      if `id`.pressed(ui):
        `id`.focus(ui)

    block:
      var bgCol =
        if `id`.hot(ui) or focused:
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
        dir = Col
        elem:
          id = `id`
          style = Style(
            fg: fgCol,
            bg: bgCol,
            borderColor: color(0.6, 0.6, 0.6),
            border: 1,
            padding: 4,
            borderRadius: 0.4,
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
              borderColor: color(0.6, 0.6, 0.6),
              border: 1,
              padding: 4,
              borderRadius: 0.1,
              gap: 4
            )
            size = (w: Sizing(kind: Fit, min: 200, max: 400), h: Fit)
            `blk`
          `value` = value

macro keyValueOption*(key, descr: string) =
  quote:
    let key = ElemId(`key`)
    if key.pressed(ui):
      value = `key`
      comboBoxId.unfocus(ui)
    ui.widget(key)
    block:
      var bgCol =
        if key.hot(ui):
          color(0.1, 0.1, 0.3)
        else:
          color(0.35, 0.34, 0.7)
      var fgCol = color(1.0)
      if key.down(ui):
        bgCol = color(0.6, 0.5, 0.9)
      elem:
        id = key
        style = Style(
          fg: fgCol,
          bg: bgCol,
          padding: 4,
          borderRadius: 0.4,
        )
        size = (w: Grow, h: Fit)
        dir = Row
        elem:
          text = `descr`
          style = Style(fg: fgCol, bg: color(0.0))
