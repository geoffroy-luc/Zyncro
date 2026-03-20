import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../shared/models/note.dart';
import '../../../groups/presentation/providers/groups_provider.dart';
import '../providers/notes_provider.dart';
import 'note_editor_screen.dart';

Color _hexToColor(String? hex) {
  if (hex == null) return AppColors.secondary;
  return Color(int.parse('FF${hex.replaceAll('#', '')}', radix: 16));
}

String _formatDate(DateTime dt) {
  final now = DateTime.now();
  final diff = now.difference(dt);
  if (diff.inMinutes < 60) return 'Il y a ${diff.inMinutes} min';
  if (diff.inHours < 24) return 'Il y a ${diff.inHours} h';
  if (diff.inDays == 1) return 'Hier';
  if (diff.inDays < 7) return 'Il y a ${diff.inDays} j';
  return DateFormat('d MMM', 'fr_FR').format(dt);
}

class NotesScreen extends ConsumerStatefulWidget {
  const NotesScreen({super.key});

  @override
  ConsumerState<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends ConsumerState<NotesScreen> {
  String _search = '';

  void _openEditor({Note? note}) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => NoteEditorScreen(note: note)));
  }

  Future<void> _togglePin(Note note) async {
    final groupId = ref.read(selectedGroupIdProvider).asData?.value;
    if (groupId == null) return;
    try {
      await ref
          .read(notesRepositoryProvider)
          .updateNote(groupId, note.copyWith(isPinned: !note.isPinned));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Impossible d\'épingler : permission refusée.'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;
    final notesAsync = ref.watch(notesProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      floatingActionButton: FloatingActionButton(
        heroTag: 'fab_notes',
        onPressed: () => _openEditor(),
        backgroundColor: const Color(0xFF2BB8A5).withValues(alpha: 0.85),
        shape: const CircleBorder(
          side: BorderSide(color: Colors.white24, width: 2),
        ),
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: notesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erreur: $e')),
        data: (allNotes) {
          final searchLower = _search.toLowerCase();
          final filtered = _search.isEmpty
              ? allNotes
              : allNotes
                    .where(
                      (n) =>
                          n.title.toLowerCase().contains(searchLower) ||
                          n.content.toLowerCase().contains(searchLower) ||
                          n.checklist.any(
                            (item) =>
                                item.text.toLowerCase().contains(searchLower),
                          ),
                    )
                    .toList();

          final pinned = filtered.where((n) => n.isPinned).toList();
          final recent = filtered.where((n) => !n.isPinned).toList();

          return CustomScrollView(
            slivers: [
              // ── Header ──────────────────────────────────────────────
              SliverToBoxAdapter(
                child: Container(
                  color: Colors.white,
                  padding: EdgeInsets.fromLTRB(24, topPad + 16, 24, 20),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Notes',
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 24,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFFF7F9FC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          children: [
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 14),
                              child: Icon(
                                Icons.search,
                                color: AppColors.textSecondary,
                                size: 20,
                              ),
                            ),
                            Expanded(
                              child: TextField(
                                onChanged: (v) => setState(() => _search = v),
                                decoration: const InputDecoration(
                                  hintText: 'Rechercher...',
                                  hintStyle: TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 14,
                                  ),
                                  border: InputBorder.none,
                                  enabledBorder: InputBorder.none,
                                  focusedBorder: InputBorder.none,
                                  contentPadding: EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                  filled: false,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SliverToBoxAdapter(
                child: Divider(height: 1, color: AppColors.border),
              ),

              // ── Contenu ─────────────────────────────────────────────
              if (allNotes.isEmpty)
                SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.description_outlined,
                          size: 48,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Aucune note',
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: () => _openEditor(),
                          icon: const Icon(Icons.add),
                          label: const Text('Créer une note'),
                        ),
                      ],
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.all(24),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      // Épinglées
                      if (pinned.isNotEmpty) ...[
                        const Row(
                          children: [
                            Icon(
                              Icons.push_pin,
                              size: 16,
                              color: AppColors.accent,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Épinglées',
                              style: TextStyle(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        ...pinned.map(
                          (note) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _PinnedNoteCard(
                              note: note,
                              onTap: () => _openEditor(note: note),
                              onTogglePin: () => _togglePin(note),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],

                      // Récentes
                      if (recent.isNotEmpty) ...[
                        const Text(
                          'Récentes',
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 16),
                        GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                crossAxisSpacing: 12,
                                mainAxisSpacing: 12,
                                childAspectRatio: 0.85,
                              ),
                          itemCount: recent.length,
                          itemBuilder: (_, i) => _RecentNoteCard(
                            note: recent[i],
                            onTap: () => _openEditor(note: recent[i]),
                            onTogglePin: () => _togglePin(recent[i]),
                          ),
                        ),
                      ],

                      const SizedBox(height: 24),
                    ]),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

// ── Aperçu checklist ──────────────────────────────────────────────────────────

Widget _buildChecklistPreview(
  List<ChecklistItem> items,
  Color accentColor, {
  int maxItems = 3,
  double fontSize = 11,
}) {
  final done = items.where((i) => i.done).length;
  final total = items.length;
  final display = items.take(maxItems).toList();
  final remaining = total - display.length;

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      // Barre de progression
      if (total > 0) ...[
        Row(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: total > 0 ? done / total : 0,
                  minHeight: 4,
                  backgroundColor: accentColor.withValues(alpha: 0.15),
                  valueColor: AlwaysStoppedAnimation<Color>(accentColor),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '$done/$total',
              style: TextStyle(
                fontSize: fontSize - 1,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
      ],
      // Items
      ...display.map(
        (item) => Padding(
          padding: const EdgeInsets.only(bottom: 3),
          child: Row(
            children: [
              Icon(
                item.done
                    ? Icons.check_box_rounded
                    : Icons.check_box_outline_blank_rounded,
                size: fontSize + 1,
                color: item.done ? accentColor : AppColors.textSecondary,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  item.text,
                  style: TextStyle(
                    fontSize: fontSize,
                    color: item.done
                        ? AppColors.textSecondary
                        : AppColors.textPrimary,
                    decoration: item.done ? TextDecoration.lineThrough : null,
                    decorationColor: AppColors.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
      if (remaining > 0)
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Text(
            '+ $remaining autre${remaining > 1 ? 's' : ''}',
            style: TextStyle(
              fontSize: fontSize - 1,
              color: AppColors.textSecondary,
            ),
          ),
        ),
    ],
  );
}

// ── Carte épinglée (pleine largeur) ──────────────────────────────────────────

class _PinnedNoteCard extends StatelessWidget {
  final Note note;
  final VoidCallback onTap;
  final VoidCallback onTogglePin;

  const _PinnedNoteCard({
    required this.note,
    required this.onTap,
    required this.onTogglePin,
  });

  @override
  Widget build(BuildContext context) {
    final color = _hexToColor(note.color);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.15), width: 2),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0A000000),
              blurRadius: 4,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 6,
              decoration: BoxDecoration(
                color: color,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(14),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          note.isChecklist
                              ? Icons.checklist_rounded
                              : Icons.description_outlined,
                          size: 16,
                          color: color,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          note.title,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      // Bouton épingler/désépingler
                      GestureDetector(
                        onTap: onTogglePin,
                        behavior: HitTestBehavior.opaque,
                        child: Padding(
                          padding: const EdgeInsets.all(4),
                          child: Icon(
                            note.isPinned
                                ? Icons.push_pin
                                : Icons.push_pin_outlined,
                            size: 18,
                            color: note.isPinned
                                ? AppColors.accent
                                : AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Contenu
                  if (note.isChecklist && note.checklist.isNotEmpty)
                    _buildChecklistPreview(
                      note.checklist,
                      color,
                      maxItems: 4,
                      fontSize: 13,
                    )
                  else
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
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(
                        Icons.access_time,
                        size: 12,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _formatDate(note.updatedAt),
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 11,
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

// ── Carte récente (grille 2 colonnes) ────────────────────────────────────────

class _RecentNoteCard extends StatelessWidget {
  final Note note;
  final VoidCallback onTap;
  final VoidCallback onTogglePin;

  const _RecentNoteCard({
    required this.note,
    required this.onTap,
    required this.onTogglePin,
  });

  @override
  Widget build(BuildContext context) {
    final color = _hexToColor(note.color);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0A000000),
              blurRadius: 4,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Bande couleur
            Container(
              height: 4,
              decoration: BoxDecoration(
                color: color,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(14),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Icône + bouton épingler
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            note.isChecklist
                                ? Icons.checklist_rounded
                                : Icons.description_outlined,
                            size: 15,
                            color: color,
                          ),
                        ),
                        const Spacer(),
                        GestureDetector(
                          onTap: onTogglePin,
                          behavior: HitTestBehavior.opaque,
                          child: Padding(
                            padding: const EdgeInsets.all(4),
                            child: Icon(
                              note.isPinned
                                  ? Icons.push_pin
                                  : Icons.push_pin_outlined,
                              size: 16,
                              color: note.isPinned
                                  ? AppColors.accent
                                  : AppColors.textSecondary.withValues(
                                      alpha: 0.5,
                                    ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Titre
                    Text(
                      note.title,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    // Contenu
                    Expanded(
                      child: note.isChecklist && note.checklist.isNotEmpty
                          ? ClipRect(
                              child: OverflowBox(
                                alignment: Alignment.topLeft,
                                maxHeight: double.infinity,
                                child: _buildChecklistPreview(
                                  note.checklist,
                                  color,
                                  maxItems: 3,
                                  fontSize: 11,
                                ),
                              ),
                            )
                          : Text(
                              note.content,
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 11,
                                height: 1.4,
                              ),
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                            ),
                    ),
                    const SizedBox(height: 6),
                    // Date
                    Row(
                      children: [
                        const Icon(
                          Icons.access_time,
                          size: 11,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _formatDate(note.updatedAt),
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
