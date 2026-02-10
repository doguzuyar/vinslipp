"""
Rate new Systembolaget wine releases using Claude CLI + ChromaDB RAG.
Reads release txt files, queries rag_db_color for context, rates each wine 1-4 stars,
injects ratings back into the txt files, and pushes to GitHub.
"""

import json
import os
import re
import subprocess
import threading
import unicodedata
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path

from langchain_ollama import OllamaEmbeddings
from langchain_community.vectorstores import Chroma

# --- Configuration ---
RAG_DIR = Path(os.getenv("RAG_DB_PATH", "./rag/rag_db_color"))
RELEASES_FILES = [
    Path("./data/french_red_releases.txt"),
    Path("./data/french_white_releases.txt"),
    Path("./data/italy_red_releases.txt"),
    Path("./data/italy_white_releases.txt"),
]
EMBEDDING_MODEL = "nomic-embed-text"

GENERIC_PREFIXES = {"chateau", "chateaux", "domaine", "domaines", "dom", "clos", "maison"}


def call_claude(prompt: str) -> str:
    """Call Claude via the claude CLI."""
    result = subprocess.run(
        ["claude", "-p", "--model", "claude-sonnet-4-5-20250929", prompt],
        capture_output=True,
        text=True,
        timeout=120,
    )
    if result.returncode != 0:
        raise RuntimeError(f"Claude CLI error: {result.stderr}")
    return result.stdout.strip()


def score_to_stars(score: int) -> str:
    return "★" * max(1, min(4, score))


RATING_PROMPT = """Rate this wine 1-4 stars. Use the wine guide as your primary source, supplemented by your own expertise. Search the web for producers you're unsure about.

Wine guide context (if available):
{context}

Wine: {producer} - {wine_name} {vintage} ({price})

Scale: 4=iconic/Grand Cru, 3=very good, 2=decent, 1=skip.

Rules:
- Match the guide's star rating for the producer if present (★→1, ★★→2, ★★★→3, ★★★★→4). Deviate +1 only for Grand Cru or exceptional site.
- Appellation hierarchy matters: Regional < Village < Premier Cru < Grand Cru.
- Guide vintages marked with ' are especially good years.

Reason: max 5 words. Don't repeat producer/wine/appellation names. Don't reference the guide. Be specific — what makes this wine worth buying or skipping.

Respond ONLY with JSON: {{"score": <1-4>, "reason": "<5 words max>"}}"""


# --- Parse release files ---
RATED_RE = re.compile(r"^(.+)\s+\[(★+|\d+)\](?:\s+\((.+?)\))?$")
WINE_WITH_VINTAGE_RE = re.compile(r"^\[(.+?)\]\s+(.+?)\s+-\s+(.+?)\s+(\d{4})\s+\((.+?)\)$")
WINE_NO_VINTAGE_RE = re.compile(r"^\[(.+?)\]\s+(.+?)\s+-\s+(.+?)\s+\((.+?)\)$")


def parse_releases(releases_file: Path) -> list[dict]:
    """Parse a releases txt file. Lines may end with [★★★] if already rated."""
    wines = []
    if not releases_file.exists():
        return wines
    with open(releases_file, "r", encoding="utf-8") as f:
        for raw_line in f:
            line = raw_line.strip()
            if not line:
                continue

            # Check if line already has a rating
            existing_score = None
            existing_reason = ""
            rated_match = RATED_RE.match(line)
            if rated_match:
                line = rated_match.group(1).strip()
                rating_val = rated_match.group(2)
                existing_score = len(rating_val) if "★" in rating_val else int(rating_val)
                existing_reason = rated_match.group(3) or ""

            match = WINE_WITH_VINTAGE_RE.match(line)
            if match:
                date, producer, wine_name, vintage, price = match.groups()
                wines.append({
                    "raw_line": line,
                    "date": date,
                    "producer": producer,
                    "wine_name": wine_name,
                    "vintage": vintage,
                    "price": price,
                    "score": existing_score,
                    "reason": existing_reason,
                })
                continue

            match2 = WINE_NO_VINTAGE_RE.match(line)
            if match2:
                date, producer, wine_name, price = match2.groups()
                wines.append({
                    "raw_line": line,
                    "date": date,
                    "producer": producer,
                    "wine_name": wine_name,
                    "vintage": "",
                    "price": price,
                    "score": existing_score,
                    "reason": existing_reason,
                })
    return wines


