-- ============================================================================
-- LUMÉ Store Database Schema - Migration 02: Row Level Security (RLS)
-- Description: Enables RLS on all tables, establishes strict granular policies,
--              configures Storage bucket and storage access controls.
-- ============================================================================

-- 1. Enable Row Level Security (RLS) on all tables
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.products ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.reservations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.reservation_items ENABLE ROW LEVEL SECURITY;

-- ----------------------------------------------------------------------------
-- POLICIES: PROFILES
-- ----------------------------------------------------------------------------

-- Customers can view their own profile; Admins can view all profiles
DROP POLICY IF EXISTS "profiles_select_policy" ON public.profiles;
CREATE POLICY "profiles_select_policy" ON public.profiles
  FOR SELECT
  USING (
    auth.uid() = id OR public.is_admin()
  );

-- Users can update their own profile info (e.g., name, phone), but CANNOT change role unless they are admin
DROP POLICY IF EXISTS "profiles_update_policy" ON public.profiles;
CREATE POLICY "profiles_update_policy" ON public.profiles
  FOR UPDATE
  USING (
    auth.uid() = id OR public.is_admin()
  )
  WITH CHECK (
    -- If regular user, role must remain unchanged
    (auth.uid() = id AND role = (SELECT p.role FROM public.profiles p WHERE p.id = auth.uid()))
    OR public.is_admin()
  );

-- User profile creation is typically handled via on_auth_user_created trigger,
-- but allow authenticated users to insert their own profile row if needed.
DROP POLICY IF EXISTS "profiles_insert_policy" ON public.profiles;
CREATE POLICY "profiles_insert_policy" ON public.profiles
  FOR INSERT
  WITH CHECK (
    auth.uid() = id OR public.is_admin()
  );

-- ----------------------------------------------------------------------------
-- POLICIES: CATEGORIES
-- ----------------------------------------------------------------------------

-- Anyone (public or authenticated) can view active categories; Admins can view all
DROP POLICY IF EXISTS "categories_select_policy" ON public.categories;
CREATE POLICY "categories_select_policy" ON public.categories
  FOR SELECT
  USING (
    is_active = true OR public.is_admin()
  );

-- Only admins can insert, update, or delete categories
DROP POLICY IF EXISTS "categories_admin_all_policy" ON public.categories;
CREATE POLICY "categories_admin_all_policy" ON public.categories
  FOR ALL
  USING (public.is_admin())
  WITH CHECK (public.is_admin());

-- ----------------------------------------------------------------------------
-- POLICIES: PRODUCTS
-- ----------------------------------------------------------------------------

-- Anyone (public or authenticated) can view active products; Admins can view all
DROP POLICY IF EXISTS "products_select_policy" ON public.products;
CREATE POLICY "products_select_policy" ON public.products
  FOR SELECT
  USING (
    is_active = true OR public.is_admin()
  );

-- Only admins can insert, update, or delete products directly.
-- Customers CANNOT modify stock or product details directly.
DROP POLICY IF EXISTS "products_admin_all_policy" ON public.products;
CREATE POLICY "products_admin_all_policy" ON public.products
  FOR ALL
  USING (public.is_admin())
  WITH CHECK (public.is_admin());

-- ----------------------------------------------------------------------------
-- POLICIES: RESERVATIONS
-- ----------------------------------------------------------------------------

-- Customers can view only their own reservations; Admins can view all reservations
DROP POLICY IF EXISTS "reservations_select_policy" ON public.reservations;
CREATE POLICY "reservations_select_policy" ON public.reservations
  FOR SELECT
  USING (
    auth.uid() = user_id OR public.is_admin()
  );

-- Direct client updates to reservations are restricted:
-- State transitions (confirm, reject, cancel, expire) are strictly driven by
-- atomic PostgreSQL functions. However, admins retain full update privileges.
DROP POLICY IF EXISTS "reservations_admin_update_policy" ON public.reservations;
CREATE POLICY "reservations_admin_update_policy" ON public.reservations
  FOR UPDATE
  USING (public.is_admin())
  WITH CHECK (public.is_admin());

-- ----------------------------------------------------------------------------
-- POLICIES: RESERVATION_ITEMS
-- ----------------------------------------------------------------------------

-- Customers can view items belonging to their own reservations; Admins view all
DROP POLICY IF EXISTS "reservation_items_select_policy" ON public.reservation_items;
CREATE POLICY "reservation_items_select_policy" ON public.reservation_items
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.reservations r
      WHERE r.id = reservation_items.reservation_id
        AND (r.user_id = auth.uid() OR public.is_admin())
    )
  );

-- Direct client updates/deletes are disallowed for reservation_items.
-- Only admins have direct modification rights.
DROP POLICY IF EXISTS "reservation_items_admin_all_policy" ON public.reservation_items;
CREATE POLICY "reservation_items_admin_all_policy" ON public.reservation_items
  FOR ALL
  USING (public.is_admin())
  WITH CHECK (public.is_admin());

-- ----------------------------------------------------------------------------
-- SUPABASE STORAGE BUCKET & POLICIES: product-images
-- ----------------------------------------------------------------------------
INSERT INTO storage.buckets (id, name, public)
VALUES ('product-images', 'product-images', true)
ON CONFLICT (id) DO UPDATE SET public = true;

-- Anyone can view product images
DROP POLICY IF EXISTS "product_images_public_read" ON storage.objects;
CREATE POLICY "product_images_public_read" ON storage.objects
  FOR SELECT
  USING (bucket_id = 'product-images');

-- Only admins can upload product images
DROP POLICY IF EXISTS "product_images_admin_insert" ON storage.objects;
CREATE POLICY "product_images_admin_insert" ON storage.objects
  FOR INSERT
  WITH CHECK (
    bucket_id = 'product-images'
    AND public.is_admin()
  );

-- Only admins can update product images
DROP POLICY IF EXISTS "product_images_admin_update" ON storage.objects;
CREATE POLICY "product_images_admin_update" ON storage.objects
  FOR UPDATE
  USING (
    bucket_id = 'product-images'
    AND public.is_admin()
  );

-- Only admins can delete product images
DROP POLICY IF EXISTS "product_images_admin_delete" ON storage.objects;
CREATE POLICY "product_images_admin_delete" ON storage.objects
  FOR DELETE
  USING (
    bucket_id = 'product-images'
    AND public.is_admin()
  );
