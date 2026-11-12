import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zyncro/design_system/context_extensions.dart';
import 'package:zyncro/features/expenses/domain/services/settlement_planner.dart';
import 'package:zyncro/features/expenses/presentation/screens/reimbursement_form_screen.dart';
import 'package:zyncro/features/expenses/presentation/widgets/expenses_screen_helpers.dart';
import 'package:zyncro/features/expenses/presentation/widgets/expenses_section_card.dart';
import 'package:zyncro/features/groups/domain/entities/group_member.dart';
import 'package:zyncro/features/settings/presentation/providers/tab_settings_provider.dart';
import 'package:zyncro/shared/widgets/user_avatar.dart';

// ── Tab Équilibre ─────────────────────────────────────────────────────────────

class EquilibreTab extends ConsumerWidget {
  final double myBalance;
  final Map<String, double> balances;
  final Map<String, String> nameByUid;
  final String? currentUid;
  final List<GroupMember> members;

  const EquilibreTab({
    super.key,
    required this.myBalance,
    required this.balances,
    required this.nameByUid,
    required this.currentUid,
    required this.members,
  });

  String _name(String uid) {
    if (uid == currentUid) return 'Vous';
    return nameByUid[uid] ?? uid.substring(0, min(6, uid.length));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currency =
        ref.watch(tabSettingsProvider).asData?.value.expensesCurrency ?? 'EUR';
    final settlements = planSettlements(balances);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Carte mon solde
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: myBalance >= 0
                    ? const [Color(0xFF2BB8A5), Color(0xFF1E9B8A)]
                    : const [Color(0xFFFF6B6B), Color(0xFFE85D75)],
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color:
                      (myBalance >= 0
                              ? const Color(0xFF2BB8A5)
                              : const Color(0xFFFF6B6B))
                          .withValues(alpha: 0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.l10n.expensesVotreSolde,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  myBalance >= 0
                      ? '+${expensesFormatAmount(myBalance, currency: currency)}'
                      : expensesFormatAmount(myBalance, currency: currency),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      myBalance >= 0 ? Icons.trending_up : Icons.trending_down,
                      color: Colors.white,
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      myBalance >= 0
                          ? 'On vous doit de l\'argent'
                          : 'Vous devez de l\'argent',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Soldes par membre
          if (balances.isNotEmpty) ...[
            ExpensesSectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                    child: Text(
                      context.l10n.expensesSoldes,
                      style: TextStyle(
                        color: context.colors.textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  Divider(height: 1, color: context.colors.border),
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: balances.entries.map((entry) {
                        final isPos = entry.value >= 0;
                        final name = _name(entry.key);
                        final member = members
                            .where((m) => m.uid == entry.key)
                            .firstOrNull;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Row(
                            children: [
                              UserAvatar(
                                photoUrl: member?.photoUrl,
                                showPhoto: member?.showProfilePhoto ?? true,
                                displayName: name,
                                color: avatarColorForUid(entry.key),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  name,
                                  style: TextStyle(
                                    color: context.colors.textPrimary,
                                    fontWeight: FontWeight.w500,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                              Row(
                                children: [
                                  Icon(
                                    isPos
                                        ? Icons.arrow_upward
                                        : Icons.arrow_downward,
                                    size: 16,
                                    color: isPos
                                        ? const Color(0xFF2BB8A5)
                                        : const Color(0xFFFF6B6B),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    expensesFormatAmount(
                                      entry.value.abs(),
                                      currency: currency,
                                    ),
                                    style: TextStyle(
                                      color: isPos
                                          ? const Color(0xFF2BB8A5)
                                          : const Color(0xFFFF6B6B),
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Suggestions de remboursement
          if (settlements.isNotEmpty) ...[
            ExpensesSectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                    child: Text(
                      context.l10n.expensesARegler,
                      style: TextStyle(
                        color: context.colors.textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  Divider(height: 1, color: context.colors.border),
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: settlements.map((s) {
                        final fromName = _name(s.fromUid);
                        final toName = _name(s.toUid);
                        final isMe = s.fromUid == currentUid;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    RichText(
                                      text: TextSpan(
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: context.colors.textPrimary,
                                        ),
                                        children: [
                                          TextSpan(
                                            text: fromName,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          const TextSpan(text: ' doit '),
                                          TextSpan(
                                            text: expensesFormatAmount(
                                              s.amount,
                                              currency: currency,
                                            ),
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w600,
                                              color: Color(0xFFFF6B6B),
                                            ),
                                          ),
                                          const TextSpan(text: ' à '),
                                          TextSpan(
                                            text: toName,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (isMe) ...[
                                const SizedBox(width: 12),
                                TextButton(
                                  onPressed: () => Navigator.of(context).push(
                                    MaterialPageRoute<void>(
                                      builder: (_) => ReimbursementFormScreen(
                                        initialToUid: s.toUid,
                                        initialAmount: s.amount,
                                      ),
                                    ),
                                  ),
                                  style: TextButton.styleFrom(
                                    foregroundColor: const Color(0xFF4F7CFF),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      side: const BorderSide(
                                        color: Color(0xFF4F7CFF),
                                      ),
                                    ),
                                  ),
                                  child: Text(
                                    context.l10n.expensesRembourser,
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
          ] else if (balances.isNotEmpty) ...[
            ExpensesSectionCard(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: const Color(0xFF2BB8A5).withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check,
                        size: 18,
                        color: Color(0xFF2BB8A5),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      context.l10n.expensesLesComptesSontEquilibres,
                      style: TextStyle(
                        color: context.colors.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
