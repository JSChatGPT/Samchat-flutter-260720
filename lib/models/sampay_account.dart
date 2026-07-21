import '../core/utils/json_utils.dart';

class SampayAccount {
  const SampayAccount({required this.username, required this.mobileNumber});

  final String username;
  final String mobileNumber;

  factory SampayAccount.fromJson(Map<String, dynamic> json) {
    return SampayAccount(
      username: asString(json['username']),
      mobileNumber: asString(json['mobile_number']),
    );
  }
}

/// Mirrors a `payment_request` message's `metadata.status` state machine.
enum SampayRequestStatus {
  pending,
  pendingApproval,
  submittedToSampay,
  approved,
  rejected,
  failed,
  unknown,
}

SampayRequestStatus sampayStatusFromString(String? raw) {
  switch (raw) {
    case 'pending':
      return SampayRequestStatus.pending;
    case 'pending_approval':
      return SampayRequestStatus.pendingApproval;
    case 'submitted_to_sampay':
      return SampayRequestStatus.submittedToSampay;
    case 'approved':
      return SampayRequestStatus.approved;
    case 'rejected':
      return SampayRequestStatus.rejected;
    case 'failed':
      return SampayRequestStatus.failed;
    default:
      return SampayRequestStatus.unknown;
  }
}

extension SampayRequestStatusX on SampayRequestStatus {
  bool get isTerminal =>
      this == SampayRequestStatus.approved ||
      this == SampayRequestStatus.rejected ||
      this == SampayRequestStatus.failed;

  String get label {
    switch (this) {
      case SampayRequestStatus.pending:
        return 'Pending';
      case SampayRequestStatus.pendingApproval:
        return 'Awaiting approval';
      case SampayRequestStatus.submittedToSampay:
        return 'Processing';
      case SampayRequestStatus.approved:
        return 'Approved';
      case SampayRequestStatus.rejected:
        return 'Rejected';
      case SampayRequestStatus.failed:
        return 'Failed';
      case SampayRequestStatus.unknown:
        return 'Unknown';
    }
  }
}
