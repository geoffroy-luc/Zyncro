part of 'expense_form_screen.dart';

/// Répartition (égale / montants / %) : valeurs par défaut, redistribution, validation.
mixin _ExpenseFormSplit on _ExpenseFormScreenStateBase {
  @override
  void _ensureSplitControllers(List<GroupMember> members) {
    final ids = members.map((m) => m.uid).toSet();
    for (final uid
        in _amountSplitControllers.keys
            .where((k) => !ids.contains(k))
            .toList()) {
      _amountSplitControllers.remove(uid)?.dispose();
    }
    for (final uid
        in _percentageSplitControllers.keys
            .where((k) => !ids.contains(k))
            .toList()) {
      _percentageSplitControllers.remove(uid)?.dispose();
    }
    for (final m in members) {
      _amountSplitControllers.putIfAbsent(m.uid, TextEditingController.new);
      _percentageSplitControllers.putIfAbsent(m.uid, TextEditingController.new);
    }
  }

  // Recalcule les parts des autres membres quand l'un d'eux est édité
  void _recalculateFrom(String editingUid, String rawValue) {
    if (_recalculating) return;
    _recalculating = true;
    final entered = _parseDouble(rawValue) ?? 0;
    final others = _selectedMemberUids
        .where((uid) => uid != editingUid)
        .toList();
    if (others.isEmpty) {
      _recalculating = false;
      return;
    }
    if (_splitType == SplitType.percentage) {
      final remaining = (100 - entered).clamp(0.0, 100.0);
      final perOther = remaining / others.length;
      for (final uid in others) {
        _percentageSplitControllers[uid]?.text = perOther.toStringAsFixed(2);
      }
    } else if (_splitType == SplitType.amount) {
      final total = _parseDouble(_amountController.text) ?? 0;
      if (total <= 0) {
        _recalculating = false;
        return;
      }
      final remaining = (total - entered).clamp(0.0, total);
      final shares = allocateCents(toCents(remaining), {
        for (final uid in others) uid: 1.0,
      });
      for (final uid in others) {
        _amountSplitControllers[uid]?.text = fromCents(
          shares[uid]!,
        ).toStringAsFixed(2);
      }
    }
    _recalculating = false;
  }

  void _fillDefaults(List<GroupMember> members, double total) {
    final selected = members
        .where((m) => _selectedMemberUids.contains(m.uid))
        .toList();
    if (selected.isEmpty) return;
    // BUG E1 corrigé : parts par défaut au centime près (33,34 / 33,33 /
    // 33,33 pour 100 €), dont la somme égale le total.
    final shares = allocateCents(toCents(total), {
      for (final m in selected) m.uid: 1.0,
    });
    final perPct = 100 / selected.length;
    for (final m in selected) {
      _amountSplitControllers[m.uid]?.text = fromCents(
        shares[m.uid]!,
      ).toStringAsFixed(2);
      _percentageSplitControllers[m.uid]?.text = perPct.toStringAsFixed(2);
    }
  }

  @override
  Map<String, double>? _buildSplitAmounts({
    required List<GroupMember> members,
    required double total,
  }) {
    final selected = members
        .where((m) => _selectedMemberUids.contains(m.uid))
        .toList();
    if (selected.isEmpty) {
      _splitError = 'Sélectionnez au moins un membre.';
      return null;
    }
    if (_splitType == SplitType.equal) {
      return {for (final m in selected) m.uid: total / selected.length};
    }
    if (_splitType == SplitType.amount) {
      final values = <String, double>{};
      for (final m in selected) {
        final v = _parseDouble(_amountSplitControllers[m.uid]?.text ?? '');
        if (v == null || v < 0) {
          _splitError = 'Montants invalides.';
          return null;
        }
        if (v > 0) values[m.uid] = v;
      }
      if (values.isEmpty) {
        _splitError = 'Au moins une part doit être > 0.';
        return null;
      }
      // Tolérance historique d'un centime, puis ajustement exact au total.
      final sumCents = values.values.fold(0, (a, b) => a + toCents(b));
      if ((sumCents - toCents(total)).abs() > 1) {
        _splitError = 'La somme des montants doit égaler le total.';
        return null;
      }
      return allocateCents(
        toCents(total),
        values,
      ).map((uid, c) => MapEntry(uid, fromCents(c)));
    }
    // percentage
    final pcts = <String, double>{};
    for (final m in selected) {
      final v = _parseDouble(_percentageSplitControllers[m.uid]?.text ?? '');
      if (v == null || v < 0) {
        _splitError = 'Pourcentages invalides.';
        return null;
      }
      if (v > 0) pcts[m.uid] = v;
    }
    if (pcts.isEmpty) {
      _splitError = 'Au moins un % doit être > 0.';
      return null;
    }
    if ((pcts.values.fold(0.0, (a, b) => a + b) - 100).abs() > 0.1) {
      _splitError = 'La somme des pourcentages doit être 100%.';
      return null;
    }
    // BUG E2 corrigé : % normalisés et répartis au centime (Σ = total).
    return allocateCents(
      toCents(total),
      pcts,
    ).map((uid, c) => MapEntry(uid, fromCents(c)));
  }
}
