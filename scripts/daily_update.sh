#!/bin/bash
source ~/.profile
# Stop at the first failed step, so half-made data is never committed.
set -eo pipefail
cd ~/vinslipp

git pull --rebase --autostash

.venv/bin/python scripts/wine_cellar.py
# Ratings land in releases.json as they come; a crash keeps the ones already made.
.venv/bin/python scripts/rate_wines.py || echo "Rating step failed, unrated wines retry tomorrow"
git add data/
git diff --cached --quiet || git commit -m "chore: update Systembolaget releases"

# A failed auction run must not hold back the releases.
if RATE_CONCURRENCY=1 .venv/bin/python auction/daily_auction.py; then
    git add auction/live_wines.json auction/auction_stats.json README.md
    git diff --cached --quiet || git commit -m "chore: update auction data"
else
    echo "Auction step failed, skipped"
fi

git pull --rebase
git push
