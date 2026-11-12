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
        final original = widget.expense!;
        final repo = ref.read(expensesRepositoryProvider);
        // BUG E8 corrigé : sur une occurrence (hors première), choix de la
        // portée ; l'ancre de la série n'est plus réécrite à sa date.
        var scope = SeriesScope.wholeSeries;
        if (original.isSeriesOccurrence && original.occurrenceIndex! > 0) {
          final chosen = await showSeriesScopeDialog(
            context,
            title: context.l10n.expensesModifierRecurrente,
            deleting: false,
          );
          if (chosen == null) {
            if (mounted) setState(() => _saving = false);
            return;
          }
          scope = chosen;
        }
        if (scope == SeriesScope.thisAndFollowing) {
          final index = original.occurrenceIndex!;
          // La série d'origine s'arrête juste avant cette occurrence…
          await repo.updateExpense(
            groupId,
            original.copyWith(
              date: original.seriesStart,
              recurrence: truncateBefore(
                original.recurrence!,
                index: index,
                occurrence: original.date,
              ),
            ),
          );
          // … et une nouvelle série reprend à partir d'elle.
          await repo.createExpense(
            groupId: groupId,
            title: title,
            amount: amount,
            paidBy: effectivePaidByUid,
            paidByName: effectivePaidByName,
            splitWith: splitAmounts.keys.toList(),
            expenseType: original.expenseType,
            splitType: _splitType,
            splitAmounts: splitAmounts,
            category: _selectedCategory,
            date: _date,
            userId: user.uid,
            recurrence: sameRule(_recurrence, original.recurrence)
                ? continueFrom(original.recurrence!, index: index)
                : _recurrence,
          );
        } else {
          final updated = original.copyWith(
            title: title,
            amount: amount,
            paidBy: effectivePaidByUid,
            paidByName: effectivePaidByName,
            splitWith: splitAmounts.keys.toList(),
            splitType: _splitType,
            splitAmounts: splitAmounts,
            category: _selectedCategory,
            date: original.isSeriesOccurrence
                ? shiftAnchor(
                    original.seriesStart!,
                    occurrence: original.date,
                    edited: _date,
                  )
                : _date,
            updatedBy: user.uid,
            recurrence: _recurrence,
            clearRecurrence: _recurrence == null,
          );
          await repo.updateExpense(groupId, updated);
        }
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
    final original = widget.expense!;
    // BUG E9 corrigé : sur une occurrence (hors première), choix entre
    // « celle-ci et les suivantes » (la série s'arrête avant) et toute la
    // série ; sur la première, l'avertissement dit que la série part.
    if (original.isSeriesOccurrence && original.occurrenceIndex! > 0) {
      final scope = await showSeriesScopeDialog(
        context,
        title: context.l10n.expensesSupprimerRecurrente,
        deleting: true,
      );
      if (scope == null || !mounted) return;
      if (scope == SeriesScope.thisAndFollowing) {
        await _stopSeriesBefore(original);
        return;
      }
      await _deleteConfirmed(original);
      return;
    }
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.l10n.expensesSupprimerLaDepense),
        content: Text(
          original.recurrence != null
              ? context.l10n.seriesSuppressionSerieEntiere
              : context.l10n.expensesCetteActionEstIrreversible,
        ),
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

    if (confirm == true && mounted) await _deleteConfirmed(original);
  }

  Future<void> _stopSeriesBefore(Expense original) async {
    final groupId = ref.read(selectedGroupIdProvider).asData?.value;
    if (groupId == null) return;
    try {
      await ref
          .read(expensesRepositoryProvider)
          .updateExpense(
            groupId,
            original.copyWith(
              date: original.seriesStart,
              recurrence: truncateBefore(
                original.recurrence!,
                index: original.occurrenceIndex!,
                occurrence: original.date,
              ),
            ),
          );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.l10n.expensesErreur(e))));
      }
    }
  }

  Future<void> _deleteConfirmed(Expense original) async {
    final user = ref.read(authStateProvider).asData?.value;
    final groupId = ref.read(selectedGroupIdProvider).asData?.value;
    if (groupId == null) return;
    try {
      await ref
          .read(expensesRepositoryProvider)
          .deleteExpense(groupId, original.firestoreId);
      final userName = user?.displayName ?? user?.email ?? 'Quelqu\'un';
      if (user != null) {
        unawaited(
          ref
              .read(messagesRepositoryProvider)
              .sendSystemMessage(
                groupId: groupId,
                userId: user.uid,
                content:
                    '💰 $userName a supprimé une dépense « ${original.title} »',
                notifScreen: 'expenses',
              ),
        );
      }
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        // BUG E24 (en partie) corrigé : « Permission refusée » seulement si
        // c'en est une ; sinon l'erreur réelle.
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              FailureMapper.from(e) is PermissionDeniedFailure
                  ? context.l10n.expensesPermissionRefusee
                  : context.l10n.expensesErreur(e),
            ),
          ),
        );
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
