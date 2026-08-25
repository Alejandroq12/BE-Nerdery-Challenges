-- Database CHECK constraints and PostgreSQL partial indexes.

-- ============================================================================
--  1. CHECK CONSTRAINTS
-- ============================================================================

-- ---------------------------------------------------------------- users ----

ALTER TABLE users ADD CONSTRAINT chk_users_email_lower
  CHECK (email = lower(email));

-- ------------------------------------------------------- product_images ----

ALTER TABLE product_images ADD CONSTRAINT chk_images_position
  CHECK (position >= 0);

-- --------------------------------------------------------- product_skus ----

ALTER TABLE product_skus ADD CONSTRAINT chk_skus_price
  CHECK (price > 0);

ALTER TABLE product_skus ADD CONSTRAINT chk_skus_stock
  CHECK (stock_quantity >= 0);

-- ----------------------------------------------------------- cart_items ----

ALTER TABLE cart_items ADD CONSTRAINT chk_cart_quantity
  CHECK (quantity > 0);

-- --------------------------------------------------------------- orders ----

ALTER TABLE orders ADD CONSTRAINT chk_orders_discount
  CHECK (discount_amount >= 0 AND discount_amount <= subtotal_amount);

ALTER TABLE orders ADD CONSTRAINT chk_orders_total
  CHECK (total_amount = subtotal_amount - discount_amount);

ALTER TABLE orders ADD CONSTRAINT chk_orders_promo_pair
  CHECK ((promo_code_id IS NULL) = (promo_code_snapshot IS NULL));

ALTER TABLE orders ADD CONSTRAINT chk_orders_discount_needs_promo
  CHECK (discount_amount = 0 OR promo_code_id IS NOT NULL);

ALTER TABLE orders ADD CONSTRAINT chk_orders_paid_at
  CHECK (status IN ('PENDING', 'CANCELLED') OR paid_at IS NOT NULL);

ALTER TABLE orders ADD CONSTRAINT chk_orders_cancelled_at
  CHECK (status <> 'CANCELLED'
         OR (cancelled_at IS NOT NULL AND cancellation_reason IS NOT NULL));

ALTER TABLE orders ADD CONSTRAINT chk_orders_cancel_fields
  CHECK (cancelled_at IS NOT NULL
         OR (cancellation_reason IS NULL
             AND cancelled_by IS NULL));

ALTER TABLE orders ADD CONSTRAINT chk_orders_superseded_never_paid
  CHECK (cancellation_reason IS DISTINCT FROM 'SUPERSEDED_BY_NEW_CHECKOUT'
         OR (cancelled_by IS NULL AND paid_at IS NULL));

ALTER TABLE orders ADD CONSTRAINT chk_orders_link_never_pending
  CHECK (payment_method <> 'PAYMENT_LINK' OR status <> 'PENDING');

-- BLUEPRINT, pending the Stripe workshop.
ALTER TABLE orders ADD CONSTRAINT chk_orders_stripe_id
  CHECK (
    paid_at IS NULL
    OR (payment_method = 'PAYMENT_LINK'
        AND stripe_checkout_session_id IS NOT NULL
        AND stripe_payment_intent_id IS NULL)
    OR (payment_method = 'PAYMENT_INTENT'
        AND stripe_payment_intent_id IS NOT NULL
        AND stripe_checkout_session_id IS NULL)
  );

-- ---------------------------------------------------------- order_items ----

ALTER TABLE order_items ADD CONSTRAINT chk_order_items_quantity
  CHECK (quantity > 0);

ALTER TABLE order_items ADD CONSTRAINT chk_order_items_price
  CHECK (unit_price >= 0);

ALTER TABLE order_items ADD CONSTRAINT chk_order_items_line
  CHECK (line_total = unit_price * quantity);

-- -------------------------------------------------- order_status_history ---

ALTER TABLE order_status_history ADD CONSTRAINT chk_status_transition
  CHECK (from_status IS DISTINCT FROM to_status);

ALTER TABLE order_status_history ADD CONSTRAINT chk_status_reason_code
  CHECK (reason_code IS NULL OR to_status = 'CANCELLED');

-- ---------------------------------------------------------- promo_codes ----

ALTER TABLE promo_codes ADD CONSTRAINT chk_promo_value
  CHECK (discount_value > 0);

ALTER TABLE promo_codes ADD CONSTRAINT chk_promo_pct_max
  CHECK (discount_type <> 'PERCENTAGE' OR discount_value <= 100);

ALTER TABLE promo_codes ADD CONSTRAINT chk_promo_usage_limit
  CHECK (usage_limit IS NULL OR usage_limit > 0);

ALTER TABLE promo_codes ADD CONSTRAINT chk_promo_min_purchase
  CHECK (min_purchase_amount IS NULL OR min_purchase_amount > 0);

-- ----------------------------------------------- promo_code_redemptions ----

ALTER TABLE promo_code_redemptions ADD CONSTRAINT chk_redemptions_amount
  CHECK (discount_amount >= 0);

-- -------------------------------------------------- stock_notifications ----

ALTER TABLE stock_notifications ADD CONSTRAINT chk_stock_notice_amount
  CHECK (stock_at_send >= 0);

-- ============================================================================
--  2. PARTIAL INDEXES
-- ============================================================================
--  Unique ones first: they are constraints wearing an index costume, and three
--  of the documented behaviours in openapi.yaml are true only because of them.
-- ============================================================================

CREATE UNIQUE INDEX uq_one_primary_image
  ON product_images (product_id) WHERE is_primary;

CREATE UNIQUE INDEX uq_sku_variant
  ON product_skus (product_id, size, color) WHERE deleted_at IS NULL;

CREATE UNIQUE INDEX uq_sku_code
  ON product_skus (sku_code) WHERE deleted_at IS NULL;

CREATE UNIQUE INDEX uq_one_pending_order
  ON orders (client_id) WHERE status = 'PENDING';

-- ------------------------------------------------------ non-unique ---------

CREATE INDEX idx_sessions_live
  ON sessions (user_id, created_at DESC)
  WHERE revoked_at IS NULL;

CREATE INDEX idx_products_live
  ON products (created_at DESC) WHERE deleted_at IS NULL AND is_active;

CREATE INDEX idx_skus_purchasable
  ON product_skus (product_id, price)
  WHERE deleted_at IS NULL AND is_active AND stock_quantity > 0;

CREATE INDEX idx_orders_paid_history
  ON orders (client_id, created_at) WHERE paid_at IS NOT NULL;

CREATE INDEX idx_orders_queue
  ON orders (status, created_at DESC)
  WHERE cancellation_reason IS DISTINCT FROM 'SUPERSEDED_BY_NEW_CHECKOUT';

CREATE INDEX idx_redemptions_live
  ON promo_code_redemptions (promo_code_id) WHERE voided_at IS NULL;