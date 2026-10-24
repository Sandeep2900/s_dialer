import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:s_dialer/core/constants/app_colors.dart';
import 'package:s_dialer/core/services/phone_number_formatter.dart';
import 'package:s_dialer/core/services/t9_search_service.dart';
import 'package:s_dialer/core/services/vcf_service.dart';
import 'package:s_dialer/core/widgets/swipe_to_call_tile.dart';
import 'package:s_dialer/data/models/call_log_item.dart';
import 'package:s_dialer/data/models/contact_item.dart';
import 'package:s_dialer/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Unit Tests: ContactItem Edge Cases & Initials', () {
    test('ContactItem handles emojis and multi-code-point unicode without surrogate crashes', () {
      const emojiContact = ContactItem(
        id: '1',
        displayName: '❤️ Wife',
        phones: [ContactPhone(number: '+15551234567')],
      );
      expect(emojiContact.initials, '❤️W');

      const familyEmojiContact = ContactItem(
        id: '2',
        displayName: '👨‍👩‍👧 Family',
      );
      expect(familyEmojiContact.initials, '👨‍👩‍👧F');

      const hindiContact = ContactItem(
        id: '3',
        displayName: 'संदीप कुमार',
      );
      expect(hindiContact.initials, 'संकु');

      const singleName = ContactItem(
        id: '4',
        displayName: 'Sandeep',
      );
      expect(singleName.initials, 'S');

      const emptyName = ContactItem(
        id: '5',
        displayName: '   ',
      );
      expect(emptyName.initials, '?');
    });

    test('ContactItem primaryNumber selects default or first phone safely', () {
      const withDefault = ContactItem(
        id: '1',
        displayName: 'Test',
        phones: [
          ContactPhone(number: '111', isDefault: false),
          ContactPhone(number: '222', isDefault: true),
        ],
      );
      expect(withDefault.primaryNumber, '222');

      const withoutDefault = ContactItem(
        id: '2',
        displayName: 'Test 2',
        phones: [ContactPhone(number: '333')],
      );
      expect(withoutDefault.primaryNumber, '333');

      const emptyPhones = ContactItem(
        id: '3',
        displayName: 'No Phone',
      );
      expect(emptyPhones.primaryNumber, '');
    });
  });

  group('Unit Tests: PhoneNumberFormatter Edge Cases', () {
    test('PhoneNumberFormatter formats standard 10-digit number', () {
      expect(PhoneNumberFormatter.format('1234567890'), '(123) 456-7890');
      expect(PhoneNumberFormatter.format('1234567'), '123-4567');
      expect(PhoneNumberFormatter.format('+12345678901'), '+12 34567 8901');
    });

    test('PhoneNumberFormatter preserves USSD codes', () {
      expect(PhoneNumberFormatter.format('*#06#'), '*#06#');
      expect(PhoneNumberFormatter.format('*123#'), '*123#');
      expect(PhoneNumberFormatter.format('*99#'), '*99#');
    });

    test('PhoneNumberFormatter handles empty, whitespace, and short inputs', () {
      expect(PhoneNumberFormatter.format(''), '');
      expect(PhoneNumberFormatter.format('   '), '');
      expect(PhoneNumberFormatter.format('1'), '1');
      expect(PhoneNumberFormatter.format('12'), '12');
      expect(PhoneNumberFormatter.format('123'), '123');
      expect(PhoneNumberFormatter.format('+'), '+');
    });

    test('PhoneNumberFormatter normalize removes special formatting cleanly', () {
      expect(PhoneNumberFormatter.normalize('(123) 456-7890'), '1234567890');
      expect(PhoneNumberFormatter.normalize('  +1 (555) 234-5678 '), '+15552345678');
      expect(PhoneNumberFormatter.normalize('*#06#'), '*#06#');
      expect(PhoneNumberFormatter.normalize(''), '');
    });
  });

  group('Unit Tests: T9SearchService Edge Cases', () {
    test('T9SearchService correctly maps names and matches queries', () {
      expect(T9SearchService.textToT9('Alice'), '25423');
      expect(T9SearchService.textToT9('Bob'), '262');
      expect(T9SearchService.textToT9('John Doe'), '5646 363');

      // T9 Name matching
      final matches = T9SearchService.matches(
        queryDigits: '25423',
        displayName: 'Alice Johnson',
        phoneNumbers: ['+1 (555) 234-5678'],
      );
      expect(matches, isTrue);

      // Number substring matching
      final numberMatch = T9SearchService.matches(
        queryDigits: '234',
        displayName: 'Unknown',
        phoneNumbers: ['+1 (555) 234-5678'],
      );
      expect(numberMatch, isTrue);
    });

    test('T9SearchService word initials matching', () {
      // John Doe initials: JD -> '53'
      expect(
        T9SearchService.matches(
          queryDigits: '53',
          displayName: 'John Doe',
          phoneNumbers: [],
        ),
        isTrue,
      );

      // Empty query returns false
      expect(
        T9SearchService.matches(
          queryDigits: '',
          displayName: 'Alice',
          phoneNumbers: ['12345'],
        ),
        isFalse,
      );
    });

    test('T9SearchService handles non-ascii and emoji text safely', () {
      expect(T9SearchService.textToT9('❤️ Bob'), '❤️ 262');
      expect(
        T9SearchService.matches(
          queryDigits: '262',
          displayName: '❤️ Bob',
          phoneNumbers: [],
        ),
        isTrue,
      );
    });
  });

  group('Unit Tests: AppColors Avatar Color Edge Cases', () {
    test('getAvatarColor returns valid color for null, empty, and unusual strings', () {
      expect(AppColors.getAvatarColor(null), AppColors.primaryBlue);
      expect(AppColors.getAvatarColor('   '), AppColors.primaryBlue);
      expect(AppColors.getAvatarColor('A'), isNotNull);
      expect(AppColors.getAvatarColor('A very long string with unicode 🚀 🌟 1234567890'), isNotNull);
    });
  });

  group('Unit Tests: CallLogItem Edge Cases & Duration Formatting', () {
    test('CallLogItem formats durations accurately', () {
      final zeroSec = CallLogItem(
        id: '1',
        number: '123',
        type: CallType.incoming,
        timestamp: DateTime.now(),
        durationSeconds: 0,
      );
      expect(zeroSec.formattedDuration, '0s');

      final underOneMin = CallLogItem(
        id: '2',
        number: '123',
        type: CallType.outgoing,
        timestamp: DateTime.now(),
        durationSeconds: 45,
      );
      expect(underOneMin.formattedDuration, '45s');

      final overOneMin = CallLogItem(
        id: '3',
        number: '123',
        type: CallType.incoming,
        timestamp: DateTime.now(),
        durationSeconds: 150,
      );
      expect(overOneMin.formattedDuration, '2m 30s');
    });

    test('CallLogItem displayTitle falls back to Unknown when empty', () {
      final item = CallLogItem(
        id: '1',
        number: '',
        name: null,
        type: CallType.missed,
        timestamp: DateTime.now(),
      );
      expect(item.displayTitle, 'Unknown');
    });
  });

  group('Unit Tests: VcfService Export and Import', () {
    test('VcfService exports contacts and imports them back accurately', () {
      final contacts = [
        const ContactItem(
          id: '1',
          displayName: 'Jane Doe',
          firstName: 'Jane',
          lastName: 'Doe',
          company: 'Acme Corp',
          phones: [ContactPhone(number: '+15551234567', label: 'Mobile')],
          emails: [ContactEmail(address: 'jane@example.com')],
          notes: 'Test note',
        ),
      ];

      final vcfString = VcfService.exportToVcf(contacts);
      expect(vcfString.contains('BEGIN:VCARD'), isTrue);
      expect(vcfString.contains('FN:Jane Doe'), isTrue);
      expect(vcfString.contains('+15551234567'), isTrue);

      final imported = VcfService.importFromVcf(vcfString);
      expect(imported.length, 1);
      expect(imported.first.displayName, 'Jane Doe');
      expect(imported.first.company, 'Acme Corp');
      expect(imported.first.phones.first.number, '+15551234567');
      expect(imported.first.emails.first.address, 'jane@example.com');
      expect(imported.first.notes, 'Test note');
    });
  });

  group('Widget Tests: SwipeToCallTile & Navigation', () {
    testWidgets('SwipeToCallTile triggers swipe right (call) gesture', (tester) async {
      bool callTriggered = false;
      bool smsTriggered = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              height: 80,
              child: SwipeToCallTile(
                onSwipeRight: () => callTriggered = true,
                onSwipeLeft: () => smsTriggered = true,
                child: const ListTile(title: Text('Test Contact')),
              ),
            ),
          ),
        ),
      );

      // Drag right across 50% width
      await tester.drag(find.text('Test Contact'), const Offset(220, 0));
      await tester.pumpAndSettle();

      expect(callTriggered, isTrue);
      expect(smsTriggered, isFalse);
    });

    testWidgets('Full SamDialer smoke test across 3 tabs and Keypad input',
        (tester) async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('github.com/QuisApp/flutter_contacts'),
        (MethodCall call) async {
          if (call.method == 'requestPermission') return false;
          return null;
        },
      );
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('com.example.s_dialer/telephony'),
        (MethodCall call) async {
          if (call.method == 'getCallLogs') return [];
          return null;
        },
      );

      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.625;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const ProviderScope(
          child: SamDialerApp(),
        ),
      );
      await tester.pumpAndSettle();

      // Verify bottom navigation tabs exist
      expect(find.text('Keypad'), findsWidgets);
      expect(find.text('Recents'), findsOneWidget);
      expect(find.text('Contacts'), findsOneWidget);

      // Tap digits 5, 5, 5 on Keypad
      await tester.tap(find.byKey(const Key('keypad_digit_5')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('keypad_digit_5')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('keypad_digit_5')));
      await tester.pump();

      expect(find.text('555'), findsOneWidget);

      // Tap backspace
      await tester.tap(find.byKey(const Key('keypad_backspace_button')));
      await tester.pump();
      expect(find.text('55'), findsOneWidget);

      // Switch to Contacts tab
      await tester.tap(find.text('Contacts'));
      await tester.pumpAndSettle();
      expect(find.text('My Profile'), findsOneWidget);
      expect(find.text('Alice Johnson'), findsWidgets);

      // Switch to Recents tab
      await tester.tap(find.text('Recents'));
      await tester.pumpAndSettle();
      expect(find.text('Recents'), findsWidgets);
    });
  });
}
