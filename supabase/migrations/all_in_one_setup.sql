-- ============================================================================
-- LUMÉ Store (متجر لومي) - All-In-One Database & Backend Setup Script
-- Supabase PostgreSQL Setup
-- Run this complete script in Supabase Dashboard -> SQL Editor -> New query
-- ============================================================================

-- ============================================================================
-- PART 1: EXTENSIONS & SCHEMAS
-- ============================================================================
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

CREATE OR REPLACE FUNCTION public.update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = timezone('utc'::text, now());
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- ----------------------------------------------------------------------------
-- TABLE 1: PROFILES
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  email TEXT,
  full_name TEXT,
  phone TEXT,
  role TEXT NOT NULL DEFAULT 'customer' CHECK (role IN ('customer', 'admin')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

DROP TRIGGER IF EXISTS update_profiles_updated_at ON public.profiles;
CREATE TRIGGER update_profiles_updated_at
  BEFORE UPDATE ON public.profiles
  FOR EACH ROW
  EXECUTE FUNCTION public.update_updated_at_column();

-- Secure helper function to check admin status
CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.profiles
    WHERE id = auth.uid() AND role = 'admin'
  );
$$;

-- Trigger to create a profile automatically when a user signs up via Supabase Auth
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.profiles (id, email, full_name, phone, role)
  VALUES (
    NEW.id,
    NEW.email,
    COALESCE(NEW.raw_user_meta_data->>'full_name', ''),
    COALESCE(NEW.raw_user_meta_data->>'phone', ''),
    COALESCE(NEW.raw_user_meta_data->>'role', 'customer')
  )
  ON CONFLICT (id) DO UPDATE
  SET email = EXCLUDED.email,
      full_name = CASE WHEN EXCLUDED.full_name <> '' THEN EXCLUDED.full_name ELSE profiles.full_name END;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_new_user();

-- ----------------------------------------------------------------------------
-- TABLE 2: CATEGORIES
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.categories (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name_ar TEXT NOT NULL,
  name_en TEXT,
  slug TEXT UNIQUE NOT NULL,
  description TEXT,
  image_url TEXT,
  is_active BOOLEAN NOT NULL DEFAULT true,
  sort_order INT NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

DROP TRIGGER IF EXISTS update_categories_updated_at ON public.categories;
CREATE TRIGGER update_categories_updated_at
  BEFORE UPDATE ON public.categories
  FOR EACH ROW
  EXECUTE FUNCTION public.update_updated_at_column();

-- ----------------------------------------------------------------------------
-- TABLE 3: PRODUCTS
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.products (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  category_id UUID REFERENCES public.categories(id) ON DELETE SET NULL,
  name_ar TEXT NOT NULL,
  name_en TEXT,
  slug TEXT UNIQUE NOT NULL,
  description_ar TEXT,
  description_en TEXT,
  price NUMERIC(10, 2) NOT NULL CHECK (price >= 0),
  compare_at_price NUMERIC(10, 2) CHECK (compare_at_price IS NULL OR compare_at_price > price),
  stock_quantity INT NOT NULL DEFAULT 0 CHECK (stock_quantity >= 0),
  images TEXT[] NOT NULL DEFAULT '{}',
  colors JSONB NOT NULL DEFAULT '[]',
  is_featured BOOLEAN NOT NULL DEFAULT false,
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

CREATE INDEX IF NOT EXISTS idx_products_category_id ON public.products(category_id);
CREATE INDEX IF NOT EXISTS idx_products_is_active ON public.products(is_active);
CREATE INDEX IF NOT EXISTS idx_products_is_featured ON public.products(is_featured);
CREATE INDEX IF NOT EXISTS idx_products_slug ON public.products(slug);

DROP TRIGGER IF EXISTS update_products_updated_at ON public.products;
CREATE TRIGGER update_products_updated_at
  BEFORE UPDATE ON public.products
  FOR EACH ROW
  EXECUTE FUNCTION public.update_updated_at_column();

-- ----------------------------------------------------------------------------
-- TABLE 4: RESERVATIONS
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.reservations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  reservation_number TEXT UNIQUE NOT NULL,
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE RESTRICT,
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'confirmed', 'rejected', 'expired', 'cancelled')),
  total_amount NUMERIC(10, 2) NOT NULL CHECK (total_amount >= 0),
  customer_notes TEXT,
  admin_notes TEXT,
  expires_at TIMESTAMPTZ NOT NULL,
  confirmed_at TIMESTAMPTZ,
  cancelled_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

