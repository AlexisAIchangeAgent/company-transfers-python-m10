Training material. Invented data.

# privacy-agent: material added for M10 (IT advanced)

M10 starts from the agent you built in cycle 6 of M5 (`agent.py`, `SCOPE.md`). This folder adds:

| file | cycle | what it is |
|---|---|---|
| `use-cases.md` | 0 | eight use cases of Company Bank, to classify by architecture |
| `faults.py`, `faults/policy-v1.1.md` | 3 | a fault switch: set `PRIVACY_AGENT_FAULT` to provoke one failure at a time |
| `eval/requests/` | 4 | 22 new synthetic requests (REQ-101 to REQ-123, no REQ-121) |
| `eval/cases.jsonl` | 4 | the evaluation set: 33 cases, five categories. The `expected` fields are empty: you fill them in before the first run |
| `knowledge/` | 5, 6 | six approved documents of the DPO, with `index.json` (audience of each document) |
| `eval/retrieval-queries.jsonl` | 6 | 12 search queries, with the caller role and the relevant documents |
| `requirements-m10.txt` | 5, 6 | the packages added by M10: `mcp`, `rank-bm25` (installed before the training) |

Synthetic only. No real customer data, ever.

The five categories of `eval/cases.jsonl`: normal, boundary, incomplete-input, tool-failure (with a
fault of `faults.py`), misleading-content. A case reads its request in `requests/` (REQ-001 to
REQ-008, from M5) or in `eval/requests/`.
