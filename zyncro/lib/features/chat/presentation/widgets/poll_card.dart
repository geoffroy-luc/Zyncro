import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:zyncro/core/utils/color_hex.dart';
import 'package:zyncro/design_system/context_extensions.dart';
import 'package:zyncro/features/chat/domain/entities/message.dart';

// ── Poll card ─────────────────────────────────────────────────────────────────

class PollCard extends StatelessWidget {
  final Message message;
  final bool isMe;
  final String? currentUserId;
  final void Function(int)? onVote;
  final VoidCallback? onLongPress;

  const PollCard({
    super.key,
    required this.message,
    required this.isMe,
    this.currentUserId,
    this.onVote,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final Map<String, dynamic> data;
    try {
      data = jsonDecode(message.content) as Map<String, dynamic>;
    } catch (_) {
      return const SizedBox.shrink();
    }

    final question = data['question'] as String? ?? '';
    final options = List<String>.from(data['options'] as List? ?? []);
    final multipleChoice = data['multipleChoice'] as bool? ?? false;

    final userVoteKeys = <String>{};
    for (final key in message.reactions.keys) {
      if (message.reactions[key]?.contains(currentUserId) == true) {
        userVoteKeys.add(key);
      }
    }

    int totalVotes = 0;
    for (final voters in message.reactions.values) {
      totalVotes += voters.length;
    }

    return GestureDetector(
      onLongPress: onLongPress,
      child: Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 320),
          margin: EdgeInsets.only(left: isMe ? 40 : 0, right: isMe ? 0 : 40),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: context.colors.border),
            boxShadow: [
              BoxShadow(
                color: context.colors.shadow,
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // En-tête gradient
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Theme.of(context).colorScheme.primary,
                      darken(Theme.of(context).colorScheme.primary),
                    ],
                  ),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(15),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.poll_rounded,
                          color: Colors.white,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            question,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                              height: 1.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (multipleChoice) ...[
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Text(
                          'Choix multiples',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              // Options
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
                child: Column(
                  children: List.generate(options.length, (i) {
                    final key = i.toString();
                    final votes = message.reactions[key]?.length ?? 0;
                    final pct = totalVotes > 0 ? votes / totalVotes : 0.0;
                    final isSelected = userVoteKeys.contains(key);

                    return GestureDetector(
                      onTap: () => onVote?.call(i),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 9,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? Theme.of(
                                  context,
                                ).colorScheme.primary.withValues(alpha: 0.08)
                              : context.colors.background,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isSelected
                                ? Theme.of(context).colorScheme.primary
                                : context.colors.border,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  multipleChoice
                                      ? (isSelected
                                            ? Icons.check_box
                                            : Icons.check_box_outline_blank)
                                      : (isSelected
                                            ? Icons.radio_button_checked
                                            : Icons.radio_button_unchecked),
                                  size: 15,
                                  color: isSelected
                                      ? Theme.of(context).colorScheme.primary
                                      : context.colors.textSecondary,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    options[i],
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: context.colors.textPrimary,
                                    ),
                                  ),
                                ),
                                Text(
                                  '$votes',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: context.colors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                            if (totalVotes > 0) ...[
                              const SizedBox(height: 6),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: pct,
                                  minHeight: 4,
                                  backgroundColor: Colors.grey.shade200,
                                  valueColor: AlwaysStoppedAnimation(
                                    isSelected
                                        ? Theme.of(context).colorScheme.primary
                                        : Theme.of(context).colorScheme.primary
                                              .withValues(alpha: 0.35),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  }),
                ),
              ),
              // Pied de carte
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
                child: Text(
                  '$totalVotes vote${totalVotes != 1 ? 's' : ''}'
                  '${message.senderName != null ? ' · ${isMe ? 'Votre sondage' : message.senderName!}' : ''}'
                  '${message.editedAt != null ? ' · modifié' : ''}',
                  style: TextStyle(
                    color: context.colors.textSecondary,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
