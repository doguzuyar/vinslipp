import json
import os
import re
import subprocess
import urllib.parse
import urllib.request
from datetime import datetime

# Get last update timestamps
def get_git_time(filepath):
    try:
        out = subprocess.check_output(
            ['git', 'log', '-1', '--format=%aI', '--', filepath],
            stderr=subprocess.DEVNULL
        ).decode().strip()
        return datetime.fromisoformat(out).strftime('%b %d, %H:%M')
    except Exception:
        try:
            return datetime.fromtimestamp(os.path.getmtime(filepath)).strftime('%b %d, %H:%M')
        except Exception:
            return ''

auction_updated = get_git_time('bukowskis/auction_stats.json')
release_updated = datetime.now().strftime('%b %d, %H:%M')

# Fetch latest French red wine releases from Systembolaget
def format_launch_date(raw_date):
    try:
        return datetime.strptime(raw_date, '%Y-%m-%d').strftime('%b %d').replace(' 0', ' ')
    except (ValueError, TypeError):
        return raw_date

SB_API_URL = "https://api-extern.systembolaget.se/sb-api-ecommerce/v1/productsearch/search"
SB_API_KEY = "cfc702aed3094c86b92d6d4ff7a54c84"

def fetch_systembolaget_releases():
    all_products = []
    page = 1
    while True:
        params = (
            f"?size=30&page={page}"
            "&categoryLevel1=Vin"
            "&sortBy=ProductLaunchDate&sortDirection=Descending"
            "&sellStartFrom=2026-01-01"
        )
        req = urllib.request.Request(
            SB_API_URL + params,
            headers={
                "Ocp-Apim-Subscription-Key": SB_API_KEY,
                "Accept": "application/json",
            },
        )
        with urllib.request.urlopen(req, timeout=15) as resp:
            data = json.loads(resp.read().decode("utf-8"))
        products = data.get("products", [])
        all_products.extend(products)
        total_pages = data.get("metadata", {}).get("totalPages", 1)
        print(f"  Page {page}/{total_pages} ({len(products)} wines)")
        if page >= total_pages:
            break
        page += 1
    return all_products

try:
    sb_releases = sorted(
        [w for w in fetch_systembolaget_releases()
         if w.get('productLaunchDate', '') >= '2026-01-01'],
        key=lambda w: (
            [-c for c in (w.get('productLaunchDate') or '').encode()],
            (w.get('producerName') or '').lower(),
            w.get('price') or 0
        )
    )
    print(f"Fetched {len(sb_releases)} wines from Systembolaget (2026+ launches)")
except Exception as e:
    print(f"Warning: Could not fetch Systembolaget data: {e}")
    sb_releases = []

# Read existing ratings from releases.txt before overwriting
existing_ratings = {}
try:
    with open('data/french_red_releases.txt', 'r', encoding='utf-8') as f:
        for line in f:
            line = line.strip()
            rated_match = re.match(r'^(.+)\s+\[(★+|\d+)\](?:\s+\((.+?)\))?$', line)
            if rated_match:
                base_line = rated_match.group(1).strip()
                key_match = re.match(r'^\[.+?\]\s+(.+)$', base_line)
                if key_match:
                    rating_val = rated_match.group(2)
                    score = len(rating_val) if '★' in rating_val else int(rating_val)
                    reason = rated_match.group(3) or ""
                    existing_ratings[key_match.group(1)] = (score, reason)
except FileNotFoundError:
    pass

