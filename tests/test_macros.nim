import ../src/shui

# Test that the macro syntax works
let ui1 = row:
  discard

let ui2 = row(justify = Center):
  discard

let ui3 = column(justify = Start, align = End):
  row(justify = Center):
    discard

echo "Macro syntax test passed!"
echo "ui1: ", ui1.repr
echo "ui2 justify: ", Container(ui2).justify
echo "ui3 direction: ", Container(ui3).direction
echo "ui3 child: ", Container(ui3).children.len
