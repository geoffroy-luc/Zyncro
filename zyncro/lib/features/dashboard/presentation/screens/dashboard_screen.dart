import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../shared/models/group_member.dart';
import '../../../../shared/widgets/user_avatar.dart';
import '../../../../shared/models/event.dart';
import '../../../../shared/models/message.dart';
import '../../../../shared/models/note.dart';
import 'package:go_router/go_router.dart';

import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../calendar/presentation/providers/events_provider.dart';
import '../../../calendar/presentation/screens/event_form_screen.dart';
import '../../../expenses/presentation/providers/expenses_provider.dart';
import '../../../chat/presentation/providers/messages_provider.dart';
import '../../../chat/presentation/screens/media_gallery_screen.dart';
import '../../../notes/presentation/providers/notes_provider.dart';
import '../../../notes/presentation/screens/note_editor_screen.dart';


bool _isToday(DateTime dt) {
  final now = DateTime.now();
  return dt.year == now.year && dt.month == now.month && dt.day == now.day;
}

String _formatAmount(double v) =>
    NumberFormat.currency(locale: 'fr_FR', symbol: '€', decimalDigits: 2)
        .format(v);

String _timeAgo(DateTime dt) {
  final diff = DateTime.now().difference(dt);
  if (diff.inMinutes < 60) return 'Il y a ${diff.inMinutes} min';
  if (diff.inHours < 24) return 'Il y a ${diff.inHours} h';
  return 'Il y a ${diff.inDays} j';
}



