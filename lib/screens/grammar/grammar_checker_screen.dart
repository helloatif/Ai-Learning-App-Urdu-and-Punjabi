import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../themes/app_theme.dart';
import '../../providers/user_provider.dart';
import '../../services/ml_vocabulary_service.dart';

class GrammarCheckerScreen extends StatefulWidget {
  const GrammarCheckerScreen({super.key});

  @override
  State<GrammarCheckerScreen> createState() => _GrammarCheckerScreenState();
}

class _GrammarCheckerScreenState extends State<GrammarCheckerScreen> {
  final _textController = TextEditingController();
  String _feedback = '';
  bool _isAnalyzing = false;

  void _checkGrammar(String language) async {
    if (_textController.text.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please enter some text')));
      return;
    }

    setState(() {
      _isAnalyzing = true;
      _feedback = '';
    });

    final inputText = _textController.text.trim();
    final expectedText = inputText;

    final result = await MLVocabularyService.checkGrammarEnhanced(
      userInput: inputText,
      expectedText: expectedText,
      language: language,
    );

    final buffer = StringBuffer();
    buffer.writeln('Score: ${result.score}%');
    buffer.writeln('ML Score: ${result.mlScore}%');
    buffer.writeln('Semantic Score: ${result.semanticScore}%');
    buffer.writeln('');
    buffer.writeln(result.feedback);

    if (result.ruleViolations.isNotEmpty) {
      buffer.writeln('');
      buffer.writeln('Issues found:');
      for (final violation in result.ruleViolations) {
        buffer.writeln('- ${violation.message}');
      }
    }

    if (result.suggestions.isNotEmpty) {
      buffer.writeln('');
      buffer.writeln('Suggestions:');
      for (final suggestion in result.suggestions) {
        buffer.writeln('- $suggestion');
      }
    }

    if (mounted) {
      setState(() {
        _isAnalyzing = false;
        _feedback = buffer.toString().trim();
      });
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);
    final language = userProvider.currentUser?.selectedLanguage ?? 'urdu';
    final languageLabel = language == 'urdu' ? 'Urdu' : 'Punjabi';

    return Scaffold(
      appBar: AppBar(title: Text('$languageLabel Grammar Checker')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Text(
              'Check Your Text',
              style: Theme.of(
                context,
              ).textTheme.displaySmall?.copyWith(color: AppTheme.primaryGreen),
            ),
            const SizedBox(height: 8),
            Text(
              'Improve your $languageLabel writing with AI-powered grammar correction',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),

            // Input Area
            TextField(
              controller: _textController,
              maxLines: 8,
              cursorColor: AppTheme.primaryGreen,
              style: TextStyle(
                color: Theme.of(context).brightness == Brightness.dark
                    ? AppTheme.textLight
                    : AppTheme.textDark,
              ),
              decoration: InputDecoration(
                hintText: 'Enter your $languageLabel text here...',
                labelText: 'Text',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                hintStyle: TextStyle(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.grey.shade400
                      : Colors.grey.shade600,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.grey.shade600
                        : Colors.grey.shade400,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: AppTheme.primaryGreen,
                    width: 2,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Check Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isAnalyzing ? null : () => _checkGrammar(language),
                icon: _isAnalyzing
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            AppTheme.white,
                          ),
                        ),
                      )
                    : const Icon(Icons.check_circle),
                label: Text(_isAnalyzing ? 'Analyzing...' : 'Check Grammar'),
              ),
            ),

            if (_feedback.isNotEmpty) ...[
              const SizedBox(height: 24),
              // Feedback Card
              Card(
                color: Colors.green.withValues(alpha: 0.1),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(
                    color: AppTheme.primaryGreen,
                    width: 2,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.lightbulb,
                            color: AppTheme.primaryGreen,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Correction',
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _feedback,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ),
            ],

            const SizedBox(height: 32),

            // Tips Section
            Text(
              'Helpful Tips',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(color: AppTheme.primaryGreen),
            ),
            const SizedBox(height: 12),
            _buildTipCard('Use punctuation marks correctly', Icons.edit),
            _buildTipCard('Avoid spelling mistakes', Icons.spellcheck),
            _buildTipCard(
              'Make sentences complete and meaningful',
              Icons.text_fields,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTipCard(String tip, IconData icon) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(icon, color: AppTheme.primaryGreen),
            const SizedBox(width: 12),
            Expanded(
              child: Text(tip, style: Theme.of(context).textTheme.bodyMedium),
            ),
          ],
        ),
      ),
    );
  }
}
