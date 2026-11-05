import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:hishab/core/router/app_routes.dart';
import 'package:hishab/features/insights/domain/insights.dart';

/// Takes the person to what an insight is about; nothing for an insight that
/// has no link.
void openInsight(BuildContext context, Insight insight) {
  switch (insight.link) {
    case InsightLink.report:
      context.go(AppRoutes.reports);
    case InsightLink.budget:
      context.go(AppRoutes.budget);
    case InsightLink.loans:
      context.push(AppRoutes.debts);
    case InsightLink.recurring:
      context.push(AppRoutes.recurring);
    case InsightLink.transaction:
      final id = insight.targetId;
      if (id != null) context.push(AppRoutes.editTransaction(id));
    case null:
      break;
  }
}
