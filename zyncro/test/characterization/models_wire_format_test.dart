// CONTRAT DE FORMAT FIRESTORE (docs/refactor/PLAN.md §1, règle n°2).
//
// Ces tests figent EXACTEMENT les cartes écrites et lues par la v1.1.3 :
// mêmes clés, mêmes omissions conditionnelles, mêmes types. Les futurs DTO
// et mappers (étape 4) doivent les faire passer sans modification.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zyncro/features/calendar/data/mappers/event_mapper.dart';
import 'package:zyncro/features/calendar/domain/entities/event.dart';
import 'package:zyncro/features/chat/data/mappers/message_mapper.dart';
import 'package:zyncro/features/chat/domain/entities/message.dart';
import 'package:zyncro/features/expenses/data/mappers/expense_mapper.dart';
import 'package:zyncro/features/expenses/domain/entities/expense.dart';
import 'package:zyncro/features/groups/data/mappers/group_mapper.dart';
import 'package:zyncro/features/groups/data/mappers/group_member_mapper.dart';
import 'package:zyncro/features/groups/domain/entities/group.dart';
import 'package:zyncro/features/groups/domain/services/invite_code_generator.dart';
import 'package:zyncro/features/notes/data/mappers/note_mapper.dart';
import 'package:zyncro/features/notes/domain/entities/note.dart';
import 'package:zyncro/features/settings/data/mappers/tab_settings_mapper.dart';
import 'package:zyncro/features/settings/domain/entities/tab_settings.dart';
import 'package:zyncro/shared/data/mappers/expense_category_mapper.dart';
import 'package:zyncro/shared/data/mappers/recurrence_rule_mapper.dart';
import 'package:zyncro/shared/domain/categories/expense_category.dart';
import 'package:zyncro/shared/domain/recurrence/recurrence_rule.dart';
import 'package:zyncro/shared/presentation/recurrence_rule_label.dart';

final t1 = DateTime(2026, 3, 14, 9, 30);
final t2 = DateTime(2026, 3, 14, 11);
final t3 = DateTime(2026, 4);
Timestamp ts(DateTime d) => Timestamp.fromDate(d);

