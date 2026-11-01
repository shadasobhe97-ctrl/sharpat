import 'package:flutter/material.dart';
import 'core/config/supabase_config.dart';
import 'core/services/supabase_service.dart';
import 'core/theme/app_colors.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Supabase backend service safely
  await SupabaseService.init();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LUMÉ | متجر لومي',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: AppColors.background,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.deepBurgundy,
          primary: AppColors.deepBurgundy,
          surface: AppColors.surface,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.deepBurgundy,
          foregroundColor: Colors.white,
          centerTitle: true,
          elevation: 0,
        ),
      ),
      builder: (context, child) {
        // Enforce Arabic RTL layout across the entire application
        return Directionality(
          textDirection: TextDirection.rtl,
          child: child ?? const SizedBox.shrink(),
        );
      },
      home: const MyHomePage(title: 'LUMÉ Store | متجر لومي للأوشحة والشالات'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _counter = 0;

  void _incrementCounter() {
    setState(() {
      _counter++;
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool isConfigured = SupabaseConfig.isConfigured;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Brand Header Banner
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                decoration: BoxDecoration(
                  color: AppColors.dustyPink.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.champagneBeige),
                ),
                child: Column(
                  children: [
                    const Text(
                      'LUMÉ | لـومـي',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: AppColors.deepBurgundy,
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'المتجر الإلكتروني الفاخر للأوشحة والشالات النسائية',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.darkBrown,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Backend Status Card
              Card(
                elevation: 1,
                color: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: AppColors.border),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isConfigured ? Icons.check_circle : Icons.info_outline,
                        color: isConfigured ? Colors.green : AppColors.champagneBeige,
                        size: 28,
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isConfigured
                                ? 'حالة الباك إند: متصل بـ Supabase'
                                : 'حالة الباك إند: بانتظار إضافة مفاتيح المشروع',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: isConfigured ? Colors.green.shade800 : AppColors.darkBrown,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            isConfigured
                                ? 'جاهز لمعالجة المنتجات والحجوزات الفورية'
                                : 'راجع دليل: docs/supabase_cloud_setup.md',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // Existing Counter Feature Preserved
              const Text(
                'تم النقر على الزر هذا العدد من المرات:',
                style: TextStyle(fontSize: 15, color: AppColors.darkBrown),
              ),
              const SizedBox(height: 8),
              Text(
                '$_counter',
                style: const TextStyle(
                  fontSize: 42,
                  fontWeight: FontWeight.bold,
                  color: AppColors.deepBurgundy,
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _incrementCounter,
        tooltip: 'زيادة العداد',
        backgroundColor: AppColors.deepBurgundy,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
    );
  }
}
