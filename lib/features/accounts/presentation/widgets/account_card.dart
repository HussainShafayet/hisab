import 'package:flutter/material.dart';
import 'package:hishab/core/l10n/translator.dart';
import 'package:hishab/core/theme/tabular_figures.dart';
import 'package:hishab/core/utils/money.dart';
import 'package:hishab/features/accounts/domain/account.dart';
import 'package:hishab/features/accounts/domain/overdrawn.dart';
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
    final card = account.isCreditCard;
    // A wallet below zero is marked; a card owes by design, so it is not.
    final low =
        balance != null &&
        isOverdrawn(AccountWithBalance(account: account, balance: balance!));
    final limit = account.creditLimit;
    final tail =
        trailing ??
        (selected ? const Icon(Icons.check_circle, color: _white) : null);
    // "Cash" under an account called "Cash" says nothing.
    final notes = [
      if (account.name.trim().toLowerCase() != account.type.label.toLowerCase())
        account.type.label,
      if (account.isArchived) tr('Archived'),
      if (!account.includeInTotal) tr('Not in total'),
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
                        // Half of the row, whatever the card's width (a card can
                        // sit in a narrow place): a long amount shrinks to fit.
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (low) ...[
                                    const Icon(
                                      Icons.warning_amber_rounded,
                                      size: 14,
                                      color: Color(0xFFFFE082),
                                    ),
                                    const SizedBox(width: 2),
                                  ],
                                  Flexible(
                                    child: Text(
                                      card
                                          ? (balance! > 0
                                                ? tr('In credit')
                                                : tr('Owed'))
                                          : low
                                          ? tr('Below zero')
                                          : tr('Balance'),
                                      key: ValueKey(
                                        'balance-label-${account.id}',
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: theme.textTheme.labelSmall
                                          ?.copyWith(
                                            color: low
                                                ? const Color(0xFFFFE082)
                                                : _whiteSoft,
                                          ),
                                    ),
                                  ),
                                ],
                              ),
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerRight,
                                child: Text(
                                  formatPoisha(
                                    card ? balance!.abs() : balance!,
                                  ),
                                  key: ValueKey('balance-${account.id}'),
                                  style: theme.textTheme.titleMedium?.tabular
                                      .copyWith(
                                        color: low
                                            ? const Color(0xFFFFE082)
                                            : _white,
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
                  if (card && account.usdLimit != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      limit == null
                          ? tr('Limit {amount}', {
                              'amount': formatUsd(account.usdLimit!),
                            })
                          : tr('Limits {taka} and {usd}', {
                              'taka': formatPoisha(limit),
                              'usd': formatUsd(account.usdLimit!),
                            }),
                      key: ValueKey('card-limits-${account.id}'),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: _whiteSoft,
                      ),
                    ),
                  ] else if (card && limit != null && balance != null) ...[
                    const SizedBox(height: 10),
                    _LimitBar(owed: balance! < 0 ? -balance! : 0, limit: limit),
                  ],
                  if (after != null) ...[
                    const SizedBox(height: 8),
                    const Divider(height: 1, color: Color(0x55FFFFFF)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text(
                          card ? tr('Owed after this') : tr('After this'),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: _whiteSoft,
                          ),
                        ),
                        const Spacer(),
                        if (card
                            ? (limit != null &&
                                  account.usdLimit == null &&
                                  -after > limit)
                            : after < 0) ...[
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
                              formatPoisha(card ? after.abs() : after),
                              key: ValueKey('balance-after-${account.id}'),
                              style: theme.textTheme.titleSmall?.tabular
                                  .copyWith(
                                    color:
                                        (card
                                            ? (limit != null &&
                                                  account.usdLimit == null &&
                                                  -after > limit)
                                            : after < 0)
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

/// How much of a credit card's limit is used, with what is still available.
class _LimitBar extends StatelessWidget {
  const _LimitBar({required this.owed, required this.limit});

  final int owed;
  final int limit;

  static const _amber = Color(0xFFFFE082);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final over = owed > limit;
    final left = limit - owed;
    final style = theme.textTheme.bodySmall?.copyWith(
      color: over ? _amber : const Color(0xCCFFFFFF),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: (owed / limit).clamp(0.0, 1.0),
            minHeight: 5,
            color: over ? _amber : Colors.white,
            backgroundColor: const Color(0x33FFFFFF),
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(
              child: Text(
                over
                    ? tr('Over the limit by {amount}', {
                        'amount': formatPoisha(-left),
                      })
                    : tr('{amount} left to spend', {
                        'amount': formatPoisha(left),
                      }),
                key: const ValueKey('limit-left'),
                style: style,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Expanded(
              child: Text(
                tr('Limit {amount}', {'amount': formatPoisha(limit)}),
                style: style,
                textAlign: TextAlign.end,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
