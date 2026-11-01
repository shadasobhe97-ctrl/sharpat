-- ============================================================================
-- LUMÉ Store Database Schema - Migration 03: Inventory & Reservation Functions
-- Description: Atomic PostgreSQL functions (RPCs) with row-level locks
--              to ensure strictly concurrent-safe stock reservation and restoration.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. Helper Function: Generate Readable Reservation Number
-- Example: LUME-20261101-9F2B
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.generate_reservation_number()
RETURNS TEXT AS $$
DECLARE
  v_date TEXT := to_char(now(), 'YYYYMMDD');
  v_random TEXT := upper(substr(md5(random()::text), 1, 4));
BEGIN
  RETURN 'LUME-' || v_date || '-' || v_random;
END;
$$ LANGUAGE plpgsql VOLATILE;

-- ----------------------------------------------------------------------------
-- 2. CREATE TEMPORARY RESERVATION (Customer Operation)
-- Atomically checks stock, deducts inventory, creates reservation and items.
-- Protected against race conditions using SELECT FOR UPDATE on products.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.create_temporary_reservation(
  p_items JSONB,                          -- Array of objects: [{"product_id": "...", "quantity": 1}]
  p_customer_notes TEXT DEFAULT NULL,
  p_duration_minutes INT DEFAULT 60       -- Default 60 minutes hold time
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id UUID;
  v_reservation_id UUID;
  v_reservation_number TEXT;
  v_total_amount NUMERIC(10, 2) := 0;
  v_expires_at TIMESTAMPTZ;
  v_item JSONB;
  v_product_id UUID;
  v_requested_qty INT;
  v_product RECORD;
  v_item_total NUMERIC(10, 2);
  v_result JSONB;
BEGIN
  -- 1. Authentication check
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'المستخدم غير مسجل دخول. يرجى تسجيل الدخول أولاً.';
  END IF;

  -- 2. Validate items array
  IF p_items IS NULL OR jsonb_array_length(p_items) = 0 THEN
    RAISE EXCEPTION 'سلة الحجز فارغة. يرجى إضافة منتجات.';
  END IF;

  -- 3. Prepare reservation metadata
  v_reservation_number := public.generate_reservation_number();
  v_expires_at := timezone('utc'::text, now()) + (p_duration_minutes || ' minutes')::interval;

  -- 4. Create master reservation record initially with 0 total
  INSERT INTO public.reservations (
    reservation_number,
    user_id,
    status,
    total_amount,
    customer_notes,
    expires_at
  )
  VALUES (
    v_reservation_number,
    v_user_id,
    'pending',
    0,
    p_customer_notes,
    v_expires_at
  )
  RETURNING id INTO v_reservation_id;

  -- 5. Iterate through each item, lock product row, verify availability and deduct stock
  FOR v_item IN SELECT * FROM jsonb_array_elements(p_items)
  LOOP
    v_product_id := (v_item->>'product_id')::UUID;
    v_requested_qty := (v_item->>'quantity')::INT;

    IF v_requested_qty <= 0 THEN
      RAISE EXCEPTION 'الكمية المطلوبة يجب أن تكون أكبر من صفر.';
    END IF;

    -- CRITICAL: Lock product row FOR UPDATE to prevent concurrent overbooking
    SELECT id, name_ar, price, stock_quantity, is_active
    INTO v_product
    FROM public.products
    WHERE id = v_product_id
    FOR UPDATE;

    IF NOT FOUND THEN
      RAISE EXCEPTION 'المنتج المحدد غير موجود: %', v_product_id;
    END IF;

    IF NOT v_product.is_active THEN
      RAISE EXCEPTION 'المنتج غير متاح حالياً: %', v_product.name_ar;
    END IF;

    IF v_product.stock_quantity < v_requested_qty THEN
      RAISE EXCEPTION 'الكمية المطلوبة غير متوفرة في المخزون للمنتج (%). المتاح حالياً: % قطعة.',
        v_product.name_ar, v_product.stock_quantity;
    END IF;

    -- Deduct reserved quantity from available stock immediately
    UPDATE public.products
    SET stock_quantity = stock_quantity - v_requested_qty
    WHERE id = v_product_id;

    -- Calculate item total price
    v_item_total := v_product.price * v_requested_qty;
    v_total_amount := v_total_amount + v_item_total;

    -- Insert into reservation_items
    INSERT INTO public.reservation_items (
      reservation_id,
      product_id,
      quantity,
      unit_price,
      total_price
    )
    VALUES (
      v_reservation_id,
      v_product_id,
      v_requested_qty,
      v_product.price,
      v_item_total
    );
  END LOOP;

  -- 6. Update master reservation with final calculated total
  UPDATE public.reservations
  SET total_amount = v_total_amount
  WHERE id = v_reservation_id;

  -- 7. Build and return result JSON
  SELECT jsonb_build_object(
    'reservation_id', r.id,
    'reservation_number', r.reservation_number,
    'status', r.status,
    'total_amount', r.total_amount,
    'expires_at', r.expires_at,
    'created_at', r.created_at
  )
  INTO v_result
  FROM public.reservations r
  WHERE r.id = v_reservation_id;

  RETURN v_result;
END;
$$;

-- ----------------------------------------------------------------------------
-- 3. APPROVE RESERVATION (Admin Operation)
-- Moves status to 'confirmed'. Reserved stock remains permanently deducted.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.approve_reservation(
  p_reservation_id UUID,
  p_admin_notes TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_res RECORD;
BEGIN
  -- 1. Authorization check: must be admin
  IF NOT public.is_admin() THEN
    RAISE EXCEPTION 'غير مصرح لك بتأكيد الحجوزات. يلزم صلاحية مدير.';
  END IF;

  -- 2. Lock reservation row FOR UPDATE
  SELECT * INTO v_res
  FROM public.reservations
  WHERE id = p_reservation_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'الحجز غير موجود: %', p_reservation_id;
  END IF;

  -- 3. Validate status
  IF v_res.status <> 'pending' THEN
    RAISE EXCEPTION 'لا يمكن تأكيد هذا الحجز لأن حالته الحالية: (%)', v_res.status;
  END IF;

  -- 4. Check if already expired
  IF v_res.expires_at < timezone('utc'::text, now()) THEN
    RAISE EXCEPTION 'انتهت صلاحية وقت هذا الحجز ولا يمكن تأكيده. يجب استرجاع الكمية أولاً.';
  END IF;

  -- 5. Update status to confirmed
  UPDATE public.reservations
  SET status = 'confirmed',
      confirmed_at = timezone('utc'::text, now()),
      admin_notes = COALESCE(p_admin_notes, admin_notes)
  WHERE id = p_reservation_id;

  RETURN jsonb_build_object(
    'success', true,
    'reservation_id', p_reservation_id,
    'status', 'confirmed',
    'confirmed_at', timezone('utc'::text, now())
  );
END;
$$;

-- ----------------------------------------------------------------------------
-- 4. REJECT RESERVATION (Admin Operation)
-- Moves status to 'rejected' and restores reserved stock EXACTLY ONCE.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.reject_reservation(
  p_reservation_id UUID,
  p_admin_notes TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_res RECORD;
  v_item RECORD;
BEGIN
  -- 1. Authorization check: must be admin
  IF NOT public.is_admin() THEN
    RAISE EXCEPTION 'غير مصرح لك برفض الحجوزات. يلزم صلاحية مدير.';
  END IF;

  -- 2. Lock reservation row FOR UPDATE
  SELECT * INTO v_res
  FROM public.reservations
  WHERE id = p_reservation_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'الحجز غير موجود: %', p_reservation_id;
  END IF;

  -- 3. Strict status validation (Only 'pending' can be rejected)
  IF v_res.status <> 'pending' THEN
    RAISE EXCEPTION 'لا يمكن رفض الحجز لأن حالته الحالية: (%)', v_res.status;
  END IF;

  -- 4. Update status to rejected
  UPDATE public.reservations
  SET status = 'rejected',
      admin_notes = COALESCE(p_admin_notes, admin_notes)
  WHERE id = p_reservation_id;

  -- 5. Restore inventory for all reserved items atomically
  FOR v_item IN
    SELECT product_id, quantity
    FROM public.reservation_items
    WHERE reservation_id = p_reservation_id
  LOOP
    -- Lock product row FOR UPDATE and restore quantity
    UPDATE public.products
    SET stock_quantity = stock_quantity + v_item.quantity
    WHERE id = v_item.product_id;
  END LOOP;

  RETURN jsonb_build_object(
    'success', true,
    'reservation_id', p_reservation_id,
    'status', 'rejected',
    'restored', true
  );
END;
$$;

-- ----------------------------------------------------------------------------
-- 5. CANCEL RESERVATION (Customer or Admin Operation)
-- Allows a customer to cancel their own pending reservation and restores stock.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.cancel_reservation(
  p_reservation_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_res RECORD;
  v_item RECORD;
  v_user_id UUID;
BEGIN
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'المستخدم غير مسجل دخول.';
  END IF;

  -- 1. Lock reservation row FOR UPDATE
  SELECT * INTO v_res
  FROM public.reservations
  WHERE id = p_reservation_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'الحجز غير موجود.';
  END IF;

  -- 2. Ownership check: user must own the reservation OR be an admin
  IF v_res.user_id <> v_user_id AND NOT public.is_admin() THEN
    RAISE EXCEPTION 'لا تملك صلاحية إلغاء هذا الحجز.';
  END IF;

  -- 3. Validate status: only 'pending' can be cancelled
  IF v_res.status <> 'pending' THEN
    RAISE EXCEPTION 'لا يمكن إلغاء الحجز لأن حالته الحالية: (%)', v_res.status;
  END IF;

  -- 4. Update status to cancelled
  UPDATE public.reservations
  SET status = 'cancelled',
      cancelled_at = timezone('utc'::text, now())
  WHERE id = p_reservation_id;

  -- 5. Restore stock quantity exactly once
  FOR v_item IN
    SELECT product_id, quantity
    FROM public.reservation_items
    WHERE reservation_id = p_reservation_id
  LOOP
    UPDATE public.products
    SET stock_quantity = stock_quantity + v_item.quantity
    WHERE id = v_item.product_id;
  END LOOP;

  RETURN jsonb_build_object(
    'success', true,
    'reservation_id', p_reservation_id,
    'status', 'cancelled',
    'restored', true
  );
END;
$$;

-- ----------------------------------------------------------------------------
-- 6. RELEASE EXPIRED RESERVATIONS (Automated Maintenance Routine)
-- Finds expired 'pending' reservations, sets status to 'expired', and restores stock.
-- Concurrency-safe: uses FOR UPDATE SKIP LOCKED.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.release_expired_reservations()
RETURNS INT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_expired_count INT := 0;
  v_res RECORD;
  v_item RECORD;
BEGIN
  -- Process expired pending reservations
  FOR v_res IN
    SELECT id
    FROM public.reservations
    WHERE status = 'pending'
      AND expires_at <= timezone('utc'::text, now())
    FOR UPDATE SKIP LOCKED
  LOOP
    -- Mark reservation as expired
    UPDATE public.reservations
    SET status = 'expired'
    WHERE id = v_res.id;

    -- Restore stock for items
    FOR v_item IN
      SELECT product_id, quantity
      FROM public.reservation_items
      WHERE reservation_id = v_res.id
    LOOP
      UPDATE public.products
      SET stock_quantity = stock_quantity + v_item.quantity
      WHERE id = v_item.product_id;
    END LOOP;

    v_expired_count := v_expired_count + 1;
  END LOOP;

  RETURN v_expired_count;
END;
$$;

-- ----------------------------------------------------------------------------
-- 7. SET USER AS ADMIN (Setup Helper)
-- Safely grants the 'admin' role to a registered user by email.
-- Can be called from Supabase SQL Editor during project initialization.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.set_user_admin_by_email(target_email TEXT)
RETURNS TEXT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_updated INT;
BEGIN
  UPDATE public.profiles
  SET role = 'admin'
  WHERE lower(email) = lower(target_email);

  GET DIAGNOSTICS v_updated = ROW_COUNT;
  IF v_updated > 0 THEN
    RETURN 'تم تعيين المستخدم (' || target_email || ') كمدير بنجاح.';
  ELSE
    RETURN 'لم يتم العثور على مستخدم بهذا البريد: ' || target_email;
  END IF;
END;
$$;