CREATE INDEX IF NOT EXISTS idx_reservations_user_id ON public.reservations(user_id);
CREATE INDEX IF NOT EXISTS idx_reservations_status ON public.reservations(status);
CREATE INDEX IF NOT EXISTS idx_reservations_expires_at ON public.reservations(expires_at);
CREATE INDEX IF NOT EXISTS idx_reservations_created_at ON public.reservations(created_at DESC);

DROP TRIGGER IF EXISTS update_reservations_updated_at ON public.reservations;
CREATE TRIGGER update_reservations_updated_at
  BEFORE UPDATE ON public.reservations
  FOR EACH ROW
  EXECUTE FUNCTION public.update_updated_at_column();

-- ----------------------------------------------------------------------------
-- TABLE 5: RESERVATION_ITEMS
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.reservation_items (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  reservation_id UUID NOT NULL REFERENCES public.reservations(id) ON DELETE CASCADE,
  product_id UUID NOT NULL REFERENCES public.products(id) ON DELETE RESTRICT,
  quantity INT NOT NULL CHECK (quantity > 0),
  unit_price NUMERIC(10, 2) NOT NULL CHECK (unit_price >= 0),
  total_price NUMERIC(10, 2) NOT NULL CHECK (total_price >= 0),
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

CREATE INDEX IF NOT EXISTS idx_reservation_items_reservation_id ON public.reservation_items(reservation_id);
CREATE INDEX IF NOT EXISTS idx_reservation_items_product_id ON public.reservation_items(product_id);

-- ============================================================================
-- PART 2: ROW LEVEL SECURITY (RLS) POLICIES
-- ============================================================================
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.products ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.reservations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.reservation_items ENABLE ROW LEVEL SECURITY;

-- Profiles Policies
DROP POLICY IF EXISTS "profiles_select_policy" ON public.profiles;
CREATE POLICY "profiles_select_policy" ON public.profiles
  FOR SELECT USING (auth.uid() = id OR public.is_admin());

DROP POLICY IF EXISTS "profiles_update_policy" ON public.profiles;
CREATE POLICY "profiles_update_policy" ON public.profiles
  FOR UPDATE
  USING (auth.uid() = id OR public.is_admin())
  WITH CHECK (
    (auth.uid() = id AND role = (SELECT p.role FROM public.profiles p WHERE p.id = auth.uid()))
    OR public.is_admin()
  );

DROP POLICY IF EXISTS "profiles_insert_policy" ON public.profiles;
CREATE POLICY "profiles_insert_policy" ON public.profiles
  FOR INSERT WITH CHECK (auth.uid() = id OR public.is_admin());

-- Categories Policies
DROP POLICY IF EXISTS "categories_select_policy" ON public.categories;
CREATE POLICY "categories_select_policy" ON public.categories
  FOR SELECT USING (is_active = true OR public.is_admin());

DROP POLICY IF EXISTS "categories_admin_all_policy" ON public.categories;
CREATE POLICY "categories_admin_all_policy" ON public.categories
  FOR ALL USING (public.is_admin()) WITH CHECK (public.is_admin());

-- Products Policies
DROP POLICY IF EXISTS "products_select_policy" ON public.products;
CREATE POLICY "products_select_policy" ON public.products
  FOR SELECT USING (is_active = true OR public.is_admin());

DROP POLICY IF EXISTS "products_admin_all_policy" ON public.products;
CREATE POLICY "products_admin_all_policy" ON public.products
  FOR ALL USING (public.is_admin()) WITH CHECK (public.is_admin());

-- Reservations Policies
DROP POLICY IF EXISTS "reservations_select_policy" ON public.reservations;
CREATE POLICY "reservations_select_policy" ON public.reservations
  FOR SELECT USING (auth.uid() = user_id OR public.is_admin());

DROP POLICY IF EXISTS "reservations_admin_update_policy" ON public.reservations;
CREATE POLICY "reservations_admin_update_policy" ON public.reservations
  FOR UPDATE USING (public.is_admin()) WITH CHECK (public.is_admin());

-- Reservation Items Policies
DROP POLICY IF EXISTS "reservation_items_select_policy" ON public.reservation_items;
CREATE POLICY "reservation_items_select_policy" ON public.reservation_items
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM public.reservations r
      WHERE r.id = reservation_items.reservation_id
        AND (r.user_id = auth.uid() OR public.is_admin())
    )
  );

