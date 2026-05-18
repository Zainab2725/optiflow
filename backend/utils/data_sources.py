import httpx
import feedparser
import pandas as pd
import os
import json
from datetime import datetime
from io import StringIO
from dotenv import load_dotenv

load_dotenv(os.path.join(os.path.dirname(__file__), "../.env"))

NEWSDATA_KEY = os.getenv("NEWSDATA_API_KEY")
OPENWEATHER_KEY = os.getenv("OPENWEATHER_API_KEY")
EXCHANGERATE_KEY = os.getenv("EXCHANGERATE_API_KEY")
WAREHOUSE_URL = os.getenv("WAREHOUSE_SHEET_URL")

PHARMA_KEYWORDS = [
    "medicine", "drug", "pharma", "shortage", "price hike",
    "supply chain", "import", "health", "hospital", "DRAP",
    "pharmaceutical", "karachi", "freight", "chemical",
    "raw material", "tablet", "injection", "vaccine", "insulin",
    "antibiotic", "panadol", "disprin", "ORS", "saline"
]

KEYWORDS_DEFAULT = [
    "medicine shortage Pakistan",
    "supply chain Karachi",
    "pharmaceutical shortage",
    "drug price Pakistan",
    "DRAP Pakistan"
]

# ─────────────────────────────────────────
# SOURCE 1 — Google Sheets Warehouse
# ─────────────────────────────────────────
async def fetch_warehouse_csv() -> dict:
    if not WAREHOUSE_URL or not WAREHOUSE_URL.startswith("http"):
        return {
            "source": "Google Sheets Warehouse",
            "source_type": "csv",
            "fetched_at": datetime.utcnow().isoformat(),
            "credibility": 0.0,
            "error": "WAREHOUSE_SHEET_URL not configured"
        }
    async with httpx.AsyncClient(follow_redirects=True, timeout=10) as client:
        r = await client.get(WAREHOUSE_URL)
    df = pd.read_csv(StringIO(r.text))
    df.columns = [c.strip().lower().replace(" ", "_") for c in df.columns]
    
    # Map 'qty_in_stock' to 'quantity'
    if "qty_in_stock" in df.columns:
        df = df.rename(columns={"qty_in_stock": "quantity"})
        
    if "quantity" not in df.columns:
        # fallback if neither exist
        df["quantity"] = 0
        
    if "unit" not in df.columns:
        df["unit"] = "Units"
        
    if "warehouse" not in df.columns:
        df["warehouse"] = "Main Warehouse"

    keep_cols = ["sku", "product_name", "quantity", "unit", "last_updated", "warehouse"]
    existing_cols = [c for c in keep_cols if c in df.columns]
    if existing_cols:
        df = df[existing_cols]
    df = df.where(pd.notna(df), None)
    records = df.to_dict(orient="records")
    today = datetime.utcnow().date()
    staleness = False
    for row in records:
        try:
            row_date = datetime.strptime(
                str(row.get("last_updated", "")), "%Y-%m-%d"
            ).date()
            if (today - row_date).days > 2:
                staleness = True
                break
        except:
            staleness = True
    return {
        "source": "Google Sheets Warehouse",
        "source_type": "csv",
        "fetched_at": datetime.utcnow().isoformat(),
        "credibility": 0.65,
        "data": {
            "records": records,
            "row_count": len(records),
            "staleness_warning": staleness
        }
    }

