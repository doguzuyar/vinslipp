#!/bin/bash
source ~/.profile
cd ~/vinslipp

git pull --rebase

.venv/bin/python scripts/wine_cellar.py
git add data/
git diff --cached --quiet || git commit -m "chore: update Systembolaget releases"

.venv/bin/python scripts/rate_wines.py
git add data/
git diff --cached --quiet || git commit -m "chore: update wine ratings"

git push
