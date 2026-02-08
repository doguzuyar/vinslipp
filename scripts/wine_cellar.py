import csv
import json
import os
import re
import subprocess
import urllib.parse
import urllib.request
from collections import Counter
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

cellar_updated = get_git_time('vivino_data/cellar.csv')
auction_updated = get_git_time('bukowskis/auction_stats.json')
release_updated = datetime.now().strftime('%b %d, %H:%M')

# Read cellar.csv
cellar_wines = []
with open('vivino_data/cellar.csv', 'r', encoding='utf-8') as f:
    reader = csv.DictReader(f)
    for row in reader:
        cellar_wines.append(row)

# Read user_prices.csv and create a lookup by 'Link to wine'
price_lookup = {}
with open('vivino_data/user_prices.csv', 'r', encoding='utf-8') as f:
    reader = csv.DictReader(f)
    for row in reader:
        link = row['Link to wine']
        price_lookup[link] = {
            'Wine price': row['Wine price'],
            'Drink Year': row['Personal Note']
        }

# Read full_wine_list.csv for history (wines with "Nybrogatan 62" as location)
history_wines = []
with open('vivino_data/full_wine_list.csv', 'r', encoding='utf-8') as f:
    reader = csv.DictReader(f)
    for row in reader:
        if row.get('Scan/Review Location') == 'Nybrogatan 62':
            history_wines.append({
                'Scan date': row.get('Scan date', ''),
                'Winery': row['Winery'],
                'Wine name': row['Wine name'],
                'Vintage': row['Vintage'],
                'Region': row['Region'],
                'Regional wine style': row['Regional wine style'],
                'Link': row['Link to wine']
            })

# Sort history by scan date (most recent first)
history_wines.sort(key=lambda x: x['Scan date'] if x['Scan date'] else '', reverse=True)

# Output columns for cellar
output_columns = [
    'Drink Year',
    'Winery',
    'Wine name',
    'Vintage',
    'Region',
    'Regional wine style',
    'Wine price',
    'User cellar count'
]

# Build merged rows for cellar
merged_rows = []
for wine in cellar_wines:
    link = wine['Link to wine']
    price_data = price_lookup.get(link, {'Wine price': '', 'Drink Year': ''})

    # Convert price to "number SEK" format (e.g., "1600 SEK")
    raw_price = price_data['Wine price'].replace('SEK ', '') if price_data['Wine price'] else ''
    price = f"{raw_price} SEK" if raw_price else ''

    drink_year_raw = price_data['Drink Year'].strip()
    total_count = int(wine['User cellar count'])

    # Parse comma-separated drink years (e.g. "2026, 2030")
    years = [y.strip() for y in drink_year_raw.split(',') if y.strip()] if drink_year_raw else ['']

    base_count = total_count // len(years)
    remainder = total_count % len(years)
    for i, year in enumerate(years):
        merged_rows.append({
            'Drink Year': year,
            'Winery': wine['Winery'],
            'Wine name': wine['Wine name'],
            'Vintage': wine['Vintage'],
            'Region': wine['Region'],
            'Regional wine style': wine['Regional wine style'],
            'User cellar count': str(base_count + (1 if i < remainder else 0)),
            'Wine price': price,
            'Link': link
        })

# Sort by Drink Year first, then by Vintage within each year (earliest first)
merged_rows.sort(key=lambda x: (
    int(x['Drink Year']) if x['Drink Year'] else 9999,
    int(x['Vintage']) if x['Vintage'] else 9999,
    x['Winery'].lower()
))

# Count bottles per year and calculate total cellar value
year_counts = Counter()
total_cellar_value = 0
for row in merged_rows:
    year = row['Drink Year']
    count = int(row['User cellar count'])
    year_counts[year] += count
    raw = row['Wine price'].replace(' SEK', '').strip()
    if raw:
        try:
            total_cellar_value += int(raw) * count
        except ValueError:
            pass

# Write output (exclude Link field from CSV)
with open('data/wine_cellar.csv', 'w', encoding='utf-8', newline='') as f:
    writer = csv.DictWriter(f, fieldnames=output_columns, extrasaction='ignore')
    writer.writeheader()
    writer.writerows(merged_rows)

    # Add summary section
    f.write('\n')
    f.write('Bottles per Year\n')
    f.write('Year,Bottles\n')
    for year in sorted(year_counts.keys()):
        f.write(f'{year},{year_counts[year]}\n')
    f.write(f'Total,{sum(year_counts.values())}\n')

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

def get_year_color(year):
    try:
        year_num = int(year)
        index = (year_num - 2026) % len(color_palette)
        return color_palette[index]
    except (ValueError, TypeError):
        return '#ffffff'

# Write JSON data files for Next.js frontend
os.makedirs('data', exist_ok=True)

# Assign release date colors (oldest first for stable colors)
release_dates_oldest_first = sorted(set(
    (w.get('productLaunchDate') or '')[:10] for w in sb_releases
))
release_date_colors = {d: color_palette[i % len(color_palette)] for i, d in enumerate(release_dates_oldest_first)}

# cellar.json
cellar_json = {
    'wines': [{
        'drinkYear': row['Drink Year'],
        'winery': row['Winery'],
        'wineName': row['Wine name'],
        'vintage': row['Vintage'],
        'region': row['Region'],
        'style': row['Regional wine style'],
        'price': row['Wine price'],
        'count': int(row['User cellar count']),
        'link': row['Link'],
        'color': get_year_color(row['Drink Year']),
    } for row in merged_rows],
    'yearCounts': {year: year_counts[year] for year in sorted(year_counts.keys())},
    'totalBottles': sum(year_counts.values()),
    'totalValue': total_cellar_value,
    'colorPalette': {str(2026 + i): c for i, c in enumerate(color_palette)},
}
with open('data/cellar.json', 'w', encoding='utf-8') as f:
    json.dump(cellar_json, f, ensure_ascii=False)

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

# history.json
history_json = {
    'wines': [{
        'scanDate': w['Scan date'],
        'winery': w['Winery'],
        'wineName': w['Wine name'],
        'vintage': w['Vintage'],
        'region': w['Region'],
        'style': w['Regional wine style'],
        'link': w['Link'],
    } for w in history_wines],
    'totalCount': len(history_wines),
}
with open('data/history.json', 'w', encoding='utf-8') as f:
    json.dump(history_json, f, ensure_ascii=False)

# metadata.json
metadata_json = {
    'cellarUpdated': cellar_updated,
    'releaseUpdated': release_updated,
    'auctionUpdated': auction_updated,
    'generatedAt': datetime.now().isoformat(),
}
with open('data/metadata.json', 'w', encoding='utf-8') as f:
    json.dump(metadata_json, f, ensure_ascii=False)

print("JSON data written to data/")

print(f"Merged {len(cellar_wines)} wines into data/wine_cellar.csv")
print(f"Added {len(history_wines)} wines to history tab")
