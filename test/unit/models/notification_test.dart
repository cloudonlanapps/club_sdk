import 'package:club_sdk_2/club_sdk_2.dart';
import 'package:test/test.dart';

/// Notification Model Unit Tests (NotificationChannel, AppNotification,
/// NotificationPref, PendingActionType).
///
/// Tests requirements from Section 20 (SDK Architecture):
/// - 20.06: Immutable Models - copyWith pattern for immutable updates
/// - 20.07: JSON Serialization - toMap/fromMap, toJson/fromJson roundtrip
/// - 20.08: Value Equality - operator==, hashCode implementation
void main() {
  group('NotificationChannel', () {
    test('values contains all expected channels', () {
      expect(
        NotificationChannel.values,
        containsAll([
          NotificationChannel.email,
          NotificationChannel.push,
          NotificationChannel.sms,
          NotificationChannel.otp,
          NotificationChannel.inApp,
        ]),
      );
    });

    test('fromName parses email channel', () {
      expect(NotificationChannel.fromName('email'), NotificationChannel.email);
    });

    test('fromName parses push channel', () {
      expect(NotificationChannel.fromName('push'), NotificationChannel.push);
    });

    test('fromName parses sms channel', () {
      expect(NotificationChannel.fromName('sms'), NotificationChannel.sms);
    });

    test('fromName parses otp channel', () {
      expect(NotificationChannel.fromName('otp'), NotificationChannel.otp);
    });

    test('fromName parses inApp channel', () {
      expect(NotificationChannel.fromName('inApp'), NotificationChannel.inApp);
    });

    test('fromName parses in_app as inApp', () {
      expect(NotificationChannel.fromName('in_app'), NotificationChannel.inApp);
    });

    test('fromName defaults to inApp for unknown value', () {
      expect(
        NotificationChannel.fromName('unknown'),
        NotificationChannel.inApp,
      );
    });
  });

  group('PendingActionType', () {
    test('wire names match server contract', () {
      expect(
        PendingActionType.groupJoinRequest.wireName,
        'group_join_request',
      );
      expect(
        PendingActionType.enrollmentOpportunity.wireName,
        'enrollment_opportunity',
      );
      expect(
        PendingActionType.enrollmentRequest.wireName,
        'enrollment_request',
      );
      expect(
        PendingActionType.attendanceCorrection.wireName,
        'attendance_correction',
      );
      expect(
        PendingActionType.userApproval.wireName,
        'user_approval',
      );
    });

    test('fromWire parses known values', () {
      expect(
        PendingActionType.fromWire('group_join_request'),
        PendingActionType.groupJoinRequest,
      );
      expect(
        PendingActionType.fromWire('enrollment_opportunity'),
        PendingActionType.enrollmentOpportunity,
      );
      expect(
        PendingActionType.fromWire('enrollment_request'),
        PendingActionType.enrollmentRequest,
      );
      expect(
        PendingActionType.fromWire('attendance_correction'),
        PendingActionType.attendanceCorrection,
      );
      expect(
        PendingActionType.fromWire('user_approval'),
        PendingActionType.userApproval,
      );
      // Retired server-side (club_server d39aa3b stopped emitting it), so
      // the wire value must no longer resolve to a type.
      expect(PendingActionType.fromWire('user_reconsider_request'), isNull);
    });


    test('Issue 358: fromWire round-trips every variant', () {
      for (final v in PendingActionType.values) {
        expect(PendingActionType.fromWire(v.wireName), v);
      }
    });

    test('Issue 358: enrollment_request and enrollment_opportunity are '
        'distinct variants', () {
      expect(
        PendingActionType.fromWire('enrollment_request'),
        isNot(PendingActionType.enrollmentOpportunity),
      );
    });

    test('fromWire returns null for null or unknown', () {
      expect(PendingActionType.fromWire(null), isNull);
      expect(PendingActionType.fromWire('something_else'), isNull);
    });
  });

  group('NotificationChannelSupport', () {
    const support = NotificationChannelSupport();

    test('two instances with same values are equal', () {
      const sameSupport = NotificationChannelSupport();

      expect(support, sameSupport);
    });

    test('two instances with different values are not equal', () {
      const differentSupport = NotificationChannelSupport(
        emailSupported: false,
        pushSupported: false,
        smsSupported: true,
        otpSupported: true,
        inAppSupported: false,
      );

      expect(support, isNot(differentSupport));
    });

    test('equal instances have same hashCode', () {
      const sameSupport = NotificationChannelSupport();

      expect(support.hashCode, sameSupport.hashCode);
    });

    test('isSupported returns correct value for each channel', () {
      expect(support.isSupported(NotificationChannel.email), isTrue);
      expect(support.isSupported(NotificationChannel.push), isTrue);
      expect(support.isSupported(NotificationChannel.sms), isFalse);
      expect(support.isSupported(NotificationChannel.otp), isFalse);
      expect(support.isSupported(NotificationChannel.inApp), isTrue);
    });

    test('supportedChannels returns only supported channels', () {
      final supported = support.supportedChannels;
      expect(supported, contains(NotificationChannel.email));
      expect(supported, contains(NotificationChannel.push));
      expect(supported, contains(NotificationChannel.inApp));
      expect(supported, isNot(contains(NotificationChannel.sms)));
      expect(supported, isNot(contains(NotificationChannel.otp)));
    });

    test('copyWith creates new instance with changed field', () {
      final updated = support.copyWith(smsSupported: true);
      expect(updated.emailSupported, support.emailSupported);
      expect(updated.smsSupported, isTrue);
    });

    test('toMap produces correct map structure', () {
      final map = support.toMap();
      expect(map['emailSupported'], true);
      expect(map['pushSupported'], true);
      expect(map['smsSupported'], false);
      expect(map['otpSupported'], false);
      expect(map['inAppSupported'], true);
    });

    test('fromMap restores equivalent instance', () {
      final map = support.toMap();
      final fromMap = NotificationChannelSupport.fromMap(map);
      expect(fromMap, support);
    });

    test('toMap/fromMap roundtrip preserves all fields', () {
      final restored = NotificationChannelSupport.fromMap(support.toMap());
      expect(restored, support);
    });

    test('toJson/fromJson roundtrip preserves all fields', () {
      final json = support.toJson();
      final fromJson = NotificationChannelSupport.fromJson(json);
      expect(fromJson, support);
    });

    test('fromMap uses defaults when fields missing', () {
      final fromMap = NotificationChannelSupport.fromMap(const {});
      expect(fromMap.emailSupported, true);
      expect(fromMap.pushSupported, true);
      expect(fromMap.smsSupported, false);
      expect(fromMap.otpSupported, false);
      expect(fromMap.inAppSupported, true);
    });
  });

  group('AppNotification', () {
    final now = DateTime.utc(2024, 6, 15, 10);
    final payload = <String, dynamic>{
      'v': 1,
      'type': 'enrollment.invited',
      'data': {
        'title': 'You have been invited',
        'eventId': 42,
      },
    };
    final notification = AppNotification(
      id: 1,
      username: 'user-1',
      type: 'enrollment.invited',
      channel: NotificationChannel.push,
      payload: payload,
      isRead: false,
      createdAtUtc: now,
      pendingActionType: PendingActionType.enrollmentOpportunity,
      pendingActionId: 99,
      broadcastId: 7,
    );

    test('two instances with same values are equal', () {
      final sameNotification = AppNotification(
        id: 1,
        username: 'user-1',
        type: 'enrollment.invited',
        channel: NotificationChannel.push,
        payload: const <String, dynamic>{
          'v': 1,
          'type': 'enrollment.invited',
          'data': <String, dynamic>{
            'title': 'You have been invited',
            'eventId': 42,
          },
        },
        isRead: false,
        createdAtUtc: now,
        pendingActionType: PendingActionType.enrollmentOpportunity,
        pendingActionId: 99,
        broadcastId: 7,
      );

      expect(notification, sameNotification);
    });

    test('two instances with different payload data are not equal', () {
      final differentPayload = notification.copyWith(
        payload: <String, dynamic>{
          'v': 1,
          'type': 'enrollment.invited',
          'data': {'title': 'Different'},
        },
      );
      expect(notification, isNot(differentPayload));
    });

    test('two instances with different scalar values are not equal', () {
      final differentNotification = AppNotification(
        id: 2,
        username: 'user-2',
        type: 'group.created',
        channel: NotificationChannel.email,
        payload: const {},
        isRead: true,
        createdAtUtc: now,
      );

      expect(notification, isNot(differentNotification));
    });

    test('equal instances have same hashCode', () {
      final sameNotification = AppNotification(
        id: 1,
        username: 'user-1',
        type: 'enrollment.invited',
        channel: NotificationChannel.push,
        payload: const <String, dynamic>{
          'v': 1,
          'type': 'enrollment.invited',
          'data': <String, dynamic>{
            'title': 'You have been invited',
            'eventId': 42,
          },
        },
        isRead: false,
        createdAtUtc: now,
        pendingActionType: PendingActionType.enrollmentOpportunity,
        pendingActionId: 99,
        broadcastId: 7,
      );

      expect(notification.hashCode, sameNotification.hashCode);
    });

    test('copyWith creates new instance with changed scalar', () {
      final updated = notification.copyWith(isRead: true);
      expect(updated.id, notification.id);
      expect(updated.isRead, isTrue);
      expect(updated.payload, notification.payload);
    });

    test('copyWith clears nullable pendingActionType via ValueGetter', () {
      final cleared = notification.copyWith(
        pendingActionType: () => null,
        pendingActionId: () => null,
      );
      expect(cleared.pendingActionType, isNull);
      expect(cleared.pendingActionId, isNull);
      // unrelated fields preserved
      expect(cleared.broadcastId, 7);
      expect(cleared.id, 1);
    });

    test('copyWith clears nullable broadcastId via ValueGetter', () {
      final cleared = notification.copyWith(broadcastId: () => null);
      expect(cleared.broadcastId, isNull);
      expect(cleared.pendingActionType, notification.pendingActionType);
    });

    test('copyWith preserves unchanged fields', () {
      final updated = notification.copyWith(isRead: true);
      expect(updated.id, 1);
      expect(updated.username, 'user-1');
      expect(updated.type, 'enrollment.invited');
      expect(updated.channel, NotificationChannel.push);
      expect(
        updated.pendingActionType,
        PendingActionType.enrollmentOpportunity,
      );
      expect(updated.pendingActionId, 99);
      expect(updated.broadcastId, 7);
    });

    test('toMap produces correct map structure', () {
      final map = notification.toMap();
      expect(map['id'], 1);
      expect(map['username'], 'user-1');
      expect(map['type'], 'enrollment.invited');
      expect(map['channel'], 'push');
      expect(map['payload'], payload);
      expect(map['pendingActionType'], 'enrollment_opportunity');
      expect(map['pendingActionId'], 99);
      expect(map['broadcastId'], 7);
      expect(map['isRead'], false);
      expect(map['createdAtUtc'], isA<int>());
    });

    test('toMap encodes null pending-action fields as null', () {
      final plain = AppNotification(
        id: 5,
        username: 'user-1',
        type: 'event.cancelled',
        channel: NotificationChannel.inApp,
        payload: const {
          'v': 1,
          'type': 'event.cancelled',
          'data': <String, dynamic>{},
        },
        isRead: false,
        createdAtUtc: now,
      );
      final map = plain.toMap();
      expect(map['pendingActionType'], isNull);
      expect(map['pendingActionId'], isNull);
      expect(map['broadcastId'], isNull);
    });

    test('fromMap restores equivalent instance', () {
      final map = notification.toMap();
      final fromMap = AppNotification.fromMap(map);
      expect(fromMap, notification);
    });

    test('toMap/fromMap roundtrip preserves all fields', () {
      final restored = AppNotification.fromMap(notification.toMap());
      expect(restored, notification);
    });

    test('toJson/fromJson roundtrip preserves all fields', () {
      final json = notification.toJson();
      final fromJson = AppNotification.fromJson(json);
      expect(fromJson, notification);
    });

    test('fromMap handles isRead default to false', () {
      final map = {
        'id': 1,
        'username': 'user-1',
        'type': 'group.created',
        'channel': 'push',
        'payload': const {
          'v': 1,
          'type': 'group.created',
          'data': <String, dynamic>{},
        },
        'createdAtUtc': now.millisecondsSinceEpoch,
      };
      final n = AppNotification.fromMap(map);
      expect(n.isRead, false);
    });

    test('fromMap handles missing payload as empty map', () {
      final map = {
        'id': 1,
        'username': 'user-1',
        'type': 'group.created',
        'channel': 'push',
        'createdAtUtc': now.millisecondsSinceEpoch,
      };
      final n = AppNotification.fromMap(map);
      expect(n.payload, isEmpty);
    });

    test('fromMap parses pendingActionType wire value', () {
      final map = {
        'id': 1,
        'username': 'user-1',
        'type': 'group.join_request',
        'channel': 'inApp',
        'payload': const {
          'v': 1,
          'type': 'group.join_request',
          'data': <String, dynamic>{},
        },
        'pendingActionType': 'group_join_request',
        'pendingActionId': 12,
        'createdAtUtc': now.millisecondsSinceEpoch,
      };
      final n = AppNotification.fromMap(map);
      expect(n.pendingActionType, PendingActionType.groupJoinRequest);
      expect(n.pendingActionId, 12);
    });

    test('Issue 355: toMap/fromMap roundtrip preserves pendingActionKey', () {
      final withKey = AppNotification(
        id: 10,
        username: 'admin-1',
        type: 'user.registration_pending',
        channel: NotificationChannel.inApp,
        payload: const {
          'v': 1,
          'type': 'user.registration_pending',
          'data': <String, dynamic>{},
        },
        isRead: false,
        createdAtUtc: now,
        pendingActionType: PendingActionType.userApproval,
        pendingActionKey: 'pending-user',
      );
      final map = withKey.toMap();
      expect(map['pendingActionKey'], 'pending-user');
      expect(map['pendingActionType'], 'user_approval');
      expect(map['pendingActionId'], isNull);
      final restored = AppNotification.fromMap(map);
      expect(restored, withKey);
      expect(restored.pendingActionKey, 'pending-user');
    });

    test('Issue 355: pendingActionKey defaults to null when absent', () {
      expect(notification.pendingActionKey, isNull);
      final map = notification.toMap();
      expect(map.containsKey('pendingActionKey'), isTrue);
      expect(map['pendingActionKey'], isNull);
      final restored = AppNotification.fromMap(map);
      expect(restored.pendingActionKey, isNull);
      expect(restored, notification);
    });

    test('Issue 355: copyWith clears pendingActionKey via ValueGetter', () {
      final withKey = notification.copyWith(
        pendingActionKey: () => 'some-user',
      );
      expect(withKey.pendingActionKey, 'some-user');
      final cleared = withKey.copyWith(pendingActionKey: () => null);
      expect(cleared.pendingActionKey, isNull);
      expect(cleared.pendingActionId, notification.pendingActionId);
      expect(cleared.broadcastId, notification.broadcastId);
    });

    test('fromMap returns null pendingActionType for unknown wire value', () {
      final map = {
        'id': 1,
        'username': 'user-1',
        'type': 'group.created',
        'channel': 'inApp',
        'payload': const {
          'v': 1,
          'type': 'group.created',
          'data': <String, dynamic>{},
        },
        'pendingActionType': 'unknown_action',
        'createdAtUtc': now.millisecondsSinceEpoch,
      };
      final n = AppNotification.fromMap(map);
      expect(n.pendingActionType, isNull);
    });
  });

  group('NotificationPref', () {
    const pref = NotificationPref(
      username: 'user-1',
      emailEnabled: true,
      pushEnabled: true,
      smsEnabled: false,
    );

    test('two instances with same values are equal', () {
      const samePref = NotificationPref(
        username: 'user-1',
        emailEnabled: true,
        pushEnabled: true,
        smsEnabled: false,
      );

      expect(pref, samePref);
    });

    test('two instances with different values are not equal', () {
      const differentPref = NotificationPref(
        username: 'user-2',
        emailEnabled: false,
        pushEnabled: false,
        smsEnabled: true,
      );

      expect(pref, isNot(differentPref));
    });

    test('equal instances have same hashCode', () {
      const samePref = NotificationPref(
        username: 'user-1',
        emailEnabled: true,
        pushEnabled: true,
        smsEnabled: false,
      );

      expect(pref.hashCode, samePref.hashCode);
    });

    test('copyWith creates new instance with changed field', () {
      final updated = pref.copyWith(smsEnabled: true);
      expect(updated.username, pref.username);
      expect(updated.smsEnabled, isTrue);
    });

    test('toMap produces correct map structure', () {
      final map = pref.toMap();
      expect(map['username'], 'user-1');
      expect(map['emailEnabled'], true);
      expect(map['pushEnabled'], true);
      expect(map['smsEnabled'], false);
    });

    test('fromMap restores equivalent instance', () {
      final map = pref.toMap();
      final fromMap = NotificationPref.fromMap(map);
      expect(fromMap, pref);
    });

    test('toMap/fromMap roundtrip preserves all fields', () {
      final restored = NotificationPref.fromMap(pref.toMap());
      expect(restored, pref);
    });

    test('toJson/fromJson roundtrip preserves all fields', () {
      final json = pref.toJson();
      final fromJson = NotificationPref.fromJson(json);
      expect(fromJson, pref);
    });

    test('fromMap uses defaults when fields missing', () {
      final fromMap = NotificationPref.fromMap(const {'username': 'user-1'});
      expect(fromMap.emailEnabled, true);
      expect(fromMap.pushEnabled, true);
      expect(fromMap.smsEnabled, false);
    });
  });
}
