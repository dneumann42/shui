import widgets, fusion/matching, options
{.experimental: "caseStmtMacros".}

type
  ThemeValues* = object
    unitScale* = 1.0
    horizontalSpacing* = 1.0
    verticalSpacing* = 1.0

  Theme* = object
    values*: ThemeValues
    measureElement*: proc(w: Element): (float, float)
    windowSize*: proc(): (float, float)

    updateButton*: proc(button: Button): void

    drawButton*: proc(button: Button): void
    drawLabel*: proc(label: Label): void

proc initTheme*(): Theme =
  Theme(
    measureElement: proc(w: Element): auto = (0.0, 0.0),
    windowSize: proc(): (float, float) = (0.0, 0.0),

    updateButton: proc(_: Button) = discard,

    drawButton: proc(_: Button) = discard,
    drawLabel: proc(_: Label) = discard)

proc horizontalSpacing*(theme: Theme): float =
  theme.values.horizontalSpacing * theme.values.unitScale

proc verticalSpacing*(theme: Theme): float =
  theme.values.verticalSpacing * theme.values.unitScale
