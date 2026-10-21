"""Playwright test of the internal CRM screen crm/customer-lookup.html (static page, no server).

Run it with: python -m pytest tests/e2e   (headless by default; add --headed --slowmo 500 to watch)
Elements are found by data-testid only, never by CSS class.
"""

from pathlib import Path

import pytest
from playwright.sync_api import Page, expect

CRM_PAGE = Path(__file__).resolve().parents[2] / "crm" / "customer-lookup.html"


@pytest.fixture
def crm(page: Page) -> Page:
    page.goto(CRM_PAGE.as_uri())
    return page


def test_instant_transfer_fee_is_shown_in_the_history_of_a_searched_customer(crm: Page):
    # arrange and act: search by name, open the customer, read the history
    crm.get_by_test_id("search-input").fill("Mirela")
    crm.get_by_test_id("search-button").click()
    customer = crm.get_by_test_id("customer-row")
    expect(customer).to_have_count(1)
    customer.click()

    # assert: the history lists the transfers and the instant one shows MDL 20.00
    history = crm.get_by_test_id("transfer-history")
    expect(history).to_be_visible()
    expect(history.get_by_test_id("transfer-row")).to_have_count(3)
    instant_row = history.get_by_test_id("transfer-row").filter(
        has=crm.get_by_test_id("transfer-type").filter(has_text="instant")
    )
    expect(instant_row).to_have_count(1)
    expect(instant_row.get_by_test_id("transfer-fee")).to_have_text("20.00")


def test_search_without_a_match_shows_no_customer_and_no_history(crm: Page):
    crm.get_by_test_id("search-input").fill("Nobody")
    crm.get_by_test_id("search-button").click()

    expect(crm.get_by_test_id("customer-row")).to_have_count(0)
    expect(crm.get_by_test_id("transfer-history")).to_be_hidden()