# Write releases list for email diff (French reds only), preserving existing ratings
with open('data/french_red_releases.txt', 'w', encoding='utf-8') as f:
    for w in sb_releases:
        if (w.get('country') or '') != 'Frankrike' or (w.get('categoryLevel2') or '') != 'Rött vin':
            continue
        name = w.get('productNameBold') or ''
        thin = w.get('productNameThin') or ''
        if thin:
            name += f" {thin}"
        producer = w.get('producerName') or ''
        vintage = w.get('vintage') or ''
        price = f"{int(w['price'])} SEK" if w.get('price') else ''
        raw_date = (w.get('productLaunchDate') or '')[:10]
        release_date = format_launch_date(raw_date)
        key = f"{producer} - {name} {vintage} ({price})"
        line = f"[{release_date}] {key}"
        rating_data = existing_ratings.get(key)
        if rating_data is not None:
            score, reason = rating_data
            stars = '★' * score
            line += f" [{stars}] ({reason})" if reason else f" [{stars}]"
        f.write(line + "\n")

# Generate JSON data for Next.js frontend
color_palette = [
    '#f3abab',  # 2026 - pink
    '#f8bbd0',  # 2027 - light pink
    '#d4a3dc',  # 2028 - purple
    '#e1bee7',  # 2029 - light purple
    '#7ec4f8',  # 2030 - blue
    '#bbdefb',  # 2031 - light blue
    '#6bc4ba',  # 2032 - teal
    '#b2dfdb',  # 2033 - light teal
    '#96d098',  # 2034 - green
    '#c8e6c9',  # 2035 - light green
    '#ffe066',  # 2036 - yellow
    '#fff9c4',  # 2037 - light yellow
    '#ffc570',  # 2038 - orange
    '#ffe0b2',  # 2039 - light orange
    '#f8a0bc',  # 2040 - pink
]

# Write JSON data files for Next.js frontend
os.makedirs('data', exist_ok=True)

# Assign release date colors (oldest first for stable colors)
release_dates_oldest_first = sorted(set(
    (w.get('productLaunchDate') or '')[:10] for w in sb_releases
))
release_date_colors = {d: color_palette[i % len(color_palette)] for i, d in enumerate(release_dates_oldest_first)}

# releases.json
releases_json = {
    'wines': [],
    'dateColors': release_date_colors,
    'totalCount': len(sb_releases),
}
for w in sb_releases:
    name_bold = w.get('productNameBold') or ''
    name_thin = w.get('productNameThin') or ''
    wine_name = name_bold + (f" {name_thin}" if name_thin else "")
    producer = w.get('producerName') or ''
    vintage = w.get('vintage') or ''
    price = f"{int(w['price'])} SEK" if w.get('price') else ''
    raw_date = (w.get('productLaunchDate') or '')[:10]
    region = w.get('originLevel2') or w.get('originLevel1') or ''
    vivino_query = f"{wine_name} {vintage}".strip()
    vivino_link = f"https://www.vivino.com/search/wines?q={urllib.parse.quote(vivino_query)}"
    sb_link = f"https://www.systembolaget.se/produkt/vin/{w.get('productNumber') or ''}"
    rating_key = f"{producer} - {wine_name} {vintage} ({price})"
    rating_data = existing_ratings.get(rating_key)
    releases_json['wines'].append({
        'launchDate': raw_date,
        'launchDateFormatted': format_launch_date(raw_date),
        'producer': producer,
        'wineName': wine_name,
        'vintage': vintage,
        'price': price,
        'region': region,
        'country': w.get('country') or '',
        'wineType': w.get('categoryLevel2') or '',
        'productNumber': w.get('productNumber') or '',
        'vivinoLink': vivino_link,
        'sbLink': sb_link,
        'ratingScore': rating_data[0] if rating_data else None,
        'ratingReason': rating_data[1] if rating_data else '',
        'rowColor': release_date_colors.get(raw_date, '#ffffff'),
    })

with open('data/releases.json', 'w', encoding='utf-8') as f:
    json.dump(releases_json, f, ensure_ascii=False)

# metadata.json
metadata_json = {
    'releaseUpdated': release_updated,
    'auctionUpdated': auction_updated,
    'generatedAt': datetime.now().isoformat(),
}
with open('data/metadata.json', 'w', encoding='utf-8') as f:
    json.dump(metadata_json, f, ensure_ascii=False)

print("JSON data written to data/")
