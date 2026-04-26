import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/api_service.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key, this.role = 'user'});

  final String role;

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _pageController = PageController();
  int _currentStep = 0;
  bool _completing = false;

  List<_OnboardingStep> get _steps {
    switch (widget.role) {
      case 'agent':
        return const [
          _OnboardingStep(
            icon: Icons.business_center,
            title: 'Welcome, Agent!',
            description: 'List properties and connect with buyers and renters on one powerful platform.',
          ),
          _OnboardingStep(
            icon: Icons.add_home_outlined,
            title: 'Add Your Listings',
            description: 'Upload property details and photos to start attracting clients.',
          ),
          _OnboardingStep(
            icon: Icons.star_outline,
            title: 'Build Your Reputation',
            description: 'Earn XP, collect badges, and climb the leaderboard.',
          ),
        ];
      case 'company':
      case 'organization':
        return const [
          _OnboardingStep(
            icon: Icons.storefront_outlined,
            title: 'Welcome to Your Dashboard',
            description: 'Manage products, track orders, and connect with buyers globally.',
          ),
          _OnboardingStep(
            icon: Icons.inventory_2_outlined,
            title: 'Add Your Products',
            description: 'List manufactured goods or agricultural products for wholesale buyers.',
          ),
          _OnboardingStep(
            icon: Icons.handshake_outlined,
            title: 'Grow Together',
            description: 'Respond to RFQs, earn reviews, and unlock enterprise features.',
          ),
        ];
      default:
        return const [
          _OnboardingStep(
            icon: Icons.explore_outlined,
            title: 'Discover the Marketplace',
            description: 'Browse properties, agricultural produce, and locally manufactured goods.',
          ),
          _OnboardingStep(
            icon: Icons.shopping_bag_outlined,
            title: 'Place Orders',
            description: 'Send RFQs, place bulk orders, and track deliveries in real time.',
          ),
          _OnboardingStep(
            icon: Icons.emoji_events_outlined,
            title: 'Earn Rewards',
            description: 'Complete daily challenges, earn XP, and unlock exclusive badges.',
          ),
        ];
    }
  }

  Future<void> _completeOnboarding() async {
    setState(() => _completing = true);
    try {
      await ref.read(apiServiceProvider).updateOnboarding(
            step: _steps.length,
            completed: true,
          );
    } catch (e) {
      debugPrint('Onboarding update failed: $e');
      // Best-effort – proceed to home even if the call fails
    }
    if (mounted) context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    final steps = _steps;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: steps.length,
                onPageChanged: (i) => setState(() => _currentStep = i),
                itemBuilder: (ctx, i) => _OnboardingPage(step: steps[i]),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                steps.length,
                (i) => AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 16),
                  width: i == _currentStep ? 24 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: i == _currentStep
                        ? Theme.of(context).colorScheme.primary
                        : Colors.grey[300],
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
              child: Row(
                children: [
                  if (_currentStep > 0)
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _pageController.previousPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        ),
                        child: const Text('Back'),
                      ),
                    ),
                  if (_currentStep > 0) const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: FilledButton(
                      onPressed: _completing
                          ? null
                          : _currentStep < steps.length - 1
                              ? () => _pageController.nextPage(
                                    duration: const Duration(milliseconds: 300),
                                    curve: Curves.easeInOut,
                                  )
                              : _completeOnboarding,
                      child: _completing
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              _currentStep < steps.length - 1
                                  ? 'Next'
                                  : 'Get Started',
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OnboardingStep {
  const _OnboardingStep({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;
}

class _OnboardingPage extends StatelessWidget {
  const _OnboardingPage({required this.step});

  final _OnboardingStep step;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 600),
            builder: (_, value, child) =>
                Opacity(opacity: value, child: child),
            child: Icon(
              step.icon,
              size: 120,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(height: 32),
          Text(
            step.title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 16),
          Text(
            step.description,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Colors.grey[600],
                ),
          ),
        ],
      ),
    );
  }
}
