const CARD_SELECTORS = [
  "a.bg-white.flex.flex-col.border-1.grow.border-black\\/10.rounded-sm.shadow-md.overflow-hidden.text-inherit.transition",
  "div.c-lot-index-lot",
  "div.c-lot-cell",
  "div.c-my-pages-lot-card",
];

// My pages (favourites) cards hold "Estimate 1 200 SEK" / "Current bid 2 000 SEK" as plain text.
const ESTIMATE_SELECTOR = "[class*='estimate-value'], .c-my-pages-lot-card__estimate";
const HAMMER_SELECTOR = "[class*='result-value'], .c-my-pages-lot-card__price";

const BADGE_SRC = chrome.runtime.getURL("vinslipp.png");

// The BUY light shows when the lot's region vintage index (published per lot as
// vintage_factor) is not red, i.e. at least 0.8x.
const BUY_MIN_FACTOR = 0.8;

function wineSearchUrl(wineName) {
  return "https://www.google.com/search?q=" + encodeURIComponent(wineName);
}

(function fixSystembolagetDateFilter() {
  if (!window.location.href.includes("systembolaget.se")) return;

  const url = new URL(window.location.href);
  const currentDateParam = url.searchParams.get("saljstart-fran");
  if (!currentDateParam) return;

  const today = new Date().toISOString().split("T")[0];

  if (currentDateParam !== today) {
    url.searchParams.set("saljstart-fran", today);
    window.location.replace(url.toString());
  }
})();

let liveWinesById = null;
let liveWinesLoaded = false;

async function loadLiveWines() {
  if (liveWinesLoaded) return liveWinesById;
  try {
    const response = await fetch("https://vinslipp.app/data/live_wines.json");
    if (response.ok) {
      const data = await response.json();
      liveWinesById = new Map();
      for (const wine of data.wines) {
        if (wine.url) {
          const lotNum = extractLotNumber(wine.url);
          if (lotNum) liveWinesById.set(lotNum, wine);
        }
      }
      liveWinesLoaded = true;
      console.log(`[Live Wines] Loaded ${liveWinesById.size} wines`);
    }
  } catch (err) {
    console.warn("[Live Wines] Failed to load:", err);
  }
  return liveWinesById;
}

function extractLotNumber(url) {
  const match = url.match(/\/lots\/(\d+)/);
  return match ? match[1] : null;
}

function findLiveWineRating(card) {
  if (!liveWinesById) return null;

  // Method 1: lot number from links
  for (const a of card.querySelectorAll("a[href]")) {
    const num = extractLotNumber(a.href);
    if (num && liveWinesById.has(num)) return liveWinesById.get(num);
  }

  // Method 2: lot number visible on card (the small number above the title)
  const numberEl = card.querySelector("[class*='number'], [class*='lot-id']");
  if (numberEl) {
    const num = (numberEl.textContent || "").trim();
    if (num && liveWinesById.has(num)) return liveWinesById.get(num);
  }

  // Method 3: scan all text nodes for a 7-digit number
  const allText = card.textContent || "";
  const nums = allText.match(/\b(\d{7})\b/g);
  if (nums) {
    for (const n of nums) {
      if (liveWinesById.has(n)) return liveWinesById.get(n);
    }
  }

  return null;
}

function ratingStars(score) {
  const filled = "\u2605";
  const empty = "\u2606";
  return filled.repeat(score) + empty.repeat(4 - score);
}

function ratingColor(score) {
  if (score >= 4) return "#d4a017";
  if (score >= 3) return "#a8a8a8";
  if (score >= 2) return "#cd7f32";
  return "#999";
}

let releasesMap = null;
let releasesLoaded = false;

async function loadReleases() {
  if (releasesLoaded) return releasesMap;
  try {
    const response = await fetch("https://vinslipp.app/data/releases.json");
    if (response.ok) {
      const data = await response.json();
      releasesMap = new Map();
      for (const wine of data.wines) {
        if (wine.productNumber) {
          releasesMap.set(wine.productNumber, wine);
        }
      }
      releasesLoaded = true;
      console.log(`[Releases] Loaded ${releasesMap.size} wines with ratings`);
    }
  } catch (err) {
    console.warn("[Releases] Failed to load:", err);
  }
  return releasesMap;
}

