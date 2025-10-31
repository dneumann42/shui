# This is just an example to get you started. You may wish to put all of your
# tests into a single file, or separate them into multiple `test1`, `test2`
# etc. files (better names are recommended, just make sure the name starts with
# the letter 't').
#
# To run these tests, simply execute `nimble test`.

import unittest
import shui/elements

test "elem macro builds children":
  var ui = UI()
  ui.onMeasureText = proc(text: string): tuple[w, h: int] =
    (w: 10, h: 12)
  elem:
    size = (
      w: Sizing(kind: Fixed, min: 100, max: 100),
      h: Sizing(kind: Fixed, min: 100, max: 100),
    )
    style = Style(padding: 0, gap: 0)
    dir = Col
    align = Start
    crossAlign = Start
    elem:
      text = "Hello, World"
    elem:
      text = "Hello, World"
  ui.updateLayout((0, 0, 100, 100))
  check ui.get(ElemIndex(1)).text == "Hello, World"
  check ui.get(ElemIndex(2)).text == "Hello, World"