# ─────────────────────────────────────────
# SOURCE 2 — OpenWeatherMap Karachi
# ─────────────────────────────────────────
async def fetch_weather_karachi() -> dict:
    url = "https://api.openweathermap.org/data/2.5/weather"
    params = {
        "q": "Karachi,PK",
        "appid": OPENWEATHER_KEY,
        "units": "metric"
    }
    async with httpx.AsyncClient(timeout=10) as client:
        r = await client.get(url, params=params)
    w = r.json()
    condition = w.get("weather", [{}])[0].get("main", "Clear")
    rain_mm = w.get("rain", {}).get("1h", 0)
    temp_c = w.get("main", {}).get("temp", 0)
    description = w.get("weather", [{}])[0].get("description", "")
    logistics_risk = "HIGH" if rain_mm > 5 or condition in [
        "Rain", "Thunderstorm", "Drizzle", "Snow"
    ] else "LOW"
    return {
        "source": "OpenWeatherMap Karachi",
        "source_type": "weather_api",
        "fetched_at": datetime.utcnow().isoformat(),
        "credibility": 0.95,
        "data": {
            "condition": condition,
            "rain_mm": rain_mm,
            "temp_c": temp_c,
            "description": description,
            "logistics_risk": logistics_risk,
            "road_impact": "Possible delays" if logistics_risk == "HIGH" else "Roads clear"
        }
    }

# ─────────────────────────────────────────
# SOURCE 3 — ExchangeRate-API
# ─────────────────────────────────────────
async def fetch_pkr_rate() -> dict:
    url = f"https://v6.exchangerate-api.com/v6/{EXCHANGERATE_KEY}/pair/USD/PKR"
    async with httpx.AsyncClient(timeout=10) as client:
        r = await client.get(url)
    rate = r.json().get("conversion_rate", 279.5)
    return {
        "source": "ExchangeRate-API",
        "source_type": "financial_api",
        "fetched_at": datetime.utcnow().isoformat(),
        "credibility": 0.99,
        "data": {
            "usd_to_pkr": rate,
            "budget_50k_pkr_in_usd": round(50000 / rate, 2),
            "budget_80k_pkr_in_usd": round(80000 / rate, 2),
            "budget_120k_pkr_in_usd": round(120000 / rate, 2),
            "note": "Used for PKR budget constraint checking"
        }
    }

# ─────────────────────────────────────────
# SOURCE 4 — In-App Complaints (from JSON file)
# ─────────────────────────────────────────
def fetch_inapp_complaints_snapshot() -> dict:
    complaints_file = os.path.join(
        os.path.dirname(__file__), "../data/complaints.json"
    )
    try:
        with open(complaints_file, "r") as f:
            complaints = json.load(f)
    except:
        complaints = []
    from datetime import timedelta
    now = datetime.utcnow()
    cutoff = (now - timedelta(hours=24)).isoformat()
    last_24h = [c for c in complaints if c.get("timestamp", "") > cutoff]
    by_sku = {}
    for c in complaints:
        sku = c.get("sku", "unknown")
        by_sku[sku] = by_sku.get(sku, 0) + 1
    spike = len(last_24h) > 3
    return {
        "source": "OptiFlow In-App Complaints",
        "source_type": "in_app_feedback",
        "fetched_at": datetime.utcnow().isoformat(),
        "credibility": 0.90,
        "data": {
            "total_complaints": len(complaints),
            "last_24h": len(last_24h),
            "by_sku": by_sku,
            "complaint_spike": spike,
            "recent_complaints": last_24h[-3:]
        }
    }

# ─────────────────────────────────────────
# SOURCE 5 — DRAP + Dawn Business + ProPakistani + Tribune RSS
# ─────────────────────────────────────────
async def fetch_pakistan_rss_news() -> dict:
    feeds = [
        "https://www.dawn.com/feeds/business-finance",
        "https://propakistani.pk/feed/",
        "https://profit.pakistantoday.com.pk/feed/",
        "https://tribune.com.pk/feed/business"
    ]
    all_articles = []
    seen_links = set()

    import asyncio

    async def parse_feed(url):
        try:
            loop = asyncio.get_event_loop()
            feed = await loop.run_in_executor(None, feedparser.parse, url)
            return feed.entries
        except:
            return []

    results = await asyncio.gather(*[parse_feed(f) for f in feeds])

    for entries in results:
        for entry in entries[:20]:
            link = entry.get("link", "")
            if link in seen_links:
                continue
            title = entry.get("title", "")
            summary = entry.get("summary", "")
            combined = (title + " " + summary).lower()
            if any(kw.lower() in combined for kw in PHARMA_KEYWORDS):
                seen_links.add(link)
                all_articles.append({
                    "title": title,
                    "summary": summary[:300],
                    "published": entry.get("published", ""),
                    "link": link
                })

    if not all_articles:
        for entries in results:
            for entry in entries[:2]:
                link = entry.get("link", "")
                if link not in seen_links:
                    seen_links.add(link)
                    all_articles.append({
                        "title": entry.get("title", ""),
                        "summary": entry.get("summary", "")[:300],
                        "published": entry.get("published", ""),
                        "link": link,
                        "note": "fallback - no pharma match today"
                    })

    return {
        "source": "Pakistan Business RSS (Dawn/ProPak/Tribune/Profit)",
        "source_type": "rss_aggregator",
        "fetched_at": datetime.utcnow().isoformat(),
        "credibility": 0.88,
        "data": {
            "articles": all_articles[:6],
            "matched": len(all_articles),
            "feeds_checked": len(feeds)
        }
    }

