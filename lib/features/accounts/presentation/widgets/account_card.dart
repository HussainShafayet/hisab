import 'package:flutter/material.dart';
import 'package:hishab/core/theme/tabular_figures.dart';
import 'package:hishab/core/utils/money.dart';
import 'package:hishab/features/accounts/domain/account.dart';
import 'package:hishab/features/accounts/presentation/widgets/account_type_ui.dart';

/// An account as a colored wallet card: its name and kind on the left, its
/// balance on the right, and, when [balanceAfter] is given, what the balance
/// will be after the transaction being entered.
class AccountCard extends StatelessWidget {
  const AccountCard({
    required this.account,
    this.balance,
    this.balanceAfter,
    this.caption,
    this.selected = false,
    this.onTap,
    this.trailing,
    super.key,
  });

  final Account account;

  /// The balance now, in poisha. Left out while it is not known yet.
  final int? balance;

  /// The balance once the transaction is saved, in poisha.
  final int? balanceAfter;

  /// A small label above the name, like "From" or "To".
  final String? caption;

  /// Marks the card with a check, for a list where one is chosen.
  final bool selected;
  final VoidCallback? onTap;

  /// Replaces the check, for example a "change" arrow.
  final Widget? trailing;

  static const _white = Colors.white;
  static const _whiteSoft = Color(0xCCFFFFFF);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final base = account.isArchived
        ? Colors.blueGrey.shade600
        : account.type.color;
    final after = balanceAfter;
    final tail =
        trailing ??
        (selected ? const Icon(Icons.check_circle, color: _white) : null);
    // "Cash" under an account called "Cash" says nothing.
    final notes = [
      if (account.name.trim().toLowerCase() != account.type.label.toLowerCase())
        account.type.label,
      if (account.isArchived) 'Archived',
      if (!account.includeInTotal) 'Not in total',
    ];

    return Semantics(
      button: onTap != null,
      selected: selected,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [base, Color.lerp(base, Colors.black, 0.35)!],
            ),
          ),
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (caption != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        caption!,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: _whiteSoft,
                        ),
                      ),
                    ),
                  Row(
                    children: [
                      _Badge(icon: account.type.icon),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              account.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: _white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (notes.isNotEmpty)
                              Text(
                                notes.join(' · '),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: _whiteSoft,
                                ),
                              ),
                          ],
                        ),
                      ),
                      if (balance != null) ...[
                        const SizedBox(width: 8),
                        ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth: MediaQuery.sizeOf(context).width * 0.42,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                'Balance',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: _whiteSoft,
                                ),
                              ),
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerRight,
                                child: Text(
                                  formatPoisha(balance!),
                                  key: ValueKey('balance-${account.id}'),
                                  style: theme.textTheme.titleMedium?.tabular
                                      .copyWith(
                                        color: _white,
                                        fontWeight: FontWeight.w600,
                                      ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      if (tail != null) ...[const SizedBox(width: 8), tail],
                    ],
                  ),
                  if (after != null) ...[
                    const SizedBox(height: 8),
                    const Divider(height: 1, color: Color(0x55FFFFFF)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text(
                          'After this',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: _whiteSoft,
                          ),
                        ),
                        const Spacer(),
                        if (after < 0) ...[
                          const Icon(
                            Icons.warning_amber_rounded,
                            size: 16,
                            color: Color(0xFFFFE082),
                          ),
                          const SizedBox(width: 4),
                        ],
                        Flexible(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerRight,
                            child: Text(
                              formatPoisha(after),
                              key: ValueKey('balance-after-${account.id}'),
                              style: theme.textTheme.titleSmall?.tabular
                                  .copyWith(
                                    color: after < 0
                                        ? const Color(0xFFFFE082)
                                        : _white,
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: 20,
      backgroundColor: const Color(0x33FFFFFF),
      child: Icon(icon, color: Colors.white),
    );
  }
}
