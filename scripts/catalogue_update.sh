#!/bin/bash
# 10:10 cron on the Pi: on a catalogue day, fetch and rate the new auction instead of waiting for 04:00.
source ~/.profile
set -eo pipefail
cd ~/vinslipp

git pull --rebase --autostash

if RATE_CONCURRENCY=1 .venv/bin/python auction/daily_auction.py --catalogue; then
    git add auction/live_wines.json auction/auction_stats.json README.md
    if ! git diff --cached --quiet; then
        git commit -m "chore: update auction data"
        git pull --rebase --autostash
        git push
    fi
else
    git checkout -- auction/live_wines.json auction/auction_stats.json README.md
    echo "Catalogue run failed, the 04:00 run retries"
fi
