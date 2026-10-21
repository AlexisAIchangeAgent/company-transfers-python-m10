Training material. Invented data.

# Transfer-fee service

Last reviewed: March 2025.

## Purpose

The transfer-fee service computes the fee of a customer transfer before the customer
confirms it. It is called by the mobile app, the web banking and the branch front office.

## Endpoints

| Method | Path | Description |
|---|---|---|
| POST | /fees | computes the fee of a transfer |
| GET | /fees/{id} | returns a fee computed earlier, by its identifier |
| GET | /health | health check |

Example request:

```json
{"amount": 2000.00, "currency": "MDL", "type": "standard", "customer_segment": "retail"}
```

Example response:

```json
{"fee": 10.00, "currency": "MDL", "rule": "standard-mdl"}
```

## Fee rules

- Standard transfer in MDL: 0.5% of the amount, minimum MDL 5.00, maximum MDL 40.00.
- Standard transfer in EUR: the amount is converted to MDL, then the MDL rule applies.
- Fees are rounded to 2 decimals with bankers rounding.

## Dependencies

- Exchange-rate provider (third party), for the EUR to MDL rate. The base URL is set by
  the environment variable RATES_BASE_URL.

## Contacts

Team Payments Core (invented).