DROP POLICY IF EXISTS "reservation_items_admin_all_policy" ON public.reservation_items;
CREATE POLICY "reservation_items_admin_all_policy" ON public.reservation_items
  FOR ALL USING (public.is_admin()) WITH CHECK (public.is_admin());

-- Storage Bucket: product-images
INSERT INTO storage.buckets (id, name, public)
VALUES ('product-images', 'product-images', true)
ON CONFLICT (id) DO UPDATE SET public = true;

DROP POLICY IF EXISTS "product_images_public_read" ON storage.objects;
CREATE POLICY "product_images_public_read" ON storage.objects
  FOR SELECT USING (bucket_id = 'product-images');

DROP POLICY IF EXISTS "product_images_admin_insert" ON storage.objects;
CREATE POLICY "product_images_admin_insert" ON storage.objects
  FOR INSERT WITH CHECK (bucket_id = 'product-images' AND public.is_admin());

DROP POLICY IF EXISTS "product_images_admin_update" ON storage.objects;
CREATE POLICY "product_images_admin_update" ON storage.objects
  FOR UPDATE USING (bucket_id = 'product-images' AND public.is_admin());

DROP POLICY IF EXISTS "product_images_admin_delete" ON storage.objects;
CREATE POLICY "product_images_admin_delete" ON storage.objects
  FOR DELETE USING (bucket_id = 'product-images' AND public.is_admin());

-- ============================================================================
-- PART 3: ATOMIC INVENTORY & RESERVATION FUNCTIONS
-- ============================================================================

-- Helper: Reservation Number Generator
CREATE OR REPLACE FUNCTION public.generate_reservation_number()
RETURNS TEXT AS $$
DECLARE
  v_date TEXT := to_char(now(), 'YYYYMMDD');
  v_random TEXT := upper(substr(md5(random()::text), 1, 4));
BEGIN
  RETURN 'LUME-' || v_date || '-' || v_random;
END;
$$ LANGUAGE plpgsql VOLATILE;

