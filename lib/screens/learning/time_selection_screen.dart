import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../services/language_onboarding_service.dart';

class TimeSelectionScreen extends StatefulWidget {
  const TimeSelectionScreen({super.key});

  @override
  State<TimeSelectionScreen> createState() => _TimeSelectionScreenState();
}

class _TimeSelectionScreenState extends State<TimeSelectionScreen> {
  int? _selectedIndex;
  bool _isContinuing = false;

  static const List<_TimeOption> _options = [
    _TimeOption(minutes: 5, title: 'Casual', iconAsset: 'assets/icons/greenlevel.png'),
    _TimeOption(minutes: 10, title: 'Regular', iconAsset: 'assets/icons/bluelevel.png'),
    _TimeOption(minutes: 15, title: 'Accelerated', iconAsset: 'assets/icons/purplelevel.png'),
    _TimeOption(minutes: 20, title: 'Intense', iconAsset: 'assets/icons/pinklevel.png'),
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
                        widthFactor: 0.46,
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
                    'assets/icons/caticon.png',
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
                      child: const Text(
                        'What is your daily goal\nfor practicing?',
                        style: TextStyle(
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
                itemCount: _options.length,
                separatorBuilder: (_, __) => const SizedBox(height: 14),
                itemBuilder: (context, index) {
                  final option = _options[index];
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
                            Text(
                              '${option.minutes} min',
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF2B2E36),
                              ),
                            ),
                            const Spacer(),
                            Text(
                              option.title,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF7B808B),
                              ),
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
                          final userId = FirebaseAuth.instance.currentUser?.uid;
                          if (userId == null) return;

                          final option = _options[_selectedIndex!];
                          setState(() => _isContinuing = true);
                          try {
                            await LanguageOnboardingService.savePracticeGoal(
                              userId,
                              option.minutes,
                              option.title,
                            );
                            await LanguageOnboardingService.markTimeSelectionCompleted(userId);

                            if (!mounted) return;
                            Navigator.of(context).pushNamed('/preparing');
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

class _TimeOption {
  final int minutes;
  final String title;
  final String iconAsset;

  const _TimeOption({
    required this.minutes,
    required this.title,
    required this.iconAsset,
  });
}