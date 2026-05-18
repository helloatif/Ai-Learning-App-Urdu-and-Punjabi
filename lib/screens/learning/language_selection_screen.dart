import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../themes/app_theme.dart';
import '../../providers/user_provider.dart';
import 'language_level_screen.dart';
import '../../services/language_onboarding_service.dart';

class LanguageSelectionScreen extends StatefulWidget {
  const LanguageSelectionScreen({super.key});

  @override
  State<LanguageSelectionScreen> createState() => _LanguageSelectionScreenState();
}

class _LanguageSelectionScreenState extends State<LanguageSelectionScreen> {
  final List<Map<String, String>> _languages = [
    {'code': 'urdu', 'name': 'Urdu', 'asset': 'assets/icons/urdulogo.png'},
    {'code': 'punjabi', 'name': 'Punjabi (Shahmukhi)', 'asset': 'assets/icons/punjabilogo.jpeg'},
  ];

  Future<void> _selectLanguage(String code) async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    try {
      if (userId != null) {
        await LanguageOnboardingService.saveSelectedLanguage(userId, code);

        // Update provider
        final userProvider = Provider.of<UserProvider>(context, listen: false);
        try {
          await userProvider.setSelectedLanguage(code);
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('Error saving language selection: $e');
    } finally {
      if (!mounted) return;

      if (userId != null) {
        final completed = await LanguageOnboardingService.isLevelCompleted(userId);
        if (completed) {
          final timeCompleted = await LanguageOnboardingService.isTimeSelectionCompleted(userId);
          final preparingCompleted = timeCompleted
              ? await LanguageOnboardingService.isPreparingScreenCompleted(userId)
              : false;
          Navigator.of(context).pushReplacementNamed(
            timeCompleted ? (preparingCompleted ? '/home' : '/preparing') : '/time-selection',
          );
          return;
        }
      }

      final selectedLanguage = _languages.firstWhere(
        (language) => language['code'] == code,
        orElse: () => _languages.first,
      );

      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => LanguageLevelScreen(
            languageCode: selectedLanguage['code']!,
            languageName: selectedLanguage['name']!,
            mascotAsset: 'assets/icons/caticon.png',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF3C404A);
    final cardColor = isDark ? AppTheme.darkSurface : Colors.white;
    final borderColor = isDark ? Colors.white10 : const Color(0xFFE8ECF1);

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBackground : Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 50.0),
          child: Column(
            children: [
              Row(
                children: [
                  Image.asset('assets/icons/caticon.png', width: 42, height: 42),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                      decoration: const BoxDecoration(
                        image: DecorationImage(
                          image: AssetImage('assets/images/bar.png'),
                          fit: BoxFit.fill,
                        ),
                      ),
                      child: const Text(
                        'what language would you like to learn?',
                        style: TextStyle(
                          fontSize: 15,
                          color: Colors.black,
                          fontWeight: FontWeight.w600,
                          fontStyle: FontStyle.italic,
                          height: 1.25,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Language options
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.only(top: 4),
                  itemCount: _languages.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final lang = _languages[index];
                    return Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(24),
                        onTap: () => _selectLanguage(lang['code']!),
                        child: Container(
                          height: 62,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(24),
                            color: cardColor,
                            border: Border.all(color: borderColor, width: 0.5),
                          ),
                          child: Row(
                            children: [
                              Image.asset(
                                lang['asset']!,
                                width: 24,
                                height: 24,
                                fit: BoxFit.contain,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  lang['name']!,
                                  style: TextStyle(
                                    fontSize: 15,
                                    height: 1.0,
                                    fontWeight: FontWeight.w600,
                                    color: textColor,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ),
                              const Icon(Icons.arrow_forward_ios, size: 14, color: Color(0xFF3C404A)),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),

              Padding(
                padding: const EdgeInsets.symmetric(vertical: 18.0),
                child: Center(
                  child: const Text(
                    'More languages coming soon!',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.grey,
                      fontStyle: FontStyle.italic,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