-- 1. Create Temporary Reservation (RPC)
CREATE OR REPLACE FUNCTION public.create_temporary_reservation(
  p_items JSONB,
  p_customer_notes TEXT DEFAULT NULL,
  p_duration_minutes INT DEFAULT 60
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
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'المستخدم غير مسجل دخول. يرجى تسجيل الدخول أولاً.';
  END IF;

  IF p_items IS NULL OR jsonb_array_length(p_items) = 0 THEN
    RAISE EXCEPTION 'سلة الحجز فارغة. يرجى إضافة منتجات.';
  END IF;

  v_reservation_number := public.generate_reservation_number();
  v_expires_at := timezone('utc'::text, now()) + (p_duration_minutes || ' minutes')::interval;

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

  FOR v_item IN SELECT * FROM jsonb_array_elements(p_items)
  LOOP
    v_product_id := (v_item->>'product_id')::UUID;
    v_requested_qty := (v_item->>'quantity')::INT;

    IF v_requested_qty <= 0 THEN
      RAISE EXCEPTION 'الكمية المطلوبة يجب أن تكون أكبر من صفر.';
    END IF;

    -- Row-level lock FOR UPDATE
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

    -- Deduct reserved quantity immediately
    UPDATE public.products
    SET stock_quantity = stock_quantity - v_requested_qty
    WHERE id = v_product_id;

    v_item_total := v_product.price * v_requested_qty;
    v_total_amount := v_total_amount + v_item_total;

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

  UPDATE public.reservations
  SET total_amount = v_total_amount
  WHERE id = v_reservation_id;

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

-- 2. Approve Reservation (Admin RPC)
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
  IF NOT public.is_admin() THEN
    RAISE EXCEPTION 'غير مصرح لك بتأكيد الحجوزات. يلزم صلاحية مدير.';
  END IF;

  SELECT * INTO v_res
  FROM public.reservations
  WHERE id = p_reservation_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'الحجز غير موجود: %', p_reservation_id;
  END IF;

  IF v_res.status <> 'pending' THEN
    RAISE EXCEPTION 'لا يمكن تأكيد هذا الحجز لأن حالته الحالية: (%)', v_res.status;
  END IF;

  IF v_res.expires_at < timezone('utc'::text, now()) THEN
    RAISE EXCEPTION 'انتهت صلاحية وقت هذا الحجز ولا يمكن تأكيده.';
  END IF;

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

-- 3. Reject Reservation (Admin RPC)
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
  IF NOT public.is_admin() THEN
    RAISE EXCEPTION 'غير مصرح لك برفض الحجوزات. يلزم صلاحية مدير.';
  END IF;

  SELECT * INTO v_res
  FROM public.reservations
  WHERE id = p_reservation_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'الحجز غير موجود: %', p_reservation_id;
  END IF;

  IF v_res.status <> 'pending' THEN
    RAISE EXCEPTION 'لا يمكن رفض الحجز لأن حالته الحالية: (%)', v_res.status;
  END IF;

  UPDATE public.reservations
  SET status = 'rejected',
      admin_notes = COALESCE(p_admin_notes, admin_notes)
  WHERE id = p_reservation_id;

  -- Restore stock quantity exactly once
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
    'status', 'rejected',
    'restored', true
  );
END;
$$;

-- 4. Cancel Reservation (Customer or Admin RPC)
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

  SELECT * INTO v_res
  FROM public.reservations
  WHERE id = p_reservation_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'الحجز غير موجود.';
  END IF;

  IF v_res.user_id <> v_user_id AND NOT public.is_admin() THEN
    RAISE EXCEPTION 'لا تملك صلاحية إلغاء هذا الحجز.';
  END IF;

  IF v_res.status <> 'pending' THEN
    RAISE EXCEPTION 'لا يمكن إلغاء الحجز لأن حالته الحالية: (%)', v_res.status;
  END IF;

  UPDATE public.reservations
  SET status = 'cancelled',
      cancelled_at = timezone('utc'::text, now())
  WHERE id = p_reservation_id;

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

-- 5. Release Expired Reservations (Automated Maintenance RPC)
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
  FOR v_res IN
    SELECT id
    FROM public.reservations
    WHERE status = 'pending'
      AND expires_at <= timezone('utc'::text, now())
    FOR UPDATE SKIP LOCKED
  LOOP
    UPDATE public.reservations
    SET status = 'expired'
    WHERE id = v_res.id;

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

-- 6. Setup Helper: Assign Admin by Email
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

-- ============================================================================
-- PART 4: SEED DATA
-- ============================================================================
INSERT INTO public.categories (id, name_ar, name_en, slug, description, is_active, sort_order)
VALUES
  (
    'a1b2c3d4-0001-4000-8000-000000000001',
    'أوشحة حريرية فاخرة',
    'Silk Scarves',
    'silk-scarves',
    'أوشحة مصنوعة من أجود خيوط الحرير الطبيعي بلمسات راقية وتصاميم انسيابية.',
    true,
    1
  ),
  (
    'a1b2c3d4-0002-4000-8000-000000000002',
    'شالات كشمير وصوف',
    'Cashmere & Wool',
    'cashmere-wool',
    'شالات شتوية دافئة وناعمة من صوف الكشمير الفاخر تمنحك إطلالة أنيقة ودافئة.',
    true,
    2
  ),
  (
    'a1b2c3d4-0003-4000-8000-000000000003',
    'شالات قطنية يومية',
    'Cotton Shawls',
    'cotton-shawls',
    'شالات قطنية مريحة وخفيفة للاستخدام اليومي والعمل، ثابتة ومريحة طوال اليوم.',
    true,
    3
  ),
  (
    'a1b2c3d4-0004-4000-8000-000000000004',
    'أوشحة شيفون ومناسبات',
    'Chiffon & Occasions',
    'chiffon-occasions',
    'أوشحة شيفون خفيفة مطرزة ومزينة لتليق بأفخم المناسبات والسهرات.',
    true,
    4
  )
