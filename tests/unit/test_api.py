import json
from decimal import Decimal

import pytest


def decimal_json(response) -> dict:
    return json.loads(response.text, parse_float=Decimal)


def fee_body(amount, currency="MDL", type_="standard", segment="retail") -> dict:
    return {"amount": amount, "currency": currency, "type": type_, "customer_segment": segment}


def test_health_returns_ok(client):
    response = client.get("/health")

    assert response.status_code == 200
    assert response.json() == {"status": "ok"}


def test_post_fees_returns_the_standard_mdl_fee(client):
    response = client.post("/fees", json=fee_body(2000.00))

    assert response.status_code == 200
    assert decimal_json(response) == {
        "fee": Decimal("10.00"),
        "currency": "MDL",
        "rule": "standard-mdl",
    }


def test_post_fees_returns_the_fee_as_a_json_number_with_two_decimals(client):
    response = client.post("/fees", json=fee_body(2000))

    assert '"fee": 10.00' in response.text


def test_post_fees_returns_the_standard_eur_fee_in_mdl(client):
    response = client.post("/fees", json=fee_body(300.00, currency="EUR", segment="premium"))

    assert response.status_code == 200
    assert decimal_json(response) == {
        "fee": Decimal("30.00"),
        "currency": "MDL",
        "rule": "standard-eur",
    }


@pytest.mark.parametrize(
    "body",
    [
        fee_body(100.00, currency="USD"),
        fee_body(0),
        fee_body(-5.00),
        fee_body(10.001),
        fee_body(100.00, type_="express"),
        fee_body(100.00, segment="vip"),
        {"currency": "MDL", "type": "standard", "customer_segment": "retail"},
    ],
)
def test_post_fees_rejects_an_invalid_body_with_422(client, body):
    assert client.post("/fees", json=body).status_code == 422
