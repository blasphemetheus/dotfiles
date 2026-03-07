#!/bin/bash
# Try various calculators in order of preference
if command -v qalculate-gtk &>/dev/null; then
    qalculate-gtk &
elif command -v kcalc &>/dev/null; then
    kcalc &
elif command -v speedcrunch &>/dev/null; then
    speedcrunch &
else
    # Fallback: simple python calculator in terminal
    kitty -e python3 -q -c "
import readline
while True:
    try:
        expr = input('calc> ')
        if expr.lower() in ('q', 'quit', 'exit'): break
        print(eval(expr))
    except Exception as e:
        print(f'Error: {e}')
" &
fi
