import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../shared/models/expense.dart';
import '../../../../shared/models/group_member.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../groups/presentation/providers/groups_provider.dart';
import '../providers/expenses_provider.dart';

const _categories = [
  ('Alimentation', Icons.restaurant_outlined, Color(0xFF2BB8A5)),
  ('Logement', Icons.home_outlined, Color(0xFF4F7CFF)),
  ('Transport', Icons.directions_car_outlined, Color(0xFF9B59B6)),
  ('Loisirs', Icons.sports_esports_outlined, Color(0xFFE85D75)),
  ('Services', Icons.build_outlined, Color(0xFFFFB86B)),
  ('Autre', Icons.category_outlined, Color(0xFF6B7280)),
];

class ExpenseFormScreen extends ConsumerStatefulWidget {
  const ExpenseFormScreen({super.key});

  @override
  ConsumerState<ExpenseFormScreen> createState() => _ExpenseFormScreenState();
}

class _ExpenseFormScreenState extends ConsumerState<ExpenseFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();
  final Map<String, TextEditingController> _amountSplitControllers = {};
  final Map<String, TextEditingController> _percentageSplitControllers = {};
  String? _selectedCategory;
  DateTime _date = DateTime.now();
  bool _saving = false;
  ExpenseType _expenseType = ExpenseType.expense;
  SplitType _splitType = SplitType.equal;
  String? _reimbursementToUid;
  String? _splitError;

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    for (final c in _amountSplitControllers.values) {
      c.dispose();
    }
    for (final c in _percentageSplitControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _date = picked);
  }

  double? _parseDouble(String input) {
    return double.tryParse(input.replaceAll(',', '.').trim());
  }

  String _memberLabel(GroupMember m, String? currentUid) {
    if (m.uid == currentUid) return 'Vous';
    return m.displayName;
  }

  void _ensureSplitControllers(List<GroupMember> members) {
    final ids = members.map((m) => m.uid).toSet();
    final staleAmount = _amountSplitControllers.keys
        .where((k) => !ids.contains(k))
        .toList();
    for (final uid in staleAmount) {
      _amountSplitControllers.remove(uid)?.dispose();
    }
    final stalePct = _percentageSplitControllers.keys
        .where((k) => !ids.contains(k))
        .toList();
    for (final uid in stalePct) {
      _percentageSplitControllers.remove(uid)?.dispose();
    }
    for (final member in members) {
      _amountSplitControllers.putIfAbsent(
        member.uid,
        () => TextEditingController(),
      );
      _percentageSplitControllers.putIfAbsent(
        member.uid,
        () => TextEditingController(),
      );
    }
  }

  void _fillDefaults(List<GroupMember> members, double total) {
    if (members.isEmpty) return;
    final perAmount = total > 0 ? total / members.length : 0.0;
    final perPct = 100 / members.length;
    for (var i = 0; i < members.length; i++) {
      final uid = members[i].uid;
      final amount = i == members.length - 1
          ? (total - (perAmount * (members.length - 1)))
          : perAmount;
      _amountSplitControllers[uid]?.text = amount.toStringAsFixed(2);
      _percentageSplitControllers[uid]?.text = perPct.toStringAsFixed(2);
    }
  }

  Map<String, double>? _buildSplitAmounts({
    required List<GroupMember> members,
    required double total,
  }) {
    if (_splitType == SplitType.equal) {
      final active = members.map((m) => m.uid).toList();
      if (active.isEmpty) {
        _splitError = 'Aucun membre disponible pour la répartition.';
        return null;
      }
      final perAmount = total / active.length;
      return {for (final uid in active) uid: perAmount};
    }

    if (_splitType == SplitType.amount) {
      final values = <String, double>{};
      for (final m in members) {
        final parsed = _parseDouble(_amountSplitControllers[m.uid]?.text ?? '');
        if (parsed == null || parsed < 0) {
          _splitError = 'Montants invalides dans la répartition.';
          return null;
        }
        if (parsed > 0) values[m.uid] = parsed;
      }
      if (values.isEmpty) {
        _splitError = 'Au moins une part doit être supérieure à 0.';
        return null;
      }
      final sum = values.values.fold(0.0, (a, b) => a + b);
      if ((sum - total).abs() > 0.01) {
        _splitError = 'La somme des montants doit être égale au total.';
        return null;
      }
      return values;
    }

    final percentages = <String, double>{};
    for (final m in members) {
      final parsed = _parseDouble(
        _percentageSplitControllers[m.uid]?.text ?? '',
      );
      if (parsed == null || parsed < 0) {
        _splitError = 'Pourcentages invalides dans la répartition.';
        return null;
      }
      if (parsed > 0) percentages[m.uid] = parsed;
    }
    if (percentages.isEmpty) {
      _splitError = 'Au moins un pourcentage doit être supérieur à 0.';
      return null;
    }
    final sumPct = percentages.values.fold(0.0, (a, b) => a + b);
    if ((sumPct - 100).abs() > 0.1) {
      _splitError = 'La somme des pourcentages doit être de 100%.';
      return null;
    }
    final values = <String, double>{};
    percentages.forEach((uid, pct) {
      values[uid] = total * (pct / 100);
    });
    return values;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final user = ref.read(authStateProvider).asData?.value;
    final groupId = ref.read(selectedGroupIdProvider).asData?.value;
    final group = ref.read(selectedGroupProvider);
    final members = ref.read(expenseMembersProvider).asData?.value ?? [];
    if (user == null || groupId == null || group == null) return;

    final amount = _parseDouble(_amountController.text);
    if (amount == null || amount <= 0) return;

    _ensureSplitControllers(members);
    setState(() {
      _saving = true;
      _splitError = null;
    });
    try {
      final memberNameByUid = <String, String>{
        for (final m in members) m.uid: m.displayName,
      };

      if (_expenseType == ExpenseType.reimbursement) {
        final toUid = _reimbursementToUid;
        if (toUid == null) {
          setState(() => _splitError = 'Choisissez à qui vous remboursez.');
          return;
        }
        await ref
            .read(expensesRepositoryProvider)
            .createExpense(
              groupId: groupId,
              title: _titleController.text.trim().isEmpty
                  ? 'Remboursement'
                  : _titleController.text.trim(),
              amount: amount,
              paidBy: toUid,
              paidByName: memberNameByUid[toUid] ?? toUid,
              splitWith: [user.uid],
              expenseType: ExpenseType.reimbursement,
              splitType: SplitType.amount,
              splitAmounts: {user.uid: amount},
              category: null,
              date: _date,
              userId: user.uid,
            );
      } else {
        final splitAmounts = _buildSplitAmounts(
          members: members,
          total: amount,
        );
        if (splitAmounts == null) return;
        await ref
            .read(expensesRepositoryProvider)
            .createExpense(
              groupId: groupId,
              title: _titleController.text.trim(),
              amount: amount,
              paidBy: user.uid,
              paidByName: user.displayName ?? user.email ?? 'Moi',
              splitWith: splitAmounts.keys.toList(),
              expenseType: ExpenseType.expense,
              splitType: _splitType,
              splitAmounts: splitAmounts,
              category: _selectedCategory,
              date: _date,
              userId: user.uid,
            );
      }
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erreur: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final members = ref.watch(expenseMembersProvider).asData?.value ?? [];
    final currentUid = ref.watch(authStateProvider).asData?.value?.uid;
    _ensureSplitControllers(members);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Nouvelle dépense'),
        actions: [
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
              const Text(
                'Type',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                children: [
                  ChoiceChip(
                    label: const Text('Dépense'),
                    selected: _expenseType == ExpenseType.expense,
                    onSelected: (_) =>
                        setState(() => _expenseType = ExpenseType.expense),
                  ),
                  ChoiceChip(
                    label: const Text('Remboursement'),
                    selected: _expenseType == ExpenseType.reimbursement,
                    onSelected: (_) => setState(
                      () => _expenseType = ExpenseType.reimbursement,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _titleController,
                decoration: InputDecoration(
                  labelText: _expenseType == ExpenseType.reimbursement
                      ? 'Libellé (optionnel)'
                      : 'Titre',
                  prefixIcon: const Icon(Icons.receipt_outlined),
                ),
                textCapitalization: TextCapitalization.sentences,
                validator: (v) {
                  if (_expenseType == ExpenseType.reimbursement) return null;
                  return v == null || v.trim().isEmpty ? 'Champ requis' : null;
                },
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _amountController,
                decoration: const InputDecoration(
                  labelText: 'Montant (€)',
                  prefixIcon: Icon(Icons.euro_outlined),
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                onChanged: (_) {
                  if (_splitType == SplitType.equal ||
                      _expenseType == ExpenseType.reimbursement) {
                    return;
                  }
                  final total = _parseDouble(_amountController.text) ?? 0;
                  if (total > 0 && members.isNotEmpty) {
                    _fillDefaults(members, total);
                  }
                },
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Champ requis';
                  final parsed = _parseDouble(v);
                  if (parsed == null || parsed <= 0) return 'Montant invalide';
                  return null;
                },
              ),
              const SizedBox(height: 24),

              const Text(
                'Date',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: _pickDate,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.calendar_today_outlined,
                        size: 18,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        DateFormat('d MMMM yyyy', 'fr_FR').format(_date),
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              if (_expenseType == ExpenseType.reimbursement) ...[
                DropdownButtonFormField<String>(
                  initialValue: _reimbursementToUid,
                  decoration: const InputDecoration(
                    labelText: 'Je rembourse à',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                  items: members
                      .where((m) => m.uid != currentUid)
                      .map(
                        (m) => DropdownMenuItem(
                          value: m.uid,
                          child: Text(_memberLabel(m, currentUid)),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setState(() => _reimbursementToUid = v),
                  validator: (v) => v == null ? 'Champ requis' : null,
                ),
              ] else ...[
                const Text(
                  'Répartition',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 10,
                  children: [
                    ChoiceChip(
                      label: const Text('Équitable'),
                      selected: _splitType == SplitType.equal,
                      onSelected: (_) =>
                          setState(() => _splitType = SplitType.equal),
                    ),
                    ChoiceChip(
                      label: const Text('Par montant'),
                      selected: _splitType == SplitType.amount,
                      onSelected: (_) {
                        final total = _parseDouble(_amountController.text) ?? 0;
                        setState(() => _splitType = SplitType.amount);
                        if (total > 0) _fillDefaults(members, total);
                      },
                    ),
                    ChoiceChip(
                      label: const Text('Par pourcentage'),
                      selected: _splitType == SplitType.percentage,
                      onSelected: (_) {
                        final total = _parseDouble(_amountController.text) ?? 0;
                        setState(() => _splitType = SplitType.percentage);
                        if (total > 0) _fillDefaults(members, total);
                      },
                    ),
                  ],
                ),
                if (_splitType != SplitType.equal) ...[
                  const SizedBox(height: 14),
                  ...members.map((m) {
                    final controller = _splitType == SplitType.amount
                        ? _amountSplitControllers[m.uid]!
                        : _percentageSplitControllers[m.uid]!;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: TextField(
                        controller: controller,
                        decoration: InputDecoration(
                          labelText: _splitType == SplitType.amount
                              ? '${_memberLabel(m, currentUid)} (€)'
                              : '${_memberLabel(m, currentUid)} (%)',
                          prefixIcon: const Icon(Icons.tune),
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                      ),
                    );
                  }),
                ],
                const SizedBox(height: 24),
                const Text(
                  'Catégorie',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: _categories.map((cat) {
                    final (label, icon, color) = cat;
                    final selected = _selectedCategory == label;
                    return GestureDetector(
                      onTap: () => setState(() => _selectedCategory = label),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: selected
                              ? color.withValues(alpha: 0.12)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: selected ? color : AppColors.border,
                            width: selected ? 1.5 : 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              icon,
                              size: 16,
                              color: selected ? color : AppColors.textSecondary,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              label,
                              style: TextStyle(
                                color: selected
                                    ? color
                                    : AppColors.textSecondary,
                                fontSize: 13,
                                fontWeight: selected
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
              if (_splitError != null) ...[
                const SizedBox(height: 16),
                Text(
                  _splitError!,
                  style: const TextStyle(color: AppColors.error, fontSize: 13),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
