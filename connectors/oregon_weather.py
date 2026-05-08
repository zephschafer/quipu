import requests
from datetime import date as _date

CITIES = {
    "portland":  (45.5231, -122.6765),
    "eugene":    (44.0521, -123.0868),
    "salem":     (44.9429, -123.0351),
    "bend":      (44.0582, -121.3153),
    "corvallis": (44.5646, -123.2620),
}


def fetch_weather(dynamic_params: dict) -> list[dict]:
    city = dynamic_params["city"]
    start_date = dynamic_params["start_date"]
    end_date = dynamic_params["end_date"]

    if end_date == "today":
        end_date = _date.today().isoformat()

    lat, lon = CITIES[city]
    resp = requests.get(
        "https://archive-api.open-meteo.com/v1/archive",
        params={
            "latitude": lat,
            "longitude": lon,
            "start_date": start_date,
            "end_date": end_date,
            "daily": "temperature_2m_max,temperature_2m_min,precipitation_sum,windspeed_10m_max",
            "timezone": "America/Los_Angeles",
        },
        timeout=30,
    )
    resp.raise_for_status()
    daily = resp.json()["daily"]

    return [
        {
            "id": f"{city}_{date}",
            "city": city,
            "date": date,
            "temp_max_c": daily["temperature_2m_max"][i],
            "temp_min_c": daily["temperature_2m_min"][i],
            "precipitation_mm": daily["precipitation_sum"][i],
            "windspeed_max_kmh": daily["windspeed_10m_max"][i],
        }
        for i, date in enumerate(daily["time"])
    ]
