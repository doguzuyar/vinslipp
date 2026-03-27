const CARD_SELECTORS = [
  "a.bg-white.flex.flex-col.border-1.grow.border-black\\/10.rounded-sm.shadow-md.overflow-hidden.text-inherit.transition",
  "div.c-lot-index-lot",
  "div.c-lot-cell",
];

const BADGE_SRC = chrome.runtime.getURL("vinslipp.png");

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

let bukowskisStats = null;
let bukowskisStatsLoaded = false;

let liveWinesById = null;
let liveWinesLoaded = false;

async function loadLiveWines() {
  if (liveWinesLoaded) return liveWinesById;
  try {
    const response = await fetch(chrome.runtime.getURL("live_wines.json"));
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

async function loadBukowskisStats() {
  if (bukowskisStatsLoaded) return bukowskisStats;
  try {
    const response = await fetch("https://vinslipp.app/data/auction_stats.json");
    if (response.ok) {
      bukowskisStats = await response.json();
      bukowskisStatsLoaded = true;
      console.log(`[Auction Stats] Loaded ${Object.keys(bukowskisStats.producers).length} producers`);
    }
  } catch (err) {
    console.warn("[Auction Stats] Failed to load:", err);
  }
  return bukowskisStats;
}

function extractProducerFromTitle(title) {
  if (!title) return null;
  return title
    .replace(/^\d{4}\s+/, "")
    .replace(/\s*\([^)]*\)\s*$/, "")
    .replace(/\.$/, "")
    .trim();
}

function findProducerStats(title) {
  if (!bukowskisStats || !bukowskisStats.producers) return null;

  const producer = extractProducerFromTitle(title);
  if (!producer) return null;

  if (bukowskisStats.producers[producer]) {
    return { producer, ...bukowskisStats.producers[producer] };
  }

  const lowerProducer = producer.toLowerCase();
  for (const [key, stats] of Object.entries(bukowskisStats.producers)) {
    if (key.toLowerCase() === lowerProducer) {
      return { producer: key, ...stats };
    }
  }

  for (const [key, stats] of Object.entries(bukowskisStats.producers)) {
    if (key.toLowerCase().includes(lowerProducer) || lowerProducer.includes(key.toLowerCase())) {
      return { producer: key, ...stats };
    }
  }

  return null;
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

  const isBukowskis = card.matches("div.c-lot-index-lot, div.c-lot-cell");
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
    const estimateEl = card.querySelector("[class*='estimate-value']");
    const hammerEl = card.querySelector("[class*='result-value']");
    const estimateText = estimateEl?.textContent;
    const hammerText = hammerEl?.textContent;
    const lotTitle = card.querySelector(".c-lot-index-lot__artist, [class*='title']")?.textContent?.trim() || wineName;

    if (estimateText) {
      const estimate = parseInt(estimateText.replace(/[^\d]/g, ""), 10);
      const hammer = hammerText
        ? parseInt(hammerText.replace(/[^\d]/g, ""), 10)
        : null;
      if (estimate > 0) {
        const guaranteePrice = Math.round(
          estimate * getGuaranteeRatioForEstimate(estimate, lotTitle)
        );

        const producerInfo = getProducerStatsInfo(lotTitle);

        if (!card.querySelector("[data-guarantee-price]")) {
          const guaranteeEl = document.createElement("div");
          guaranteeEl.dataset.guaranteePrice = "true";

          let guaranteeText = `Win: ${guaranteePrice.toLocaleString("sv-SE")} SEK`;
          if (producerInfo && producerInfo.lots >= 3) {
            const premiumSign = producerInfo.premium >= 0 ? "+" : "";
            guaranteeText += ` (${premiumSign}${producerInfo.premium}%)`;
          }

          guaranteeEl.textContent = guaranteeText;
          Object.assign(guaranteeEl.style, {
            fontSize: "13px",
            fontWeight: "600",
            color: "#1a1a1a",
            textAlign: "right",
            marginLeft: "auto",
            marginTop: "-16px",
            display: "block",
          });

          if (producerInfo) {
            guaranteeEl.title = `Based on ${producerInfo.lots} historical sales\nAvg: ${producerInfo.premium >= 0 ? "+" : ""}${producerInfo.premium}% vs estimate`;
          }

          estimateEl.parentNode.insertBefore(
            guaranteeEl,
            estimateEl.nextSibling
          );
        }

        const indicator = document.createElement("div");
        let indicatorColor = "#22c55e";

        if (hammer && hammer > 0) {
          indicatorColor = hammer <= guaranteePrice ? "#22c55e" : "#ef4444";
        }

        Object.assign(indicator.style, {
          position: "absolute",
          bottom: "-3px",
          right: "-3px",
          width: "12px",
          height: "12px",
          borderRadius: "50%",
          backgroundColor: indicatorColor,
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
  el.innerHTML = `<span style="color:#888 !important;">${reason || ""}</span><span style="float:right; letter-spacing:1px; color:${color} !important;">${ratingStars(score)}</span>`;
  return el;
}

function injectAllRatings() {
  if (!liveWinesById && !releasesMap) return;

  const url = window.location.href;

  if (url.includes("bukowskis.com") && liveWinesById) {
    document.querySelectorAll("div.c-lot-index-lot, div.c-lot-cell").forEach((card) => {
      if (card.querySelector("[data-wine-rating]")) return;
      const wine = findLiveWineRating(card);
      if (!wine || !wine.rating_score) return;
      card.appendChild(createRatingEl(wine.rating_score, wine.rating_reason));
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

function extractTitleParts(card) {
  const monopolParagraphs = card.querySelectorAll("p.monopol-250");
  const primary = Array.from(monopolParagraphs)
    .slice(0, 2)
    .map((el) => el.innerText.trim())
    .filter(Boolean);
  if (primary.length) return primary;

  const lotIndexTitle = card.querySelector(
    ".c-lot-index-lot__artist, a.c-lot-index-lot__title, .c-lot-index-lot__title"
  );
  if (lotIndexTitle?.innerText.trim()) {
    return [lotIndexTitle.innerText.trim()];
  }

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

function scrapeBukowskisData() {
  const lots = document.querySelectorAll("div.c-lot-index-lot, div.c-lot-cell");
  const data = { withHammer: [], withEstimateOnly: [] };

  lots.forEach((lot) => {
    const hammerEl = lot.querySelector("[class*='result-value']");
    const estimateEl = lot.querySelector("[class*='estimate-value']");
    const titleEl = lot.querySelector(".c-lot-index-lot__artist, [class*='title']");

    const hammer = parsePrice(hammerEl?.textContent);
    const estimate = parsePrice(estimateEl?.textContent);
    const title = titleEl?.textContent?.trim() || "Unknown";

    if (hammer && estimate) {
      data.withHammer.push({
        title,
        hammer,
        estimate,
        ratio: hammer / estimate,
      });
    } else if (estimate) {
      data.withEstimateOnly.push({ title, estimate });
    }
  });

  return data;
}

function calculateStats(data, expectedRatio = null) {
  const { withHammer, withEstimateOnly } = data;
  const allLots = [
    ...withHammer,
    ...withEstimateOnly.map((lot) => ({ ...lot, hammer: null, ratio: null })),
  ];

  let ratioForPredictions, minRatioForPredictions, maxRatioForPredictions;
  let actualAvgRatio = null;
  const useExpected = expectedRatio !== null;

  if (withHammer.length === 0) {
    const ratio = expectedRatio || 1;
    ratioForPredictions = ratio;
    minRatioForPredictions = ratio * 0.9;
    maxRatioForPredictions = ratio * 1.1;
  } else {
    const ratios = withHammer.map((d) => d.ratio);
    actualAvgRatio = ratios.reduce((a, b) => a + b, 0) / ratios.length;
    const actualMinRatio = Math.min(...ratios);
    const actualMaxRatio = Math.max(...ratios);

    ratioForPredictions = useExpected ? expectedRatio : actualAvgRatio;
    minRatioForPredictions = useExpected ? expectedRatio * 0.9 : actualMinRatio;
    maxRatioForPredictions = useExpected ? expectedRatio * 1.1 : actualMaxRatio;
  }

  const guaranteeRatio = (HISTORICAL_P80_RATIO + ratioForPredictions) / 2;

  const predictions = allLots.map((lot) => ({
    title: lot.title,
    estimate: lot.estimate,
    hammer: lot.hammer,
    predictedLow: Math.round(lot.estimate * minRatioForPredictions),
    predictedAvg: Math.round(lot.estimate * ratioForPredictions),
    predictedHigh: Math.round(lot.estimate * maxRatioForPredictions),
    guaranteePrice: Math.round(lot.estimate * guaranteeRatio),
  }));

  const avgHammer =
    withHammer.length > 0
      ? Math.round(
          withHammer.reduce((a, b) => a + b.hammer, 0) / withHammer.length
        )
      : 0;
  const avgEstimate =
    allLots.length > 0
      ? Math.round(allLots.reduce((a, b) => a + b.estimate, 0) / allLots.length)
      : 0;

  const allEstimates = allLots.map((lot) => lot.estimate);
  const minEstimate = allEstimates.length > 0 ? Math.min(...allEstimates) : 0;
  const maxEstimate = allEstimates.length > 0 ? Math.max(...allEstimates) : 0;

  return {
    totalLots: allLots.length,
    soldLots: withHammer.length,
    unsoldLots: withEstimateOnly.length,
    avgHammer,
    avgEstimate,
    minEstimate,
    maxEstimate,
    avgRatio: useExpected ? expectedRatio : actualAvgRatio || 1,
    minRatio: minRatioForPredictions,
    maxRatio: maxRatioForPredictions,
    guaranteeRatio,
    actualAvgRatio,
    predictions,
    soldData: withHammer,
    usingExpectedRatio: useExpected,
  };
}

function formatSEK(value) {
  return value.toLocaleString("sv-SE") + " SEK";
}

function formatRatio(ratio) {
  return (ratio * 100).toFixed(0) + "%";
}

function calculateExpectedRatio(avgEstimate) {
  if (!avgEstimate || avgEstimate <= 0) return 1;
  return 2.15 * Math.pow(avgEstimate, -0.084);
}

const HISTORICAL_P80_RATIO = 1.15;

function getGuaranteeRatioForEstimate(estimate, wineTitle = null) {
  if (wineTitle && bukowskisStats) {
    const producerStats = findProducerStats(wineTitle);
    if (producerStats && producerStats.avg_ratio) {
      return producerStats.avg_ratio;
    }
  }

  return HISTORICAL_P80_RATIO;
}

function getProducerStatsInfo(wineTitle) {
  if (!bukowskisStats) return null;
  const stats = findProducerStats(wineTitle);
  if (!stats) return null;
  return {
    producer: stats.producer,
    ratio: stats.avg_ratio,
    lots: stats.sold,
    sellRate: stats.sell_rate,
    premium: stats.avg_ratio ? Math.round((stats.avg_ratio - 1) * 100) : 0
  };
}

function updateAllBadgeIndicators() {
  const cards = document.querySelectorAll(
    "[data-badge-injected='true']"
  );
  cards.forEach((card) => {
    const badge = card.querySelector("[data-vinslipp-badge='true']");
    if (!badge) return;

    const indicator = Array.from(badge.children).find(
      (child) => child.tagName === "DIV" && child.style.borderRadius === "50%"
    );
    if (!indicator) return;

    const estimateEl = card.querySelector("[class*='estimate-value']");
    const hammerEl = card.querySelector("[class*='result-value']");
    const titleEl = card.querySelector(".c-lot-index-lot__artist, [class*='title']");
    const estimateText = estimateEl?.textContent;
    const hammerText = hammerEl?.textContent;
    const wineTitle = titleEl?.textContent?.trim() || "";

    if (!estimateText) return;

    const estimate = parseInt(estimateText.replace(/[^\d]/g, ""), 10);
    const hammer = hammerText
      ? parseInt(hammerText.replace(/[^\d]/g, ""), 10)
      : null;

    if (estimate <= 0) return;

    let indicatorColor = "#22c55e";
    if (hammer && hammer > 0) {
      const guaranteePrice = Math.round(
        estimate * getGuaranteeRatioForEstimate(estimate, wineTitle)
      );
      indicatorColor = hammer <= guaranteePrice ? "#22c55e" : "#ef4444";
    }

    indicator.style.backgroundColor = indicatorColor;
  });
}

let statsPanel = null;

function createStatsPanel() {
  if (statsPanel) statsPanel.remove();

  const data = scrapeBukowskisData();
  const lots = document.querySelectorAll("div.c-lot-index-lot, div.c-lot-cell");
  const isOngoingPage = Array.from(lots).some((lot) =>
    (lot.innerText || "").toLowerCase().includes("current bid")
  );

  const prelimStats = calculateStats(data, null);
  const autoExpectedRatio = calculateExpectedRatio(prelimStats.avgEstimate);
  const autoExpectedPercent = (autoExpectedRatio * 100).toFixed(0);

  const savedRatio = localStorage.getItem("bukowskis_expected_ratio");
  const manualEntry = localStorage.getItem("bukowskis_ratio_manual") === "true";
  const testMode = localStorage.getItem("bukowskis_test_mode") === "true";
  const manualRatioPercent = savedRatio ? parseFloat(savedRatio) : null;
  const manualRatio = manualRatioPercent ? manualRatioPercent / 100 : null;

  let useExpectedRatio = false;
  let expectedRatio = null;

  if (manualEntry && manualRatio !== null) {
    useExpectedRatio = true;
    expectedRatio = manualRatio;
  } else if (isOngoingPage || prelimStats.soldLots === 0 || testMode) {
    useExpectedRatio = true;
    expectedRatio = autoExpectedRatio;
  }

  const stats = calculateStats(data, useExpectedRatio ? expectedRatio : null);

  if (!isOngoingPage && stats.soldLots > 0 && !manualEntry) {
    const ratioPercent = (stats.avgRatio * 100).toFixed(0);
    localStorage.setItem("bukowskis_expected_ratio", ratioPercent);
  }

  statsPanel = document.createElement("div");
  statsPanel.id = "bukowskis-stats-panel";

  Object.assign(statsPanel.style, {
    position: "fixed",
    top: "80px",
    right: "20px",
    width: "320px",
    maxHeight: "80vh",
    overflowY: "auto",
    backgroundColor: "#ffffff",
    color: "#333",
    borderRadius: "12px",
    border: "1px solid #e5e5e5",
    zIndex: "10000",
    fontFamily:
      "-apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif",
    fontSize: "14px",
  });

  const header = `
    <div style="padding:16px; border-bottom:1px solid #e5e5e5; display:flex; justify-content:space-between; align-items:center;">
      <div style="font-size:16px; font-weight:600; color:#333;">Bukowskis Stats</div>
      <button id="stats-close-btn" style="background:none; border:none; color:#999; font-size:20px; cursor:pointer;">×</button>
    </div>
  `;

  const displayRatioPercent = (stats.avgRatio * 100).toFixed(0);
  const actualRatioPercent = prelimStats.actualAvgRatio
    ? (prelimStats.actualAvgRatio * 100).toFixed(0)
    : null;
  let ratioStatus;
  if (manualEntry && manualRatio !== null) {
    ratioStatus = `<div style="font-size:10px; color:#0369a1; margin-top:4px;">Using manual override: ${manualRatioPercent}%</div>`;
  } else if (testMode && !isOngoingPage && prelimStats.soldLots > 0) {
    ratioStatus = `<div style="font-size:10px; color:#f59e0b; margin-top:4px;">TEST MODE: Using ${autoExpectedPercent}% (actual was ${actualRatioPercent}%)</div>`;
  } else if (isOngoingPage || prelimStats.soldLots === 0) {
    ratioStatus = `<div style="font-size:10px; color:#22c55e; margin-top:4px;">Auto-calculated: ${autoExpectedPercent}% (from avg estimate ${formatSEK(
      prelimStats.avgEstimate
    )})</div>`;
  } else {
    ratioStatus = `<div style="font-size:10px; color:#666; margin-top:4px;">Using actual: ${displayRatioPercent}% from ${stats.soldLots} sold lots</div>`;
  }

  const testModeHtml =
    !isOngoingPage && prelimStats.soldLots > 0
      ? `
    <div style="display:flex; align-items:center; gap:6px; margin-top:8px; padding-top:8px; border-top:1px dashed #e5e5e5;">
      <label style="font-size:11px; color:#666; cursor:pointer; display:flex; align-items:center; gap:4px;">
        <input type="checkbox" id="test-mode-toggle" ${
          testMode ? "checked" : ""
        } style="cursor:pointer;" />
        Test Mode (compare auto vs actual)
      </label>
    </div>
  `
      : "";

  const inputDisabled = !testMode ? "disabled" : "";
  const inputStyle = testMode
    ? "width:50px; padding:4px 6px; border:1px solid #ddd; border-radius:4px; font-size:13px; text-align:right;"
    : "width:50px; padding:4px 6px; border:1px solid #ddd; border-radius:4px; font-size:13px; text-align:right; background:#e5e5e5; color:#999; cursor:not-allowed;";
  const applyBtnStyle = testMode
    ? "padding:4px 8px; background:#2563eb; color:white; border:none; border-radius:4px; font-size:11px; cursor:pointer;"
    : "padding:4px 8px; background:#9ca3af; color:white; border:none; border-radius:4px; font-size:11px; cursor:not-allowed;";
  const resetBtnStyle = testMode
    ? "padding:4px 8px; background:#6b7280; color:white; border:none; border-radius:4px; font-size:11px; cursor:pointer;"
    : "padding:4px 8px; background:#9ca3af; color:white; border:none; border-radius:4px; font-size:11px; cursor:not-allowed;";

  const ratioInputHtml = `
    <div style="padding:12px 16px; border-bottom:1px solid #e5e5e5; background:#f8f9fa;">
      <div style="display:flex; justify-content:space-between; align-items:center;">
        <label style="font-size:12px; color:#666;">Expected Hammer/Est:</label>
        <div style="display:flex; align-items:center; gap:4px;">
          <input
            type="number"
            id="expected-ratio-input"
            value="${displayRatioPercent}"
            min="50"
            max="200"
            ${inputDisabled}
            style="${inputStyle}"
          />
          <span style="color:#666; font-size:13px;">%</span>
          <button id="apply-ratio-btn" ${inputDisabled} style="${applyBtnStyle}">Apply</button>
          <button id="reset-ratio-btn" ${inputDisabled} style="${resetBtnStyle}">Reset</button>
        </div>
      </div>
      ${ratioStatus}
      ${testModeHtml}
    </div>
  `;

  const lotsLabel1 = isOngoingPage ? "With Bids" : "Sold Lots";
  const lotsLabel2 = isOngoingPage ? "No Bids" : "Unsold Lots";
  const overview = `
    <div style="padding:16px; border-bottom:1px solid #e5e5e5;">
      <div style="display:grid; grid-template-columns:1fr 1fr; gap:12px;">
        <div style="background:${
          isOngoingPage ? "#e0f2fe" : "#f0fdf4"
        }; padding:12px; border-radius:8px; text-align:center; border:1px solid ${
    isOngoingPage ? "#7dd3fc" : "#bbf7d0"
  };">
          <div style="font-size:24px; font-weight:700; color:${
            isOngoingPage ? "#0369a1" : "#22c55e"
          };">${stats.soldLots}</div>
          <div style="font-size:11px; color:#666;">${lotsLabel1}</div>
        </div>
        <div style="background:#fefce8; padding:12px; border-radius:8px; text-align:center; border:1px solid #fef08a;">
          <div style="font-size:24px; font-weight:700; color:#ca8a04;">${
            stats.unsoldLots
          }</div>
          <div style="font-size:11px; color:#666;">${lotsLabel2}</div>
        </div>
      </div>
      <div style="display:flex; justify-content:space-between; margin-top:12px; padding-top:12px; border-top:1px dashed #e5e5e5;">
        <div>
          <div style="font-size:10px; color:#888;">Low Estimate:</div>
          <div style="font-size:13px; color:#333; font-weight:500;">${formatSEK(
            stats.minEstimate
          )}</div>
        </div>
        <div style="text-align:right;">
          <div style="font-size:10px; color:#888;">High Estimate:</div>
          <div style="font-size:13px; color:#333; font-weight:500;">${formatSEK(
            stats.maxEstimate
          )}</div>
        </div>
      </div>
    </div>
  `;

  const priceHeader = isOngoingPage ? "Bid Analysis" : "Price Analysis";
  const avgPriceLabel = isOngoingPage ? "Avg Current Bid:" : "Avg Hammer:";
  const ratioLabel = isOngoingPage ? "Avg Bid/Est:" : "Avg Hammer/Est:";
  const priceStats =
    stats.soldLots > 0
      ? `
    <div style="padding:16px; border-bottom:1px solid #e5e5e5;">
      <div style="font-weight:600; margin-bottom:12px; color:#333;">${priceHeader}</div>
      <div style="display:flex; flex-direction:column; gap:8px;">
        <div style="display:flex; justify-content:space-between;">
          <span style="color:#666;">${avgPriceLabel}</span>
          <span style="color:${
            isOngoingPage ? "#0369a1" : "#22c55e"
          }; font-weight:600;">${formatSEK(stats.avgHammer)}</span>
        </div>
        <div style="display:flex; justify-content:space-between;">
          <span style="color:#666;">Avg Estimate:</span>
          <span style="color:#333;">${formatSEK(stats.avgEstimate)}</span>
        </div>
        <div style="display:flex; justify-content:space-between;">
          <span style="color:#666;">${ratioLabel}</span>
          <span style="color:#2563eb; font-weight:600;">${formatRatio(
            stats.avgRatio
          )}</span>
        </div>
        <div style="display:flex; justify-content:space-between;">
          <span style="color:#666;">Range:</span>
          <span style="color:#333;">${formatRatio(
            stats.minRatio
          )} - ${formatRatio(stats.maxRatio)}</span>
        </div>
        <div style="background:#1a1a1a; border-radius:6px; padding:8px; margin-top:8px; display:flex; justify-content:space-between; align-items:center;">
          <span style="color:rgba(255,255,255,0.7); font-size:11px;">Guarantee Ratio (P80):</span>
          <span style="color:#fff; font-weight:700;">${formatRatio(
            stats.guaranteeRatio
          )}</span>
        </div>
      </div>
    </div>
  `
      : "";

  const predictionsHeader = isOngoingPage
    ? "Predicted Final Prices"
    : "All Lots Predictions";
  const predictionsHtml =
    stats.predictions.length > 0
      ? `
    <div style="padding:16px;">
      <div style="font-weight:600; margin-bottom:12px; color:#333;">${predictionsHeader} (${
          stats.predictions.length
        })</div>
      <div style="display:flex; flex-direction:column; gap:10px;">
        ${stats.predictions
          .map((p) => {
            const hasSold = p.hammer !== null;
            const diff = hasSold ? p.hammer - p.predictedAvg : 0;
            const diffPercent = hasSold
              ? ((diff / p.predictedAvg) * 100).toFixed(0)
              : 0;
            const isBelow = diff < 0;
            let boxColor = "#22c55e";
            if (hasSold) {
              boxColor = p.hammer <= p.guaranteePrice ? "#22c55e" : "#ef4444";
            }
            return `
          <div style="background:#f8f9fa; padding:10px; border-radius:8px; border:2px solid ${boxColor};">
            <div style="font-size:12px; color:#555; margin-bottom:6px; white-space:nowrap; overflow:hidden; text-overflow:ellipsis;" title="${
              p.title
            }">${p.title.substring(0, 40)}${
              p.title.length > 40 ? "..." : ""
            }</div>
            <div style="display:flex; justify-content:space-between; font-size:12px;">
              <span style="color:#666;">Est: ${formatSEK(p.estimate)}</span>
              ${
                hasSold
                  ? `<span style="color:${
                      isBelow ? "#22c55e" : "#ef4444"
                    }; font-weight:600;">Sold: ${formatSEK(p.hammer)}</span>`
                  : `<span style="color:#0369a1;">Pending</span>`
              }
            </div>
            <div style="background:#1a1a1a; border-radius:6px; padding:6px 8px; margin-top:6px; display:flex; justify-content:space-between; align-items:center;">
              <span style="color:rgba(255,255,255,0.7); font-size:10px;">Guarantee</span>
              <span style="color:#fff; font-weight:700; font-size:12px;">${formatSEK(
                p.guaranteePrice
              )}</span>
            </div>
            <div style="display:flex; justify-content:space-between; margin-top:6px;">
              <span style="color:#22c55e; font-size:11px;">${formatSEK(
                p.predictedLow
              )}</span>
              <span style="color:#facc15; font-weight:600;">${formatSEK(
                p.predictedAvg
              )}</span>
              <span style="color:#ef4444; font-size:11px;">${formatSEK(
                p.predictedHigh
              )}</span>
            </div>
            <div style="display:flex; justify-content:space-between; font-size:10px; color:#888; margin-top:2px;">
              <span>Low</span>
              <span>Predicted</span>
              <span>High</span>
            </div>
            ${
              hasSold
                ? `<div style="font-size:10px; color:${
                    isBelow ? "#22c55e" : "#ef4444"
                  }; margin-top:4px; text-align:center;">vs Predicted: ${
                    diff >= 0 ? "+" : ""
                  }${formatSEK(diff)} (${
                    diff >= 0 ? "+" : ""
                  }${diffPercent}%)</div>`
                : ""
            }
          </div>
        `;
          })
          .join("")}
      </div>
    </div>
  `
      : `
    <div style="padding:16px; text-align:center; color:#888;">
      No lots to predict
    </div>
  `;

  let predictionsPanel = document.getElementById("bukowskis-predictions-panel");
  const savedScrollTop = predictionsPanel ? predictionsPanel.scrollTop : 0;
  if (predictionsPanel) predictionsPanel.remove();

  if (stats.predictions.length > 0) {
    predictionsPanel = document.createElement("div");
    predictionsPanel.id = "bukowskis-predictions-panel";
    Object.assign(predictionsPanel.style, {
      position: "fixed",
      top: "80px",
      bottom: "50px",
      left: "20px",
      width: "320px",
      overflow: "scroll",
      overscrollBehavior: "contain",
      backgroundColor: "#ffffff",
      color: "#333",
      borderRadius: "12px",
      border: "1px solid #e5e5e5",
      zIndex: "10000",
      fontFamily:
        "-apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif",
      fontSize: "14px",
    });
    predictionsPanel.innerHTML = predictionsHtml;
    document.body.appendChild(predictionsPanel);
    predictionsPanel.scrollTop = savedScrollTop;
  }

  statsPanel.innerHTML = header + ratioInputHtml + overview + priceStats;
  document.body.appendChild(statsPanel);

  document.getElementById("stats-close-btn").addEventListener("click", () => {
    statsPanel.remove();
    statsPanel = null;
    const predPanel = document.getElementById("bukowskis-predictions-panel");
    if (predPanel) predPanel.remove();
  });

  const applyBtn = document.getElementById("apply-ratio-btn");
  const ratioInput = document.getElementById("expected-ratio-input");
  if (applyBtn && ratioInput) {
    applyBtn.onclick = function () {
      const value = parseFloat(ratioInput.value);
      if (value >= 50 && value <= 200) {
        localStorage.setItem("bukowskis_expected_ratio", value.toString());
        localStorage.setItem("bukowskis_ratio_manual", "true");
        createStatsPanel();
        updateAllBadgeIndicators();
      }
    };
  }

  const resetBtn = document.getElementById("reset-ratio-btn");
  if (resetBtn) {
    resetBtn.onclick = function () {
      localStorage.removeItem("bukowskis_ratio_manual");
      localStorage.removeItem("bukowskis_expected_ratio");
      createStatsPanel();
      updateAllBadgeIndicators();
    };
  }

  const testModeToggle = document.getElementById("test-mode-toggle");
  if (testModeToggle) {
    testModeToggle.onchange = function () {
      if (this.checked) {
        localStorage.setItem("bukowskis_test_mode", "true");
      } else {
        localStorage.removeItem("bukowskis_test_mode");
      }
      createStatsPanel();
    };
  }
}

function createStatsToggleButton() {
  if (!isBukowskisPage()) return;
  if (document.getElementById("stats-toggle-btn")) return;

  const btn = document.createElement("button");
  btn.id = "stats-toggle-btn";
  btn.innerHTML = "📊";
  btn.title = "Show Bukowskis Stats";

  Object.assign(btn.style, {
    position: "fixed",
    top: "10px",
    right: "10px",
    width: "32px",
    height: "32px",
    borderRadius: "50%",
    border: "1px solid #e5e5e5",
    backgroundColor: "#ffffff",
    color: "#333",
    fontSize: "16px",
    cursor: "pointer",
    zIndex: "9999",
    display: "flex",
    alignItems: "center",
    justifyContent: "center",
  });

  btn.addEventListener("click", () => {
    if (statsPanel) {
      statsPanel.remove();
      statsPanel = null;
    } else {
      createStatsPanel();
    }
  });

  document.body.appendChild(btn);
}

let initialized = false;

async function initialize() {
  if (initialized) return;
  initialized = true;

  await Promise.all([loadBukowskisStats(), loadLiveWines(), loadReleases()]);

  refreshInjections();
  createStatsToggleButton();

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
    if (statsPanel) createStatsPanel();
  }
}
setInterval(checkUrlChange, 1000);

if (document.body) {
  setupObserver();
} else {
  document.addEventListener("DOMContentLoaded", setupObserver);
}