void main() {
  group('RecurrenceRule', () {
    test('toMap complet / minimal', () {
      expect(
        RecurrenceRuleMapper.toFirestore(
          RecurrenceRule(
            frequency: RecurrenceFrequency.monthly,
            endType: RecurrenceEndType.until,
            until: t3,
          ),
        ),
        {'frequency': 'monthly', 'endType': 'until', 'until': ts(t3)},
      );
      expect(
        RecurrenceRuleMapper.toFirestore(
          const RecurrenceRule(
            frequency: RecurrenceFrequency.weekly,
            endType: RecurrenceEndType.count,
            count: 3,
          ),
        ),
        {'frequency': 'weekly', 'endType': 'count', 'count': 3},
      );
      expect(
        RecurrenceRuleMapper.toFirestore(
          const RecurrenceRule(frequency: RecurrenceFrequency.daily),
        ),
        {'frequency': 'daily', 'endType': 'forever'},
      );
    });
    test('fromMap legacy sans endType → forever', () {
      final rule = RecurrenceRuleMapper.fromFirestore({'frequency': 'yearly'});
      expect(rule.frequency, RecurrenceFrequency.yearly);
      expect(rule.endType, RecurrenceEndType.forever);
      expect(rule.count, isNull);
      expect(rule.until, isNull);
    });
    test('label', () {
      expect(
        const RecurrenceRule(frequency: RecurrenceFrequency.daily).label,
        'Tous les jours',
      );
      expect(
        const RecurrenceRule(
          frequency: RecurrenceFrequency.weekly,
          endType: RecurrenceEndType.count,
          count: 4,
        ).label,
        'Toutes les semaines · 4 fois',
      );
      expect(
        RecurrenceRule(
          frequency: RecurrenceFrequency.monthly,
          endType: RecurrenceEndType.until,
          until: t3,
        ).label,
        "Tous les mois · jusqu'au 1/4/2026",
      );
    });
  });

  group('Event', () {
    test('toMap complet', () {
      final event = Event(
        id: 'e1',
        groupId: 'g1',
        title: 'Dîner',
        description: 'chez Bob',
        startDate: t1,
        endDate: t2,
        location: 'Paris',
        createdBy: 'alice',
        creatorName: 'Alice',
        createdAt: t3,
        color: '#4F7CFF',
        updatedBy: 'bob',
        recurrence: const RecurrenceRule(frequency: RecurrenceFrequency.weekly),
        participantIds: const ['alice', 'bob'],
      );
      expect(EventMapper.toFirestore(event), {
        'groupId': 'g1',
        'title': 'Dîner',
        'description': 'chez Bob',
        'startDate': ts(t1),
        'endDate': ts(t2),
        'location': 'Paris',
        'createdBy': 'alice',
        'creatorName': 'Alice',
        'createdAt': ts(t3),
        'color': '#4F7CFF',
        'updatedBy': 'bob',
        'recurrence': {'frequency': 'weekly', 'endType': 'forever'},
        'participantIds': ['alice', 'bob'],
      });
    });
    test('toMap minimal : clés nulles écrites vs omises', () {
      final event = Event(
        id: 'e1',
        groupId: 'g1',
        title: 'T',
        startDate: t1,
        createdBy: 'alice',
        createdAt: t3,
      );
      expect(EventMapper.toFirestore(event), {
        'groupId': 'g1',
        'title': 'T',
        'description': null,
        'startDate': ts(t1),
        'endDate': null,
        'location': null,
        'createdBy': 'alice',
        'createdAt': ts(t3),
        'participantIds': <String>[],
      });
    });
    test('fromMap legacy (sans participants ni couleur)', () {
      final e = EventMapper.fromFirestore('e1', {
        'groupId': 'g1',
        'title': 'T',
        'startDate': ts(t1),
        'createdBy': 'a',
        'createdAt': ts(t3),
      });
      expect(e.participantIds, isEmpty);
      expect(e.color, isNull);
      expect(e.endDate, isNull);
      expect(e.recurrence, isNull);
    });
    test('BUG K3 : copyWith ne permet pas de retirer la couleur', () {
      final e = Event(
        id: 'e',
        groupId: 'g',
        title: 't',
        startDate: t1,
        createdBy: 'a',
        createdAt: t3,
        color: '#4F7CFF',
      );
      expect(e.copyWith().color, '#4F7CFF');
    });
  });

  group('Expense', () {
    test('toMap complet', () {
      final expense = Expense(
        id: 'x1',
        groupId: 'g1',
        title: 'Courses',
        amount: 42.5,
        paidBy: 'alice',
        paidByName: 'Alice',
        splitWith: const ['alice', 'bob'],
        settled: false,
        category: 'Alimentation',
        date: t1,
        createdBy: 'alice',
        createdAt: t3,
        splitType: SplitType.amount,
        splitAmounts: const {'alice': 20, 'bob': 22.5},
        updatedBy: 'bob',
        recurrence: const RecurrenceRule(
          frequency: RecurrenceFrequency.monthly,
          endType: RecurrenceEndType.count,
          count: 3,
        ),
      );
      expect(ExpenseMapper.toFirestore(expense), {
        'groupId': 'g1',
        'title': 'Courses',
        'amount': 42.5,
        'paidBy': 'alice',
        'paidByName': 'Alice',
        'splitWith': ['alice', 'bob'],
        'settled': false,
        'category': 'Alimentation',
        'date': ts(t1),
        'createdBy': 'alice',
        'createdAt': ts(t3),
        'expenseType': 'expense',
        'splitType': 'amount',
        'splitAmounts': {'alice': 20.0, 'bob': 22.5},
        'updatedBy': 'bob',
        'recurrence': {'frequency': 'monthly', 'endType': 'count', 'count': 3},
      });
    });
    test('toMap minimal (category null écrite, splitAmounts omis)', () {
      final expense = Expense(
        id: 'x1',
        groupId: 'g1',
        title: 'T',
        amount: 10,
        paidBy: 'a',
        paidByName: 'A',
        splitWith: const ['a'],
        settled: false,
        date: t1,
        createdBy: 'a',
        createdAt: t3,
        expenseType: ExpenseType.reimbursement,
      );
      expect(ExpenseMapper.toFirestore(expense), {
        'groupId': 'g1',
        'title': 'T',
        'amount': 10.0,
        'paidBy': 'a',
        'paidByName': 'A',
        'splitWith': ['a'],
        'settled': false,
        'category': null,
        'date': ts(t1),
        'createdBy': 'a',
        'createdAt': ts(t3),
        'expenseType': 'reimbursement',
        'splitType': 'equal',
      });
    });
    test('fromMap legacy : paidByName absent → paidBy, montant entier', () {
      final e = ExpenseMapper.fromFirestore('x1', {
        'groupId': 'g1',
        'title': 'T',
        'amount': 12,
        'paidBy': 'bob',
        'date': ts(t1),
        'createdBy': 'bob',
        'createdAt': ts(t3),
      });
      expect(e.paidByName, 'bob');
      expect(e.amount, 12.0);
      expect(e.splitWith, isEmpty);
      expect(e.settled, isFalse);
      expect(e.expenseType, ExpenseType.expense);
      expect(e.splitType, SplitType.equal);
      expect(e.firestoreId, 'x1');
    });
    test('effectiveSplitAmounts : parts égales si pas de splitAmounts', () {
      final e = ExpenseMapper.fromFirestore('x1', {
        'groupId': 'g',
        'title': 'T',
        'amount': 30,
        'paidBy': 'a',
        'splitWith': ['a', 'b', 'c'],
        'date': ts(t1),
        'createdBy': 'a',
        'createdAt': ts(t3),
      });
      expect(e.effectiveSplitAmounts, {'a': 10.0, 'b': 10.0, 'c': 10.0});
    });
  });

  group('Note', () {
    test('toMap (color null écrite, updatedBy omis)', () {
      final note = Note(
        id: 'n1',
        groupId: 'g1',
        title: 'Liste',
        content: '',
        isPinned: true,
        isChecklist: true,
        checklist: const [ChecklistItem(text: 'lait', done: true)],
        createdBy: 'a',
        createdAt: t1,
        updatedAt: t2,
      );
      expect(NoteMapper.toFirestore(note), {
        'groupId': 'g1',
        'title': 'Liste',
        'content': '',
        'isPinned': true,
        'color': null,
        'isChecklist': true,
        'checklist': [
          {'text': 'lait', 'done': true},
        ],
        'createdBy': 'a',
        'createdAt': ts(t1),
        'updatedAt': ts(t2),
      });
    });
    test('fromMap legacy (pas de checklist ni isPinned)', () {
      final n = NoteMapper.fromFirestore('n1', {
        'groupId': 'g1',
        'title': 'T',
        'content': 'c',
        'createdBy': 'a',
        'createdAt': ts(t1),
        'updatedAt': ts(t2),
      });
      expect(n.isPinned, isFalse);
      expect(n.isChecklist, isFalse);
      expect(n.checklist, isEmpty);
    });
  });

  group('Message', () {
    test('toMap (reactions et réponse omises si vides)', () {
      final m = Message(
        id: 'm1',
        groupId: 'g1',
        senderId: 'a',
        senderName: 'Alice',
        content: 'hello',
        type: MessageType.text,
        timestamp: t1,
      );
      expect(MessageMapper.toFirestore(m), {
        'groupId': 'g1',
        'senderId': 'a',
        'senderName': 'Alice',
        'content': 'hello',
        'type': 'text',
        'timestamp': ts(t1),
      });
    });
    test('toMap complet', () {
      final m = Message(
        id: 'm1',
        groupId: 'g1',
        senderId: 'a',
        senderName: 'Alice',
        content: '{"url":"u","mimeType":"image/jpeg"}',
        type: MessageType.image,
        timestamp: t1,
        editedAt: t2,
        reactions: const {
          '❤️': ['b'],
        },
        replyToId: 'm0',
        replyToSenderName: 'Bob',
        replyToContent: 'avant',
      );
      expect(MessageMapper.toFirestore(m), {
        'groupId': 'g1',
        'senderId': 'a',
        'senderName': 'Alice',
        'content': '{"url":"u","mimeType":"image/jpeg"}',
        'type': 'image',
        'timestamp': ts(t1),
        'editedAt': ts(t2),
        'reactions': {
          '❤️': ['b'],
        },
        'replyToId': 'm0',
        'replyToSenderName': 'Bob',
        'replyToContent': 'avant',
      });
    });
    test('types écrits : file = vidéo', () {
      expect(MessageType.values.map((t) => t.name), [
        'text',
        'system',
        'image',
        'file',
        'poll',
        'audio',
      ]);
    });
  });

  group('Group / GroupMember', () {
    test('Group.toMap', () {
      final g = Group(
        id: 'g1',
        name: 'Coloc',
        memberIds: const ['a'],
        createdBy: 'a',
        createdAt: t1,
        inviteCode: 'ABC234',
      );
      expect(GroupMapper.toFirestore(g), {
        'name': 'Coloc',
        'description': null,
        'emoji': null,
        'photoUrl': null,
        'memberIds': ['a'],
        'createdBy': 'a',
        'createdAt': ts(t1),
        'inviteCode': 'ABC234',
      });
    });
    test('Group.generateInviteCode : 6 caractères sans ambiguïté', () {
      for (var i = 0; i < 200; i++) {
        expect(
          newInviteCode(),
          matches(RegExp(r'^[ABCDEFGHJKLMNPQRSTUVWXYZ23456789]{6}$')),
        );
      }
    });
    test('GroupMember.fromMap : défauts', () {
      final m = GroupMemberMapper.fromFirestore(const {});
      expect(m.uid, '');
      expect(m.displayName, 'Membre');
      expect(m.role, 'member');
      expect(m.isOwner, isFalse);
      expect(m.showProfilePhoto, isTrue);
    });
  });

  group('TabSettings', () {
    test('toMap des défauts', () {
      expect(TabSettingsMapper.toFirestore(TabSettings.defaults), {
        'customColors': <String>[],
        'hiddenBaseColors': <String>[],
        'homeThemeColor': null,
        'calendarThemeColor': null,
        'notesThemeColor': null,
        'expensesThemeColor': null,
        'chatThemeColor': null,
        'chatBackgroundType': null,
        'chatBackgroundValue': null,
        'expensesCurrency': 'EUR',
        'expensesCategories': [
          for (final c in defaultExpenseCategories)
            ExpenseCategoryMapper.toFirestore(c),
        ],
        'calendarDisplayMode': 'band',
        'calendarCustomCategories': <String>[],
        'calendarFilters': {
          'participantIds': <String>[],
          'recurrenceOnly': false,
          'category': null,
        },
        'homePhotoUrl': null,
      });
    });
    test('fromMap legacy : expensesCustomCategories ajoutées aux défauts', () {
      final s = TabSettingsMapper.fromFirestore({
        'expensesCustomCategories': ['Animaux'],
      });
      expect(s.expensesCategories.map((c) => c.name), [
        ...defaultExpenseCategories.map((c) => c.name),
        'Animaux',
      ]);
      expect(s.expensesCategories.last.iconKey, 'label');
      expect(s.expensesCategories.last.colorHex, '#4F7CFF');
    });
    test('fromMap vide → défauts', () {
      final s = TabSettingsMapper.fromFirestore(const {});
      expect(
        TabSettingsMapper.toFirestore(s),
        TabSettingsMapper.toFirestore(TabSettings.defaults),
      );
    });
    test(
      'withColorRemoved : couleur perso supprimée, couleur de base masquée',
      () {
        const s = TabSettings(customColors: ['#111111']);
        expect(s.withColorRemoved('#111111').customColors, isEmpty);
        expect(s.withColorRemoved('#4F7CFF').hiddenBaseColors, ['#4F7CFF']);
        // BUG G2 : pas de dédoublonnage
        expect(
          s
              .withColorRemoved('#4F7CFF')
              .withColorRemoved('#4F7CFF')
              .hiddenBaseColors,
          ['#4F7CFF', '#4F7CFF'],
        );
      },
    );
  });

  group('ExpenseCategory', () {
    test('toMap / fromMap avec défauts', () {
      const c = ExpenseCategory(
        name: 'X',
        iconKey: 'pets',
        colorHex: '#FFA940',
      );
      expect(ExpenseCategoryMapper.toFirestore(c), {
        'name': 'X',
        'iconKey': 'pets',
        'colorHex': '#FFA940',
      });
      final d = ExpenseCategoryMapper.fromFirestore(const {});
      expect([d.name, d.iconKey, d.colorHex], ['', 'label', '#4F7CFF']);
    });
  });
}