# ─────────────────────────────────────────
# SOURCE 6 — NewsData.io
# ─────────────────────────────────────────
async def fetch_pakistan_news(keywords: list = None) -> dict:
    if not keywords:
        keywords = KEYWORDS_DEFAULT
    params = {
        "apikey": NEWSDATA_KEY,
        "q": " OR ".join(keywords[:3]),
        "country": "pk",
        "language": "en",
        "category": "business,health"
    }
    async with httpx.AsyncClient(timeout=15) as client:
        r = await client.get("https://newsdata.io/api/1/news", params=params)
    articles = r.json().get("results", [])
    return {
        "source": "NewsData.io Pakistan",
        "source_type": "news_api",
        "fetched_at": datetime.utcnow().isoformat(),
        "credibility": 0.85,
        "data": {
            "articles": [
                {
                    "title": a.get("title"),
                    "description": a.get("description"),
                    "published_at": a.get("pubDate"),
                    "source_name": a.get("source_name"),
                    "link": a.get("link")
                }
                for a in articles[:5]
            ],
            "total_fetched": len(articles)
        }
    }

# ─────────────────────────────────────────
# SOURCE 7 — Google Trends Pakistan
# ─────────────────────────────────────────
async def fetch_google_trends() -> dict:
    """
    Custom trend detector built from RSS keyword frequency.
    Replaces pytrends (which is rate-limited).
    Counts how many times pharma keywords appear across
    all RSS feeds in the last 48 hours to detect spikes.
    """
    import asyncio

    feeds = [
        "https://www.dawn.com/feeds/home",
        "https://www.dawn.com/feeds/business-finance",
        "https://propakistani.pk/feed/",
        "https://profit.pakistantoday.com.pk/feed/",
        "https://tribune.com.pk/feed/business",
        "https://arynews.tv/feed/"
    ]

    TREND_KEYWORDS = {
        "panadol": 0,
        "medicine shortage": 0,
        "drug price": 0,
        "pharmacy": 0,
        "pharmaceutical": 0,
        "supply chain": 0,
        "import": 0,
        "shortage": 0,
        "DRAP": 0,
        "health crisis": 0
    }

    total_articles_scanned = 0

    async def scan_feed(url):
        try:
            loop = asyncio.get_event_loop()
            feed = await loop.run_in_executor(
                None, feedparser.parse, url
            )
            return feed.entries[:30]
        except:
            return []

    results = await asyncio.gather(
        *[scan_feed(f) for f in feeds]
    )

    keyword_counts = dict(TREND_KEYWORDS)

    for entries in results:
        for entry in entries:
            total_articles_scanned += 1
            text = (
                entry.get("title", "") + " " +
                entry.get("summary", "")
            ).lower()
            for keyword in keyword_counts:
                if keyword.lower() in text:
                    keyword_counts[keyword] += 1

    top_keywords = {
        k: v for k, v in keyword_counts.items() if v > 0
    }
    top_keywords = dict(
        sorted(top_keywords.items(),
               key=lambda x: x[1], reverse=True)
    )

    total_mentions = sum(keyword_counts.values())

    if total_mentions > 15:
        alert = "CRITICAL - High pharma topic frequency in media"
        panic_signal = True
    elif total_mentions > 7:
        alert = "ELEVATED - Moderate pharma discussion in media"
        panic_signal = False
    elif total_mentions > 2:
        alert = "LOW - Minor pharma mentions in media"
        panic_signal = False
    else:
        alert = "NORMAL - No unusual pharma activity in media"
        panic_signal = False

    return {
        "source": "Pakistan Media Trend Scanner",
        "source_type": "trend_analysis",
        "fetched_at": datetime.utcnow().isoformat(),
        "credibility": 0.82,
        "data": {
            "keyword_mentions": keyword_counts,
            "top_trending_keywords": top_keywords,
            "total_mentions": total_mentions,
            "articles_scanned": total_articles_scanned,
            "feeds_scanned": len(feeds),
            "trend_alert": alert,
            "public_panic_signal": panic_signal,
            "methodology": (
                "Scans 6 Pakistani news RSS feeds in real-time, "
                "counts pharma keyword frequency to detect "
                "media attention spikes"
            )
        }
    }

