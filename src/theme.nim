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
    drawButton*: proc(x, y, w, h: float, button: Button): void
    drawLabel*: proc(x, y, w, h: float, label: Label): void

proc initTheme*(): Theme =
  Theme(
    measureElement: proc(w: Element): auto = (0.0, 0.0),
    windowSize: proc(): (float, float) = (0.0, 0.0),
    drawButton: proc(_, _, _, _: float, _: Button) = discard,
    drawLabel: proc(_, _, _, _: float, _: Label) = discard)

proc horizontalSpacing*(theme: Theme): float =
  theme.values.horizontalSpacing * theme.values.unitScale

proc verticalSpacing*(theme: Theme): float =
  theme.values.verticalSpacing * theme.values.unitScale