function extractProductNumber(url) {
  // Match /produkt/vin/282321 or /produkt/vin/chateau-bois-282321
  const match = url.match(/\/produkt\/[^/]+\/(?:.*?[-/])?(\d{5,8})\b/);
  return match ? match[1] : null;
}

function findReleaseRating(cardOrUrl) {
  if (!releasesMap) return null;
  let productNumber = null;
  if (typeof cardOrUrl === "string") {
    productNumber = extractProductNumber(cardOrUrl);
  } else {
    const href = cardOrUrl.href || cardOrUrl.querySelector("a")?.href;
    if (href) productNumber = extractProductNumber(href);
  }
  // Fallback: find "Nr XXXXXX" on the page or card
  if (!productNumber) {
    const text = typeof cardOrUrl === "string" ? document.body.textContent : (cardOrUrl.textContent || "");
    const nrMatch = text.match(/Nr\s+(\d{5,8})\b/);
    if (nrMatch) productNumber = nrMatch[1];
  }
  if (!productNumber) return null;
  return releasesMap.get(productNumber) || null;
}

function isSystembolagetPage() {
  const url = window.location.href.toLowerCase();
  return url.includes("systembolaget.se") &&
    (url.includes("vin") || url.includes("mina-listor") || url.includes("/produkt/"));
}

function isBukowskisPage() {
  const url = window.location.href.toLowerCase();
  return url.includes("bukowskis.com") &&
    (url.includes("wine") || url.includes("favorites") || url.includes("ongoing") || url.includes("lots"));
}

function shouldInjectLinks() {
  return isSystembolagetPage() || isBukowskisPage();
}

function debounce(fn, delay = 500) {
  let timer;
  return (...args) => {
    clearTimeout(timer);
    timer = setTimeout(() => fn(...args), delay);
  };
}

function isProductPage() {
  return window.location.href.toLowerCase().includes("/produkt/");
}

function addBadgeToProductPage() {
  const titleEls = document.querySelectorAll("span.monopol-300, span.monopol-400");
  if (!titleEls.length) return;

  const firstEl = titleEls[0];
  if (firstEl.dataset.badgeInjected) return;

  const titleParts = Array.from(titleEls).slice(0, 2).map(el => el.innerText.replace(/\n/g, " ").trim()).filter(Boolean);
  const wineName = titleParts.join(" ");
  if (!wineName) return;

  const badge = document.createElement("a");
  badge.dataset.vinslippBadge = "true";
  badge.href = wineSearchUrl(wineName);
  badge.target = "_blank";
  badge.rel = "noopener noreferrer";

  const img = document.createElement("img");
  img.src = chrome.runtime.getURL("vinslipp.png");
  img.style.width = "28px";
  img.style.height = "28px";
  img.style.borderRadius = "50%";
  img.style.objectFit = "cover";
  img.style.verticalAlign = "middle";
  badge.appendChild(img);

  badge.style.marginLeft = "8px";
  badge.style.display = "inline-block";
  badge.style.verticalAlign = "middle";

  firstEl.style.display = "inline-flex";
  firstEl.style.alignItems = "center";
  firstEl.appendChild(badge);
  firstEl.dataset.badgeInjected = "true";
}

function injectBadges() {
  if (!shouldInjectLinks()) return;

  if (isProductPage()) {
    addBadgeToProductPage();
    return;
  }

  const cards = CARD_SELECTORS.flatMap((selector) =>
    Array.from(document.querySelectorAll(selector))
  );
  const uniqueCards = [...new Set(cards)];
  uniqueCards.forEach(addBadge);
}