# ─────────────────────────────────────────
# SOURCE 8 — Supplier Delay Feed (Mock API)
# ─────────────────────────────────────────
async def fetch_supplier_feed() -> dict:
    supplier_data = {
        "source": "Supplier Delay Feed",
        "source_type": "supplier_api",
        "fetched_at": datetime.utcnow().isoformat(),
        "credibility": 0.85,
        "data": {
            "active_delays": [
                {
                    "supplier": "MediTrade Pakistan",
                    "sku": "PKR-001",
                    "product": "Panadol Extra 500mg",
                    "original_eta": "2026-05-16",
                    "revised_eta": "2026-05-21",
                    "delay_days": 5,
                    "reason": "M9 motorway partial closure near Hyderabad",
                    "severity": "HIGH",
                    "transit_stock_available": 800
                },
                {
                    "supplier": "PharmaCo Lahore",
                    "sku": "PKR-003",
                    "product": "ORS Sachets",
                    "original_eta": "2026-05-17",
                    "revised_eta": "2026-05-20",
                    "delay_days": 3,
                    "reason": "Production line maintenance",
                    "severity": "MEDIUM",
                    "transit_stock_available": 0
                }
            ],
            "total_delays": 2,
            "critical_delays": 1,
            "last_updated": datetime.utcnow().isoformat()
        }
    }
    return supplier_data

# ─────────────────────────────────────────
# MASTER FUNCTION — All 8 Sources
# ─────────────────────────────────────────
async def fetch_all_sources(keywords: list = None) -> dict:
    import asyncio
    if not keywords:
        keywords = KEYWORDS_DEFAULT

    results = await asyncio.gather(
        fetch_warehouse_csv(),
        fetch_weather_karachi(),
        fetch_pkr_rate(),
        fetch_pakistan_rss_news(),
        fetch_pakistan_news(keywords),
        fetch_google_trends(),
        fetch_supplier_feed(),
        return_exceptions=True
    )

    inapp = fetch_inapp_complaints_snapshot()

    names = [
        "warehouse", "weather", "currency",
        "rss_news", "news_api", "google_trends", "supplier_feed"
    ]

    output = {}
    healthy = 0
    for name, result in zip(names, results):
        if isinstance(result, Exception):
            output[name] = {
                "source": name,
                "error": str(result),
                "credibility": 0.0,
                "fetched_at": datetime.utcnow().isoformat()
            }
        else:
            output[name] = result
            if "error" not in result:
                healthy += 1

    output["inapp_complaints"] = inapp
    healthy += 1

    output["meta"] = {
        "fetched_at": datetime.utcnow().isoformat(),
        "sources_healthy": healthy,
        "sources_total": 8,
        "keywords_used": keywords
    }

    return output
