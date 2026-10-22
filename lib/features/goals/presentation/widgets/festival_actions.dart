import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hishab/core/l10n/translator.dart';
import 'package:hishab/core/router/app_routes.dart';
import 'package:hishab/core/utils/clock.dart';
import 'package:hishab/core/utils/dates.dart';
import 'package:hishab/core/utils/validation_exception.dart';
import 'package:hishab/core/widgets/app_snack_bar.dart';
import 'package:hishab/features/goals/domain/festival.dart';
import 'package:hishab/features/goals/presentation/providers/goals_providers.dart';
import 'package:hishab/features/goals/presentation/widgets/goal_actions.dart';

/// What can be done to a festival card.
enum FestivalAction { changeDate, usualDate, hide, editFund, deleteFund }

/// Does [action] to [item]. Each says what it did in a message.
Future<void> doFestivalAction(
  BuildContext context,
  WidgetRef ref,
  UpcomingFestival item,
  FestivalAction action,
) async {
  final messenger = ScaffoldMessenger.of(context);
  final settings = ref.read(festivalSettingsRepositoryProvider);
  try {
    switch (action) {
      case FestivalAction.changeDate:
        final today = dateOnly(ref.read(clockProvider)());
        final picked = await showDatePicker(
          context: context,
          initialDate: item.date,
          firstDate: today,
          lastDate: DateTime(today.year + 2, today.month, today.day),
          helpText: tr('The day of {festival}', {
            'festival': festivalName(item.festival),
          }),
        );
        if (picked == null) return;
        final day = dateOnly(picked);
        if (day == item.usualDate) {
          await settings.clearDate(item.festival);
        } else {
          await settings.setDate(item.festival, day);
        }
        await _moveFund(ref, item, day);
      case FestivalAction.usualDate:
        await settings.clearDate(item.festival);
        await _moveFund(ref, item, item.usualDate);
      case FestivalAction.hide:
        await settings.hide(item.festival);
        messenger.showMessage(
          tr('{name} hidden', {'name': festivalName(item.festival)}),
          duration: undoDuration,
          action: SnackBarAction(
            label: tr('Undo'),
            onPressed: () => settings.show(item.festival),
          ),
        );
      case FestivalAction.editFund:
        final fund = item.fund;
        if (fund != null) await context.push(AppRoutes.editGoal(fund.goal.id));
      case FestivalAction.deleteFund:
        final fund = item.fund;
        if (fund != null) await confirmDeleteGoal(context, ref, fund);
    }
  } on Object catch (error) {
    messenger.showError(describeError(error));
  }
}

/// The fund of a festival keeps the day of the festival.
Future<void> _moveFund(
  WidgetRef ref,
  UpcomingFestival item,
  DateTime day,
) async {
  final fund = item.fund;
  if (fund == null) return;
  await ref
      .read(goalsRepositoryProvider)
      .updateGoal(
        fund.goal.id,
        name: fund.goal.name,
        target: fund.goal.target,
        targetDate: day,
        icon: fund.goal.icon,
      );
}
