-- ============================================================================
-- LUMÉ Store Database Schema - Migration 04: Seed Data
-- Description: Initial categories and starter products reflecting LUMÉ brand identity.
-- ============================================================================

-- 1. Insert Initial Categories
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

-- 2. Insert Starter Products with LUMÉ Color Palette
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