class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUid = ref.watch(authStateProvider).asData?.value?.uid;

    final allEvents = ref.watch(eventsProvider).asData?.value ?? [];
    final allNotes = ref.watch(notesProvider).asData?.value ?? [];
    final allExpenses = ref.watch(expensesProvider).asData?.value ?? [];
    final balances = ref.watch(balancesProvider);
    final allMessages = ref.watch(chatMessagesProvider).asData?.value.messages ?? [];
    final members = ref.watch(expenseMembersProvider).asData?.value ?? [];
    final memberNames = {for (final m in members) m.uid: m.displayName};

    final now = DateTime.now();

    // Prochains événements (à partir d'aujourd'hui, triés)
    final upcomingEvents = (allEvents
          ..sort((a, b) => a.startDate.compareTo(b.startDate)))
        .where((e) => !e.startDate.isBefore(
            DateTime(now.year, now.month, now.day)))
        .take(3)
        .toList();

    // Note épinglée
    final pinnedNote = allNotes.where((n) => n.isPinned).isNotEmpty
        ? allNotes.firstWhere((n) => n.isPinned)
        : null;

    // Résumé dépenses
    final totalExpenses =
        allExpenses.fold(0.0, (s, e) => s + e.amount);
    final myBalance =
        currentUid != null ? (balances[currentUid] ?? 0.0) : 0.0;
    // Derniers messages (activité récente)
    final recentMessages = allMessages.take(3).toList();

    // Médias partagés
    final allMedia = ref.watch(mediaMessagesProvider).asData?.value ?? [];
    final previewMedia = allMedia.take(6).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // ── Contenu ──────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Prochains événements
                  _Card(
                    child: Column(
                      children: [
                        const _CardHeader(
                          icon: Icons.calendar_today,
                          iconColor: AppColors.primary,
                          title: 'Prochains événements',
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                          child: upcomingEvents.isEmpty
                              ? _EmptyHint(
                                  label: 'Aucun événement à venir',
                                  onTap: () => Navigator.of(context).push(
                                    MaterialPageRoute(
                                        builder: (_) =>
                                            const EventFormScreen()),
                                  ),
                                )
                              : Column(
                                  children: upcomingEvents
                                      .map((e) => Padding(
                                            padding: const EdgeInsets.only(
                                                bottom: 12),
                                            child: _EventRow(event: e),
                                          ))
                                      .toList(),
                                ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Note épinglée
                  if (pinnedNote != null) ...[
                    _PinnedNoteCard(note: pinnedNote),
                    const SizedBox(height: 12),
                  ],

                  // Résumé dépenses
                  _Card(
                    child: Column(
                      children: [
                        const _CardHeader(
                          icon: Icons.trending_up,
                          iconColor: AppColors.accent,
                          title: 'Résumé des dépenses',
                        ),
                        Padding(
                          padding:
                              const EdgeInsets.fromLTRB(20, 12, 20, 4),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment:
                                    CrossAxisAlignment.baseline,
                                textBaseline: TextBaseline.alphabetic,
                                children: [
                                  Text(
                                    _formatAmount(totalExpenses),
                                    style: const TextStyle(
                                      color: AppColors.textPrimary,
                                      fontSize: 28,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  const Text(
                                    'total du groupe',
                                    style: TextStyle(
                                        color: AppColors.textSecondary,
                                        fontSize: 13),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              const Divider(
                                  height: 1, color: AppColors.border),
                              _ExpenseRow(
                                label: 'Votre solde',
                                value: myBalance >= 0
                                    ? '+${_formatAmount(myBalance)}'
                                    : _formatAmount(myBalance),
                                valueColor: myBalance >= 0
                                    ? const Color(0xFF2BB8A5)
                                    : AppColors.error,
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
                    _Card(
                      child: Column(
                        children: [
                          const _CardHeader(
                            icon: Icons.chat_bubble_outline,
                            iconColor: AppColors.primary,
                            title: 'Activité récente',
                          ),
                          Padding(
                            padding:
                                const EdgeInsets.fromLTRB(20, 12, 20, 20),
                            child: Column(
                              children: recentMessages
                                  .map((m) => Padding(
                                        padding:
                                            const EdgeInsets.only(bottom: 12),
                                        child: _MessageRow(
                                            message: m,
                                            isMe: m.senderId == currentUid,
                                            memberNames: memberNames,
                                            members: members),
                                      ))
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
                    _Card(
                      child: Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
                            child: Row(
                              children: [
                                Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFE85D75).withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(Icons.photo_library_outlined,
                                      size: 16, color: Color(0xFFE85D75)),
                                ),
                                const SizedBox(width: 8),
                                const Text(
                                  'Médias partagés',
                                  style: TextStyle(
                                    color: AppColors.textPrimary,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 15,
                                  ),
                                ),
                                const Spacer(),
                                TextButton(
                                  onPressed: () => context.push('/media-gallery'),
                                  child: const Text('Voir tout',
                                      style: TextStyle(fontSize: 13)),
                                ),
                              ],
                            ),
                          ),
                          const Divider(height: 1, color: AppColors.border),
                          SizedBox(
                            height: 88,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 8),
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
                  const Text(
                    'Actions rapides',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _QuickActionButton(
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [Color(0xFF4F7CFF), Color(0xFF315FEA)],
                          ),
                          icon: Icons.calendar_today,
                          label: 'Ajouter un événement',
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                                builder: (_) => const EventFormScreen()),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _QuickActionButton(
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [Color(0xFF2BB8A5), Color(0xFF1E9B8A)],
                          ),
                          icon: Icons.sticky_note_2_outlined,
                          label: 'Nouvelle note',
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                                builder: (_) => const NoteEditorScreen()),
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
    );
  }
}

// ── Widgets helpers ──────────────────────────────────────────────────────────

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(color: Color(0x0A000000), blurRadius: 4, offset: Offset(0, 2))
        ],
      ),
      child: child,
    );
  }
}

class _CardHeader extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;

  const _CardHeader(
      {required this.icon, required this.iconColor, required this.title});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: iconColor),
          ),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyHint extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _EmptyHint({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: const TextStyle(
                color: AppColors.textSecondary, fontSize: 13)),
        TextButton.icon(
          onPressed: onTap,
          icon: const Icon(Icons.add, size: 16),
          label: const Text('Ajouter'),
        ),
      ],
    );
  }
}

class _EventRow extends StatelessWidget {
  final Event event;
  const _EventRow({required this.event});

  Color _parseEventColor() {
    if (event.color == null) return const Color(0xFF4F7CFF);
    try {
      return Color(int.parse('FF${event.color!.replaceAll('#', '')}', radix: 16));
    } catch (_) {
      return const Color(0xFF4F7CFF);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isToday = _isToday(event.startDate);

    final baseColor = _parseEventColor();
    final colorPair = [baseColor, Color.fromARGB(
      (baseColor.a * 255.0).round() & 0xff,
      ((baseColor.r * 255.0).round() & 0xff) * 4 ~/ 5,
      ((baseColor.g * 255.0).round() & 0xff) * 4 ~/ 5,
      ((baseColor.b * 255.0).round() & 0xff) * 4 ~/ 5,
    )];

    String dateLabel;
    if (isToday) {
      dateLabel =
          "Aujourd'hui • ${DateFormat('HH:mm').format(event.startDate)}";
    } else {
      dateLabel = DateFormat('d MMM • HH:mm', 'fr_FR').format(event.startDate);
    }

    return Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: colorPair,
            ),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: colorPair.first.withValues(alpha: 0.3),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                DateFormat('MMM', 'fr_FR')
                    .format(event.startDate)
                    .toUpperCase(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                '${event.startDate.day}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  height: 1,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                event.title,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                ),
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                dateLabel,
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 12),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PinnedNoteCard extends StatelessWidget {
  final Note note;
  const _PinnedNoteCard({required this.note});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0x0D2BB8A5), Color(0x1A2BB8A5)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x332BB8A5)),
        boxShadow: const [
          BoxShadow(color: Color(0x0A000000), blurRadius: 4, offset: Offset(0, 2))
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: const Color(0x262BB8A5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.sticky_note_2,
                      size: 16, color: Color(0xFF2BB8A5)),
                ),
                const SizedBox(width: 8),
                const Text(
                  'Note épinglée',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
                const Spacer(),
                const Icon(Icons.push_pin, size: 16, color: AppColors.accent),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0x332BB8A5)),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  note.title,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w500,
                    fontSize: 15,
                  ),
                ),
                if (note.content.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    note.content,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                      height: 1.5,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 12),
                Text(
                  'Modifié ${_timeAgo(note.updatedAt)}',
                  style: const TextStyle(
                    color: Color(0xFF2BB8A5),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ExpenseRow extends StatelessWidget {
  final String label;
  final String value;
  final Color valueColor;

  const _ExpenseRow(
      {required this.label, required this.value, required this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 13)),
          Text(value,
              style: TextStyle(
                  color: valueColor,
                  fontWeight: FontWeight.w600,
                  fontSize: 14)),
        ],
      ),
    );
  }
}