def write_releases(releases_file: Path, wines: list[dict]):
    """Write a releases txt file with star ratings injected."""
    with open(releases_file, "w", encoding="utf-8") as f:
        for w in wines:
            line = w["raw_line"]
            if w["score"] is not None:
                stars = score_to_stars(w["score"])
                reason = w.get("reason", "")
                line += f" [{stars}] ({reason})" if reason else f" [{stars}]"
            f.write(line + "\n")


# --- Name matching utilities (from server.py) ---
def remove_generic_prefix(name: str) -> str:
    stripped = name.strip()
    if not stripped:
        return stripped
    parts = stripped.split(maxsplit=1)
    first = parts[0]
    first_ascii = (
        unicodedata.normalize("NFKD", first)
        .encode("ascii", "ignore")
        .decode("ascii")
        .lower()
        .rstrip(".")
    )
    if first_ascii in GENERIC_PREFIXES and len(parts) > 1:
        return parts[1].strip()
    if first_ascii in GENERIC_PREFIXES:
        return ""
    return stripped


def normalize_wine_name(name: str) -> str:
    ascii_name = unicodedata.normalize("NFKD", name).encode("ascii", "ignore").decode("ascii")
    cleaned = "".join(ch if ch.isalnum() or ch.isspace() else " " for ch in ascii_name)
    collapsed = " ".join(cleaned.split())
    base = remove_generic_prefix(collapsed)
    return base.lower()


def normalize_text(text: str) -> str:
    if not text:
        return ""
    quote_chars = "\u2018\u2019\u201a\u201b\u2032\u0060\u00b4"
    for ch in quote_chars:
        text = text.replace(ch, "'")
    dash_chars = "\u2010\u2011\u2012\u2013\u2014\u2015"
    for ch in dash_chars:
        text = text.replace(ch, "-")
    ascii_text = unicodedata.normalize("NFKD", text).encode("ascii", "ignore").decode("ascii")
    cleaned = "".join(ch if ch.isalnum() or ch.isspace() else " " for ch in ascii_text)
    return "-".join(cleaned.lower().split())


def get_search_variants(text: str) -> list:
    if not text:
        return []
    parts = text.split("-")
    variants = set()
    for i in range(len(parts), 0, -1):
        variants.add("-".join(parts[:i]))
    for i in range(len(parts)):
        variants.add("-".join(parts[i:]))
    generic = {"chateau", "château", "domaine", "dom", "clos", "maison"}
    variants = {v for v in variants if v not in generic and len(v) >= 4}
    return sorted(variants, key=len, reverse=True)


def matches_variant(text: str, variant: str) -> bool:
    if not text or not variant:
        return False
    if not text.startswith(variant):
        return False
    rest = text[len(variant):]
    return not rest or rest[0] in ("-", " ")


def build_search_name(wine: str) -> str:
    stripped = wine.strip()
    if not stripped:
        return stripped
    base = remove_generic_prefix(stripped)
    return base or stripped


# --- RAG retrieval ---
def retrieve_context(retriever, producer: str, wine_name: str) -> str:
    queries = [q for q in [producer, wine_name] if q]
    all_docs = []
    seen = set()
    for query in queries:
        normalized = normalize_wine_name(query)
        search_name = build_search_name(query)
        for doc in retriever.invoke(f"{search_name}\n{normalized}"):
            doc_id = doc.page_content[:100]
            if doc_id not in seen:
                all_docs.append(doc)
                seen.add(doc_id)

    producer_normalized = normalize_text(producer)
    wine_normalized = normalize_text(wine_name) if wine_name else ""

    producer_match = None
    wine_match = None

    for doc in all_docs:
        first_line = doc.page_content.split("\n")[0]
        doc_key = normalize_text(first_line)
        doc_variants = get_search_variants(doc_key)

        # Check if any RAG doc variant appears in our producer/wine strings
        if not producer_match and doc_variants:
            for variant in doc_variants:
                if variant in producer_normalized or producer_normalized in variant:
                    producer_match = doc
                    break

        if not wine_match and wine_normalized and doc_variants:
            for variant in doc_variants:
                if variant in wine_normalized or wine_normalized in variant:
                    wine_match = doc
                    break

        if producer_match and wine_match:
            break

    matched = [d for d in [producer_match, wine_match] if d]
    if not matched:
        matched = all_docs[:3]

    return "\n\n".join(d.page_content for d in matched)


