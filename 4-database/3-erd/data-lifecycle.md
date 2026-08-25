# Data lifecycle

`openapi.yaml` is the frozen API contract. This file only consolidates existing decisions.

## Deletion

| Entity | Policy |
|---|---|
| User | Deactivate; never hard-delete |
| Product / SKU | Retire (soft delete) |
| Product image | Hard delete |
| Like / cart item | Hard delete |
| Order / order item | Never delete; cancellation is terminal |
| Promo code | Disable |
| Redemption | Void |

No FK uses `SET NULL`; history references use `RESTRICT` where applicable.
Users are not deleted. Future deletion support will anonymize their data.

## Stock

Stock is stored as the current quantity only.

## Cart unavailable states

| Case | Reason | Behavior |
|---|---|---|
| Stock is 0 | `OUT_OF_STOCK` | Keep and flag |
| Stock is below requested quantity | `INSUFFICIENT_STOCK` | Keep and flag |
| SKU disabled | `SKU_INACTIVE` | Keep and flag |
| SKU retired | `SKU_RETIRED` | Keep and flag |
| Product disabled | `PRODUCT_INACTIVE` | Keep and flag |
| Product retired | `PRODUCT_RETIRED` | Keep and flag |

Checkout is all-or-nothing. Cart lines are not silently removed or reduced.

## Stripe blueprint

Stripe behavior remains tentative pending the workshop.

Current Payment Link assumption: one durable link per SKU; creating the link does not create an order. The webhook creates the paid order. This remains provisional.