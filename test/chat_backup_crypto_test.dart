import 'package:flutter_test/flutter_test.dart';
import 'package:samchat_flutter/core/crypto/backup/chat_backup_crypto.dart';

void main() {
  test('encrypt/decrypt round-trips with the correct password', () async {
    final blob = await ChatBackupCrypto.encrypt(
      password: 'correct horse battery staple',
      deviceId: 'device-123',
      privateKeyBase64: 'fake-private-key-base64==',
    );

    final result = await ChatBackupCrypto.decrypt(password: 'correct horse battery staple', blobJson: blob);

    expect(result, isNotNull);
    expect(result!.deviceId, 'device-123');
    expect(result.privateKeyBase64, 'fake-private-key-base64==');
  });

  test('decrypt returns null for a wrong password', () async {
    final blob = await ChatBackupCrypto.encrypt(
      password: 'right password',
      deviceId: 'device-123',
      privateKeyBase64: 'fake-key==',
    );

    final result = await ChatBackupCrypto.decrypt(password: 'wrong password', blobJson: blob);

    expect(result, isNull);
  });

  test('decrypt returns null for a malformed blob', () async {
    final result = await ChatBackupCrypto.decrypt(password: 'anything', blobJson: 'not even json');
    expect(result, isNull);
  });
}
