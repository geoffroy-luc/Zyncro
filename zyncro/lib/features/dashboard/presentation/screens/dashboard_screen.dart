import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:zyncro/core/utils/color_hex.dart';
import 'package:zyncro/design_system/context_extensions.dart';
import 'package:zyncro/features/auth/presentation/providers/auth_provider.dart';
import 'package:zyncro/features/calendar/presentation/providers/events_provider.dart';
import 'package:zyncro/features/calendar/presentation/screens/event_form_screen.dart';
import 'package:zyncro/features/chat/presentation/providers/messages_provider.dart';
import 'package:zyncro/features/chat/presentation/screens/media_gallery_screen.dart';
import 'package:zyncro/features/dashboard/presentation/widgets/dashboard_card.dart';
import 'package:zyncro/features/dashboard/presentation/widgets/dashboard_card_header.dart';
import 'package:zyncro/features/dashboard/presentation/widgets/dashboard_empty_hint.dart';
import 'package:zyncro/features/dashboard/presentation/widgets/dashboard_screen_helpers.dart';
import 'package:zyncro/features/dashboard/presentation/widgets/event_row.dart';
import 'package:zyncro/features/dashboard/presentation/widgets/expense_row.dart';
import 'package:zyncro/features/dashboard/presentation/widgets/message_row.dart';
import 'package:zyncro/features/dashboard/presentation/widgets/pinned_note_card.dart';
import 'package:zyncro/features/dashboard/presentation/widgets/quick_action_button.dart';
import 'package:zyncro/features/expenses/presentation/providers/expenses_provider.dart';
import 'package:zyncro/features/notes/presentation/providers/notes_provider.dart';
import 'package:zyncro/features/notes/presentation/screens/note_editor_screen.dart';
import 'package:zyncro/features/settings/domain/entities/tab_settings.dart';
import 'package:zyncro/features/settings/presentation/providers/tab_settings_provider.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUid = ref.watch(authStateProvider).asData?.value?.uid;

    final allEvents = ref.watch(eventsProvider).asData?.value ?? [];
    final allNotes = ref.watch(notesProvider).asData?.value ?? [];
    final allExpenses = ref.watch(expensesProvider).asData?.value ?? [];
    final balances = ref.watch(balancesProvider);
    final allMessages =
        ref.watch(chatMessagesProvider).asData?.value.messages ?? [];
    final members = ref.watch(expenseMembersProvider).asData?.value ?? [];
    final memberNames = {for (final m in members) m.uid: m.displayName};

    final now = DateTime.now();

    // Prochains événements (à partir d'aujourd'hui, triés)
    final upcomingEvents =
        (allEvents..sort((a, b) => a.startDate.compareTo(b.startDate)))
            .where(
              (e) =>
                  !e.startDate.isBefore(DateTime(now.year, now.month, now.day)),
            )
            .take(3)
            .toList();

    // Note épinglée
    final pinnedNote = allNotes.where((n) => n.isPinned).isNotEmpty
        ? allNotes.firstWhere((n) => n.isPinned)
        : null;

    // Résumé dépenses
    final totalExpenses = allExpenses.fold(0.0, (s, e) => s + e.amount);
    final myBalance = currentUid != null ? (balances[currentUid] ?? 0.0) : 0.0;
    // Derniers messages (activité récente)
    final recentMessages = allMessages.take(3).toList();

    // Médias partagés
    final allMedia = ref.watch(mediaMessagesProvider).asData?.value ?? [];
    final previewMedia = allMedia.take(6).toList();

    final tabSettings =
        ref.watch(tabSettingsProvider).asData?.value ?? TabSettings.defaults;
    final homeColor = dashboardColorForTab(0, tabSettings);
    final calendarColor = dashboardColorForTab(1, tabSettings);
    final notesColor = dashboardColorForTab(2, tabSettings);
    return Scaffold(
      backgroundColor: context.colors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              // ── Contenu ──────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Prochains événements
                    DashboardCard(
                      child: Column(
                        children: [
                          DashboardCardHeader(
                            icon: Icons.calendar_today,
                            iconColor: homeColor,
                            title: 'Prochains événements',
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                            child: upcomingEvents.isEmpty
                                ? DashboardEmptyHint(
                                    label: 'Aucun événement à venir',
                                    onTap: () => Navigator.of(context).push(
                                      MaterialPageRoute<void>(
                                        builder: (_) => const EventFormScreen(),
                                      ),
                                    ),
                                  )
                                : Column(
                                    children: upcomingEvents
                                        .map(
                                          (e) => Padding(
                                            padding: const EdgeInsets.only(
                                              bottom: 12,
                                            ),
                                            child: EventRow(event: e),
                                          ),
                                        )
                                        .toList(),
                                  ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Note épinglée
                    if (pinnedNote != null) ...[
                      PinnedNoteCard(note: pinnedNote, color: notesColor),
                      const SizedBox(height: 12),
                    ],

                    // Résumé dépenses
                    DashboardCard(
                      child: Column(
                        children: [
                          DashboardCardHeader(
                            icon: Icons.trending_up,
                            iconColor: homeColor,
                            title: 'Résumé des dépenses',
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.baseline,
                                  textBaseline: TextBaseline.alphabetic,
                                  children: [
                                    Text(
                                      dashboardFormatAmount(totalExpenses),
                                      style: TextStyle(
                                        color: context.colors.textPrimary,
                                        fontSize: 28,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'total du groupe',
                                      style: TextStyle(
                                        color: context.colors.textSecondary,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Divider(
                                  height: 1,
                                  color: context.colors.border,
                                ),
                                ExpenseRow(
                                  label: 'Votre solde',
                                  value: myBalance >= 0
                                      ? '+${dashboardFormatAmount(myBalance)}'
                                      : dashboardFormatAmount(myBalance),
                                  valueColor: myBalance >= 0
                                      ? const Color(0xFF2BB8A5)
                                      : context.colors.error,
                                ),
                                const SizedBox(height: 4),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Activité récente (messages)
                    if (recentMessages.isNotEmpty) ...[
                      DashboardCard(
                        child: Column(
                          children: [
                            DashboardCardHeader(
                              icon: Icons.chat_bubble_outline,
                              iconColor: homeColor,
                              title: 'Activité récente',
                            ),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(
                                20,
                                12,
                                20,
                                20,
                              ),
                              child: Column(
                                children: recentMessages
                                    .map(
                                      (m) => Padding(
                                        padding: const EdgeInsets.only(
                                          bottom: 12,
                                        ),
                                        child: MessageRow(
                                          message: m,
                                          isMe: m.senderId == currentUid,
                                          memberNames: memberNames,
                                          members: members,
                                        ),
                                      ),
                                    )
                                    .toList(),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                    ] else
                      const SizedBox(height: 8),

                    // Médias partagés
                    if (previewMedia.isNotEmpty) ...[
                      DashboardCard(
                        child: Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(
                                20,
                                16,
                                12,
                                12,
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 32,
                                    height: 32,
                                    decoration: BoxDecoration(
                                      color: homeColor.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(
                                      Icons.photo_library_outlined,
                                      size: 16,
                                      color: homeColor,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Médias partagés',
                                    style: TextStyle(
                                      color: context.colors.textPrimary,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 15,
                                    ),
                                  ),
                                  const Spacer(),
                                  TextButton(
                                    onPressed: () =>
                                        context.push('/media-gallery'),
                                    child: const Text(
                                      'Voir tout',
                                      style: TextStyle(fontSize: 13),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Divider(height: 1, color: context.colors.border),
                            SizedBox(
                              height: 88,
                              child: ListView.separated(
                                scrollDirection: Axis.horizontal,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                itemCount: previewMedia.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(width: 8),
                                itemBuilder: (_, i) =>
                                    MediaPreviewTile(message: previewMedia[i]),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],

                    // Actions rapides
                    Text(
                      'Actions rapides',
                      style: TextStyle(
                        color: context.colors.textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: QuickActionButton(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [calendarColor, darken(calendarColor)],
                            ),
                            icon: Icons.calendar_today,
                            label: 'Ajouter un événement',
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => const EventFormScreen(),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: QuickActionButton(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [notesColor, darken(notesColor)],
                            ),
                            icon: Icons.sticky_note_2_outlined,
                            label: 'Nouvelle note',
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => const NoteEditorScreen(),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ), // SafeArea
    );
  }
}
