import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:telnyx_webrtc/model/verto/send/anonymous_login_message.dart';
import 'package:telnyx_webrtc/model/verto/send/attach_call_message.dart';
import 'package:telnyx_webrtc/model/verto/send/invite_answer_message_body.dart';
import 'package:telnyx_webrtc/model/verto/send/login_message_body.dart';
import 'package:telnyx_webrtc/utils/version_utils.dart';

void main() {
  const name = 'webrtc-flutter';
  final version = VersionUtils.getSDKVersion();

  void expectWireIdentity(Object message) {
    final encoded = jsonEncode(message);
    final decoded = jsonDecode(encoded) as Map<String, dynamic>;
    final params = decoded['params'] as Map<String, dynamic>;
    expect(params['mobile_sdk_name'], name);
    expect(params['mobile_sdk_version'], version);
  }

  test('credential and token login encode identity in top-level params', () {
    for (final params in [
      LoginParams(
          login: 'user',
          passwd: 'pass',
          mobileSdkName: name,
          mobileSdkVersion: version),
      LoginParams(
          loginToken: 'token', mobileSdkName: name, mobileSdkVersion: version),
    ]) {
      expectWireIdentity(LoginMessage(
          id: '1', jsonrpc: '2.0', method: 'login', params: params));
    }
  });

  test('anonymous login encodes identity in top-level params', () {
    expectWireIdentity(AnonymousLoginMessage(
      id: '1',
      jsonrpc: '2.0',
      method: 'anonymous_login',
      params: AnonymousLoginParams(
        targetType: 'ai_assistant',
        targetId: 'target',
        mobileSdkName: name,
        mobileSdkVersion: version,
      ),
    ));
  });

  test('invite, answer, and attach encode identity in top-level params', () {
    for (final method in ['invite', 'answer', 'attach']) {
      expectWireIdentity(InviteAnswerMessage(
        id: '1',
        jsonrpc: '2.0',
        method: method,
        params: InviteParams(mobileSdkName: name, mobileSdkVersion: version),
      ));
    }
    expectWireIdentity(AttachCallMessage(
      id: '1',
      jsonrpc: '2.0',
      method: 'attach_call',
      params: Params(
        userVariables: const {},
        mobileSdkName: name,
        mobileSdkVersion: version,
      ),
    ));
  });

  test('unrelated params do not gain identity implicitly', () {
    final params = LoginParams(login: 'user', passwd: 'pass').toJson();
    expect(params, isNot(contains('mobile_sdk_name')));
    expect(params, isNot(contains('mobile_sdk_version')));
  });
}
