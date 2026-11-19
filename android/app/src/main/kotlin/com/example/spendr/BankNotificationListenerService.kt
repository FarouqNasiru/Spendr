package com.example.spendr

import android.app.Notification
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import android.util.Log

class BankNotificationListenerService : NotificationListenerService() {

    companion object {
        private const val TAG = "BankNotifListener"
    }

    override fun onNotificationPosted(sbn: StatusBarNotification?) {
        super.onNotificationPosted(sbn)
        if (sbn == null) return

        // 1. Verify feature is enabled by user
        if (!BankAppConfig.isEnabled(applicationContext)) return

        val packageName = sbn.packageName ?: return

        // Don't listen to Spendr's own notifications!
        if (packageName == applicationContext.packageName) return

        val extras = sbn.notification?.extras ?: return
        val title = extras.getCharSequence(Notification.EXTRA_TITLE)?.toString() ?: ""
        val text = extras.getCharSequence(Notification.EXTRA_TEXT)?.toString() ?: ""
        val bigText = extras.getCharSequence(Notification.EXTRA_BIG_TEXT)?.toString() ?: ""
        val combinedText = "$title $text $bigText".trim()

        if (combinedText.isEmpty()) return

        val monitoredPackages = BankAppConfig.getMonitoredPackages(applicationContext)
        val isMonitoredPackage = monitoredPackages.contains(packageName)
        val hasFinancialSignals = BankAppConfig.hasFinancialSignal(combinedText)

        // Only proceed if it is a monitored bank OR contains strong financial keywords
        if (!isMonitoredPackage && !hasFinancialSignals) return

        val bankName = BankAppConfig.DEFAULT_BANKS[packageName]
            ?: try {
                val pm = packageManager
                val appInfo = pm.getApplicationInfo(packageName, 0)
                pm.getApplicationLabel(appInfo).toString()
            } catch (e: Exception) {
                "Your Bank"
            }

        // Try extracting transaction amount and type (Income vs Expense)
        val amount = BankAppConfig.parseAmount(combinedText)
        val type = BankAppConfig.detectTransactionType(combinedText)

        // Apply deduplication (prevent duplicate notifications within 10-minute window)
        val bankKey = "$packageName-${amount ?: 0.0}"
        if (BankAppConfig.shouldDebounce(applicationContext, bankKey, amount)) {
            Log.d(TAG, "Debounced duplicate alert for $bankKey")
            return
        }

        Log.d(TAG, "Triggering Spendr reminder for $bankName: amount=$amount, type=$type")

        BankAppConfig.postReminderNotification(
            context = applicationContext,
            bankName = bankName,
            amount = amount,
            type = type,
            note = "Logged from $bankName alert"
        )
    }
}
