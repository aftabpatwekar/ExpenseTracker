# Home-screen widget setup

The **Dart side is already done** — `HomeWidgetService.push()` writes this
month's `month_spent`, `month_balance`, and `updated` values every time the
expense list loads or changes (wired in `home_shell.dart`). It safely no-ops
until you add the native widget below.

You add the native part once, per platform. It needs Android Studio (already
have it) / Xcode (on the Mac). Do this whenever you want the widget to appear;
the app builds and runs fine without it.

---

## Android (do from Windows or Mac)

1. **Layout** — `android/app/src/main/res/layout/expense_widget.xml`:

```xml
<?xml version="1.0" encoding="utf-8"?>
<LinearLayout xmlns:android="http://schemas.android.com/apk/res/android"
    android:layout_width="match_parent"
    android:layout_height="match_parent"
    android:orientation="vertical"
    android:padding="16dp"
    android:background="#1E1B2E">
    <TextView android:id="@+id/w_title"
        android:layout_width="wrap_content" android:layout_height="wrap_content"
        android:text="This month" android:textColor="#B7A6FF" android:textSize="12sp"/>
    <TextView android:id="@+id/w_spent"
        android:layout_width="wrap_content" android:layout_height="wrap_content"
        android:text="₹0" android:textColor="#FFFFFF" android:textSize="24sp"
        android:textStyle="bold" android:layout_marginTop="4dp"/>
    <TextView android:id="@+id/w_balance"
        android:layout_width="wrap_content" android:layout_height="wrap_content"
        android:text="Balance ₹0" android:textColor="#9E97B8" android:textSize="12sp"
        android:layout_marginTop="6dp"/>
</LinearLayout>
```

2. **Widget metadata** — `android/app/src/main/res/xml/expense_widget_info.xml`:

```xml
<?xml version="1.0" encoding="utf-8"?>
<appwidget-provider xmlns:android="http://schemas.android.com/apk/res/android"
    android:minWidth="180dp" android:minHeight="80dp"
    android:updatePeriodMillis="1800000"
    android:initialLayout="@layout/expense_widget"
    android:resizeMode="horizontal|vertical"
    android:widgetCategory="home_screen"/>
```

3. **Provider** — `android/app/src/main/kotlin/com/aftabpatwekar/expense_tracker/ExpenseWidgetProvider.kt`:

```kotlin
package com.aftabpatwekar.expense_tracker

import android.appwidget.AppWidgetManager
import android.content.Context
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetPlugin
import es.antonborri.home_widget.HomeWidgetProvider

class ExpenseWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: android.content.SharedPreferences
    ) {
        appWidgetIds.forEach { id ->
            val views = RemoteViews(context.packageName, R.layout.expense_widget)
            views.setTextViewText("w_spent".toId(context), widgetData.getString("month_spent", "₹0"))
            views.setTextViewText("w_balance".toId(context),
                "Balance " + widgetData.getString("month_balance", "₹0"))
            appWidgetManager.updateAppWidget(id, views)
        }
    }
    private fun String.toId(c: Context) =
        c.resources.getIdentifier(this, "id", c.packageName)
}
```

4. **Register the receiver** inside `<application>` in
   `android/app/src/main/AndroidManifest.xml`:

```xml
<receiver android:name=".ExpenseWidgetProvider" android:exported="true">
    <intent-filter>
        <action android:name="android.appwidget.action.APPWIDGET_UPDATE"/>
    </intent-filter>
    <meta-data android:name="android.appwidget.provider"
        android:resource="@xml/expense_widget_info"/>
</receiver>
```

Then `flutter run`, long-press the home screen → Widgets → Expense Tracker.

---

## iOS (do on the Mac, in Xcode)

1. Open `ios/Runner.xcworkspace` in Xcode.
2. **File → New → Target → Widget Extension**, name it **ExpenseWidget**
   (uncheck "Include Live Activity"). This creates a Swift widget target.
3. **App Groups** (shares data app ↔ widget): select the **Runner** target →
   Signing & Capabilities → **+ Capability → App Groups** → add
   `group.com.aftabpatwekar.expense_tracker`. Repeat for the **ExpenseWidget**
   target. This group id must match `_appGroupId` in `home_widget_service.dart`.
4. Add the `home_widget` iOS helper to the widget target: add the pod, or read
   `UserDefaults(suiteName: "group.com.aftabpatwekar.expense_tracker")`.
5. In the generated `ExpenseWidget.swift`, read the shared values and render:

```swift
let defaults = UserDefaults(suiteName: "group.com.aftabpatwekar.expense_tracker")
let spent = defaults?.string(forKey: "month_spent") ?? "₹0"
let balance = defaults?.string(forKey: "month_balance") ?? "₹0"
```

6. Build & run to the iPhone, then add the widget from the home-screen gallery.

Reference: https://pub.dev/packages/home_widget (full iOS walkthrough).
