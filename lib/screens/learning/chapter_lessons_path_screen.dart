import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ChapterLessonsPathScreen extends StatefulWidget {
  final String chapterId;
  final String chapterTitle;

  const ChapterLessonsPathScreen({
    Key? key,
    required this.chapterId,
    required this.chapterTitle,
  }) : super(key: key);

  @override
  State<ChapterLessonsPathScreen> createState() => _ChapterLessonsPathScreenState();
}

class _ChapterLessonsPathScreenState extends State<ChapterLessonsPathScreen> {
  late int _highestUnlocked; // 1-based index of highest unlocked node (1..5)
  bool _loading = true;

  static const int totalNodes = 5;

  final List<_NodeData> _nodes = [
    const _NodeData(title: 'Lesson 1'),
    const _NodeData(title: 'Lesson 2'),
    const _NodeData(title: 'Lesson 3'),
    const _NodeData(title: 'Lesson 4'),
    const _NodeData(title: 'Chapter Quiz'),
  ];

  @override
  void initState() {
    super.initState();
    _loadProgress();
  }

  Future<void> _loadProgress() async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'chapter_${widget.chapterId}_highest_unlocked';
    final stored = prefs.getInt(key) ?? 1;
    setState(() {
      _highestUnlocked = (stored.clamp(1, totalNodes));
      _loading = false;
    });
  }

  Future<void> _saveProgress() async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'chapter_${widget.chapterId}_highest_unlocked';
    await prefs.setInt(key, _highestUnlocked);
  }

  void _onNodeTap(int index) async {
    // index is 1-based
    if (index > _highestUnlocked) return; // locked

    // For now show a simple dialog to allow marking completed (simulates finishing lesson)
    final didComplete = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Open ${_nodes[index - 1].title}'),
        content: Text('Simulate opening this lesson. Mark it completed when finished?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Complete')),
        ],
      ),
    );

    if (didComplete == true) {
      setState(() {
        // Unlock next node (unless already at max)
        if (_highestUnlocked < totalNodes) _highestUnlocked = (_highestUnlocked + 1).clamp(1, totalNodes);
      });
      await _saveProgress();
    }
  }

  Widget _buildNode(BuildContext context, int index) {
    final node = _nodes[index - 1];
    final unlocked = index <= _highestUnlocked;

    final theme = Theme.of(context);

    final circle = GestureDetector(
      onTap: unlocked ? () => _onNodeTap(index) : null,
      child: SizedBox(
        width: 76,
        height: 76,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // use uploaded asset backgrounds for unlocked/locked look
            Image.asset(
              unlocked ? 'assets/icons/unlocknodes.png' : 'assets/icons/locknodes.png',
              width: 76,
              height: 76,
              fit: BoxFit.contain,
            ),
          ],
        ),
      ),
    );

    // Label under node
    final label = Padding(
      padding: const EdgeInsets.only(top: 8.0),
      child: Text(node.title, style: theme.textTheme.bodySmall),
    );

    // Positioning: per spec: 1-left,2-center,3-right,4-center,5-center
    Alignment alignment;
    switch (index) {
      case 1:
        alignment = const Alignment(-0.7, 0);
        break;
      case 2:
        alignment = Alignment.center;
        break;
      case 3:
        alignment = const Alignment(0.7, 0);
        break;
      case 4:
        alignment = Alignment.center;
        break;
      case 5:
      default:
        alignment = Alignment.center;
        break;
    }

    return SizedBox(
      height: 140,
      child: Stack(
        children: [
          Align(alignment: alignment, child: Column(mainAxisSize: MainAxisSize.min, children: [circle, label])),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Sticky header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(color: Theme.of(context).scaffoldBackgroundColor, boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 6, offset: const Offset(0, 2)),
              ]),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: 8),
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('SECTION', style: Theme.of(context).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text(widget.chapterTitle, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                  ]),
                ],
              ),
            ),

            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Column(
                  children: List.generate(totalNodes, (i) => _buildNode(context, i + 1)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NodeData {
  final String title;

  const _NodeData({required this.title});
}
