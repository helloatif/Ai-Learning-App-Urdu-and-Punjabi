import 'package:flutter/material.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F6FF),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.topCenter,
                children: [
                  Container(
                    height: 220,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF1F9CFF), Color(0xFF0D63D6)],
                      ),
                      borderRadius: BorderRadius.only(
                        bottomLeft: Radius.circular(36),
                        bottomRight: Radius.circular(36),
                      ),
                    ),
                    child: Stack(
                      children: [
                        Positioned(
                          top: 20,
                          left: 20,
                          child: _HeaderAction(icon: Icons.arrow_back),
                        ),
                        Positioned(
                          top: 20,
                          right: 72,
                          child: _HeaderAction(icon: Icons.navigation_rounded),
                        ),
                        Positioned(
                          top: 20,
                          right: 20,
                          child: _HeaderAction(icon: Icons.settings),
                        ),
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 18,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              Text(
                                'Profile',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 28,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              SizedBox(height: 6),
                              Text(
                                'Gamified learner dashboard',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    bottom: -52,
                    child: Container(
                      width: 112,
                      height: 112,
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.15),
                            blurRadius: 18,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: const CircleAvatar(
                        backgroundColor: Color(0xFFFFD6E7),
                        child: Icon(
                          Icons.person_rounded,
                          size: 54,
                          color: Color(0xFFE64A8D),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 68),
            const Center(
              child: Column(
                children: [
                  Text(
                    '@John',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF20304D),
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Switzerland',
                    style: TextStyle(
                      fontSize: 14,
                      color: Color(0xFF6E7B91),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              height: 44,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                scrollDirection: Axis.horizontal,
                itemBuilder: (context, index) {
                  final labels = [
                    ('Rank Title 1', const Color(0xFFFF6B6B)),
                    ('Rank Title 2', const Color(0xFF5C8DFF)),
                    ('Rank Title 3', const Color(0xFFFFB347)),
                  ];
                  return _BadgeChip(
                    label: labels[index].$1,
                    color: labels[index].$2,
                  );
                },
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemCount: 3,
              ),
            ),
            const SizedBox(height: 18),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF2DBB5F),
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF2DBB5F).withValues(alpha: 0.25),
                      blurRadius: 18,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: const Row(
                  children: [
                    Expanded(
                      child: _MetricTile(
                        icon: Icons.star_border_rounded,
                        title: 'POINTS',
                        value: '600',
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: _MetricTile(
                        icon: Icons.public_rounded,
                        title: 'WORLD RANK',
                        value: '#800',
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: _MetricTile(
                        icon: Icons.language_rounded,
                        title: 'LOCAL RANK',
                        value: '#800',
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: _DashboardCard(
                          title: 'Followed',
                          subtitle: 'Status',
                          backgroundColor: const Color(0xFFFF6A6A),
                          icon: Icons.favorite_rounded,
                          illustration: Icons.groups_rounded,
                          minHeight: 170,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _DashboardCard(
                          title: 'Your Quizzes',
                          subtitle: '',
                          backgroundColor: const Color(0xFFFFC233),
                          icon: Icons.quiz_rounded,
                          illustration: Icons.inventory_2_rounded,
                          minHeight: 170,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _DashboardCard(
                          title: 'Friends',
                          subtitle: '',
                          backgroundColor: const Color(0xFF5B8DFF),
                          icon: Icons.group_rounded,
                          illustration: Icons.emoji_emotions_rounded,
                          minHeight: 155,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 1,
                        child: _DashboardCard(
                          title: 'Achievements',
                          subtitle: '',
                          backgroundColor: const Color(0xFFCE63FF),
                          icon: Icons.emoji_events_rounded,
                          illustration: Icons.workspace_premium_rounded,
                          minHeight: 155,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _HeaderAction extends StatelessWidget {
  final IconData icon;

  const _HeaderAction({required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: const BoxDecoration(
        color: Color(0xFFECEFF5),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: Color(0xFF2B3548), size: 22),
    );
  }
}

class _BadgeChip extends StatelessWidget {
  final String label;
  final Color color;

  const _BadgeChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;

  const _MetricTile({
    required this.icon,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: Column(
        children: [
          Icon(icon, color: Colors.white, size: 24),
          const SizedBox(height: 10),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _DashboardCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final Color backgroundColor;
  final IconData icon;
  final IconData illustration;
  final double minHeight;

  const _DashboardCard({
    required this.title,
    required this.subtitle,
    required this.backgroundColor,
    required this.icon,
    required this.illustration,
    required this.minHeight,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(minHeight: minHeight),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Stack(
        children: [
          Positioned(
            right: 0,
            top: 0,
            child: Icon(icon, color: Colors.white.withValues(alpha: 0.9), size: 22),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (subtitle.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.92),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
              Align(
                alignment: Alignment.bottomRight,
                child: Container(
                  width: 78,
                  height: 78,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.16),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    illustration,
                    color: Colors.white,
                    size: 38,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
