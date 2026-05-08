import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../shared/models/expense.dart';
import '../../../../shared/widgets/user_avatar.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../chat/presentation/providers/messages_provider.dart';
import '../../../groups/presentation/providers/groups_provider.dart';
import '../providers/expenses_provider.dart';


class ReimbursementFormScreen extends ConsumerStatefulWidget {
  final String? initialToUid;
  final double? initialAmount;

  const ReimbursementFormScreen({
    super.key,
    this.initialToUid,
    this.initialAmount,
  });

  @override
  ConsumerState<ReimbursementFormScreen> createState() =>
      _ReimbursementFormScreenState();
}

class _ReimbursementFormScreenState
    extends ConsumerState<ReimbursementFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();
  DateTime _date = DateTime.now();
  String? _toUid;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _toUid = widget.initialToUid;
    if (widget.initialAmount != null) {
      _amountController.text =
          widget.initialAmount!.toStringAsFixed(2).replaceAll('.', ',');
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  double? _parseDouble(String input) =>
      double.tryParse(input.replaceAll(',', '.').trim());

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
    setState(() => _error = null);

    if (!_formKey.currentState!.validate()) return;

    if (_toUid == null) {
      setState(() => _error = 'Choisissez à qui vous remboursez.');
      return;
    }

    final user = ref.read(authStateProvider).asData?.value;
    final groupId = ref.read(selectedGroupIdProvider).asData?.value;
    final members = ref.read(expenseMembersProvider).asData?.value ?? [];
    if (user == null || groupId == null) return;

    final amount = _parseDouble(_amountController.text);
    if (amount == null || amount <= 0) return;

    setState(() => _saving = true);
    try {
      final nameByUid = {for (final m in members) m.uid: m.displayName};
      final title = _titleController.text.trim().isEmpty
          ? 'Remboursement'
          : _titleController.text.trim();

      await ref.read(expensesRepositoryProvider).createExpense(
        groupId: groupId,
        title: title,
        amount: amount,
        paidBy: user.uid,
        paidByName: nameByUid[user.uid] ?? user.displayName ?? user.email ?? user.uid,
        splitWith: [_toUid!],
        expenseType: ExpenseType.reimbursement,
        splitType: SplitType.amount,
        splitAmounts: {_toUid!: amount},
        category: null,
        date: _date,
        userId: user.uid,
      );

      final userName = nameByUid[user.uid] ?? user.displayName ?? user.email ?? 'Quelqu\'un';
      ref.read(messagesRepositoryProvider).sendSystemMessage(
        groupId: groupId,
        userId: user.uid,
        content:
            '💸 $userName a remboursé ${nameByUid[_toUid] ?? ''} (${amount.toStringAsFixed(2)} €)',
        notifScreen: 'expenses',
      );
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

  @override
  Widget build(BuildContext context) {
    final members = ref.watch(expenseMembersProvider).asData?.value ?? [];
    final currentUid = ref.watch(authStateProvider).asData?.value?.uid;
    final others = members.where((m) => m.uid != currentUid).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Remboursement'),
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
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Libellé (optionnel)',
                  prefixIcon: Icon(Icons.receipt_outlined),
                ),
                textCapitalization: TextCapitalization.sentences,
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _amountController,
                decoration: const InputDecoration(
                  labelText: 'Montant (€)',
                  prefixIcon: Icon(Icons.euro_outlined),
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Champ requis';
                  final p = _parseDouble(v);
                  if (p == null || p <= 0) return 'Montant invalide';
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

              const Text(
                'Je rembourse à',
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
                children: others.map((m) {
                  final isSelected = _toUid == m.uid;
                  final color = avatarColorForUid(m.uid);
                  return GestureDetector(
                    onTap: () => setState(() => _toUid = m.uid),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? color.withValues(alpha: 0.10)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(14),
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
                            radius: 18,
                            color: color,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            m.displayName,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: isSelected
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                              color: isSelected ? color : AppColors.textPrimary,
                            ),
                          ),
                          if (isSelected) ...[
                            const SizedBox(width: 8),
                            Icon(Icons.check_circle_rounded,
                                size: 16, color: color),
                          ],
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),

              if (_error != null) ...[
                const SizedBox(height: 16),
                Text(_error!,
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