# --- Wine rating ---
def rate_wine(retriever, wine: dict) -> tuple[int, str]:
    context = retrieve_context(retriever, wine["producer"], wine["wine_name"])

    prompt = RATING_PROMPT.format(
        context=context,
        producer=wine["producer"],
        wine_name=wine["wine_name"],
        vintage=wine["vintage"],
        price=wine["price"],
    )

    response = call_claude(prompt)

    try:
        text = response.strip()
        if text.startswith("```"):
            text = text.split("\n", 1)[-1].rsplit("```", 1)[0].strip()
        json_match = re.search(r'\{[^}]+\}', text)
        if json_match:
            result = json.loads(json_match.group())
        else:
            result = json.loads(text)
        score = max(1, min(4, int(result["score"])))
        reason = result.get("reason", "").rstrip(".")
    except (json.JSONDecodeError, KeyError, ValueError):
        score = 2
        reason = "Could not parse response"

    return score, reason


# --- Main ---
MAX_CONCURRENT = 4


def main():
    # Parse all files and collect unrated wines
    file_data = {}  # releases_file -> (all_wines, unrated_wines)
    for releases_file in RELEASES_FILES:
        print(f"Reading {releases_file.name}...")
        wines = parse_releases(releases_file)
        if not wines:
            print(f"  No wines found")
            continue
        unrated = [w for w in wines if w["score"] is None]
        rated = len(wines) - len(unrated)
        print(f"  {len(wines)} wines ({rated} rated, {len(unrated)} unrated)")
        if unrated:
            file_data[releases_file] = (wines, unrated)

    # Flatten all unrated wines with their file reference
    all_tasks = []
    for releases_file, (wines, unrated) in file_data.items():
        for wine in unrated:
            all_tasks.append((releases_file, wines, wine))

    if not all_tasks:
        print("\nAll wines already rated across all files.")
        return

    print(f"\n{len(all_tasks)} unrated wines across {len(file_data)} files.")
    print("Initializing RAG...")
    emb = OllamaEmbeddings(model=EMBEDDING_MODEL)
    db = Chroma(persist_directory=str(RAG_DIR), embedding_function=emb)
    retriever = db.as_retriever(search_kwargs={"k": 10})
    print(f"Ready. Rating with {MAX_CONCURRENT} concurrent calls.\n")

    write_lock = threading.Lock()
    completed = [0]

    def process_wine(task):
        releases_file, wines, wine = task
        try:
            score, reason = rate_wine(retriever, wine)
            wine["score"] = score
            wine["reason"] = reason
        except Exception as e:
            wine["score"] = 2
            wine["reason"] = ""
            reason = f"Error: {e}"
            score = 2
        with write_lock:
            completed[0] += 1
            stars = score_to_stars(wine["score"])
            print(f"[{completed[0]}/{len(all_tasks)}] {wine['producer']} - {wine['wine_name']} → {stars} ({wine.get('reason', '')})")
            write_releases(releases_file, wines)

    with ThreadPoolExecutor(max_workers=MAX_CONCURRENT) as pool:
        futures = [pool.submit(process_wine, task) for task in all_tasks]
        for future in as_completed(futures):
            future.result()  # raise any unhandled exceptions

    print(f"\nDone. Rated {len(all_tasks)} wines.")

    # Auto-commit and push
    try:
        for f in file_data:
            subprocess.run(["git", "add", str(f)], check=True)
        subprocess.run(
            ["git", "commit", "-m", "chore: update wine ratings"],
            check=True,
        )
        subprocess.run(["git", "pull", "--rebase"], check=True)
        subprocess.run(["git", "push"], check=True)
        print("Pushed updated ratings to GitHub.")
    except subprocess.CalledProcessError as e:
        print(f"Git push failed: {e}")


if __name__ == "__main__":
    main()
