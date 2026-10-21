"""IBAN display helpers for the CRM screen."""

MIN_IBAN_LENGTH = 8


def mask_iban(iban: str) -> str:
    compact = iban.replace(" ", "")
    if len(compact) < MIN_IBAN_LENGTH:
        raise ValueError(f"IBAN too short: at least {MIN_IBAN_LENGTH} characters expected")
    return compact[:2] + "*" * (len(compact) - 6) + compact[-4:]
