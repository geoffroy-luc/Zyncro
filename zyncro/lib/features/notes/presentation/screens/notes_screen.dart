import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zyncro/design_system/context_extensions.dart';
import 'package:zyncro/features/groups/presentation/providers/groups_provider.dart';
import 'package:zyncro/features/notes/domain/entities/note.dart';
import 'package:zyncro/features/notes/presentation/providers/notes_provider.dart';
import 'package:zyncro/features/notes/presentation/screens/note_editor_screen.dart';
import 'package:zyncro/features/notes/presentation/widgets/pinned_note_card.dart';
import 'package:zyncro/features/notes/presentation/widgets/recent_note_card.dart';

class NotesScreen extends ConsumerStatefulWidget {
  const NotesScreen({super.key});

  @override
  ConsumerState<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends ConsumerState<NotesScreen> {
  String _search = '';

  void _openEditor({Note? note}) {
    unawaited(
      Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => NoteEditorScreen(note: note)),
      ),
    );
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
          SnackBar(
            content: Text(
              context.l10n.notesImpossibleDEpinglerPermissionRefusee,
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final notesAsync = ref.watch(notesProvider);

    return Scaffold(
      backgroundColor: context.colors.background,
      floatingActionButton: FloatingActionButton(
        heroTag: 'fab_notes',
        onPressed: _openEditor,
        backgroundColor: Theme.of(
          context,
        ).colorScheme.primary.withValues(alpha: 0.85),
        shape: const CircleBorder(
          side: BorderSide(color: Colors.white24, width: 2),
        ),
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: SafeArea(
        child: notesAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text(context.l10n.notesErreur(e))),
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
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
                    child: Column(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            color: context.colors.background,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: context.colors.border),
                          ),
                          child: Row(
                            children: [
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                ),
                                child: Icon(
                                  Icons.search,
                                  color: context.colors.textSecondary,
                                  size: 20,
                                ),
                              ),
                              Expanded(
                                child: TextField(
                                  onChanged: (v) => setState(() => _search = v),
                                  decoration: InputDecoration(
                                    hintText: context.l10n.notesRechercher,
                                    hintStyle: TextStyle(
                                      color: context.colors.textSecondary,
                                      fontSize: 14,
                                    ),
                                    border: InputBorder.none,
                                    enabledBorder: InputBorder.none,
                                    focusedBorder: InputBorder.none,
                                    contentPadding: const EdgeInsets.symmetric(
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
                SliverToBoxAdapter(
                  child: Divider(height: 1, color: context.colors.border),
                ),

                // ── Contenu ─────────────────────────────────────────────
                if (allNotes.isEmpty)
                  SliverFillRemaining(
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.description_outlined,
                            size: 48,
                            color: context.colors.textSecondary,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            context.l10n.notesAucuneNote,
                            style: TextStyle(
                              color: context.colors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: _openEditor,
                            icon: const Icon(Icons.add),
                            label: Text(context.l10n.notesCreerUneNote),
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
                          Row(
                            children: [
                              Icon(
                                Icons.push_pin,
                                size: 16,
                                color: context.colors.accent,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                context.l10n.notesEpinglees,
                                style: TextStyle(
                                  color: context.colors.textPrimary,
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
                              child: PinnedNoteCard(
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
                          Text(
                            context.l10n.notesRecentes,
                            style: TextStyle(
                              color: context.colors.textPrimary,
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
                            itemBuilder: (_, i) => RecentNoteCard(
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
      ),
    );
  }
}
