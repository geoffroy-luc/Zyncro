import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../shared/models/note.dart';
import '../providers/notes_provider.dart';
import 'note_editor_screen.dart';

class _ChecklistPreview extends StatelessWidget {
  final Note note;
  final int maxItems;

  const _ChecklistPreview({required this.note, required this.maxItems});

  @override
  Widget build(BuildContext context) {
    final items = note.checklist.take(maxItems).toList();
    final remaining = note.checklist.length - items.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        ...items.map((item) => Padding(
              padding: const EdgeInsets.only(bottom: 3),
              child: Row(
                children: [
                  Icon(
                    item.done ? Icons.check_box : Icons.check_box_outline_blank,
                    size: 13,
                    color: item.done ? AppColors.secondary : AppColors.textSecondary,
                  ),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      item.text,
                      style: TextStyle(
                        color: item.done ? AppColors.textSecondary : AppColors.textPrimary,
                        fontSize: 12,
                        decoration: item.done ? TextDecoration.lineThrough : null,
                        height: 1.4,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            )),
        if (remaining > 0)
          Text(
            '+ $remaining autre${remaining > 1 ? 's' : ''}',
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
          ),
      ],
    );
  }
}

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
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => NoteEditorScreen(note: note)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;
    final notesAsync = ref.watch(notesProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      body: notesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erreur: $e')),
        data: (allNotes) {
          final filtered = _search.isEmpty
              ? allNotes
              : allNotes
                  .where((n) =>
                      n.title.toLowerCase().contains(_search.toLowerCase()) ||
                      n.content.toLowerCase().contains(_search.toLowerCase()))
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
                          GestureDetector(
                            onTap: () => _openEditor(),
                            child: Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [Color(0xFF2BB8A5), Color(0xFF1E9B8A)],
                                ),
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF2BB8A5).withValues(alpha: 0.25),
                                    blurRadius: 8,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: const Icon(Icons.add, color: Colors.white, size: 20),
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
                              child: Icon(Icons.search, color: AppColors.textSecondary, size: 20),
                            ),
                            Expanded(
                              child: TextField(
                                onChanged: (v) => setState(() => _search = v),
                                decoration: const InputDecoration(
                                  hintText: 'Rechercher...',
                                  hintStyle: TextStyle(color: AppColors.textSecondary, fontSize: 14),
                                  border: InputBorder.none,
                                  enabledBorder: InputBorder.none,
                                  focusedBorder: InputBorder.none,
                                  contentPadding: EdgeInsets.symmetric(vertical: 12),
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
                        const Icon(Icons.description_outlined,
                            size: 48, color: AppColors.textSecondary),
                        const SizedBox(height: 12),
                        const Text('Aucune note',
                            style: TextStyle(color: AppColors.textSecondary)),
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
                            Icon(Icons.push_pin, size: 16, color: AppColors.accent),
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
                        ...pinned.map((note) => Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _PinnedNoteCard(
                                note: note,
                                onTap: () => _openEditor(note: note),
                              ),
                            )),
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

class _PinnedNoteCard extends StatelessWidget {
  final Note note;
  final VoidCallback onTap;

  const _PinnedNoteCard({required this.note, required this.onTap});

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
            BoxShadow(color: Color(0x0A000000), blurRadius: 4, offset: Offset(0, 2))
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 6,
              decoration: BoxDecoration(
                color: color,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
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
                          note.isChecklist ? Icons.checklist_outlined : Icons.description_outlined,
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
                      const Icon(Icons.push_pin, size: 16, color: AppColors.accent),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (note.isChecklist)
                    _ChecklistPreview(note: note, maxItems: 3)
                  else
                    Text(
                      note.content,
                      style: const TextStyle(
                          color: AppColors.textSecondary, fontSize: 13, height: 1.5),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(Icons.access_time, size: 12, color: AppColors.textSecondary),
                      const SizedBox(width: 4),
                      Text(
                        _formatDate(note.updatedAt),
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
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

class _RecentNoteCard extends StatelessWidget {
  final Note note;
  final VoidCallback onTap;

  const _RecentNoteCard({required this.note, required this.onTap});

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
            BoxShadow(color: Color(0x0A000000), blurRadius: 4, offset: Offset(0, 2))
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 4,
              decoration: BoxDecoration(
                color: color,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        note.isChecklist ? Icons.checklist_outlined : Icons.description_outlined,
                        size: 16,
                        color: color,
                      ),
                    ),
                    const SizedBox(height: 10),
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
                    Expanded(
                      child: note.isChecklist
                          ? _ChecklistPreview(note: note, maxItems: 2)
                          : Text(
                              note.content,
                              style: const TextStyle(
                                  color: AppColors.textSecondary, fontSize: 11, height: 1.4),
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                            ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.access_time, size: 11, color: AppColors.textSecondary),
                        const SizedBox(width: 4),
                        Text(
                          _formatDate(note.updatedAt),
                          style: const TextStyle(color: AppColors.textSecondary, fontSize: 10),
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
