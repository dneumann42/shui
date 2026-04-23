import std/[math, macros, strutils]

import ../elements

type
  NumberInputState* = object
    editText*: string
    dragStartX*: int
    dragStartValue*: float
    dragMoved*: bool

  LineInputConfig* = object
    placeholder: string

proc clampNumberValue*(value: float; decimals: int): float =
  if decimals <= 0:
    result = round(value)
  else:
    let factor = pow(10.0, decimals.float)
    result = round(value * factor) / factor

proc formatNumberValue*(value: float; decimals: int): string =
  if decimals <= 0:
    $int(round(value))
  else:
    value.formatFloat(ffDecimal, decimals)

proc acceptsNumberText*(text: string; decimals: int): bool =
  if text.len == 0:
    return true
  var dotCount = 0
  for i, ch in text:
    case ch
    of '0'..'9':
      discard
    of '-':
      if i != 0:
        return false
    of '.':
      if decimals <= 0:
        return false
      inc dotCount
      if dotCount > 1:
        return false
    else:
      return false
  true

proc parseNumberText*(text: string; value: var float; decimals: int): bool =
  if text.len == 0 or text == "-" or text == "." or text == "-.":
    return false
  try:
    value = clampNumberValue(parseFloat(text), decimals)
    true
  except ValueError:
    false

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

template numberInput*(
  value: var float;
  widgetId: ElemId;
  decimals = 2;
  step = 1.0
) =
  block:
    let decId = ElemId($widgetId & ".dec")
    let fieldId = ElemId($widgetId & ".field")
    let incId = ElemId($widgetId & ".inc")
    ui.registerWidget(decId)
    ui.registerWidget(fieldId)
    ui.registerWidget(incId)

    if not ui.hasState(widgetId):
      ui.setState(widgetId, NumberInputState(editText: formatNumberValue(value, decimals)))
    var state = ui.getState(widgetId, NumberInputState)

    let focused = fieldId.focused(ui)
    let adjustedStep = step * (if ui.input.shiftDown: 5.0 else: 1.0)

    if decId.clicked(ui):
      value = value - adjustedStep
      state.editText = formatNumberValue(value, decimals)
      fieldId.unfocus(ui)

    if incId.clicked(ui):
      value = value + adjustedStep
      state.editText = formatNumberValue(value, decimals)
      fieldId.unfocus(ui)

    if fieldId.active(ui) and ui.input.actionDown and not focused:
      if ui.input.actionPressed:
        state.dragStartX = ui.input.mousePosition.x
        state.dragStartValue = value
        state.dragMoved = false
      let deltaX = ui.input.mousePosition.x - state.dragStartX
      if abs(deltaX) >= 4:
        state.dragMoved = true
      let wholeSteps =
        if deltaX >= 0:
          deltaX div 8
        else:
          -((-deltaX) div 8)
      value = state.dragStartValue + wholeSteps.float * adjustedStep
      state.editText = formatNumberValue(value, decimals)

    if focused:
      if ui.input.textInput.len > 0:
        for ch in ui.input.textInput:
          let candidate = state.editText & $ch
          if acceptsNumberText(candidate, decimals):
            state.editText = candidate
            discard parseNumberText(state.editText, value, decimals)
        ui.input.textInput = ""
      if ui.input.backspacePressed and state.editText.len > 0:
        state.editText = state.editText[0..^2]
        discard parseNumberText(state.editText, value, decimals)
      if fieldId.clicked(ui) or ui.input.enterPressed or ui.input.tabPressed:
        state.editText = formatNumberValue(value, decimals)
        fieldId.unfocus(ui)
      if not fieldId.hot(ui) and ui.input.actionPressed:
        state.editText = formatNumberValue(value, decimals)
        fieldId.unfocus(ui)
    elif fieldId.clicked(ui):
      if not state.dragMoved:
        state.editText = formatNumberValue(value, decimals)
        fieldId.focus(ui)
      state.dragMoved = false
    else:
      state.editText = formatNumberValue(value, decimals)

    ui.setState(widgetId, state)

    let theme = ui.theme.input
    let buttonTheme = ui.theme.button
    let decBg =
      if decId.down(ui): buttonTheme.downBg
      elif decId.hot(ui): buttonTheme.hotBg
      else: buttonTheme.bg
    let incBg =
      if incId.down(ui): buttonTheme.downBg
      elif incId.hot(ui): buttonTheme.hotBg
      else: buttonTheme.bg
    let fieldBg =
      if fieldId.down(ui): theme.downBg
      elif fieldId.hot(ui) or fieldId.focused(ui): theme.hotBg
      else: theme.bg

    elem:
      dir = Row
      align = Start
      crossAlign = Center
      size = (w: Fit, h: Fit)
      style = Style(bg: color(0.0, 0.0, 0.0, 0.0), gap: 4)
      elem:
        id = decId
        text = "-"
        dir = Row
        align = Center
        crossAlign = Center
        size = (
          w: Sizing(kind: Fixed, min: 44, max: 44),
          h: Sizing(kind: Fixed, min: 34, max: 34)
        )
        style = Style(
          fg: buttonTheme.fg,
          bg: decBg,
          borderColor: buttonTheme.border,
          border: buttonTheme.borderWidth,
          padding: 6,
          borderRadius: buttonTheme.borderRadius
        )
      elem:
        id = fieldId
        dir = Row
        align = Center
        crossAlign = Center
        size = (
          w: Sizing(kind: Fixed, min: 92, max: 92),
          h: Sizing(kind: Fixed, min: 34, max: 34)
        )
        style = Style(
          fg: theme.fg,
          bg: fieldBg,
          borderColor: theme.border,
          border: theme.borderWidth,
          padding: theme.padding,
          borderRadius: theme.borderRadius,
          gap: 2
        )
        elem:
          text = state.editText
          style = Style(fg: theme.fg, bg: color(0.0, 0.0, 0.0, 0.0))
        if fieldId.focused(ui):
          elem:
            size = (w: Sizing(kind: Fit, min: 2, max: 2), h: Grow)
            style = Style(
              bg: (if ui.blinkTicker mod 2 == 0: theme.caretFg else: color(0.0, 0.0, 0.0, 0.0))
            )
      elem:
        id = incId
        text = "+"
        dir = Row
        align = Center
        crossAlign = Center
        size = (
          w: Sizing(kind: Fixed, min: 44, max: 44),
          h: Sizing(kind: Fixed, min: 34, max: 34)
        )
        style = Style(
          fg: buttonTheme.fg,
          bg: incBg,
          borderColor: buttonTheme.border,
          border: buttonTheme.borderWidth,
          padding: 6,
          borderRadius: buttonTheme.borderRadius
        )

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
