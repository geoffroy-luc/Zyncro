import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../shared/models/note.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../chat/presentation/providers/messages_provider.dart';
import '../../../groups/presentation/providers/groups_provider.dart';
import '../providers/notes_provider.dart';

const _colorPalette = [
  '#4F7CFF',
  '#2BB8A5',
  '#FF6B6B',
  '#FFA940',
  '#7B61FF',
  '#52C41A',
  '#FF85C2',
  '#1890FF',
];

Color _hexToColor(String hex) =>
    Color(int.parse('FF${hex.replaceAll('#', '')}', radix: 16));

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
    _contentController = TextEditingController(text: widget.note?.content ?? '');
    _isPinned = widget.note?.isPinned ?? false;
    _selectedColor = widget.note?.color ?? _colorPalette.first;
    _isChecklist = widget.note?.isChecklist ?? false;
    _checklist = List<ChecklistItem>.from(widget.note?.checklist ?? []);
    _syncChecklistControllers();
  }

  void _syncChecklistControllers() {
    for (final c in _itemControllers) { c.dispose(); }
    for (final f in _itemFocusNodes) { f.dispose(); }
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
    for (final c in _itemControllers) { c.dispose(); }
    for (final f in _itemFocusNodes) { f.dispose(); }
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
      final userName = ref.read(currentMemberProvider).asData?.value?.displayName ??
          user.displayName ??
          user.email ??
          'Quelqu\'un';
      final action = isCreating ? 'a créé une note' : 'a modifié la note';
      ref.read(messagesRepositoryProvider).sendSystemMessage(
        groupId: groupId,
        userId: user.uid,
        content: '📝 $userName $action « $title »',
        notifScreen: 'notes',
      );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Erreur: $e')));
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
        title: const Text('Supprimer la note'),
        content: const Text('Cette action est irréversible.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Supprimer',
                style: TextStyle(color: AppColors.error)),
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
          final userName = ref.read(currentMemberProvider).asData?.value?.displayName ??
          user.displayName ??
          user.email ??
          'Quelqu\'un';
          ref.read(messagesRepositoryProvider).sendSystemMessage(
            groupId: groupId,
            userId: user.uid,
            content:
                '📝 $userName a supprimé la note « ${widget.note!.title} »',
            notifScreen: 'notes',
          );
        }
        if (mounted) Navigator.of(context).pop();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Permission refusée')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(currentMemberProvider); // garde le provider actif pour ref.read() dans les méthodes async
    final isEditing = widget.note != null;
    final accentColor = _hexToColor(_selectedColor);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(isEditing ? 'Modifier la note' : 'Nouvelle note'),
        actions: [
          if (isEditing)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: AppColors.error),
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
                decoration: const InputDecoration(
                  labelText: 'Titre',
                  prefixIcon: Icon(Icons.sticky_note_2_outlined),
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
                'Couleur',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: _colorPalette.map((hex) {
                  final color = _hexToColor(hex);
                  final isSelected = _selectedColor == hex;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedColor = hex),
                    child: Container(
                      width: 30,
                      height: 30,
                      margin: const EdgeInsets.only(right: 10),
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: isSelected
                            ? Border.all(
                                color: AppColors.textPrimary, width: 2.5)
                            : null,
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: color.withValues(alpha: 0.5),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                )
                              ]
                            : null,
                      ),
                      child: isSelected
                          ? const Icon(Icons.check,
                              color: Colors.white, size: 16)
                          : null,
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),

              // Options : épingler + checklist
              Row(
                children: [
                  _OptionChip(
                    icon: _isPinned
                        ? Icons.push_pin
                        : Icons.push_pin_outlined,
                    label: 'Épingler',
                    selected: _isPinned,
                    accentColor: accentColor,
                    onTap: () => setState(() => _isPinned = !_isPinned),
                  ),
                  const SizedBox(width: 8),
                  _OptionChip(
                    icon: _isChecklist
                        ? Icons.checklist_rounded
                        : Icons.checklist_outlined,
                    label: 'Checklist',
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
                  decoration: const InputDecoration(
                    labelText: 'Contenu (optionnel)',
                    prefixIcon: Icon(Icons.notes_outlined),
                    alignLabelWithHint: true,
                  ),
                  textCapitalization: TextCapitalization.sentences,
                  maxLines: 4,
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
                            child: const Icon(
                              Icons.drag_handle,
                              size: 20,
                              color: AppColors.textSecondary,
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
                                hintText: 'Élément ${i + 1}…',
                                hintStyle: const TextStyle(
                                    color: AppColors.textSecondary),
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                contentPadding: EdgeInsets.zero,
                              ),
                              style: TextStyle(
                                fontSize: 15,
                                color: item.done
                                    ? AppColors.textSecondary
                                    : AppColors.textPrimary,
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
                            icon: const Icon(Icons.close,
                                size: 18, color: AppColors.textSecondary),
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
                  label: const Text('Ajouter un élément'),
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

class _OptionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final Color accentColor;
  final VoidCallback onTap;

  const _OptionChip({
    required this.icon,
    required this.label,
    required this.selected,
    required this.accentColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? accentColor.withValues(alpha: 0.1)
              : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? accentColor : AppColors.border,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 16,
                color: selected ? accentColor : AppColors.textSecondary),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: selected ? accentColor : AppColors.textSecondary,
                fontWeight:
                    selected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
