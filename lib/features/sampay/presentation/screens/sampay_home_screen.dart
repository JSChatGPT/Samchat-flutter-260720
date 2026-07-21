import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/route_names.dart';
import '../../../settings/application/biometric_confirm.dart';
import '../../application/sampay_status_provider.dart';

/// Pushed from the shared shell's SAMPAY tab item (not a persisted tab
/// branch — the backend only exposes account link/unlink today, so there's
/// no dashboard content that would justify keeping its own navigation stack
/// alive in the background).
class SampayHomeScreen extends ConsumerWidget {
  const SampayHomeScreen({super.key});

  Future<void> _link(BuildContext context, WidgetRef ref) async {
    final confirmed = await confirmWithBiometricIfEnabled(
      ref,
      reason: 'Confirm to link your Sampay wallet',
    );
    if (!context.mounted || !confirmed) return;
    try {
      final url = await ref.read(sampayRepositoryProvider).getLinkUrl();
      if (context.mounted) {
        context.pushNamed(RouteNames.sampayLink, extra: url);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not start linking: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final sampay = ref.watch(sampayStatusProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Payment Settings'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
            onPressed: () => ref.read(sampayStatusProvider.notifier).refresh(),
          ),
        ],
      ),
      body: sampay.loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: scheme.surface,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 8, offset: const Offset(0, 2)),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: sampay.isLinked ? Colors.green : scheme.outlineVariant,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                sampay.isLinked ? Icons.account_balance_wallet_rounded : Icons.account_balance_wallet_outlined,
                                color: Colors.white,
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              sampay.isLinked ? 'Wallet Linked' : 'Wallet not linked',
                              style: textTheme.titleMedium,
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        if (sampay.isLinked) ...[
                          Text('Connected as ${sampay.account?.mobileNumber ?? ''}', style: textTheme.bodyMedium),
                          const SizedBox(height: 2),
                          Text(
                            '@${sampay.account?.username ?? ''}',
                            style: textTheme.bodySmall,
                          ),
                        ] else
                          Text(
                            'Link your SamPay account to send and receive payments in chat.',
                            style: textTheme.bodyMedium,
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () => _link(context, ref),
                    style: ElevatedButton.styleFrom(shape: const StadiumBorder()),
                    icon: const Icon(Icons.link_rounded, size: 18),
                    label: Text(sampay.isLinked ? 'Relink Sampay Wallet' : 'Link Sampay Wallet'),
                  ),
                  if (sampay.isLinked) ...[
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: () => ref.read(sampayStatusProvider.notifier).unlink(),
                      style: OutlinedButton.styleFrom(
                        shape: const StadiumBorder(),
                        foregroundColor: scheme.error,
                        side: BorderSide(color: scheme.error),
                      ),
                      icon: const Icon(Icons.link_off_rounded, size: 18),
                      label: const Text('Unlink Wallet'),
                    ),
                  ],
                ],
              ),
            ),
    );
  }
}
