import 'package:flutter/material.dart';
import 'package:zyncro/design_system/context_extensions.dart';

// ── Guest pseudo sheet ────────────────────────────────────────────────────────

class GuestPseudoSheet extends StatefulWidget {
  final void Function(String pseudo) onConfirm;

  const GuestPseudoSheet({super.key, required this.onConfirm});

  @override
  State<GuestPseudoSheet> createState() => _GuestPseudoSheetState();
}

class _GuestPseudoSheetState extends State<GuestPseudoSheet> {
  final _controller = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(
        24,
        24,
        24,
        MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Continuer sans compte',
                  style: theme.textTheme.titleLarge,
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Entre un pseudo pour être identifié dans ton groupe.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: context.colors.textSecondary,
              ),
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _controller,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Pseudo',
                prefixIcon: Icon(Icons.person_outline),
              ),
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _submit(),
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return 'Le pseudo est requis';
                }
                if (v.trim().length < 2) return 'Minimum 2 caractères';
                return null;
              },
            ),
            const SizedBox(height: 20),
            ElevatedButton(onPressed: _submit, child: const Text('Continuer')),
          ],
        ),
      ),
    );
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      widget.onConfirm(_controller.text.trim());
    }
  }
}
