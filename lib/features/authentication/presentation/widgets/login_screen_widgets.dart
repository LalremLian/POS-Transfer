import 'package:flutter/material.dart';

class LoginHeader extends StatelessWidget {
  const LoginHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Column(
      children: [
        Icon(
          Icons.cloud_sync_rounded,
          size: 56,
          color: cs.primary,
        ),
        const SizedBox(height: 16),
        Text(
          'POS Transfer',
          style: theme.textTheme.headlineMedium?.copyWith(
            color: cs.onSurface,
            fontWeight: FontWeight.w700,
          ),
          textAlign: TextAlign.center,
        ),
        Text(
          'Reliable file transfers for your POS system',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: cs.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

/// Segmented toggle for switching between Log in and Register mode.
class LoginModeToggle extends StatelessWidget {
  const LoginModeToggle({
    super.key,
    required this.isRegisterMode,
    required this.onChanged,
  });

  final bool isRegisterMode;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<bool>(
      segments: const [
        ButtonSegment(value: false, label: Text('Log in')),
        ButtonSegment(value: true, label: Text('Register')),
      ],
      selected: {isRegisterMode},
      onSelectionChanged: (s) => onChanged(s.first),
    );
  }
}

/// Error banner widget displaying auth error messages.
class AuthErrorBanner extends StatelessWidget {
  const AuthErrorBanner({super.key, required this.error});

  final String error;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.errorContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: cs.onErrorContainer, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              error,
              style: TextStyle(color: cs.onErrorContainer, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

/// Footer note for HTTP connection security warning.
class SecurityNote extends StatelessWidget {
  const SecurityNote({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.info_outline, size: 14, color: cs.onSurfaceVariant),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            'Connection is HTTP only. See README for details.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: cs.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }
}
