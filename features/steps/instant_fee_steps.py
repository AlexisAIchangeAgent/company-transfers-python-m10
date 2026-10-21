"""Step definitions of features/instant-fee.feature: one per Gherkin step, no fee logic."""

import json
from decimal import Decimal

from behave import given, then, when
from fastapi.testclient import TestClient

from company_transfers.clients.exchange_rate import FixedRateClient
from company_transfers.main import create_app


@given("the fee service is running")
def step_service_is_running(context):
    response = context.client.get("/health")

    assert response.status_code == 200, response.text


@given("the EUR to MDL exchange rate is {rate}")
def step_exchange_rate_is(context, rate):
    context.client.close()
    context.rate_client = FixedRateClient(rate=Decimal(rate))
    context.client = TestClient(create_app(rate_client=context.rate_client))


@given("it is night")
def step_it_is_night(context):
    # The feature does not say what "night" is nor how the service learns it (see the
    # ambiguous criteria reported with this step). No mechanism is chosen here.
    raise NotImplementedError("'it is night' is ambiguous: no definition of night, no clock input")


@when("a {segment} customer asks for the fee of an instant transfer of {currency} {amount}")
def step_customer_asks_for_the_fee(context, segment, currency, amount):
    context.response = context.client.post(
        "/fees",
        json={
            "amount": amount,
            "currency": currency,
            "type": "instant",
            "customer_segment": segment,
        },
    )


@then("the response status is {status:d}")
def step_response_status_is(context, status):
    assert context.response.status_code == status, context.response.text


@then("the fee is MDL {fee}")
def step_fee_is(context, fee):
    body = json.loads(context.response.text, parse_float=Decimal)

    assert body["fee"] == Decimal(fee)


@then('the error is "{message}"')
def step_error_is(context, message):
    body = json.loads(context.response.text)

    assert body["error"] == message
