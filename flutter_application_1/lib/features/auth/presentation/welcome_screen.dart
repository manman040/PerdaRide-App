import 'package:flutter/material.dart';

import '../../../app/app_router.dart';
import '../../../core/settings/app_copy.dart';
import '../../../core/widgets/auth_gradient_scaffold.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  bool _showSignUpOptions = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final copy = AppCopy.of(context);
    return AuthGradientScaffold(
      header: Row(
        children: [
          const Spacer(),
          IconButton(
            onPressed: () {},
            icon: Icon(
              Icons.more_horiz_rounded,
              color: theme.colorScheme.onSurface,
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(28, 36, 28, 32),
        child: Column(
          children: [
            const Spacer(),
            Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                color: const Color(0xFF121212),
                borderRadius: BorderRadius.circular(18),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x22000000),
                    blurRadius: 18,
                    offset: Offset(0, 10),
                  ),
                ],
              ),
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.local_taxi_rounded,
                    size: 34,
                    color: Color(0xFFF68B1F),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Urban Drive',
                    style: TextStyle(
                      color: Color(0xFFF68B1F),
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 36),
            Text(
              copy.welcomeBack,
              style: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              copy.welcomeTagline,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                height: 1.5,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 40),
            _WelcomeActionButton(
              label: copy.loginCta,
              filled: true,
              onPressed: () {
                Navigator.of(context).pushNamed(AppRouter.login);
              },
            ),
            const SizedBox(height: 14),
            _WelcomeActionButton(
              label: _showSignUpOptions ? copy.closeSignUpCta : copy.signUpCta,
              filled: false,
              onPressed: () {
                setState(() {
                  _showSignUpOptions = !_showSignUpOptions;
                });
              },
            ),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              child: _showSignUpOptions
                  ? Padding(
                      key: const ValueKey('welcome-sign-up-options'),
                      padding: const EdgeInsets.only(top: 18),
                      child: Column(
                        children: [
                          _RoleFloatingButton(
                            label: copy.registerAsUser,
                            icon: Icons.person_outline_rounded,
                            onTap: () {
                              Navigator.of(context).pushNamed(
                                AppRouter.userRegistration,
                              );
                            },
                          ),
                          const SizedBox(height: 12),
                          _RoleFloatingButton(
                            label: copy.registerAsDriver,
                            icon: Icons.drive_eta_outlined,
                            onTap: () {
                              Navigator.of(context).pushNamed(
                                AppRouter.driverRegistration,
                              );
                            },
                          ),
                        ],
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
            const Spacer(),
          ],
        ),
      ),
    );
  }
}

class _WelcomeActionButton extends StatelessWidget {
  const _WelcomeActionButton({
    required this.label,
    required this.onPressed,
    required this.filled,
  });

  final String label;
  final VoidCallback onPressed;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final child = SizedBox(
      width: double.infinity,
      height: 54,
      child: Center(
        child: Text(
          label,
          style: TextStyle(
            color: filled ? Colors.white : const Color(0xFFF68B1F),
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
          ),
        ),
      ),
    );

    if (filled) {
      return DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xFFF68B1F),
          borderRadius: BorderRadius.circular(28),
          boxShadow: const [
            BoxShadow(
              color: Color(0x18000000),
              blurRadius: 18,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(28),
          onTap: onPressed,
          child: child,
        ),
      );
    }

    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(double.infinity, 54),
        foregroundColor: const Color(0xFFF68B1F),
        side: const BorderSide(color: Color(0xFFF68B1F), width: 1.4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28),
        ),
      ),
      child: Text(label),
    );
  }
}

class _RoleFloatingButton extends StatelessWidget {
  const _RoleFloatingButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Align(
      alignment: Alignment.centerRight,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(28),
          child: Ink(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(28),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x1A000000),
                  blurRadius: 14,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 18, color: const Color(0xFFF68B1F)),
                const SizedBox(width: 10),
                Text(
                  label,
                  style: TextStyle(
                    color: theme.colorScheme.onSurface,
                    fontWeight: FontWeight.w700,
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
