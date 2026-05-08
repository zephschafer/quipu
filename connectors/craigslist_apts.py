"""
Craigslist apartment listings scraper.

Craigslist serves a static-rendered fallback page (no JS required) that contains
all listings in a single request. The static page has limited fields per card
(title, price, neighborhood, URL); detail pages are visited for beds, sqft,
posted date, address, and coordinates.

If selectors break after a Craigslist redesign, check these in a browser:
  Search results: ol.cl-static-search-results > li.cl-static-search-result
  Title:          div.title  (or li[title] attribute)
  Price:          div.price
  Neighborhood:   div.location
  Detail - beds/sqft:  .attrgroup span.attr  ("2BR / 1Ba", "900ft²")
  Detail - posted:     time.date[datetime]
  Detail - address:    .mapaddress
  Detail - coords:     div#map[data-latitude][data-longitude]
  Detail - body:       #postingbody
"""
from __future__ import annotations

import re
import time
from random import uniform
from typing import Any

import requests
from bs4 import BeautifulSoup

_BASE = "https://{region}.craigslist.org/search/apa"
_HEADERS = {
    "User-Agent": (
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) "
        "AppleWebKit/537.36 (KHTML, like Gecko) "
        "Chrome/124.0.0.0 Safari/537.36"
    ),
    "Accept-Language": "en-US,en;q=0.9",
}


def _get(url: str, params: dict | None = None) -> BeautifulSoup:
    resp = requests.get(url, params=params, headers=_HEADERS, timeout=30)
    resp.raise_for_status()
    return BeautifulSoup(resp.text, "html.parser")


def _parse_price(text: str) -> int | None:
    digits = re.sub(r"[^\d]", "", text)
    return int(digits) if digits else None


def _parse_attr_spans(soup) -> tuple[float | None, float | None]:
    """Parse bedrooms and sqft from .attrgroup spans like '2BR / 1Ba' and '900ft²'."""
    bedrooms = sqft = None
    for span in soup.select(".attrgroup span.attr"):
        text = span.get_text()
        br = re.search(r"(\d+)\s*BR", text, re.I)
        ft = re.search(r"(\d+)\s*ft", text, re.I)
        if br:
            bedrooms = float(br.group(1))
        if ft:
            sqft = float(ft.group(1))
    return bedrooms, sqft


def _parse_card(card) -> dict[str, Any] | None:
    anchor = card.select_one("a")
    if not anchor:
        return None
    url = anchor.get("href", "")
    title = card.select_one("div.title")
    price_el = card.select_one("div.price")
    location_el = card.select_one("div.location")
    return {
        "url": url,
        "title": title.get_text(strip=True) if title else card.get("title", ""),
        "price": _parse_price(price_el.get_text()) if price_el else None,
        "neighborhood": location_el.get_text(strip=True) if location_el else None,
    }


def _detail_extras(url: str) -> dict[str, Any]:
    extras: dict[str, Any] = {
        "posted": None,
        "bedrooms": None,
        "sqft": None,
        "latitude": None,
        "longitude": None,
        "address": None,
        "post_description": None,
    }
    try:
        soup = _get(url)

        dt = soup.select_one("time.date[datetime]")
        if dt:
            extras["posted"] = dt["datetime"]

        extras["bedrooms"], extras["sqft"] = _parse_attr_spans(soup)

        map_div = soup.select_one("div#map")
        if map_div:
            extras["latitude"] = map_div.get("data-latitude")
            extras["longitude"] = map_div.get("data-longitude")

        addr_el = soup.select_one(".mapaddress")
        if addr_el:
            extras["address"] = addr_el.get_text(strip=True)

        body = soup.select_one("#postingbody")
        if body:
            for tag in body.select(".print-qrcode-container"):
                tag.decompose()
            extras["post_description"] = body.get_text(separator=" ", strip=True)
    except Exception:
        pass
    return extras


def fetch_region(dynamic_params: dict) -> list[dict]:
    """
    Scrape all apartment listings for a single Craigslist region.
    Craigslist's static fallback returns all results in one request (no pagination).
    Use max_records to cap how many listings are fully scraped (detail pages included).
    """
    region = dynamic_params["region"]
    max_records = int(dynamic_params.get("max_records", 999999))

    soup = _get(_BASE.format(region=region), params={"hasPic": "1", "availabilityMode": "0"})
    cards = soup.select("li.cl-static-search-result")
    print(f"    {region}: {len(cards)} listings found")

    records: list[dict] = []
    for i, card in enumerate(cards[:max_records]):
        record = _parse_card(card)
        if not record or not record.get("url"):
            continue
        time.sleep(uniform(1, 3))
        record.update(_detail_extras(record["url"]))
        record["region"] = region
        records.append(record)

    return records
