import 'package:flutter/material.dart';
import 'package:zyncro/design_system/context_extensions.dart';

// ── Edit poll dialog ──────────────────────────────────────────────────────────

class EditPollDialog extends StatefulWidget {
  final String question;
  final List<String> options;
  final bool multipleChoice;

  const EditPollDialog({
    super.key,
    required this.question,
    required this.options,
    this.multipleChoice = false,
  });

  @override
  State<EditPollDialog> createState() => _EditPollDialogState();
}

class _EditPollDialogState extends State<EditPollDialog> {
  late final TextEditingController _questionController;
  late final List<TextEditingController> _optionControllers;
  late bool _multipleChoice;

  @override
  void initState() {
    super.initState();
    _questionController = TextEditingController(text: widget.question);
    _optionControllers = widget.options
        .map((o) => TextEditingController(text: o))
        .toList();
    while (_optionControllers.length < 2) {
      _optionControllers.add(TextEditingController());
    }
    _multipleChoice = widget.multipleChoice;
  }

  @override
  void dispose() {
    _questionController.dispose();
    for (final c in _optionControllers) {
      c.dispose();
    }
    super.dispose();
  }

  bool get _isValid {
    if (_questionController.text.trim().isEmpty) return false;
    return _optionControllers.where((c) => c.text.trim().isNotEmpty).length >=
        2;
  }

  void _addOption() {
    if (_optionControllers.length >= 5) return;
    setState(() => _optionControllers.add(TextEditingController()));
  }

  void _removeOption(int index) {
    if (_optionControllers.length <= 2) return;
    final c = _optionControllers.removeAt(index);
    c.dispose();
    setState(() {});
  }

  void _submit() {
    final question = _questionController.text.trim();
    final options = _optionControllers
        .map((c) => c.text.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    if (question.isEmpty || options.length < 2) return;
    Navigator.of(context).pop({
      'question': question,
      'options': options,
      'multipleChoice': _multipleChoice,
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Icon(
            Icons.poll_outlined,
            color: Theme.of(context).colorScheme.primary,
            size: 20,
          ),
          const SizedBox(width: 8),
          Text(context.l10n.chatModifierLeSondage),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _questionController,
              autofocus: true,
              maxLines: 2,
              minLines: 1,
              decoration: InputDecoration(
                labelText: context.l10n.chatQuestion,
                hintText: context.l10n.chatPosezVotreQuestion,
                border: const OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 16),
            Text(
              context.l10n.chatOptions,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: context.colors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            ...List.generate(_optionControllers.length, (i) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _optionControllers[i],
                        decoration: InputDecoration(
                          hintText: context.l10n.chatOption(i + 1),
                          border: const OutlineInputBorder(),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          isDense: true,
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    if (_optionControllers.length > 2)
                      IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        color: context.colors.textSecondary,
                        onPressed: () => _removeOption(i),
                        padding: const EdgeInsets.only(left: 4),
                        constraints: const BoxConstraints(),
                      ),
                  ],
                ),
              );
            }),
            if (_optionControllers.length < 5)
              TextButton.icon(
                onPressed: _addOption,
                icon: const Icon(Icons.add, size: 16),
                label: Text(context.l10n.chatAjouterUneOption),
                style: TextButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.primary,
                  padding: EdgeInsets.zero,
                ),
              ),
            SwitchListTile(
              value: _multipleChoice,
              onChanged: (v) => setState(() => _multipleChoice = v),
              title: Text(
                context.l10n.chatReponsesMultiples,
                style: const TextStyle(fontSize: 14),
              ),
              subtitle: Text(
                context.l10n.chatLesParticipantsPeuventVoterPour,
                style: const TextStyle(fontSize: 11),
              ),
              activeThumbColor: Theme.of(context).colorScheme.primary,
              contentPadding: EdgeInsets.zero,
              dense: true,
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.warning_amber_outlined,
                    color: Colors.orange,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      context.l10n.chatLesVotesExistantsSerontReinitialises,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.orange,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.l10n.chatAnnuler),
        ),
        FilledButton(
          onPressed: _isValid ? _submit : null,
          child: Text(context.l10n.chatModifier),
        ),
      ],
    );
  }
}
