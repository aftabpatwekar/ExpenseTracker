import 'package:home_widget/home_widget.dart';

import '../domain/models/expense.dart';
import 'format.dart';

/// Pushes a small summary to the OS home-screen widget.
///
/// The Dart side is complete and safe to call even before a native widget
/// exists — [HomeWidget.updateWidget] just no-ops if no widget is installed.
/// See docs/HOME_WIDGET.md for the native Android/iOS setup done on the Mac.
class HomeWidgetService {
  // Must match the App Group id (iOS) configured in docs/HOME_WIDGET.md.
  static const _appGroupId = 'group.com.aftabpatwekar.expense_tracker';
  static const _androidProvider = 'ExpenseWidgetProvider';
  static const _iOSWidgetName = 'ExpenseWidget';

  static bool _groupSet = false;

  /// Recomputes this month's totals and hands them to the widget.
  static Future<void> push(List<Expense> expenses) async {
    try {
      if (!_groupSet) {
        await HomeWidget.setAppGroupId(_appGroupId);
        _groupSet = true;
      }
      final now = DateTime.now();
      var spent = 0.0;
      var income = 0.0;
      for (final e in expenses) {
        if (e.spentAt.year != now.year || e.spentAt.month != now.month) {
          continue;
        }
        if (e.isIncome) {
          income += e.amount;
        } else if (e.isExpense) {
          spent += e.amount;
        }
      }
      await HomeWidget.saveWidgetData<String>(
          'month_spent', formatMoney(spent));
      await HomeWidget.saveWidgetData<String>(
          'month_balance', formatMoney(income - spent));
      await HomeWidget.saveWidgetData<String>(
          'updated', formatDay(now));
      await HomeWidget.updateWidget(
        androidName: _androidProvider,
        iOSName: _iOSWidgetName,
      );
    } catch (_) {
      // No widget installed yet, or the platform doesn't support it — ignore.
    }
  }
}
