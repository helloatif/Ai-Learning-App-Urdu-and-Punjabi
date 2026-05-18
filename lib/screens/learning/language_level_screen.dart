import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../services/language_onboarding_service.dart';

class LanguageLevelScreen extends StatefulWidget {
  final String languageCode;
  final String languageName;
  final String mascotAsset;

  const LanguageLevelScreen({
    super.key,
    required this.languageCode,
    required this.languageName,
    required this.mascotAsset,
  });

  @override
  State<LanguageLevelScreen> createState() => _LanguageLevelScreenState();
}

class _LanguageLevelScreenState extends State<LanguageLevelScreen> {
  int? _selectedIndex;
  bool _isContinuing = false;

  static const List<_LevelOption> _levels = [
    _LevelOption('I\'m a total beginner', 'assets/icons/level_1.png'),
    _LevelOption('I\'m a total beginner', 'assets/icons/level_2.png'),
    _LevelOption('I\'m a total beginner', 'assets/icons/level_3.png'),
    _LevelOption('I\'m a total beginner', 'assets/icons/level_4.png'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 6, 18, 8),
              child: Row(
                children: [
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
                    color: const Color(0xFF9EA3AE),
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Container(
                      height: 8,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0F2F6),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      alignment: Alignment.centerLeft,
                      child: FractionallySizedBox(
                        widthFactor: 0.28,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.black,
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 6, 14, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Image.asset(
                    widget.mascotAsset,
                    width: 62,
                    height: 62,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5F8FC),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'How much ${widget.languageName} do you know?',
                        style: const TextStyle(
                          fontSize: 18,
                          height: 1.25,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF2B2E36),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: _levels.length,
                separatorBuilder: (_, __) => const SizedBox(height: 14),
                itemBuilder: (context, index) {
                  final option = _levels[index];
                  final isSelected = _selectedIndex == index;
                  return Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => setState(() => _selectedIndex = index),
                      borderRadius: BorderRadius.circular(18),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        height: 58,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: isSelected ? const Color(0xFF4F84FF) : const Color(0xFFE7ECF3),
                            width: isSelected ? 1.5 : 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF101828).withOpacity(0.05),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Image.asset(
                              option.iconAsset,
                              width: 32,
                              height: 32,
                              fit: BoxFit.contain,
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Text(
                                option.label,
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF2B2E36),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Icon(
                              Icons.chevron_right_rounded,
                              size: 26,
                              color: isSelected ? const Color(0xFF4F84FF) : const Color(0xFF9FA6B2),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _selectedIndex == null || _isContinuing
                      ? null
                      : () async {
                          final user = FirebaseAuth.instance.currentUser;
                          final userId = user?.uid;
                          if (userId == null) return;

                          setState(() => _isContinuing = true);
                          try {
                            await LanguageOnboardingService.saveSelectedLanguage(
                              userId,
                              widget.languageCode,
                            );
                            await LanguageOnboardingService.markLevelCompleted(userId);
                            await FirebaseFirestore.instance.collection('users').doc(userId).set(
                              {
                                'selectedLanguage': widget.languageCode,
                                'languageLevelCompleted': true,
                              },
                              SetOptions(merge: true),
                            );

                            if (!mounted) return;
                            Navigator.of(context).pushNamed('/time-selection');
                          } finally {
                            if (mounted) {
                              setState(() => _isContinuing = false);
                            }
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4F84FF),
                    disabledBackgroundColor: const Color(0xFFD9E4FF),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                  ),
                  child: Text(
                    _isContinuing ? 'Saving...' : 'Continue',
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LevelOption {
  final String label;
  final String iconAsset;

  const _LevelOption(this.label, this.iconAsset);
}
