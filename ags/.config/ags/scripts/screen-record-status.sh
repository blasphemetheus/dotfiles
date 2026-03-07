#!/bin/bash
if pgrep -x wf-recorder >/dev/null 2>&1; then
    echo "🔴 Recording"
else
    echo "⚫ Not Recording"
fi
