import 'package:flutter/material.dart';
import '../../themes/app_theme.dart';
import '../../services/firebase_service.dart';
import 'login_screen.dart';
import 'email_verification_screen.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _showComingSoon() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Coming soon',
          style: const TextStyle(fontStyle: FontStyle.italic),
        ),
      ),
    );
  }

  void _signup() async {
    if (_nameController.text.isEmpty ||
        _emailController.text.isEmpty ||
        _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Full name, email, and password are required.',
            style: const TextStyle(fontStyle: FontStyle.italic),
          ),
        ),
      );
      return;
    }

    if (!_emailController.text.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Please enter a valid email address',
            style: const TextStyle(fontStyle: FontStyle.italic),
          ),
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final userId = await FirebaseService.signUp(
        _emailController.text.trim(),
        _passwordController.text,
        displayName: _nameController.text.trim(),
      );

      // Stop loading immediately
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }

      if (userId != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Verification email sent. Please verify your email before logging in.',
            ),
            duration: Duration(seconds: 4),
          ),
        );

        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const EmailVerificationScreen()),
        );
        return;
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✗ Signup failed. Email may already be in use.'),
            duration: Duration(seconds: 3),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        String errorMessage = 'Signup failed: ${e.toString()}';
        if (e.toString().contains('email-already-in-use')) {
          errorMessage =
              'This email is already registered. Please login instead.';
        } else if (e.toString().contains('weak-password')) {
          errorMessage = 'Password is too weak. Use at least 6 characters.';
        } else if (e.toString().contains('invalid-email')) {
          errorMessage = 'Invalid email address format.';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage, style: const TextStyle(fontStyle: FontStyle.italic)),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final scale = (constraints.maxHeight / 820).clamp(0.82, 1.0);
            final bottomInset = MediaQuery.of(context).viewInsets.bottom;

            return AnimatedPadding(
              duration: const Duration(milliseconds: 160),
              curve: Curves.easeOut,
              padding: EdgeInsets.only(bottom: bottomInset),
              child: SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: IntrinsicHeight(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 24 * scale),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SizedBox(height: 22 * scale),
                          Text(
                            'Welcome',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 26 * scale,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF1F2A3A),
                              letterSpacing: 0.2,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                          SizedBox(height: 20 * scale),
                          _SocialButton(
                            label: 'Sign up with Apple',
                            icon: Icon(
                              Icons.apple,
                              size: 24 * scale,
                              color: const Color(0xFF1F2A3A),
                            ),
                            onTap: _showComingSoon,
                          ),
                          SizedBox(height: 12 * scale),
                          _SocialButton(
                            label: 'Sign up with Google',
                            icon: Image.asset(
                              'assets/icons/google-logo-transparent-free-png.webp',
                              width: 24 * scale,
                              height: 24 * scale,
                              fit: BoxFit.contain,
                            ),
                            onTap: _showComingSoon,
                          ),
                          SizedBox(height: 12 * scale),
                          _SocialButton(
                            label: 'Sign up with SMS',
                            icon: Image.asset(
                              'assets/icons/smslogo.jpg',
                              width: 22 * scale,
                              height: 22 * scale,
                              fit: BoxFit.contain,
                            ),
                            onTap: _showComingSoon,
                          ),
                          SizedBox(height: 18 * scale),
                          Row(
                            children: [
                              const Expanded(child: Divider(color: Color(0xFFE6E6E6), thickness: 1)),
                              Padding(
                                padding: EdgeInsets.symmetric(horizontal: 14 * scale),
                                child: Text(
                                  'OR',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    color: const Color(0xFFA5A5A5),
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12 * scale,
                                    letterSpacing: 0.8,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ),
                              const Expanded(child: Divider(color: Color(0xFFE6E6E6), thickness: 1)),
                            ],
                          ),
                          SizedBox(height: 16 * scale),
                          _StyledField(
                            controller: _nameController,
                            hintText: 'Full name',
                            keyboardType: TextInputType.name,
                            prefix: Icon(
                              Icons.person_outline,
                              color: const Color(0xFF4A4A4A),
                              size: 22 * scale,
                            ),
                          ),
                          SizedBox(height: 12 * scale),
                          _StyledField(
                            controller: _emailController,
                            hintText: 'Email',
                            keyboardType: TextInputType.emailAddress,
                            prefix: Icon(
                              Icons.mail_outline_rounded,
                              color: const Color(0xFF4A4A4A),
                              size: 21 * scale,
                            ),
                          ),
                          SizedBox(height: 12 * scale),
                          _StyledField(
                            controller: _passwordController,
                            hintText: 'Password',
                            obscureText: _obscurePassword,
                            prefix: Icon(
                              Icons.lock_outline_rounded,
                              color: const Color(0xFF4A4A4A),
                              size: 22 * scale,
                            ),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword ? Icons.visibility_off : Icons.visibility,
                                color: const Color(0xFF4A4A4A),
                                size: 20 * scale,
                              ),
                              onPressed: () {
                                setState(() {
                                  _obscurePassword = !_obscurePassword;
                                });
                              },
                            ),
                          ),
                          SizedBox(height: 14 * scale),
                          SizedBox(
                            height: 56 * scale,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _signup,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.primaryGreen,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              child: _isLoading
                                  ? const SizedBox(
                                      height: 22,
                                      width: 22,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation<Color>(AppTheme.white),
                                      ),
                                    )
                                  : Text(
                                      'Create an account',
                                      style: TextStyle(fontSize: 17 * scale, fontWeight: FontWeight.w500, fontStyle: FontStyle.italic),
                                    ),
                            ),
                          ),
                          SizedBox(height: 16 * scale),
                          Text(
                            'By creating an account you agree to our\nTerms of Service and Privacy Policy',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13 * scale,
                              height: 1.35,
                              color: const Color(0xFF232323),
                              fontWeight: FontWeight.w700,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                          const Spacer(),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'Already got an account? ',
                                style: TextStyle(fontSize: 14 * scale, color: const Color(0xFF1F2A3A), fontStyle: FontStyle.italic),
                              ),
                              GestureDetector(
                                onTap: () {
                                  Navigator.of(context).pushReplacement(
                                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                                  );
                                },
                                child: Text(
                                  'LOGIN',
                                  style: TextStyle(
                                    fontSize: 14 * scale,
                                    fontWeight: FontWeight.w800,
                                    color: AppTheme.primaryGreen,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 10 * scale),
                          Center(
                            child: Container(
                              width: 120 * scale,
                              height: 5 * scale,
                              decoration: BoxDecoration(
                                color: Colors.black,
                                borderRadius: BorderRadius.circular(999),
                              ),
                            ),
                          ),
                          SizedBox(height: 8 * scale),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _SocialButton extends StatelessWidget {
  const _SocialButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final Widget icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 54,
      child: Material(
        color: const Color(0xFFEFF2FC),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(width: 30, child: Center(child: icon)),
                const SizedBox(width: 14),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 16,
                    color: Color(0xFF1F2A3A),
                    fontWeight: FontWeight.w500,
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

class _StyledField extends StatelessWidget {
  const _StyledField({
    required this.controller,
    required this.hintText,
    required this.prefix,
    this.keyboardType,
    this.obscureText = false,
    this.suffixIcon,
  });

  final TextEditingController controller;
  final String hintText;
  final Widget prefix;
  final TextInputType? keyboardType;
  final bool obscureText;
  final Widget? suffixIcon;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      style: const TextStyle(fontSize: 16, color: Color(0xFF1F2A3A)),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: const TextStyle(color: Color(0xFF3E3E3E), fontSize: 16),
        prefixIcon: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: prefix,
        ),
        prefixIconConstraints: const BoxConstraints(minWidth: 56),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppTheme.primaryGreen, width: 2),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppTheme.primaryGreen, width: 2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppTheme.primaryGreen, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      ),
    );
  }
}
