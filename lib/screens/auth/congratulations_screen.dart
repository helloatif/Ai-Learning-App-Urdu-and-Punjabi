import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class CongratulationsScreen extends StatelessWidget {
  final String userId;
  const CongratulationsScreen({Key? key, required this.userId}) : super(key: key);

  Future<void> _markShown() async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .set({'congratsShown': true}, SetOptions(merge: true));
    } catch (e) {
      // ignore errors - non-fatal
      debugPrint('Error marking congratsShown: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: BackButton(color: const Color(0xFF2E3A46)),
        title: const Text(
          'Verification code',
          style: TextStyle(
            color: Color(0xFF2E3A46),
            fontStyle: FontStyle.italic,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 18),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset(
                  'assets/images/Hands_Show.png',
                  height: 320,
                  fit: BoxFit.contain,
                ),
                const SizedBox(height: 14),
                Text(
                  'Congratulations',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF2E3A46),
                    fontStyle: FontStyle.italic,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Your Account is Ready to Use. Tap the tick to enter the app.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF6B6B6B),
                    fontStyle: FontStyle.italic,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 58),
                GestureDetector(
                  onTap: () async {
                    await _markShown();

                    // Decide next route: if user hasn't selected a language, go to language selection,
                    // otherwise go to home.
                    try {
                      final doc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
                      final selectedLanguage = (doc.data()?['selectedLanguage'] ?? '').toString().trim();
                      final levelCompleted = (doc.data()?['languageLevelCompleted'] ?? false) == true;
                      final timeCompleted = (doc.data()?['timeSelectionCompleted'] ?? false) == true;
                      final preparingCompleted = (doc.data()?['preparingScreenCompleted'] ?? false) == true;
                      if (selectedLanguage.isEmpty) {
                        Navigator.of(context).pushReplacementNamed('/language-selection');
                        return;
                      }

                      if (!levelCompleted) {
                        Navigator.of(context).pushReplacementNamed(
                          '/language-level',
                          arguments: selectedLanguage,
                        );
                        return;
                      }

                      if (!timeCompleted) {
                        Navigator.of(context).pushReplacementNamed('/time-selection');
                        return;
                      }

                      if (!preparingCompleted) {
                        Navigator.of(context).pushReplacementNamed('/preparing');
                        return;
                      }
                    } catch (e) {
                      debugPrint('Error checking selectedLanguage: $e');
                      // fallback to language selection on error
                      Navigator.of(context).pushReplacementNamed('/language-selection');
                      return;
                    }

                    Navigator.of(context).pushReplacementNamed('/home');
                  },
                  child: Container(
                    width: 86,
                    height: 86,
                    decoration: BoxDecoration(
                      color: Color(0xFF2196F3),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.12),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Image.asset(
                        'assets/icons/Fitz _Checkmark.png',
                        width: 42,
                        height: 42,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Tap the tick to continue',
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF6B6B6B),
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
