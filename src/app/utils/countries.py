import re

from sqlalchemy import or_

_CANONICAL_COUNTRY_ALIASES = {
    "uganda": {"uganda", "ug"},
    "united arab emirates": {
        "uae",
        "u.a.e",
        "u a e",
        "united arab emirates",
        "emirates",
    },
    "united kingdom": {"united kingdom", "uk", "u.k", "great britain", "britain"},
    "united states": {"united states", "usa", "u.s.a", "us", "u.s", "america"},
}

_CANONICAL_COUNTRY_DISPLAY = {
    "uganda": "Uganda",
    "united arab emirates": "United Arab Emirates",
    "united kingdom": "United Kingdom",
    "united states": "United States",
}


def _tokenize_country(value: str | None) -> str:
    cleaned = re.sub(r"[^a-z0-9]+", " ", (value or "").strip().lower())
    return " ".join(cleaned.split())


def normalize_country_name(value: str | None) -> str | None:
    tokenized = _tokenize_country(value)
    if not tokenized:
        return None
    for canonical, aliases in _CANONICAL_COUNTRY_ALIASES.items():
        if tokenized == canonical or tokenized in aliases:
            return _CANONICAL_COUNTRY_DISPLAY.get(canonical, canonical.title())
    return " ".join(part.capitalize() for part in tokenized.split())


def country_aliases(value: str | None) -> list[str]:
    tokenized = _tokenize_country(value)
    if not tokenized:
        return []
    for canonical, aliases in _CANONICAL_COUNTRY_ALIASES.items():
        if tokenized == canonical or tokenized in aliases:
            return sorted({canonical, *aliases})
    return [tokenized]


def country_equals_clause(column, value: str | None):
    aliases = country_aliases(value)
    if not aliases:
        return None
    return or_(*[column.ilike(alias) for alias in aliases])


def country_contains_clause(column, value: str | None):
    aliases = country_aliases(value)
    if not aliases:
        return None
    return or_(*[column.ilike(f"%{alias}%") for alias in aliases])
