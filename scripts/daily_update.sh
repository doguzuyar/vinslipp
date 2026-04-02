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

git pull --rebase
git push
