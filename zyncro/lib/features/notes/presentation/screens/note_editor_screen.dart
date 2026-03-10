import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../shared/models/note.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../groups/presentation/providers/groups_provider.dart';
import '../providers/notes_provider.dart';

// Palette de couleurs disponibles pour une note (stockée en hex string)
const _noteColors = [
  Color(0xFF2BB8A5),
  Color(0xFF4F7CFF),
  Color(0xFFFFB86B),
  Color(0xFFE85D75),
  Color(0xFF9B59B6),
  Color(0xFF27AE60),
];

String _colorToHex(Color c) =>
    '#${c.toARGB32().toRadixString(16).substring(2).toUpperCase()}';

Color _hexToColor(String hex) =>
    Color(int.parse('FF${hex.replaceAll('#', '')}', radix: 16));

class NoteEditorScreen extends ConsumerStatefulWidget {
  final Note? note; // null = création

  const NoteEditorScreen({super.key, this.note});

  @override
  ConsumerState<NoteEditorScreen> createState() => _NoteEditorScreenState();
}

class _NoteEditorScreenState extends ConsumerState<NoteEditorScreen> {
  late final TextEditingController _titleController;
  late final TextEditingController _contentController;
  late bool _isPinned;
  late Color _selectedColor;
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
    _selectedColor = widget.note?.color != null
        ? _hexToColor(widget.note!.color!)
        : _noteColors.first;
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

  void _toggleChecklistItem(int index, bool done) {
    setState(() {
      _checklist[index] = _checklist[index].copyWith(done: done);
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
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Le titre est requis')),
      );
      return;
    }

    final user = ref.read(authStateProvider).asData?.value;
    final groupId = ref.read(selectedGroupIdProvider).asData?.value;
    if (user == null || groupId == null) return;

    setState(() => _saving = true);
    try {
      final repo = ref.read(notesRepositoryProvider);
      final checklist = _isChecklist ? _buildChecklist() : <ChecklistItem>[];
      final content = _isChecklist ? '' : _contentController.text.trim();

      if (widget.note == null) {
        await repo.createNote(
          groupId: groupId,
          title: title,
          content: content,
          isPinned: _isPinned,
          color: _colorToHex(_selectedColor),
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
            color: _colorToHex(_selectedColor),
            isChecklist: _isChecklist,
            checklist: checklist,
          ),
        );
      }
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e')),
        );
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
            child: const Text('Supprimer', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      try {
        await ref.read(notesRepositoryProvider).deleteNote(groupId, widget.note!.id);
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
    final isEditing = widget.note != null;
    final authUser = ref.watch(authStateProvider).asData?.value;
    final group = ref.watch(selectedGroupProvider);
    final canDelete = isEditing &&
        authUser != null &&
        (widget.note!.createdBy == authUser.uid ||
            group?.createdBy == authUser.uid);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(isEditing ? 'Modifier la note' : 'Nouvelle note'),
        actions: [
          if (canDelete)
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
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Couleur
            SizedBox(
              height: 36,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _noteColors.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (_, i) {
                  final color = _noteColors[i];
                  final selected = color == _selectedColor;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedColor = color),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: selected
                            ? Border.all(color: AppColors.textPrimary, width: 2.5)
                            : null,
                      ),
                      child: selected
                          ? const Icon(Icons.check, color: Colors.white, size: 18)
                          : null,
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 20),

            // Épingler + Toggle checklist
            Row(
              children: [
                Expanded(
                  child: SwitchListTile(
                    value: _isPinned,
                    onChanged: (v) => setState(() => _isPinned = v),
                    title: const Text('Épingler'),
                    secondary: const Icon(Icons.push_pin_outlined),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: SwitchListTile(
                    value: _isChecklist,
                    onChanged: (v) {
                      setState(() {
                        _isChecklist = v;
                        if (v && _checklist.isEmpty) {
                          _checklist.add(const ChecklistItem(text: ''));
                          _itemControllers.add(TextEditingController());
                          _itemFocusNodes.add(FocusNode());
                        }
                      });
                    },
                    title: const Text('Checklist'),
                    secondary: const Icon(Icons.checklist_outlined),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Titre
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                hintText: 'Titre',
                hintStyle: TextStyle(color: AppColors.textSecondary),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
              ),
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
              textCapitalization: TextCapitalization.sentences,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r"[a-zA-ZÀ-ÿ0-9 '\-]")),
              ],
            ),
            const Divider(color: AppColors.border),
            const SizedBox(height: 8),

            // Contenu : texte libre ou checklist
            if (_isChecklist) ...[
              ..._checklist.asMap().entries.map((entry) {
                final i = entry.key;
                final item = entry.value;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: [
                      Checkbox(
                        value: item.done,
                        onChanged: (v) => _toggleChecklistItem(i, v ?? false),
                        activeColor: _selectedColor,
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
                            hintStyle: const TextStyle(color: AppColors.textSecondary),
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
                          textCapitalization: TextCapitalization.sentences,
                          onSubmitted: (_) => _addChecklistItem(),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 18, color: AppColors.textSecondary),
                        onPressed: () => _removeChecklistItem(i),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                );
              }),
              TextButton.icon(
                onPressed: _addChecklistItem,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Ajouter un élément'),
                style: TextButton.styleFrom(
                  foregroundColor: _selectedColor,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                ),
              ),
            ] else
              TextField(
                controller: _contentController,
                decoration: const InputDecoration(
                  hintText: 'Écrire quelque chose...',
                  hintStyle: TextStyle(color: AppColors.textSecondary),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                ),
                style: const TextStyle(
                  fontSize: 15,
                  color: AppColors.textPrimary,
                  height: 1.6,
                ),
                maxLines: null,
                keyboardType: TextInputType.multiline,
                textCapitalization: TextCapitalization.sentences,
              ),
          ],
        ),
      ),
    );
  }
}
