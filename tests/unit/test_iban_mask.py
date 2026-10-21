import pytest

from company_transfers.domain.iban import mask_iban


def test_mask_iban_keeps_the_first_2_and_the_last_4_characters():
    masked = mask_iban("MD24AG000225100013104168")

    assert masked == "MD" + "*" * 18 + "4168"


def test_mask_iban_ignores_the_spaces_of_the_input():
    masked = mask_iban("MD24 AG00 0225 1000 1310 4168")

    assert masked == "MD******************4168"


def test_mask_iban_refuses_an_input_shorter_than_8_characters_without_spaces():
    with pytest.raises(ValueError):
        mask_iban("MD24 AG0")


def test_mask_iban_accepts_an_input_of_exactly_8_characters():
    masked = mask_iban("MD241234")

    assert masked == "MD**1234"
