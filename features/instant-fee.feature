# Training material. Invented data.
Feature: Instant transfer fee
  As a customer of Company Bank
  I want to know the fee of an instant transfer before I confirm it
  So that I am charged the published tariff

  Acceptance criteria (product decision pending, see docs/fee-rules.md):
  - a retail customer pays the standard fee plus a flat fee of MDL 10.00
  - a premium customer pays the standard fee only, the flat fee is waived
  - an instant transfer above MDL 100,000.00, or the equivalent in EUR, is rejected
  - an EUR amount is converted to MDL first, then the MDL rule applies

  Background:
    Given the fee service is running
    And the EUR to MDL exchange rate is 19.8765

  Scenario Outline: Instant MDL transfer for a retail customer
    When a retail customer asks for the fee of an instant transfer of MDL <amount>
    Then the response status is 200
    And the fee is MDL <fee>

    Examples: standard fee plus MDL 10.00
      | amount    | fee   |
      | 2000.00   | 20.00 |
      | 500.00    | 15.00 |
      | 20000.00  | 60.00 |

  Scenario: Instant transfer for a premium customer
    When a premium customer asks for the fee of an instant transfer of MDL 2000.00
    Then the response status is 200
    And the fee is MDL 10.00

  Scenario Outline: Instant transfer above the limit is rejected
    When a <segment> customer asks for the fee of an instant transfer of <currency> <amount>
    Then the response status is 422
    And the error is "limit exceeded"

    Examples:
      | segment | currency | amount     |
      | retail  | MDL      | 100000.01  |
      | premium | MDL      | 150000.00  |
      | retail  | EUR      | 5100.00    |

  Scenario: Instant EUR transfer for a retail customer
    When a retail customer asks for the fee of an instant transfer of EUR 500.00
    Then the response status is 200
    And the fee is MDL 59.69

  Scenario: Instant transfer at night
    Instant transfers at night cost MDL 5.00 more.

    Given it is night
    When a retail customer asks for the fee of an instant transfer of MDL 2000.00
    Then the response status is 200
    And the fee is MDL 25.00
