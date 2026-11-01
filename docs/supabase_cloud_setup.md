# دليل إعداد Supabase Cloud وربطه بتطبيق LUMÉ Store

يشرح هذا الدليل الخطوات العملية واليدوية لإنشاء مشروع Supabase سحابي وربطه بتطبيق Flutter.

---

## الخطوة 1: إنشاء مشروع جديد على Supabase Cloud

1. اذهب إلى [supabase.com](https://supabase.com) وسجّل الدخول بحسابك.
2. انقر على **New project** (مشروع جديد).
3. أدخل البيانات التالية:
   - **Name**: `lume-store` (أو أي اسم تفضله).
   - **Database Password**: احفظ كلمة مرور قوية لقاعدة البيانات.
   - **Region**: اختر أقرب منطقة لعملائك (مثلاً: `Frankfurt` أو `Bahrain`).
   - **Pricing Plan**: الخطة المجانية (Free tier).
4. انقر على **Create new project** وانتظر دقيقة أو دقيقتين حتى تكتمل تهيئة الخادم.

---

## الخطوة 2: تطبيق جداول وقواعد البيانات (SQL Migrations)

وفرنا لك ملفاً مجمعاً يحتوي على كافة الجداول، العلاقات، الفهارس، سياسات الأمان RLS، ودوال الحجز والمخزون:

1. من القائمة الجانبية في لوحة تحكم Supabase، انقر على **SQL Editor**.
2. انقر على زر **New query** (استعلام جديد).
3. افتح الملف التالي من مشروعك:
   [`supabase/migrations/all_in_one_setup.sql`](file:///c:/Users/User/Desktop/sharpat/supabase/migrations/all_in_one_setup.sql)
4. انسخ كامل محتويات الملف والصقها في محرر SQL على Supabase.
5. اضغط على زر **Run** (أو `Ctrl + Enter`).
6. ستظهر لك رسالة نجاح `Success. No rows returned` تؤكد إنشاء الجداول الخمسة:
   - `profiles`
   - `categories`
   - `products`
   - `reservations`
   - `reservation_items`
   إضافةً لسياسات الأمان ودوال الحجز وإدراج البيانات الأولية للأقسام والمنتجات.

---

## الخطوة 3: التحقق من مجلد الصور (Storage Bucket)

الملف البرمجي قام بإنشاء وعاء التخزين `product-images` وسياسات الأمان الخاصة به تلقائياً. للتحقق:
1. انقر على **Storage** من القائمة الجانبية.
2. تأكد من ظهور مجلد باسم `product-images` ومحدد كـ **Public**.

---

## الخطوة 4: إنشاء أول حساب مدير (Admin Account)

لإنشاء حساب مدير متجر لومي والتحكم في لوحة الإدارة:
1. انتقل إلى **Authentication** -> **Users** في Supabase.
2. انقر على **Add user** -> **Create user**.
3. أدخل بريدك الإلكتروني وكلمة المرور (مثال: `admin@lume.com`).
4. بعد إنشاء المستخدم، انتقل إلى **SQL Editor** ونفّذ الأمر التالي لترقية الحساب إلى مدير:
   ```sql
   SELECT public.set_user_admin_by_email('admin@lume.com');
   ```
5. سيعود الأمر بنتيجة:
   `تم تعيين المستخدم (admin@lume.com) كمدير بنجاح.`

---

## الخطوة 5: نسخ مفاتيح المشروع (API Credentials)

1. من القائمة الجانبية انقر على **Project Settings** (أيقونة الترس ⚙️).
2. انقر على **API**.
3. ستجد قسمين أساسيين:
   - **Project URL**: يبدأ بـ `https://xxxxxxxxxxxxxxxx.supabase.co`
   - **Project API keys**: انسخ مفتاح **`anon` (public)**.
   > ⚠️ **تنبيه أمني هام**: لا تشارك ولا تضع مفتاح `service_role (secret)` في كود Flutter مطلقاً!

---

## الخطوة 6: ربط المفاتيح بتطبيق Flutter

هناك طريقتان لربط المفاتيح:

### الطريقة الأولى: التعديل المباشر في ملف الإعدادات (الأسهل للتطوير)
افتح الملف:
[`lib/core/config/supabase_config.dart`](file:///c:/Users/User/Desktop/sharpat/lib/core/config/supabase_config.dart)

وقم باستبدال القيم المؤقتة بمفاتيح مشروعك:
```dart
static const String supabaseUrl = 'https://YOUR_ACTUAL_PROJECT_REF.supabase.co';
static const String supabaseAnonKey = 'YOUR_ACTUAL_ANON_KEY';
```

### الطريقة الثانية: التمرير عبر بيئة التشغيل (`--dart-define`)
دون الحاجة لتعديل الملف، يمكنك تشغيل المشروع مباشرة وتمرير المفاتيح:
```bash
flutter run -d chrome --dart-define=SUPABASE_URL=https://xyz.supabase.co --dart-define=SUPABASE_ANON_KEY=eyJhbG...
```

---

## الخطوة 7: تشغيل التطبيق واختباره

بعد ضبط المفاتيح، شغّل التطبيق:
```bash
flutter run -d chrome
```
ستلاحظ أن بطاقة حالة الباك إند في الشاشة الرئيسية أصبحت تظهر:
`حالة الباك إند: متصل بـ Supabase (أخضر)`
وهذا يؤكد نجاح الاتصال وجاهزية التطبيق للانتقال إلى المرحلة التالية.
