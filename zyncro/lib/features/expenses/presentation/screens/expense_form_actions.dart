part of 'expense_form_screen.dart';

/// Date, enregistrement, suppression, création de catégorie.
mixin _ExpenseFormActions on _ExpenseFormScreenStateBase {
  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final user = ref.read(authStateProvider).asData?.value;
    final groupId = ref.read(selectedGroupIdProvider).asData?.value;
    final members = ref.read(expenseMembersProvider).asData?.value ?? [];
    if (user == null || groupId == null) return;

    final amount = _parseDouble(_amountController.text);
    if (amount == null || amount <= 0) return;

    _ensureSplitControllers(members);
    setState(() {
      _saving = true;
      _splitError = null;
    });

    try {
      final splitAmounts = _buildSplitAmounts(members: members, total: amount);
      if (splitAmounts == null) {
        setState(() => _saving = false);
        return;
      }
      final title = _titleController.text.trim();
      final effectivePaidByUid = _paidByUid ?? user.uid;
      final currentMemberName = members
          .where((m) => m.uid == user.uid)
          .map((m) => m.displayName)
          .firstOrNull;
      final effectivePaidByName = effectivePaidByUid == user.uid
          ? (currentMemberName ?? user.displayName ?? _paidByName ?? 'Moi')
          : (_paidByName ?? 'Membre');
      final userName =
          currentMemberName ?? user.displayName ?? user.email ?? 'Quelqu\'un';

      if (widget.expense != null) {
        final updated = widget.expense!.copyWith(
          title: title,
          amount: amount,
          paidBy: effectivePaidByUid,
          paidByName: effectivePaidByName,
          splitWith: splitAmounts.keys.toList(),
          splitType: _splitType,
          splitAmounts: splitAmounts,
          category: _selectedCategory,
          date: _date,
          updatedBy: user.uid,
          recurrence: _recurrence,
          clearRecurrence: _recurrence == null,
        );
        await ref
            .read(expensesRepositoryProvider)
            .updateExpense(groupId, updated);
        unawaited(
          ref
              .read(messagesRepositoryProvider)
              .sendSystemMessage(
                groupId: groupId,
                userId: user.uid,
                content:
                    '💰 $userName a modifié la dépense « $title » (${amount.toStringAsFixed(2)} €)',
                notifScreen: 'expenses',
              ),
        );
      } else {
        await ref
            .read(expensesRepositoryProvider)
            .createExpense(
              groupId: groupId,
              title: title,
              amount: amount,
              paidBy: effectivePaidByUid,
              paidByName: effectivePaidByName,
              splitWith: splitAmounts.keys.toList(),
              expenseType: ExpenseType.expense,
              splitType: _splitType,
              splitAmounts: splitAmounts,
              category: _selectedCategory,
              date: _date,
              userId: user.uid,
              recurrence: _recurrence,
            );
        unawaited(
          ref
              .read(messagesRepositoryProvider)
              .sendSystemMessage(
                groupId: groupId,
                userId: user.uid,
                content:
                    '💰 $userName a ajouté une dépense « $title » (${amount.toStringAsFixed(2)} €)',
                notifScreen: 'expenses',
              ),
        );
      }
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.l10n.expensesErreur(e))));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.l10n.expensesSupprimerLaDepense),
        content: Text(context.l10n.expensesCetteActionEstIrreversible),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(context.l10n.expensesAnnuler),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(
              context.l10n.expensesSupprimer,
              style: TextStyle(color: context.colors.error),
            ),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      final user = ref.read(authStateProvider).asData?.value;
      final groupId = ref.read(selectedGroupIdProvider).asData?.value;
      if (groupId == null) return;
      try {
        await ref
            .read(expensesRepositoryProvider)
            .deleteExpense(groupId, widget.expense!.firestoreId);
        final userName = user?.displayName ?? user?.email ?? 'Quelqu\'un';
        if (user != null) {
          unawaited(
            ref
                .read(messagesRepositoryProvider)
                .sendSystemMessage(
                  groupId: groupId,
                  userId: user.uid,
                  content:
                      '💰 $userName a supprimé une dépense « ${widget.expense!.title} »',
                  notifScreen: 'expenses',
                ),
          );
        }
        if (mounted) Navigator.of(context).pop();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(context.l10n.expensesPermissionRefusee)),
          );
        }
      }
    }
  }

  Future<void> _addCategory() async {
    final result = await showCategoryEditor(context);
    if (result == null) return;
    final groupId = ref.read(selectedGroupIdProvider).asData?.value;
    if (groupId == null) return;
    final settings =
        ref.read(tabSettingsProvider).asData?.value ?? TabSettings.defaults;
    final updated = [...settings.expensesCategories, result];
    await ref
        .read(tabSettingsRepositoryProvider)
        .updateSettings(
          groupId,
          from: settings,
          to: settings.copyWith(expensesCategories: updated),
        );
    if (!mounted) return;
    setState(() => _selectedCategory = result.name);
  }
}
