part of 'expense_form_screen.dart';

/// Sections du formulaire (payeur, participants, répartition, catégorie) : déplacement pur du build.
mixin _ExpenseFormScreenSections
    on
        _ExpenseFormScreenStateBase,
        _ExpenseFormSplit,
        _ExpenseFormRecurrence,
        _ExpenseFormActions {
  Widget _buildPaidByPicker(List<GroupMember> members, String? currentUid) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: members.map((m) {
        final isSelected = _paidByUid == m.uid;
        final color = avatarColorForUid(m.uid);
        final label = _memberLabel(m, currentUid);
        return GestureDetector(
          onTap: () => setState(() {
            _paidByUid = m.uid;
            _paidByName = m.displayName;
          }),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected ? color.withValues(alpha: 0.10) : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? color : context.colors.border,
                width: isSelected ? 1.5 : 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                UserAvatar(
                  photoUrl: m.photoUrl,
                  showPhoto: m.showProfilePhoto,
                  displayName: m.displayName,
                  radius: 14,
                  color: color,
                ),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                    color: isSelected ? color : context.colors.textPrimary,
                  ),
                ),
                if (isSelected) ...[
                  const SizedBox(width: 6),
                  Icon(Icons.check_circle_rounded, size: 14, color: color),
                ],
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildMembersPicker(List<GroupMember> members, String? currentUid) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: members.map((m) {
        final isSelected = _selectedMemberUids.contains(m.uid);
        final color = avatarColorForUid(m.uid);
        final label = _memberLabel(m, currentUid);
        return GestureDetector(
          onTap: () {
            setState(() {
              if (isSelected && _selectedMemberUids.length > 1) {
                _selectedMemberUids.remove(m.uid);
              } else if (!isSelected) {
                _selectedMemberUids.add(m.uid);
              }
              // Recalculer les défauts si besoin
              if (_splitType != SplitType.equal) {
                final total = _parseDouble(_amountController.text) ?? 0;
                if (total > 0) {
                  _fillDefaults(
                    members
                        .where((x) => _selectedMemberUids.contains(x.uid))
                        .toList(),
                    total,
                  );
                }
              }
            });
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected ? color.withValues(alpha: 0.10) : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? color : context.colors.border,
                width: isSelected ? 1.5 : 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                UserAvatar(
                  photoUrl: m.photoUrl,
                  showPhoto: m.showProfilePhoto,
                  displayName: m.displayName,
                  radius: 14,
                  color: color,
                ),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                    color: isSelected ? color : context.colors.textPrimary,
                  ),
                ),
                if (isSelected) ...[
                  const SizedBox(width: 6),
                  Icon(Icons.check_circle_rounded, size: 14, color: color),
                ],
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSplitDetails(
    String? currentUid,
    List<GroupMember> selectedMembers,
  ) {
    return Builder(
      builder: (_) {
        final total = _parseDouble(_amountController.text) ?? 0;
        final n = selectedMembers.length;
        if (_splitType == SplitType.equal && total > 0 && n > 0) {
          final share = total / n;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 14),
              ...selectedMembers.map((m) {
                final color = avatarColorForUid(m.uid);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      UserAvatar(
                        photoUrl: m.photoUrl,
                        showPhoto: m.showProfilePhoto,
                        displayName: m.displayName,
                        radius: 14,
                        color: color,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _memberLabel(m, currentUid),
                          style: TextStyle(
                            fontSize: 14,
                            color: context.colors.textPrimary,
                          ),
                        ),
                      ),
                      Text(
                        '${share.toStringAsFixed(2)} €',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: color,
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          );
        }
        if (_splitType != SplitType.equal) {
          return Column(
            children: [
              const SizedBox(height: 14),
              ...selectedMembers.map((m) {
                final ctrl = _splitType == SplitType.amount
                    ? _amountSplitControllers[m.uid]!
                    : _percentageSplitControllers[m.uid]!;
                final suffix = _splitType == SplitType.amount ? '€' : '%';
                final color = avatarColorForUid(m.uid);
                // Montant réel calculé pour le mode pourcentage
                String? realAmount;
                if (_splitType == SplitType.percentage && total > 0) {
                  final pct = _parseDouble(ctrl.text) ?? 0;
                  realAmount = '${(total * pct / 100).toStringAsFixed(2)} €';
                }
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: TextField(
                    controller: ctrl,
                    decoration: InputDecoration(
                      labelText: '${_memberLabel(m, currentUid)} ($suffix)',
                      prefixIcon: const Icon(Icons.tune),
                      suffixText: realAmount,
                      suffixStyle: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: color,
                      ),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    onChanged: (v) {
                      _recalculateFrom(m.uid, v);
                      setState(() {});
                    },
                  ),
                );
              }),
            ],
          );
        }
        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildCategoryPicker(List<ExpenseCategory> categories) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        ...categories.map((cat) {
          final label = cat.name;
          final icon = iconForKey(cat.iconKey);
          final color = hexToColor(cat.colorHex);
          final selected = _selectedCategory == label;
          return GestureDetector(
            // Toucher la catégorie choisie la retire (BUG E17 corrigé).
            onTap: () => setState(
              () =>
                  _selectedCategory = _selectedCategory == label ? null : label,
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: selected ? color.withValues(alpha: 0.12) : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: selected ? color : context.colors.border,
                  width: selected ? 1.5 : 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    icon,
                    size: 16,
                    color: selected ? color : context.colors.textSecondary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    label,
                    style: TextStyle(
                      color: selected ? color : context.colors.textSecondary,
                      fontSize: 13,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
        GestureDetector(
          onTap: _addCategory,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: context.colors.border),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.add, size: 16, color: context.colors.textSecondary),
                const SizedBox(width: 6),
                Text(
                  context.l10n.expensesNouvelleCategorie,
                  style: TextStyle(
                    color: context.colors.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