function addBadge(card) {
  const titleParts = extractTitleParts(card);
  if (!titleParts.length) return;

  const isBukowskis = card.matches("div.c-lot-index-lot, div.c-lot-cell, div.c-my-pages-lot-card");
  const normalizedParts = titleParts.map((part) =>
    isBukowskis ? part.replace(/\.$/, "").trim() : part
  );
  const joiner = isBukowskis ? " " : ", ";
  let wineName = normalizedParts.join(joiner);

  if (isBukowskis) {
    const [firstPart, ...restParts] = normalizedParts;
    const yearMatch = firstPart.match(/^\s*(\d{4})(.*)$/);
    if (yearMatch) {
      const [, year, restText] = yearMatch;
      const preparedParts = [restText.trim(), ...restParts, year].filter(
        Boolean
      );
      wineName = preparedParts.join(" ").trim();
    }
    if (wineName.endsWith(".")) {
      wineName = wineName.slice(0, -1).trim();
    }
  }

  if (
    card.dataset.vinslippSignature === wineName &&
    card.dataset.badgeInjected
  ) {
    return;
  }

  const existingBadge = card.querySelector('[data-vinslipp-badge="true"]');
  if (existingBadge) existingBadge.remove();

  const badge = document.createElement("a");
  badge.dataset.vinslippBadge = "true";
  badge.href = wineSearchUrl(wineName);
  badge.target = "_blank";
  badge.rel = "noopener noreferrer";

  badge.addEventListener("click", (e) => {
    e.stopPropagation();
  });
  const img = document.createElement("img");
  img.src = BADGE_SRC;
  Object.assign(img.style, {
    width: "24px",
    height: "24px",
    borderRadius: "50%",
    objectFit: "cover",
  });
  badge.appendChild(img);

  const isMinaListor = window.location.href
    .toLowerCase()
    .includes("mina-listor");
  const isLotCell = card.matches("div.c-lot-cell");
  Object.assign(badge.style, {
    position: "absolute",
    zIndex: "20",
    ...(isLotCell
      ? { top: "70px", left: "16px" }
      : {
          top: isBukowskis ? "16px" : "8px",
          ...(isMinaListor ? { left: "8px" } : { right: "8px" }),
        }),
  });

  card.style.position = "relative";
  card.appendChild(badge);
  card.dataset.vinslippSignature = wineName;
  card.dataset.badgeInjected = "true";

  if (isBukowskis) {
    // Win price and BUY light come precomputed per lot in live_wines.json.
    const estimateEl = card.querySelector(ESTIMATE_SELECTOR);
    const wine = findLiveWineRating(card);
    if (estimateEl && wine?.expected_per_bottle) {
      const bottles = wine.bottles || 1;
      const winPrice = wine.expected_per_bottle * bottles;

      if (!card.querySelector("[data-guarantee-price]")) {
        const guaranteeEl = document.createElement("div");
        guaranteeEl.dataset.guaranteePrice = "true";
        guaranteeEl.textContent = `Win: ${winPrice.toLocaleString("sv-SE")} SEK`;
        guaranteeEl.title = wine.expected_basis + (bottles > 1 ? ` x ${bottles} bottles` : "");
        // Same row as "Estimate ...": inline, pushed to the right edge.
        Object.assign(guaranteeEl.style, {
          fontSize: "13px",
          fontWeight: "600",
          color: "#1a1a1a",
          display: "inline",
          float: "right",
          marginLeft: "12px",
        });

        if (estimateEl.matches(".c-my-pages-lot-card__estimate")) {
          estimateEl.appendChild(guaranteeEl);
        } else {
          estimateEl.parentNode.insertBefore(guaranteeEl, estimateEl.nextSibling);
        }
      }

      if (wine.vintage_factor >= BUY_MIN_FACTOR) {
        const hammer = parsePrice(card.querySelector(HAMMER_SELECTOR)?.textContent);
        const indicator = document.createElement("div");
        Object.assign(indicator.style, {
          position: "absolute",
          bottom: "-3px",
          right: "-3px",
          width: "12px",
          height: "12px",
          borderRadius: "50%",
          backgroundColor: hammer && hammer > winPrice ? "#ef4444" : "#22c55e",
          border: "2px solid white",
          zIndex: "21",
        });
        badge.appendChild(indicator);
      }
    }
  }
}

function createRatingEl(score, reason, fontSize = "11px") {
  const color = ratingColor(score);
  const el = document.createElement("div");
  el.dataset.wineRating = "true";
  el.style.cssText = `font-size:${fontSize} !important; margin-top:4px !important; overflow:hidden !important; padding:2px 0 !important; text-align:left !important;`;
  // Built from nodes, not innerHTML: the reason is text from the data files.
  const reasonEl = document.createElement("span");
  reasonEl.style.cssText = "color:#888 !important;";
  reasonEl.textContent = reason || "";
  const starsEl = document.createElement("span");
  starsEl.style.cssText = `float:right; letter-spacing:1px; color:${color} !important;`;
  starsEl.textContent = ratingStars(score);
  el.append(reasonEl, starsEl);
  return el;
}

