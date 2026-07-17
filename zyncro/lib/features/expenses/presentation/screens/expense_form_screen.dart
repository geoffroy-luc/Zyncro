import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/expense_categories.dart';
import '../../../../shared/models/expense.dart';
import '../../../../shared/models/expense_category.dart';
import '../../../../shared/models/group_member.dart';
import '../../../../shared/models/recurrence_rule.dart';
import '../../../../shared/models/tab_settings.dart';
import '../../../../shared/widgets/category_editor_sheet.dart';
import '../../../../shared/widgets/color_picker_row.dart';
import '../../../../shared/widgets/user_avatar.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../chat/presentation/providers/messages_provider.dart';
import '../../../groups/presentation/providers/groups_provider.dart';
import '../../../groups/presentation/providers/tab_settings_provider.dart';
import '../providers/expenses_provider.dart';


class ExpenseFormScreen extends ConsumerStatefulWidget {
  final Expense? expense;
  const ExpenseFormScreen({super.key, this.expense});

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
  SplitType _splitType = SplitType.equal;
  String? _splitError;
  Set<String> _selectedMemberUids = {};
  bool _membersInitialized = false;
  bool _recalculating = false;
  String? _paidByUid;
  String? _paidByName;
  RecurrenceRule? _recurrence;

  @override
  void initState() {
    super.initState();
    final e = widget.expense;
    if (e != null) {
      _titleController.text = e.title;
      _amountController.text = e.amount.toStringAsFixed(2);
      _date = e.date;
      _paidByUid = e.paidBy;
      _paidByName = e.paidByName;
      _selectedMemberUids = e.splitWith.toSet();
      _splitType = e.splitType;
      _selectedCategory = e.category;
      _recurrence = e.recurrence;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    for (final c in _amountSplitControllers.values) { c.dispose(); }
    for (final c in _percentageSplitControllers.values) { c.dispose(); }
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

  double? _parseDouble(String input) =>
      double.tryParse(input.replaceAll(',', '.').trim());

  String _memberLabel(GroupMember m, String? currentUid) =>
      m.uid == currentUid ? 'Vous' : m.displayName;

  void _ensureSplitControllers(List<GroupMember> members) {
    final ids = members.map((m) => m.uid).toSet();
    for (final uid in _amountSplitControllers.keys
        .where((k) => !ids.contains(k))
        .toList()) {
      _amountSplitControllers.remove(uid)?.dispose();
    }
    for (final uid in _percentageSplitControllers.keys
        .where((k) => !ids.contains(k))
        .toList()) {
      _percentageSplitControllers.remove(uid)?.dispose();
    }
    for (final m in members) {
      _amountSplitControllers.putIfAbsent(m.uid, () => TextEditingController());
      _percentageSplitControllers.putIfAbsent(
          m.uid, () => TextEditingController());
    }
  }

  // Recalcule les parts des autres membres quand l'un d'eux est édité
  void _recalculateFrom(String editingUid, String rawValue) {
    if (_recalculating) return;
    _recalculating = true;
    final entered = _parseDouble(rawValue) ?? 0;
    final others = _selectedMemberUids.where((uid) => uid != editingUid).toList();
    if (others.isEmpty) {
      _recalculating = false;
      return;
    }
    if (_splitType == SplitType.percentage) {
      final remaining = (100 - entered).clamp(0.0, 100.0);
      final perOther = remaining / others.length;
      for (final uid in others) {
        _percentageSplitControllers[uid]?.text =
            perOther.toStringAsFixed(2);
      }
    } else if (_splitType == SplitType.amount) {
      final total = _parseDouble(_amountController.text) ?? 0;
      if (total <= 0) {
        _recalculating = false;
        return;
      }
      final remaining = (total - entered).clamp(0.0, total);
      final perOther = remaining / others.length;
      for (final uid in others) {
        _amountSplitControllers[uid]?.text = perOther.toStringAsFixed(2);
      }
    }
    _recalculating = false;
  }

  void _fillDefaults(List<GroupMember> members, double total) {
    final selected = members.where((m) => _selectedMemberUids.contains(m.uid)).toList();
    if (selected.isEmpty) return;
    final perAmount = total / selected.length;
    final perPct = 100 / selected.length;
    for (var i = 0; i < selected.length; i++) {
      final uid = selected[i].uid;
      final amount = i == selected.length - 1
          ? total - perAmount * (selected.length - 1)
          : perAmount;
      _amountSplitControllers[uid]?.text = amount.toStringAsFixed(2);
      _percentageSplitControllers[uid]?.text = perPct.toStringAsFixed(2);
    }
  }

  Map<String, double>? _buildSplitAmounts({
    required List<GroupMember> members,
    required double total,
  }) {
    final selected = members.where((m) => _selectedMemberUids.contains(m.uid)).toList();
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
      if ((values.values.fold(0.0, (a, b) => a + b) - total).abs() > 0.01) {
        _splitError = 'La somme des montants doit égaler le total.';
        return null;
      }
      return values;
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
    return {for (final e in pcts.entries) e.key: total * e.value / 100};
  }

  Future<void> _showRecurrencePicker() async {
    RecurrenceFrequency? selectedFreq = _recurrence?.frequency;
    RecurrenceEndType endType = _recurrence?.endType ?? RecurrenceEndType.forever;
    int countValue = _recurrence?.count ?? 4;
    final countController = TextEditingController(text: '$countValue');
    DateTime untilDate = _recurrence?.until ?? _date.add(const Duration(days: 30));

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) {
          final primary = Theme.of(ctx).colorScheme.primary;
          final frequencies = [
            (RecurrenceFrequency.daily, 'Tous les jours'),
            (RecurrenceFrequency.weekly, 'Toutes les semaines'),
            (RecurrenceFrequency.monthly, 'Tous les mois'),
            (RecurrenceFrequency.yearly, 'Tous les ans'),
          ];
          return SafeArea(
            child: SingleChildScrollView(
              padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
                    child: Text('Répétition',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w600)),
                  ),
                  ListTile(
                    leading: Icon(Icons.block_outlined,
                        color: selectedFreq == null ? primary : AppColors.textSecondary),
                    title: const Text('Aucune'),
                    trailing: selectedFreq == null
                        ? Icon(Icons.check, color: primary) : null,
                    onTap: () => setSt(() => selectedFreq = null),
                  ),
                  ...frequencies.map((f) {
                    final (freq, label) = f;
                    final isSelected = selectedFreq == freq;
                    return ListTile(
                      leading: Icon(Icons.repeat,
                          color: isSelected ? primary : AppColors.textSecondary),
                      title: Text(label),
                      trailing: isSelected
                          ? Icon(Icons.check, color: primary) : null,
                      onTap: () => setSt(() => selectedFreq = freq),
                    );
                  }),
                  if (selectedFreq != null) ...[
                    const Divider(height: 24),
                    const Padding(
                      padding: EdgeInsets.fromLTRB(24, 0, 24, 8),
                      child: Text('Fin de la répétition',
                          style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                              fontWeight: FontWeight.w500)),
                    ),
                    RadioListTile<RecurrenceEndType>(
                      value: RecurrenceEndType.forever,
                      groupValue: endType,
                      onChanged: (v) => setSt(() => endType = v!),
                      title: const Text('Toujours'),
                      activeColor: primary,
                    ),
                    RadioListTile<RecurrenceEndType>(
                      value: RecurrenceEndType.count,
                      groupValue: endType,
                      onChanged: (v) => setSt(() => endType = v!),
                      activeColor: primary,
                      title: endType == RecurrenceEndType.count
                          ? Row(children: [
                              const Text('Nombre de fois :'),
                              const SizedBox(width: 12),
                              SizedBox(
                                width: 72,
                                child: TextField(
                                  controller: countController,
                                  keyboardType: TextInputType.number,
                                  textAlign: TextAlign.center,
                                  maxLength: 3,
                                  decoration: const InputDecoration(
                                    counterText: '',
                                    isDense: true,
                                    border: OutlineInputBorder(),
                                    contentPadding: EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 8),
                                  ),
                                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                  onChanged: (v) {
                                    final n = int.tryParse(v);
                                    if (n != null && n >= 1 && n <= 999) {
                                      setSt(() => countValue = n);
                                    }
                                  },
                                ),
                              ),
                            ])
                          : const Text('Nombre de fois'),
                    ),
                    RadioListTile<RecurrenceEndType>(
                      value: RecurrenceEndType.until,
                      groupValue: endType,
                      onChanged: (v) => setSt(() => endType = v!),
                      activeColor: primary,
                      title: endType == RecurrenceEndType.until
                          ? Row(children: [
                              const Text('Jusqu\'au :'),
                              const SizedBox(width: 12),
                              GestureDetector(
                                onTap: () async {
                                  final picked = await showDatePicker(
                                    context: ctx,
                                    initialDate: untilDate,
                                    firstDate: _date,
                                    lastDate: DateTime(2100),
                                  );
                                  if (picked != null) {
                                    setSt(() {
                                      untilDate = picked;
                                    });
                                  }
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    border: Border.all(color: AppColors.border),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    DateFormat('d MMM yyyy', 'fr_FR').format(untilDate),
                                    style: TextStyle(
                                        color: primary, fontSize: 13),
                                  ),
                                ),
                              ),
                            ])
                          : const Text('Jusqu\'au'),
                    ),
                  ],
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                    child: SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () {
                          setState(() {
                            if (selectedFreq == null) {
                              _recurrence = null;
                            } else {
                              _recurrence = RecurrenceRule(
                                frequency: selectedFreq!,
                                endType: endType,
                                count: endType == RecurrenceEndType.count ? countValue : null,
                                until: endType == RecurrenceEndType.until ? untilDate : null,
                              );
                            }
                          });
                          Navigator.pop(ctx);
                        },
                        style: FilledButton.styleFrom(backgroundColor: primary),
                        child: const Text('Confirmer'),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildRecurrenceRow() {
    final label = _recurrence?.label ?? 'Aucune répétition';
    return GestureDetector(
      onTap: _showRecurrencePicker,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            const Icon(Icons.repeat, size: 20, color: AppColors.textSecondary),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: _recurrence != null ? AppColors.textPrimary : AppColors.textSecondary,
                  fontSize: 14,
                ),
              ),
            ),
            const Icon(Icons.chevron_right, size: 20, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
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
      final userName = currentMemberName ?? user.displayName ?? user.email ?? 'Quelqu\'un';

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
        await ref.read(expensesRepositoryProvider).updateExpense(groupId, updated);
        ref.read(messagesRepositoryProvider).sendSystemMessage(
          groupId: groupId,
          userId: user.uid,
          content:
              '💰 $userName a modifié la dépense « $title » (${amount.toStringAsFixed(2)} €)',
          notifScreen: 'expenses',
        );
      } else {
        await ref.read(expensesRepositoryProvider).createExpense(
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
        ref.read(messagesRepositoryProvider).sendSystemMessage(
          groupId: groupId,
          userId: user.uid,
          content:
              '💰 $userName a ajouté une dépense « $title » (${amount.toStringAsFixed(2)} €)',
          notifScreen: 'expenses',
        );
      }
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
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Supprimer la dépense'),
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
      final user = ref.read(authStateProvider).asData?.value;
      final groupId = ref.read(selectedGroupIdProvider).asData?.value;
      if (groupId == null) return;
      try {
        await ref
            .read(expensesRepositoryProvider)
            .deleteExpense(groupId, widget.expense!.firestoreId);
        final userName = user?.displayName ?? user?.email ?? 'Quelqu\'un';
        if (user != null) {
          ref.read(messagesRepositoryProvider).sendSystemMessage(
            groupId: groupId,
            userId: user.uid,
            content:
                '💰 $userName a supprimé une dépense « ${widget.expense!.title} »',
            notifScreen: 'expenses',
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
        .updateSettings(groupId, settings.copyWith(expensesCategories: updated));
    if (!mounted) return;
    setState(() => _selectedCategory = result.name);
  }

  @override
  Widget build(BuildContext context) {
    final members = ref.watch(expenseMembersProvider).asData?.value ?? [];
    final currentUid = ref.watch(authStateProvider).asData?.value?.uid;
    final categories = ref.watch(tabSettingsProvider).asData?.value.expensesCategories ??
        defaultExpenseCategories;
    _ensureSplitControllers(members);

    // Initialise la sélection avec tous les membres au premier chargement
    if (!_membersInitialized && members.isNotEmpty) {
      _membersInitialized = true;
      if (widget.expense == null) {
        _selectedMemberUids = members.map((m) => m.uid).toSet();
        if (_paidByUid == null && currentUid != null) {
          final me = members.firstWhere((m) => m.uid == currentUid,
              orElse: () => members.first);
          _paidByUid = me.uid;
          _paidByName = me.displayName;
        }
      } else {
        // En mode édition, pré-remplir les controllers de répartition
        final e = widget.expense!;
        final splitAmounts = e.splitAmounts;
        if (splitAmounts != null && e.splitType != SplitType.equal) {
          for (final uid in _selectedMemberUids) {
            final v = splitAmounts[uid] ?? 0.0;
            if (e.splitType == SplitType.amount) {
              _amountSplitControllers[uid]?.text = v.toStringAsFixed(2);
            } else {
              _percentageSplitControllers[uid]?.text =
                  (v / e.amount * 100).toStringAsFixed(2);
            }
          }
        }
      }
    }

    final selectedMembers =
        members.where((m) => _selectedMemberUids.contains(m.uid)).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(widget.expense != null ? 'Modifier la dépense' : 'Nouvelle dépense'),
        actions: [
          if (widget.expense != null)
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
                  prefixIcon: Icon(Icons.receipt_outlined),
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

              // Montant
              TextFormField(
                controller: _amountController,
                decoration: const InputDecoration(
                  labelText: 'Montant (€)',
                  prefixIcon: Icon(Icons.euro_outlined),
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                onChanged: (_) => setState(() {
                  if (_splitType != SplitType.equal) {
                    final total = _parseDouble(_amountController.text) ?? 0;
                    if (total > 0 && selectedMembers.isNotEmpty) {
                      _fillDefaults(selectedMembers, total);
                    }
                  }
                }),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Champ requis';
                  final p = _parseDouble(v);
                  if (p == null || p <= 0) return 'Montant invalide';
                  if (p > 999999.99) return 'Montant trop élevé (max 999 999,99 €)';
                  return null;
                },
              ),
              const SizedBox(height: 24),

              // Date
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
                      horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today_outlined,
                          size: 18, color: AppColors.textSecondary),
                      const SizedBox(width: 12),
                      Text(
                        DateFormat('d MMMM yyyy', 'fr_FR').format(_date),
                        style: const TextStyle(
                            color: AppColors.textPrimary, fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Payé par
              const Text(
                'Payé par',
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
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? color.withValues(alpha: 0.10)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected ? color : AppColors.border,
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
                              fontWeight: isSelected
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                              color:
                                  isSelected ? color : AppColors.textPrimary,
                            ),
                          ),
                          if (isSelected) ...[
                            const SizedBox(width: 6),
                            Icon(Icons.check_circle_rounded,
                                size: 14, color: color),
                          ],
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),

              // Membres
              const Text(
                'Partager avec',
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
                          final total =
                              _parseDouble(_amountController.text) ?? 0;
                          if (total > 0) {
                            _fillDefaults(
                              members
                                  .where((x) =>
                                      _selectedMemberUids.contains(x.uid))
                                  .toList(),
                              total,
                            );
                          }
                        }
                      });
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? color.withValues(alpha: 0.10)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected ? color : AppColors.border,
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
                              fontWeight: isSelected
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                              color: isSelected
                                  ? color
                                  : AppColors.textPrimary,
                            ),
                          ),
                          if (isSelected) ...[
                            const SizedBox(width: 6),
                            Icon(Icons.check_circle_rounded,
                                size: 14, color: color),
                          ],
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),

              // Répartition
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
                      if (total > 0) _fillDefaults(selectedMembers, total);
                    },
                  ),
                  ChoiceChip(
                    label: const Text('Par pourcentage'),
                    selected: _splitType == SplitType.percentage,
                    onSelected: (_) {
                      final total = _parseDouble(_amountController.text) ?? 0;
                      setState(() => _splitType = SplitType.percentage);
                      if (total > 0) _fillDefaults(selectedMembers, total);
                    },
                  ),
                ],
              ),
              Builder(builder: (_) {
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
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: AppColors.textPrimary,
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
                                decimal: true),
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
              }),
              const SizedBox(height: 24),

              // Répétition
              const Text(
                'Répétition',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              _buildRecurrenceRow(),
              const SizedBox(height: 24),

              // Catégorie
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
                children: [
                  ...categories.map((cat) {
                    final label = cat.name;
                    final icon = iconForKey(cat.iconKey);
                    final color = hexToColor(cat.colorHex);
                    final selected = _selectedCategory == label;
                    return GestureDetector(
                      onTap: () => setState(() => _selectedCategory = label),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
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
                            Icon(icon,
                                size: 16,
                                color: selected
                                    ? color
                                    : AppColors.textSecondary),
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
                  }),
                  GestureDetector(
                    onTap: _addCategory,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.add,
                              size: 16, color: AppColors.textSecondary),
                          SizedBox(width: 6),
                          Text(
                            'Nouvelle catégorie',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 13,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              if (_splitError != null) ...[
                const SizedBox(height: 16),
                Text(_splitError!,
                    style: const TextStyle(
                        color: AppColors.error, fontSize: 13)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
