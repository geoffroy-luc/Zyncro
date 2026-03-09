import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../shared/models/event.dart';
import '../../../../shared/models/message.dart';
import '../../../../shared/models/note.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../calendar/presentation/providers/events_provider.dart';
import '../../../calendar/presentation/screens/event_form_screen.dart';
import '../../../expenses/presentation/providers/expenses_provider.dart';
import '../../../groups/presentation/providers/groups_provider.dart';
import '../../../chat/presentation/providers/messages_provider.dart';
import '../../../notes/presentation/providers/notes_provider.dart';
import '../../../notes/presentation/screens/note_editor_screen.dart';

String _greeting() {
  final h = DateTime.now().hour;
  if (h < 12) return 'Bonjour';
  if (h < 18) return 'Bon après-midi';
  return 'Bonsoir';
}

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

const _avatarColors = [
  Color(0xFF4F7CFF),
  Color(0xFF2BB8A5),
  Color(0xFFFFB86B),
  Color(0xFFE85D75),
  Color(0xFF9B59B6),
];

Color _avatarColor(String uid) =>
    _avatarColors[uid.hashCode.abs() % _avatarColors.length];

String _initials(String? name) {
  if (name == null || name.isEmpty) return '?';
  final parts = name.trim().split(' ');
  if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  return name.substring(0, name.length >= 2 ? 2 : 1).toUpperCase();
}

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final group = ref.watch(selectedGroupProvider);
    final topPad = MediaQuery.of(context).padding.top;
    final currentUid = ref.watch(authStateProvider).asData?.value?.uid;

    final allEvents = ref.watch(eventsProvider).asData?.value ?? [];
    final allNotes = ref.watch(notesProvider).asData?.value ?? [];
    final allExpenses = ref.watch(expensesProvider).asData?.value ?? [];
    final balances = ref.watch(balancesProvider);
    final allMessages = ref.watch(messagesProvider).asData?.value ?? [];

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
    final pendingCount = allExpenses.where((e) => !e.settled).length;

    // Événements aujourd'hui
    final todayEvents = allEvents.where((e) => _isToday(e.startDate)).length;

    // Derniers messages (activité récente)
    final recentMessages = allMessages.take(3).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // ── Header gradient ──────────────────────────────────────
            Container(
              padding: EdgeInsets.fromLTRB(24, topPad + 24, 24, 32),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF4F7CFF), Color(0xFF315FEA)],
                ),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(32),
                  bottomRight: Radius.circular(32),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Color(0x334F7CFF),
                    blurRadius: 16,
                    offset: Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.3),
                            width: 2,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            group?.emoji ?? '🏠',
                            style: const TextStyle(fontSize: 22),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              group?.name ?? '',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              '${group?.memberIds.length ?? 0} membre${(group?.memberIds.length ?? 0) > 1 ? 's' : ''}',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.8),
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  // Carte de résumé
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.2)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${_greeting()} 👋',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.9),
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          todayEvents == 0 && pendingCount == 0
                              ? 'Aucun événement ni dépense en attente aujourd\'hui.'
                              : [
                                  if (todayEvents > 0)
                                    '$todayEvents événement${todayEvents > 1 ? 's' : ''} aujourd\'hui',
                                  if (pendingCount > 0)
                                    '$pendingCount dépense${pendingCount > 1 ? 's' : ''} en attente',
                                ].join(' • '),
                          style: const TextStyle(
                              color: Colors.white, fontSize: 15),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

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
                              const Divider(
                                  height: 1, color: AppColors.border),
                              _ExpenseRow(
                                label: 'En attente',
                                value: '$pendingCount',
                                valueColor: pendingCount > 0
                                    ? AppColors.accent
                                    : AppColors.textPrimary,
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
                                        child: _MessageRow(message: m,
                                            isMe: m.senderId == currentUid),
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

  @override
  Widget build(BuildContext context) {
    final isToday = _isToday(event.startDate);

    final colors = [
      [const Color(0xFF4F7CFF), const Color(0xFF315FEA)],
      [const Color(0xFF2BB8A5), const Color(0xFF1E9B8A)],
      [const Color(0xFFFFB86B), const Color(0xFFF5A855)],
    ];
    final colorPair =
        colors[event.id.hashCode.abs() % colors.length];

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
  const _MessageRow({required this.message, required this.isMe});

  @override
  Widget build(BuildContext context) {
    final color = _avatarColor(message.senderId ?? '');
    final name = isMe ? 'Vous' : (message.senderName ?? '?');
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          child: Center(
            child: Text(
              _initials(isMe ? 'Moi' : message.senderName),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
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
                message.content,
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
