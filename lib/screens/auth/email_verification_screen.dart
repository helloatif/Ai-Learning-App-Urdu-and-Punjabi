import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../themes/app_theme.dart';
import '../../services/firebase_service.dart';
import '../../providers/user_provider.dart';
import '../../providers/gamification_provider.dart';
import '../../providers/learning_provider.dart';
import '../../providers/theme_provider.dart';

class EmailVerificationScreen extends StatefulWidget {
  const EmailVerificationScreen({super.key});

  @override
  State<EmailVerificationScreen> createState() =>
      _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen> {
  Timer? _timer;
  Timer? _cooldownTimer;
  bool _isCheckingVerification = false;
  bool _canResend = false; // Start as false - email was just sent on signup
  int _resendCooldown = 60; // Start with 60 second cooldown
  bool _isResending = false;

  @override
  void initState() {
    super.initState();

    // Start cooldown timer immediately (email was sent during signup)
    _startCooldownTimer();

    // Check verification status every 3 seconds
    _timer = Timer.periodic(const Duration(seconds: 3), (timer) {
      _checkEmailVerification();
    });
  }

  void _startCooldownTimer() {
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_resendCooldown > 0) {
        if (mounted) {
          setState(() {
            _resendCooldown--;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _canResend = true;
          });
        }
        timer.cancel();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _cooldownTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkEmailVerification() async {
    if (_isCheckingVerification) return;

    setState(() {
      _isCheckingVerification = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await user.reload();
        final refreshedUser = FirebaseAuth.instance.currentUser;

        if (refreshedUser != null && refreshedUser.emailVerified) {
          // Email verified! Check if user has selected a language
          _timer?.cancel();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('✓ Email verified successfully!'),
                backgroundColor: Colors.green,
              ),
            );

            // Check if user has already selected a language
            try {
              final themeProvider = Provider.of<ThemeProvider>(
                context,
                listen: false,
              );
              await themeProvider.loadForUser(refreshedUser.uid);

              // Load user data into provider first
              final userProvider = Provider.of<UserProvider>(
                context,
                listen: false,
              );
              await userProvider.loadUserFromFirebase();

              // Load gamification data (points, level, streak, etc.)
              final gamificationProvider = Provider.of<GamificationProvider>(
                context,
                listen: false,
              );
              await gamificationProvider.loadFromFirestore();

              // Load learning progress (chapter completions, quiz scores)
              final learningProvider = Provider.of<LearningProvider>(
                context,
                listen: false,
              );
              await learningProvider.loadProgressFromFirestore();

              final doc = await FirebaseFirestore.instance
                  .collection('users')
                  .doc(refreshedUser.uid)
                  .get();

              final selectedLanguage =
                  doc.data()?['selectedLanguage'] as String?;

              if (selectedLanguage != null &&
                  selectedLanguage.isNotEmpty &&
                  mounted) {
                // Language already selected - go directly to home
                Navigator.of(context).pushReplacementNamed('/home');
              } else if (mounted) {
                // No language selected yet - go to language selection
                Navigator.of(
                  context,
                ).pushReplacementNamed('/language-selection');
              }
            } catch (e) {
              // If Firestore check fails, default to language selection
              if (mounted) {
                Navigator.of(
                  context,
                ).pushReplacementNamed('/language-selection');
              }
            }
          }
        }
      }
    } catch (e) {
      print('Error checking verification: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isCheckingVerification = false;
        });
      }
    }
  }

  Future<void> _resendVerificationEmail() async {
    if (!_canResend || _isResending) return;

    setState(() {
      _isResending = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        throw Exception('No user logged in');
      }

      if (user.emailVerified) {
        // Already verified, check language selection and navigate accordingly
        if (mounted) {
          try {
            final themeProvider = Provider.of<ThemeProvider>(
              context,
              listen: false,
            );
            await themeProvider.loadForUser(user.uid);

            // Load user data into provider first
            final userProvider = Provider.of<UserProvider>(
              context,
              listen: false,
            );
            await userProvider.loadUserFromFirebase();

            final doc = await FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .get();

            final selectedLanguage = doc.data()?['selectedLanguage'] as String?;

            if (mounted) {
              if (selectedLanguage != null && selectedLanguage.isNotEmpty) {
                Navigator.of(context).pushReplacementNamed('/home');
              } else {
                Navigator.of(
                  context,
                ).pushReplacementNamed('/language-selection');
              }
            }
          } catch (e) {
            if (mounted) {
              Navigator.of(context).pushReplacementNamed('/language-selection');
            }
          }
        }
        return;
      }

      // Send verification email directly
      print('📧 Resending verification email to ${user.email}...');
      await user.sendEmailVerification();
      print('✅ Verification email resent successfully!');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '✉️ Verification email sent to ${user.email}!\nCheck your inbox and spam folder.',
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 4),
          ),
        );

        // Reset cooldown
        setState(() {
          _canResend = false;
          _resendCooldown = 60;
        });

        // Start cooldown timer
        _startCooldownTimer();
      }
    } on FirebaseAuthException catch (e) {
      print('❌ Firebase error resending email: ${e.code} - ${e.message}');
      if (mounted) {
        String errorMessage = 'Failed to send email';
        if (e.code == 'too-many-requests') {
          errorMessage =
              'Too many requests. Please wait a few minutes and try again.';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      print('❌ Error resending verification email: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isResending = false;
        });
      }
    }
  }

  Future<void> _signOut() async {
    // Don't clear Remember Me - user just needs to verify email
    await FirebaseService.signOut(clearRememberMe: false);
    if (mounted) {
      Navigator.of(context).pushReplacementNamed('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Verify Your Email'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _signOut,
            tooltip: 'Sign out',
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Email icon
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: AppTheme.primaryGreen.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.email_outlined,
                  size: 60,
                  color: AppTheme.primaryGreen,
                ),
              ),
              const SizedBox(height: 32),

              // Title
              Text(
                'Verify Your Email',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.darkGray,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),

              // Email address
              Text(
                user?.email ?? '',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppTheme.primaryGreen,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),

              // Instructions
              Text(
                'We\'ve sent a verification email to your inbox. Please click the link in the email to verify your account.',
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(color: AppTheme.darkGray),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),

              // Auto-checking indicator
              if (_isCheckingVerification)
                const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          AppTheme.primaryGreen,
                        ),
                      ),
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Checking verification...',
                      style: TextStyle(
                        color: AppTheme.primaryGreen,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 32),

              // Resend button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: (_canResend && !_isResending)
                      ? _resendVerificationEmail
                      : null,
                  icon: _isResending
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                      : const Icon(Icons.refresh),
                  label: Text(
                    _isResending
                        ? 'Sending...'
                        : _canResend
                        ? 'Resend Verification Email'
                        : 'Resend in $_resendCooldown seconds',
                    style: const TextStyle(fontSize: 16),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryGreen,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Back to Login button
              TextButton(
                onPressed: () {
                  _timer?.cancel();
                  // Don't clear Remember Me - user just needs to verify email
                  FirebaseService.signOut(clearRememberMe: false);
                  Navigator.of(context).pushReplacementNamed('/login');
                },
                child: const Text(
                  'Back to Login',
                  style: TextStyle(
                    color: AppTheme.primaryGreen,
                    fontSize: 16,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Help text
              Text(
                'Didn\'t receive the email? Check your spam folder or resend.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppTheme.darkGray,
                  fontStyle: FontStyle.italic,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
