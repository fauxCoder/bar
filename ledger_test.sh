#!/usr/bin/env bash

ledger -f ~/accounts/combined.journal \
    csv expenses: income: \
    --csv-format '%(date),%(account),%(quantity(display_amount))\n' \
    "$@" | ~/bin/zig build run -- --average 7 --cols 120
