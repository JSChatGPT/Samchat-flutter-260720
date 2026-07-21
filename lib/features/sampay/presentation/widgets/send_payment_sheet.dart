import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl_phone_field/intl_phone_field.dart';

import '../../../chat_detail/application/chat_detail_notifier.dart';
import '../../../settings/application/biometric_confirm.dart';
import '../../application/sampay_status_provider.dart';

/// Preset purposes, kept in sync with the web chat payment modal's options.
const _purposeOptions = <String>[
  'Bill split',
  'Rent',
  'Groceries',
  'Loan repayment',
  'Gift',
  'Goods payment',
  'Service payment',
];

/// Bottom sheet to send a Sampay payment in a direct chat.
/// Returns nothing — success posts the `payment_request` message directly,
/// which arrives back into the chat via the existing MessageSent listener.
Future<void> showSendPaymentSheet(
  BuildContext context,
  WidgetRef ref, {
  required String chatId,
  String? prefillAccount,
  String? recipientUserId,
}) async {
  // Await the notifier's initial status fetch so the very first call site
  // (e.g. the first tap of "Send payment" in a fresh app session) doesn't
  // race the constructor's fire-and-forget refresh() and see the default
  // unloaded state (isLinked: false) before the real status arrives.
  await ref.read(sampayStatusProvider.notifier).ready;
  if (!context.mounted) return;
  final linkState = ref.read(sampayStatusProvider);
  if (!linkState.isLinked) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Link your Sampay account first, from Settings.'),
      ),
    );
    return;
  }

  final amountController = TextEditingController();
  String recipientAccount = prefillAccount ?? '';
  String? selectedPurpose;
  final purposeOtherController = TextEditingController();
  final remarksController = TextEditingController();
  String recipientType = 'personal';
  bool submitting = false;
  bool validating = false;
  bool syncing = false;
  String? error;

  await showModalBottomSheet(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, setState) {
          final scheme = Theme.of(ctx).colorScheme;

          Future<void> validate() async {
            final amount = double.tryParse(amountController.text.trim());
            final purpose = selectedPurpose == 'other'
                ? purposeOtherController.text.trim()
                : (selectedPurpose ?? '');
            if (recipientAccount.trim().isEmpty) {
              setState(() => error = 'Enter a recipient account first');
              return;
            }
            if (amount == null || amount <= 0) {
              setState(() => error = 'Enter a valid amount first');
              return;
            }
            if (purpose.isEmpty) {
              setState(() => error = 'Select or enter a purpose first');
              return;
            }
            setState(() {
              validating = true;
              error = null;
            });
            try {
              await ref
                  .read(sampayRepositoryProvider)
                  .validateRecipient(
                    chatId,
                    recipientType: recipientType,
                    recipientAccount: recipientAccount.trim(),
                    amount: amount,
                    purpose: purpose,
                    remarks: remarksController.text.trim(),
                    recipientUserId: recipientUserId,
                  );
              if (ctx.mounted) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(content: Text('Recipient looks valid')),
                );
              }
            } catch (e) {
              setState(() => error = 'Could not validate recipient: $e');
            } finally {
              if (ctx.mounted) setState(() => validating = false);
            }
          }

          Future<void> syncStatus() async {
            setState(() => syncing = true);
            try {
              await ref.read(sampayRepositoryProvider).syncStatus(chatId);
              if (ctx.mounted) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(content: Text('Payment status synced')),
                );
              }
            } catch (e) {
              if (ctx.mounted) {
                ScaffoldMessenger.of(
                  ctx,
                ).showSnackBar(SnackBar(content: Text('Sync failed: $e')));
              }
            } finally {
              if (ctx.mounted) setState(() => syncing = false);
            }
          }

          Future<void> submit() async {
            final amount = double.tryParse(amountController.text.trim());
            final purpose = selectedPurpose == 'other'
                ? purposeOtherController.text.trim()
                : (selectedPurpose ?? '');
            if (amount == null || amount <= 0) {
              setState(() => error = 'Enter a valid amount');
              return;
            }
            if (recipientAccount.trim().isEmpty || purpose.isEmpty) {
              setState(() => error = 'Fill in the recipient and purpose');
              return;
            }
            if (!context.mounted) return;
            setState(() {
              submitting = true;
              error = null;
            });
            final confirmed = await confirmWithBiometricIfEnabled(
              ref,
              reason: 'Confirm to send this payment',
            );
            if (!ctx.mounted) return;
            if (!confirmed) {
              setState(() {
                submitting = false;
                error = 'Fingerprint confirmation failed';
              });
              return;
            }
            try {
              final message = await ref
                  .read(sampayRepositoryProvider)
                  .requestPayment(
                    chatId,
                    amount: amount,
                    recipientType: recipientType,
                    recipientAccount: recipientAccount.trim(),
                    purpose: purpose,
                    remarks: remarksController.text.trim(),
                    recipientUserId: recipientUserId,
                  );
              ref
                  .read(chatDetailNotifierProvider(chatId).notifier)
                  .addSentMessage(message);
              if (ctx.mounted) Navigator.pop(ctx);
            } catch (e) {
              setState(() {
                submitting = false;
                error = 'Could not send request: $e';
              });
            }
          }

          return Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 8,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
            ),
            // Scrollable, not just size-to-min: with the keyboard up (the
            // recipient field autofocuses as soon as the sheet opens) this
            // form's fields + buttons don't all fit in the remaining height
            // on smaller screens, and a plain Column has no way to yield —
            // it just overflows past the bottom of the sheet.
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Send Payment',
                    style: Theme.of(ctx).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Send a Sampay payment directly from chat.',
                    style: Theme.of(ctx).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: recipientType,
                    decoration: const InputDecoration(
                      labelText: 'Recipient Type',
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'personal',
                        child: Text('Personal'),
                      ),
                    ],
                    onChanged: (value) =>
                        setState(() => recipientType = value ?? recipientType),
                  ),
                  const SizedBox(height: 12),
                  IntlPhoneField(
                    decoration: const InputDecoration(
                      labelText: 'Recipient Account',
                    ),
                    initialCountryCode: prefillAccount == null ? 'ZM' : null,
                    initialValue: prefillAccount,
                    invalidNumberMessage: 'Enter a valid phone number',
                    autofocus: true,
                    onChanged: (phone) =>
                        recipientAccount = phone.completeNumber,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: amountController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Amount (ZMW)',
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: selectedPurpose,
                    decoration: const InputDecoration(labelText: 'Purpose'),
                    items: [
                      for (final option in _purposeOptions)
                        DropdownMenuItem(value: option, child: Text(option)),
                      const DropdownMenuItem(
                        value: 'other',
                        child: Text('Other (specify)'),
                      ),
                    ],
                    onChanged: (value) =>
                        setState(() => selectedPurpose = value),
                  ),
                  if (selectedPurpose == 'other') ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: purposeOtherController,
                      autofocus: true,
                      maxLength: 120,
                      decoration: const InputDecoration(
                        labelText: 'Specify Purpose',
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  TextField(
                    controller: remarksController,
                    maxLength: 255,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Remarks (optional)',
                    ),
                  ),
                  if (error != null) ...[
                    const SizedBox(height: 4),
                    Text(error!, style: TextStyle(color: scheme.error)),
                  ],
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: validating ? null : validate,
                          style: OutlinedButton.styleFrom(
                            shape: const StadiumBorder(),
                          ),
                          child: validating
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text('Validate'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: submitting ? null : submit,
                          style: ElevatedButton.styleFrom(
                            shape: const StadiumBorder(),
                          ),
                          child: submitting
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text('Send'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Center(
                    child: TextButton.icon(
                      onPressed: syncing ? null : syncStatus,
                      icon: syncing
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.sync_rounded, size: 16),
                      label: const Text('Sync Payment Status'),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}
