import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:zyncro/core/constants/expense_categories.dart';
import 'package:zyncro/core/utils/color_hex.dart';
import 'package:zyncro/design_system/context_extensions.dart';
import 'package:zyncro/features/auth/presentation/providers/auth_provider.dart';
import 'package:zyncro/features/chat/presentation/providers/messages_provider.dart';
import 'package:zyncro/features/expenses/domain/entities/expense.dart';
import 'package:zyncro/features/expenses/domain/services/money.dart';
import 'package:zyncro/features/expenses/presentation/providers/expenses_provider.dart';
import 'package:zyncro/features/groups/domain/entities/group_member.dart';
import 'package:zyncro/features/groups/presentation/providers/groups_provider.dart';
import 'package:zyncro/features/settings/domain/entities/tab_settings.dart';
import 'package:zyncro/features/settings/presentation/providers/tab_settings_provider.dart';
import 'package:zyncro/shared/domain/categories/expense_category.dart';
import 'package:zyncro/shared/domain/recurrence/recurrence_rule.dart';
import 'package:zyncro/shared/presentation/recurrence_rule_label.dart';
import 'package:zyncro/shared/widgets/category_editor_sheet.dart';
import 'package:zyncro/shared/widgets/user_avatar.dart';

part 'expense_form_split.dart';
part 'expense_form_recurrence.dart';
part 'expense_form_actions.dart';
part 'expense_form_screen_sections.dart';

class ExpenseFormScreen extends ConsumerStatefulWidget {
  final Expense? expense;
  const ExpenseFormScreen({super.key, this.expense});

  @override
  ConsumerState<ExpenseFormScreen> createState() => _ExpenseFormScreenState();
}

/// Champs et contrat commun des mixins de l'écran (parts expense_form_split.dart, expense_form_recurrence.dart, expense_form_actions.dart).
abstract class _ExpenseFormScreenStateBase
    extends ConsumerState<ExpenseFormScreen> {
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

  double? _parseDouble(String input) =>
      double.tryParse(input.replaceAll(',', '.').trim());

  String _memberLabel(GroupMember m, String? currentUid) =>
      m.uid == currentUid ? 'Vous' : m.displayName;

  // ── Implémentées par les mixins ──
  void _ensureSplitControllers(List<GroupMember> members);
  Map<String, double>? _buildSplitAmounts({
    required List<GroupMember> members,
    required double total,
  });
}

class _ExpenseFormScreenState extends _ExpenseFormScreenStateBase
    with
        _ExpenseFormSplit,
        _ExpenseFormRecurrence,
        _ExpenseFormActions,
        _ExpenseFormScreenSections {
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
    for (final c in _amountSplitControllers.values) {
      c.dispose();
    }
    for (final c in _percentageSplitControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final members = ref.watch(expenseMembersProvider).asData?.value ?? [];
    final currentUid = ref.watch(authStateProvider).asData?.value?.uid;
    final categories =
        ref.watch(tabSettingsProvider).asData?.value.expensesCategories ??
        defaultExpenseCategories;
    _ensureSplitControllers(members);

    // Initialise la sélection avec tous les membres au premier chargement
    if (!_membersInitialized && members.isNotEmpty) {
      _membersInitialized = true;
      if (widget.expense == null) {
        _selectedMemberUids = members.map((m) => m.uid).toSet();
        if (_paidByUid == null && currentUid != null) {
          final me = members.firstWhere(
            (m) => m.uid == currentUid,
            orElse: () => members.first,
          );
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
              _percentageSplitControllers[uid]?.text = (v / e.amount * 100)
                  .toStringAsFixed(2);
            }
          }
        }
      }
    }

    final selectedMembers = members
        .where((m) => _selectedMemberUids.contains(m.uid))
        .toList();

    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: AppBar(
        title: Text(
          widget.expense != null ? 'Modifier la dépense' : 'Nouvelle dépense',
        ),
        actions: [
          if (widget.expense != null)
            IconButton(
              icon: Icon(Icons.delete_outline, color: context.colors.error),
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
                decoration: InputDecoration(
                  labelText: context.l10n.expensesTitre,
                  prefixIcon: const Icon(Icons.receipt_outlined),
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
                decoration: InputDecoration(
                  labelText: context.l10n.expensesMontant,
                  prefixIcon: const Icon(Icons.euro_outlined),
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
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
                  if (p > 999999.99) {
                    return 'Montant trop élevé (max 999 999,99 €)';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),

              // Date
              Text(
                context.l10n.expensesDate,
                style: TextStyle(
                  color: context.colors.textSecondary,
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
                    border: Border.all(color: context.colors.border),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.calendar_today_outlined,
                        size: 18,
                        color: context.colors.textSecondary,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        DateFormat('d MMMM yyyy', 'fr_FR').format(_date),
                        style: TextStyle(
                          color: context.colors.textPrimary,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Payé par
              Text(
                context.l10n.expensesPayePar,
                style: TextStyle(
                  color: context.colors.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 12),
              _buildPaidByPicker(members, currentUid),
              const SizedBox(height: 24),

              // Membres
              Text(
                context.l10n.expensesPartagerAvec,
                style: TextStyle(
                  color: context.colors.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 12),
              _buildMembersPicker(members, currentUid),
              const SizedBox(height: 24),

              // Répartition
              Text(
                context.l10n.expensesRepartition,
                style: TextStyle(
                  color: context.colors.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                children: [
                  ChoiceChip(
                    label: Text(context.l10n.expensesEquitable),
                    selected: _splitType == SplitType.equal,
                    onSelected: (_) =>
                        setState(() => _splitType = SplitType.equal),
                  ),
                  ChoiceChip(
                    label: Text(context.l10n.expensesParMontant),
                    selected: _splitType == SplitType.amount,
                    onSelected: (_) {
                      final total = _parseDouble(_amountController.text) ?? 0;
                      setState(() => _splitType = SplitType.amount);
                      if (total > 0) _fillDefaults(selectedMembers, total);
                    },
                  ),
                  ChoiceChip(
                    label: Text(context.l10n.expensesParPourcentage),
                    selected: _splitType == SplitType.percentage,
                    onSelected: (_) {
                      final total = _parseDouble(_amountController.text) ?? 0;
                      setState(() => _splitType = SplitType.percentage);
                      if (total > 0) _fillDefaults(selectedMembers, total);
                    },
                  ),
                ],
              ),
              _buildSplitDetails(currentUid, selectedMembers),
              const SizedBox(height: 24),

              // Répétition
              Text(
                context.l10n.expensesRepetition,
                style: TextStyle(
                  color: context.colors.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              _buildRecurrenceRow(),
              const SizedBox(height: 24),

              // Catégorie
              Text(
                context.l10n.expensesCategorie,
                style: TextStyle(
                  color: context.colors.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 12),
              _buildCategoryPicker(categories),

              if (_splitError != null) ...[
                const SizedBox(height: 16),
                Text(
                  _splitError!,
                  style: TextStyle(color: context.colors.error, fontSize: 13),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
