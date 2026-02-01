import ../src/shui

# Test that label() function was generated from component
let myLabel = label("Hello World")

echo "Label created!"
echo "Label state: ", myLabel.state
echo "Label title: ", myLabel.state.title