class _MessageRow extends StatelessWidget {
  final Message message;
  final bool isMe;
  final Map<String, String> memberNames;
  final List<GroupMember> members;
  const _MessageRow({
    required this.message,
    required this.isMe,
    required this.memberNames,
    required this.members,
  });

  @override
  Widget build(BuildContext context) {
    final resolvedName = isMe ? 'Vous' : (memberNames[message.senderId] ?? message.senderName ?? '?');
    final name = resolvedName;
    final member = members.where((m) => m.uid == message.senderId).firstOrNull;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        UserAvatar(
          photoUrl: member?.photoUrl,
          showPhoto: member?.showProfilePhoto ?? true,
          displayName: isMe ? 'Vous' : resolvedName,
          radius: 18,
          color: avatarColorForUid(message.senderId ?? ''),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(name,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w500,
                        fontSize: 13,
                      )),
                  const SizedBox(width: 8),
                  Text(_timeAgo(message.timestamp),
                      style: const TextStyle(
                          color: AppColors.textSecondary, fontSize: 11)),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                message.type == MessageType.image
                    ? 'a envoyé une photo'
                    : message.type == MessageType.file
                        ? 'a envoyé un fichier'
                        : message.type == MessageType.audio
                            ? 'a envoyé un audio'
                            : message.type == MessageType.poll
                                ? 'a créé un sondage'
                                : message.content,
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 13),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  final LinearGradient gradient;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _QuickActionButton({
    required this.gradient,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: gradient,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: gradient.colors.first.withValues(alpha: 0.25),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                  border:
                      Border.all(color: Colors.white.withValues(alpha: 0.3)),
                ),
                child: Icon(icon, color: Colors.white, size: 20),
              ),
              const SizedBox(height: 12),
              Text(label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                    fontSize: 13,
                  )),
            ],
          ),
        ),
      ),
    );
  }
}