ON CONFLICT (slug) DO NOTHING;

INSERT INTO public.products (
  category_id,
  name_ar,
  name_en,
  slug,
  description_ar,
  price,
  compare_at_price,
  stock_quantity,
  colors,
  is_featured,
  is_active
)
VALUES
  (
    'a1b2c3d4-0001-4000-8000-000000000001',
    'وشاح لومي الحريري - عنابي عميق',
    'LUMÉ Royal Silk Scarf - Deep Burgundy',
    'lume-royal-silk-deep-burgundy',
    'وشاح حرير نقي 100% بنقشات هندسية رقيقة ولمعان هادئ، مستوحى من فخامة اللون العنابي الكلاسيكي.',
    145.00,
    180.00,
    15,
    '[{"name": "عنابي عميق", "hex": "#702F40"}]'::jsonb,
    true,
    true
  ),
  (
    'a1b2c3d4-0001-4000-8000-000000000001',
    'وشاح الحرير العاجي - تدرجات البيج',
    'Ivory Silk Scarf - Warm Beige',
    'ivory-silk-warm-beige',
    'وشاح حريري بلون العاج الدافئ مع حواف شامبين راقية تناسب مختلف الإطلالات الأنيقة.',
    135.00,
    NULL,
    12,
    '[{"name": "عاجي دافئ", "hex": "#F8F3ED"}, {"name": "بيج شامبين", "hex": "#C7AE91"}]'::jsonb,
    true,
    true
  ),
  (
    'a1b2c3d4-0002-4000-8000-000000000002',
    'شال كشمير ناعم - وردي غباري',
    'Soft Cashmere Shawl - Dusty Pink',
    'soft-cashmere-dusty-pink',
    'شال كشمير خفيف الوزن وفائق النعومة باللون الوردي الغباري المميز لعلامة لومي.',
    210.00,
    250.00,
    8,
    '[{"name": "وردي غباري", "hex": "#DDBFC1"}]'::jsonb,
    true,
    true
  ),
  (
    'a1b2c3d4-0002-4000-8000-000000000002',
    'شال كشمير شتوي - زيتي كلاسيكي',
    'Winter Cashmere - Classic Olive',
    'winter-cashmere-classic-olive',
    'شال كشمير منسوج بإتقان بلون زيتي هادئ يوفر دفئاً استثنائياً ولمسة فخمة.',
    225.00,
    NULL,
    10,
    '[{"name": "أخضر زيتي", "hex": "#777F69"}]'::jsonb,
    false,
    true
  ),
  (
    'a1b2c3d4-0003-4000-8000-000000000003',
    'شال قطن بريميوم - بني داكن',
    'Premium Cotton Shawl - Dark Brown',
    'premium-cotton-dark-brown',
    'شال قطن عملي ومريح جداً، غير قابل للانزلاق، بلون بني دافئ جذاب.',
    75.00,
    90.00,
    25,
    '[{"name": "بني داكن", "hex": "#39312F"}]'::jsonb,
    false,
    true
  ),
  (
    'a1b2c3d4-0004-4000-8000-000000000004',
    'وشاح شيفون مطرز - لمسات ذهبية شامبين',
    'Embroidered Chiffon - Champagne Accents',
    'embroidered-chiffon-champagne',
    'وشاح شيفون فاخر للمناسبات والأفراح مع تطريز يدوي دقيق على الأطراف بلون الشامبين.',
    160.00,
    195.00,
    6,
    '[{"name": "شامبين", "hex": "#C7AE91"}]'::jsonb,
    true,
    true
  )
ON CONFLICT (slug) DO NOTHING;
