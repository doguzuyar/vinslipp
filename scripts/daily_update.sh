#!/bin/bash
source ~/.profile
cd ~/vinslipp

git stash --quiet
git pull --rebase
git stash pop --quiet 2>/dev/null

.venv/bin/python scripts/wine_cellar.py
git add data/
git diff --cached --quiet || git commit -m "chore: update Systembolaget releases"

.venv/bin/python scripts/rate_wines.py
git add data/
git diff --cached --quiet || git commit -m "chore: update wine ratings"

RATE_CONCURRENCY=1 .venv/bin/python auction/daily_auction.py
git add auction/live_wines.json auction/auction_stats.json README.md
git diff --cached --quiet || git commit -m "chore: update auction data"

git pull --rebase
git push