function injectAllRatings() {
  if (!liveWinesById && !releasesMap) return;

  const url = window.location.href;

  if (url.includes("bukowskis.com") && liveWinesById) {
    document.querySelectorAll("div.c-lot-index-lot, div.c-lot-cell, div.c-my-pages-lot-card").forEach((card) => {
      if (card.querySelector("[data-wine-rating]")) return;
      const wine = findLiveWineRating(card);
      if (!wine || !wine.rating_score) return;
      const ratingEl = createRatingEl(wine.rating_score, wine.rating_reason);
      // My pages cards: keep the rating above the "Place a bid" button.
      const cta = card.querySelector(".c-my-pages-lot-card__call-to-action");
      if (cta) {
        card.insertBefore(ratingEl, cta);
        return;
      }
      // Inside the price block, right under the Estimate row: the card itself is a
      // flex column with a gap, so appending to the card leaves an empty band.
      const target = card.querySelector("[class*='price-block']") || card;
      target.appendChild(ratingEl);
    });
  }

  if (url.includes("systembolaget.se") && releasesMap) {
    document.querySelectorAll(CARD_SELECTORS[0]).forEach((card) => {
      if (card.querySelector("[data-wine-rating]")) return;
      const release = findReleaseRating(card);
      if (!release || !release.ratingScore) return;
      const el = createRatingEl(release.ratingScore, release.ratingReason, "13px");
      el.style.cssText += "padding:4px 12px !important;";
      // Insert before the last child (status banner) to stay inside the card
      const lastChild = card.lastElementChild;
      if (lastChild) {
        card.insertBefore(el, lastChild);
      } else {
        card.appendChild(el);
      }
    });
  }
}

function getBukowskisLotTitle(card) {
  const artist = card.querySelector(".c-lot-index-lot__artist")?.textContent?.trim() || "";
  const titleEl = card.querySelector("div.c-lot-index-lot__title");
  const title = titleEl?.textContent?.trim() || "";
  const combined = [artist, title].filter(Boolean).join(" ").replace(/\.$/, "").trim();
  if (combined) return combined;
  return card.querySelector(".c-lot-cell__title, .c-my-pages-lot-card__title")?.textContent?.trim() || "";
}

function extractTitleParts(card) {
  const monopolParagraphs = card.querySelectorAll("p.monopol-250");
  const primary = Array.from(monopolParagraphs)
    .slice(0, 2)
    .map((el) => el.innerText.trim())
    .filter(Boolean);
  if (primary.length) return primary;

  const lotIndexTitle = getBukowskisLotTitle(card);
  if (lotIndexTitle) return [lotIndexTitle];

  const lotCellTitle = card.querySelector(".c-lot-cell__title");
  if (lotCellTitle?.innerText.trim()) {
    return [lotCellTitle.innerText.trim()];
  }

  return [];
}

function parsePrice(priceText) {
  if (!priceText) return null;
  const cleaned = priceText.replace(/[^\d]/g, "");
  const value = parseInt(cleaned, 10);
  return isNaN(value) ? null : value;
}

let initialized = false;

async function initialize() {
  if (initialized) return;
  initialized = true;

  await Promise.all([loadLiveWines(), loadReleases()]);

  refreshInjections();

  let retries = 0;
  const retryInterval = setInterval(() => {
    injectAllRatings();
    retries++;
    if (retries >= 15) clearInterval(retryInterval);
  }, 2000);
}

function refreshInjections() {
  if (shouldInjectLinks()) injectBadges();
  injectAllRatings();
}

if (document.readyState === "loading") {
  document.addEventListener("DOMContentLoaded", initialize);
} else {
  initialize();
}

window.addEventListener("load", initialize);
window.addEventListener("scroll", debounce(refreshInjections, 750));

function setupObserver() {
  if (!window.MutationObserver || !document.body) return;

  const observer = new MutationObserver(debounce(refreshInjections, 500));

  observer.observe(document.body, {
    childList: true,
    subtree: true,
    characterData: true,
  });
}

let lastUrl = window.location.href;
function checkUrlChange() {
  if (window.location.href !== lastUrl) {
    lastUrl = window.location.href;
    refreshInjections();
  }
}
setInterval(checkUrlChange, 1000);

if (document.body) {
  setupObserver();
} else {
  document.addEventListener("DOMContentLoaded", setupObserver);
}
