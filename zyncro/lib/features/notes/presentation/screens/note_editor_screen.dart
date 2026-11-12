import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zyncro/core/constants/app_colors.dart';
import 'package:zyncro/core/utils/color_hex.dart';
import 'package:zyncro/design_system/context_extensions.dart';
import 'package:zyncro/features/auth/presentation/providers/auth_provider.dart';
import 'package:zyncro/features/chat/presentation/providers/messages_provider.dart';
import 'package:zyncro/features/groups/presentation/providers/groups_provider.dart';
import 'package:zyncro/features/notes/domain/entities/note.dart';
import 'package:zyncro/features/notes/presentation/providers/notes_provider.dart';
import 'package:zyncro/features/notes/presentation/widgets/option_chip.dart';
import 'package:zyncro/features/settings/domain/entities/tab_settings.dart';
import 'package:zyncro/features/settings/presentation/providers/tab_settings_provider.dart';
import 'package:zyncro/shared/widgets/color_picker_row.dart';

class NoteEditorScreen extends ConsumerStatefulWidget {
  final Note? note; // null = création

  const NoteEditorScreen({super.key, this.note});

  @override
  ConsumerState<NoteEditorScreen> createState() => _NoteEditorScreenState();
}

class _NoteEditorScreenState extends ConsumerState<NoteEditorScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _contentController;
  late bool _isPinned;
  late String _selectedColor;
  late bool _isChecklist;
  late List<ChecklistItem> _checklist;
  bool _saving = false;

  final List<TextEditingController> _itemControllers = [];
  final List<FocusNode> _itemFocusNodes = [];

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.note?.title ?? '');
    _contentController = TextEditingController(
      text: widget.note?.content ?? '',
    );
    _isPinned = widget.note?.isPinned ?? false;
    _selectedColor =
        widget.note?.color ??
        ref.read(tabSettingsProvider).asData?.value.notesThemeColor ??
        AppColors.itemPalette.first;
    _isChecklist = widget.note?.isChecklist ?? false;
    _checklist = List<ChecklistItem>.from(widget.note?.checklist ?? []);
    _syncChecklistControllers();
  }

  void _syncChecklistControllers() {
    for (final c in _itemControllers) {
      c.dispose();
    }
    for (final f in _itemFocusNodes) {
      f.dispose();
    }
    _itemControllers.clear();
    _itemFocusNodes.clear();
    for (final item in _checklist) {
      _itemControllers.add(TextEditingController(text: item.text));
      _itemFocusNodes.add(FocusNode());
    }
  }

  void _addChecklistItem() {
    setState(() {
      _checklist.add(const ChecklistItem(text: ''));
      final ctrl = TextEditingController();
      final focus = FocusNode();
      _itemControllers.add(ctrl);
      _itemFocusNodes.add(focus);
      WidgetsBinding.instance.addPostFrameCallback((_) => focus.requestFocus());
    });
  }

  void _removeChecklistItem(int index) {
    setState(() {
      _itemControllers[index].dispose();
      _itemFocusNodes[index].dispose();
      _checklist.removeAt(index);
      _itemControllers.removeAt(index);
      _itemFocusNodes.removeAt(index);
    });
  }

  void _reorderChecklistItem(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex--;
      final item = _checklist.removeAt(oldIndex);
      final ctrl = _itemControllers.removeAt(oldIndex);
      final focus = _itemFocusNodes.removeAt(oldIndex);
      _checklist.insert(newIndex, item);
      _itemControllers.insert(newIndex, ctrl);
      _itemFocusNodes.insert(newIndex, focus);
    });
  }

  void _toggleChecklistItem(int index, bool done) {
    setState(() {
      _checklist[index] = _checklist[index].copyWith(done: done);
      if (done) {
        final item = _checklist.removeAt(index);
        final ctrl = _itemControllers.removeAt(index);
        final focus = _itemFocusNodes.removeAt(index);
        _checklist.add(item);
        _itemControllers.add(ctrl);
        _itemFocusNodes.add(focus);
      }
    });
  }

  List<ChecklistItem> _buildChecklist() {
    return List.generate(
      _checklist.length,
      (i) => ChecklistItem(
        text: _itemControllers[i].text.trim(),
        done: _checklist[i].done,
      ),
    ).where((item) => item.text.isNotEmpty).toList();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    for (final c in _itemControllers) {
      c.dispose();
    }
    for (final f in _itemFocusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final user = ref.read(authStateProvider).asData?.value;
    final groupId = ref.read(selectedGroupIdProvider).asData?.value;
    if (user == null || groupId == null) return;

    setState(() => _saving = true);
    try {
      final repo = ref.read(notesRepositoryProvider);
      final checklist = _isChecklist ? _buildChecklist() : <ChecklistItem>[];
      final content = _isChecklist ? '' : _contentController.text.trim();
      final title = _titleController.text.trim();

      final isCreating = widget.note == null;
      if (isCreating) {
        await repo.createNote(
          groupId: groupId,
          title: title,
          content: content,
          isPinned: _isPinned,
          color: _selectedColor,
          isChecklist: _isChecklist,
          checklist: checklist,
          userId: user.uid,
        );
      } else {
        await repo.updateNote(
          groupId,
          widget.note!.copyWith(
            title: title,
            content: content,
            isPinned: _isPinned,
            color: _selectedColor,
            isChecklist: _isChecklist,
            checklist: checklist,
            updatedBy: user.uid,
          ),
        );
      }
      final userName =
          ref.read(currentMemberProvider).asData?.value?.displayName ??
          user.displayName ??
          user.email ??
          'Quelqu\'un';
      final action = isCreating ? 'a créé une note' : 'a modifié la note';
      unawaited(
        ref
            .read(messagesRepositoryProvider)
            .sendSystemMessage(
              groupId: groupId,
              userId: user.uid,
              content: '📝 $userName $action « $title »',
              notifScreen: 'notes',
            ),
      );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.l10n.notesErreur(e))));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    final groupId = ref.read(selectedGroupIdProvider).asData?.value;
    if (groupId == null || widget.note == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.l10n.notesSupprimerLaNote),
        content: Text(context.l10n.notesCetteActionEstIrreversible),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(context.l10n.notesAnnuler),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(
              context.l10n.notesSupprimer,
              style: TextStyle(color: context.colors.error),
            ),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      try {
        await ref
            .read(notesRepositoryProvider)
            .deleteNote(groupId, widget.note!.id);
        final user = ref.read(authStateProvider).asData?.value;
        if (user != null) {
          final userName =
              ref.read(currentMemberProvider).asData?.value?.displayName ??
              user.displayName ??
              user.email ??
              'Quelqu\'un';
          unawaited(
            ref
                .read(messagesRepositoryProvider)
                .sendSystemMessage(
                  groupId: groupId,
                  userId: user.uid,
                  content:
                      '📝 $userName a supprimé la note « ${widget.note!.title} »',
                  notifScreen: 'notes',
                ),
          );
        }
        if (mounted) Navigator.of(context).pop();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(context.l10n.notesPermissionRefusee)),
          );
        }
      }
    }
  }

  Future<void> _addCustomColor(String hex) async {
    final groupId = ref.read(selectedGroupIdProvider).asData?.value;
    if (groupId == null) return;
    final settings =
        ref.read(tabSettingsProvider).asData?.value ?? TabSettings.defaults;
    await ref
        .read(tabSettingsRepositoryProvider)
        .updateSettings(
          groupId,
          from: settings,
          to: settings.copyWith(customColors: [...settings.customColors, hex]),
        );
  }

  Future<void> _deleteCustomColor(String hex) async {
    final groupId = ref.read(selectedGroupIdProvider).asData?.value;
    if (groupId == null) return;
    final settings =
        ref.read(tabSettingsProvider).asData?.value ?? TabSettings.defaults;
    await ref
        .read(tabSettingsRepositoryProvider)
        .updateSettings(
          groupId,
          from: settings,
          to: settings.withColorRemoved(hex),
        );
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(
      currentMemberProvider,
    ); // garde le provider actif pour ref.read() dans les méthodes async
    final isEditing = widget.note != null;
    final tabSettings =
        ref.watch(tabSettingsProvider).asData?.value ?? TabSettings.defaults;
    final accentColor = hexToColor(_selectedColor);

    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: AppBar(
        title: Text(isEditing ? 'Modifier la note' : 'Nouvelle note'),
        actions: [
          if (isEditing)
            IconButton(
              icon: Icon(Icons.delete_outline, color: context.colors.error),
              onPressed: _delete,
            ),
          IconButton(
            icon: _saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.check),
            onPressed: _saving ? null : _save,
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Titre
              TextFormField(
                controller: _titleController,
                decoration: InputDecoration(
                  labelText: context.l10n.notesTitre,
                  prefixIcon: const Icon(Icons.sticky_note_2_outlined),
                ),
                textCapitalization: TextCapitalization.sentences,
                maxLength: 50,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Champ requis';
                  if (v.trim().length > 50) return '50 caractères maximum';
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Couleur
              Text(
                context.l10n.notesCouleur,
                style: TextStyle(
                  color: context.colors.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 10),
              ColorPickerRow(
                basePalette: AppColors.itemPalette,
                selected: _selectedColor,
                extraColors: tabSettings.customColors,
                hiddenBaseColors: tabSettings.hiddenBaseColors,
                onSelect: (hex) => setState(() => _selectedColor = hex),
                onAddColor: _addCustomColor,
                onDeleteColor: _deleteCustomColor,
              ),
              const SizedBox(height: 24),

              // Options : épingler + checklist
              Row(
                children: [
                  OptionChip(
                    icon: _isPinned ? Icons.push_pin : Icons.push_pin_outlined,
                    label: context.l10n.notesEpingler,
                    selected: _isPinned,
                    accentColor: accentColor,
                    onTap: () => setState(() => _isPinned = !_isPinned),
                  ),
                  const SizedBox(width: 8),
                  OptionChip(
                    icon: _isChecklist
                        ? Icons.checklist_rounded
                        : Icons.checklist_outlined,
                    label: context.l10n.notesChecklist,
                    selected: _isChecklist,
                    accentColor: accentColor,
                    onTap: () {
                      setState(() {
                        _isChecklist = !_isChecklist;
                        if (_isChecklist && _checklist.isEmpty) {
                          _checklist.add(const ChecklistItem(text: ''));
                          _itemControllers.add(TextEditingController());
                          _itemFocusNodes.add(FocusNode());
                        }
                      });
                    },
                  ),
                ],
              ),

              // Contenu (seulement si pas checklist)
              if (!_isChecklist) ...[
                const SizedBox(height: 24),
                TextFormField(
                  controller: _contentController,
                  decoration: InputDecoration(
                    labelText: context.l10n.notesContenuOptionnel,
                    prefixIcon: const Icon(Icons.notes_outlined),
                    alignLabelWithHint: true,
                  ),
                  textCapitalization: TextCapitalization.sentences,
                  maxLines: null,
                ),
              ],

              // Checklist items
              if (_isChecklist) ...[
                const SizedBox(height: 16),
                ReorderableListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _checklist.length,
                  onReorder: _reorderChecklistItem,
                  itemBuilder: (context, i) {
                    final item = _checklist[i];
                    return Padding(
                      key: ValueKey(i),
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        children: [
                          ReorderableDragStartListener(
                            index: i,
                            child: Icon(
                              Icons.drag_handle,
                              size: 20,
                              color: context.colors.textSecondary,
                            ),
                          ),
                          Checkbox(
                            value: item.done,
                            onChanged: (v) =>
                                _toggleChecklistItem(i, v ?? false),
                            activeColor: accentColor,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          Expanded(
                            child: TextField(
                              controller: _itemControllers[i],
                              focusNode: _itemFocusNodes[i],
                              decoration: InputDecoration(
                                hintText: context.l10n.notesElement(i + 1),
                                hintStyle: TextStyle(
                                  color: context.colors.textSecondary,
                                ),
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                contentPadding: EdgeInsets.zero,
                              ),
                              style: TextStyle(
                                fontSize: 15,
                                color: item.done
                                    ? context.colors.textSecondary
                                    : context.colors.textPrimary,
                                decoration: item.done
                                    ? TextDecoration.lineThrough
                                    : TextDecoration.none,
                                height: 1.6,
                              ),
                              maxLines: null,
                              textCapitalization: TextCapitalization.sentences,
                              onSubmitted: (_) => _addChecklistItem(),
                            ),
                          ),
                          IconButton(
                            icon: Icon(
                              Icons.close,
                              size: 18,
                              color: context.colors.textSecondary,
                            ),
                            onPressed: () => _removeChecklistItem(i),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                TextButton.icon(
                  onPressed: _addChecklistItem,
                  icon: const Icon(Icons.add, size: 18),
                  label: Text(context.l10n.notesAjouterUnElement),
                  style: TextButton.styleFrom(
                    foregroundColor: accentColor,
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
