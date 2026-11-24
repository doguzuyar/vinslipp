import json
import os
import subprocess
import urllib.parse
import urllib.request
from datetime import datetime

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

auction_updated = get_git_time('auction/auction_stats.json')
release_updated = datetime.now().strftime('%b %d, %H:%M')

def format_launch_date(raw_date):
    try:
        return datetime.strptime(raw_date, '%Y-%m-%d').strftime('%b %d').replace(' 0', ' ')
    except (ValueError, TypeError):
        return raw_date

SB_API_URL = "https://api-extern.systembolaget.se/sb-api-ecommerce/v1/productsearch/search"
SB_API_KEY = os.environ.get("SB_API_KEY", "")

today = datetime.now().strftime('%Y-%m-%d')

def fetch_systembolaget_releases():
    all_products = []
    page = 1
    while True:
        params = (
            f"?size=30&page={page}"
            "&categoryLevel1=Vin"
            "&sortBy=ProductLaunchDate&sortDirection=Descending"
            f"&sellStartFrom={today}"
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
        total_pages = data.get("metadata", {}).get("totalPages", 1)
        # Stop early if all wines on this page launched before today
        future_on_page = [p for p in products if p.get('productLaunchDate', '') >= today]
        all_products.extend(future_on_page)
        print(f"  Page {page}/{total_pages} ({len(future_on_page)} upcoming, {len(products) - len(future_on_page)} past)")
        if len(future_on_page) == 0 or page >= total_pages:
            break
        page += 1
    return all_products

fetch_ok = True
try:
    new_releases = sorted(
        [w for w in fetch_systembolaget_releases()
         if w.get('productLaunchDate', '') >= today
         and w.get('volume', 0) == 750.0],
        key=lambda w: (
            [-c for c in (w.get('productLaunchDate') or '').encode()],
            (w.get('producerName') or '').lower(),
            w.get('price') or 0
        )
    )
    # Deduplicate API results by productNumber
    deduped = []
    seen_pn = set()
    for w in new_releases:
        pn = w.get('productNumber') or ''
        if pn and pn in seen_pn:
            continue
        if pn:
            seen_pn.add(pn)
        deduped.append(w)
    new_releases = deduped
    print(f"Fetched {len(new_releases)} upcoming wines from Systembolaget (from {today})")
except Exception as e:
    print(f"Warning: Could not fetch Systembolaget data: {e}")
    new_releases = []
    fetch_ok = False

# Load existing releases.json to preserve past wines
existing_wines = []
try:
    with open('data/releases.json', 'r', encoding='utf-8') as f:
        existing_wines = json.load(f).get('wines', [])
    print(f"Loaded {len(existing_wines)} existing wines from releases.json")
except (FileNotFoundError, json.JSONDecodeError):
    print("No existing releases.json found, starting fresh")

# Keep past wines (launched before today), drop future ones (API is the truth for those)
# Deduplicate by productNumber
seen_products = set()
# Systembolaget reuses a product number for a new vintage; the new release replaces the old entry.
api_products = {w.get('productNumber') for w in new_releases}
past_wines = []
for w in existing_wines:
    # Only drop future wines when the API actually answered - otherwise a failed
    # fetch would wipe every upcoming release.
    if fetch_ok and w.get('launchDate', '') >= today:
        continue
    pn = w.get('productNumber', '')
    if pn in api_products:
        continue
    if pn and pn in seen_products:
        continue
    if pn:
        seen_products.add(pn)
    if 'searchLink' not in w:
        query = f"{w.get('wineName', '')} {w.get('vintage', '')}".strip()
        w['searchLink'] = f"https://www.google.com/search?q={urllib.parse.quote(query)}"
    if 'vivinoLink' not in w:
        w['vivinoLink'] = w['searchLink']
    past_wines.append(w)
if fetch_ok:
    print(f"Keeping {len(past_wines)} past wines, replacing future wines with {len(new_releases)} from API")
else:
    print(f"API fetch failed - keeping all {len(past_wines)} existing wines, including upcoming ones")

# Ratings live in releases.json itself, keyed by product number and vintage: a price change
# keeps the rating, a new vintage under the same number gets its own.
existing_ratings = {
    (w['productNumber'], w.get('vintage') or ''): (w['ratingScore'], w.get('ratingReason', ''))
    for w in existing_wines if w.get('productNumber') and w.get('ratingScore')
}

os.makedirs('data', exist_ok=True)

# Build releases.json: past wines from existing file + new wines from API
releases_json = {
    'wines': list(past_wines),
}
for w in new_releases:
    pn = w.get('productNumber') or ''
    if pn and pn in seen_products:
        continue
    if pn:
        seen_products.add(pn)
    name_bold = w.get('productNameBold') or ''
    name_thin = w.get('productNameThin') or ''
    wine_name = name_bold + (f" {name_thin}" if name_thin else "")
    producer = w.get('producerName') or ''
    vintage = w.get('vintage') or ''
    price = f"{int(w['price'])} SEK" if w.get('price') else ''
    raw_date = (w.get('productLaunchDate') or '')[:10]
    region = w.get('originLevel2') or w.get('originLevel1') or ''
    search_query = f"{wine_name} {vintage}".strip()
    search_link = f"https://www.google.com/search?q={urllib.parse.quote(search_query)}"
    sb_link = f"https://www.systembolaget.se/produkt/vin/{w.get('productNumber') or ''}"
    rating_data = existing_ratings.get((w.get('productNumber') or '', vintage))
    images = w.get('images') or []
    if images:
        img = images[0]
        ext = img.get('fileType', 'png')
        image_url = f"{img['imageUrl']}.{ext}"
    else:
        image_url = ''

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
        'vivinoLink': search_link,
        'searchLink': search_link,
        'sbLink': sb_link,
        'imageUrl': image_url,
        'ratingScore': rating_data[0] if rating_data else None,
        'ratingReason': rating_data[1] if rating_data else '',
    })

# Sort all wines by date descending, then producer, then price (matching original order)
releases_json['wines'].sort(key=lambda w: (
    [-c for c in (w.get('launchDate') or '').encode()],
    (w.get('producer') or '').lower(),
    int(w.get('price', '0 SEK').split()[0]) if w.get('price') else 0
))
releases_json['totalCount'] = len(releases_json['wines'])

with open('data/releases.json', 'w', encoding='utf-8') as f:
    json.dump(releases_json, f, ensure_ascii=False)

metadata_json = {
    'releaseUpdated': release_updated,
    'auctionUpdated': auction_updated,
    'generatedAt': datetime.now().isoformat(),
}
with open('data/metadata.json', 'w', encoding='utf-8') as f:
    json.dump(metadata_json, f, ensure_ascii=False)

print(f"JSON data written to data/ ({releases_json['totalCount']} total wines)")
