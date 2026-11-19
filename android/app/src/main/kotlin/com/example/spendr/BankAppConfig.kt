package com.example.spendr

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.os.Build
import androidx.core.app.NotificationCompat
import java.text.NumberFormat
import java.util.Locale
import java.util.regex.Pattern

object BankAppConfig {
    const val PREFS_NAME = "spendr_smart_reminders"
    const val KEY_ENABLED = "smart_reminders_enabled"
    const val KEY_MONITORED_PACKAGES = "monitored_packages"
    const val CHANNEL_ID = "spendr_smart_reminders"
    const val NOTIFICATION_ID_BASE = 5000

    val DEFAULT_BANKS = mapOf(
        "team.opay.pay" to "OPay",
        "com.kuda.android" to "Kuda Bank",
        "com.moniepoint.business" to "Moniepoint",
        "com.palmpay.palmfinance" to "PalmPay",
        "com.gtbank.gtworldv1" to "GTWorld",
        "com.accessbank.neomobile" to "Access More",
        "com.zenithBank.eazymobile" to "Zenith Bank",
        "com.firstbank.firstmobile" to "FirstMobile",
        "com.uba.versett.ubamobilebanking" to "UBA Mobile",
        "com.stanbicibtc.mobile" to "Stanbic IBTC",
        "com.chase.sig.android" to "Chase",
        "com.revolut.revolut" to "Revolut",
        "com.transferwise.android" to "Wise",
        "com.bofa.mobilebanking" to "Bank of America",
        "com.wf.wellsfargomobile" to "Wells Fargo"
    )

    private val DEBIT_KEYWORDS = listOf(
        "debit", "dr:", "dr ", "paid", "spent", "sent to", "transfer to",
        "pos purchase", "withdrawal", "purchase of", "charged", "bought",
        "bill payment", "outward"
    )

    private val CREDIT_KEYWORDS = listOf(
        "credit", "cr:", "cr ", "received from", "deposit", "inward",
        "refund", "cashback", "credited", "salary", "bonus"
    )

    private val AMOUNT_PATTERN = Pattern.compile(
        """(?:NGN|USD|EUR|GBP|KES|GHS|₦|\$|€|£)\s*([0-9]{1,3}(?:,[0-9]{3})*(?:\.[0-9]{1,2})?|[0-9]+(?:\.[0-9]{1,2})?)""",
        Pattern.CASE_INSENSITIVE
    )

    private val FALLBACK_AMOUNT_PATTERN = Pattern.compile(
        """(?:amount|amt|sum of|for)\s*:?\s*([0-9]{1,3}(?:,[0-9]{3})*(?:\.[0-9]{1,2})?|[0-9]+(?:\.[0-9]{1,2})?)""",
        Pattern.CASE_INSENSITIVE
    )

    fun getPrefs(context: Context): SharedPreferences {
        return context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
    }

    fun isEnabled(context: Context): Boolean {
        return getPrefs(context).getBoolean(KEY_ENABLED, true)
    }

    fun getMonitoredPackages(context: Context): Set<String> {
        val prefs = getPrefs(context)
        return prefs.getStringSet(KEY_MONITORED_PACKAGES, DEFAULT_BANKS.keys) ?: DEFAULT_BANKS.keys
    }

    fun parseAmount(text: String): Double? {
        val matcher = AMOUNT_PATTERN.matcher(text)
        if (matcher.find()) {
            val numStr = matcher.group(1)?.replace(",", "")
            return numStr?.toDoubleOrNull()
        }
        val fallback = FALLBACK_AMOUNT_PATTERN.matcher(text)
        if (fallback.find()) {
            val numStr = fallback.group(1)?.replace(",", "")
            return numStr?.toDoubleOrNull()
        }
        return null
    }

    fun detectTransactionType(text: String): String {
        val lower = text.lowercase(Locale.ROOT)
        var creditScore = 0
        var debitScore = 0

        for (kw in CREDIT_KEYWORDS) {
            if (lower.contains(kw)) creditScore++
        }
        for (kw in DEBIT_KEYWORDS) {
            if (lower.contains(kw)) debitScore++
        }

        return if (creditScore > debitScore) "Income" else "Expense"
    }

    fun hasFinancialSignal(text: String): Boolean {
        val lower = text.lowercase(Locale.ROOT)
        for (kw in DEBIT_KEYWORDS) {
            if (lower.contains(kw)) return true
        }
        for (kw in CREDIT_KEYWORDS) {
            if (lower.contains(kw)) return true
        }
        return false
    }

    fun shouldDebounce(context: Context, bankKey: String, amount: Double?): Boolean {
        val prefs = getPrefs(context)
        val now = System.currentTimeMillis()
        val lastTime = prefs.getLong("last_time_$bankKey", 0L)
        val lastAmount = prefs.getFloat("last_amount_$bankKey", -1f)

        // 10 minutes debounce (600,000 ms)
        val cooldown = 10 * 60 * 1000L
        if ((now - lastTime) < cooldown) {
            if (amount != null && lastAmount > 0 && Math.abs(amount - lastAmount) < 0.01) {
                return true // Duplicate alert for same amount within 10 min
            }
            if (amount == null) {
                return true // Generic app-open reminder within cooldown
            }
        }

        // Record this trigger
        prefs.edit()
            .putLong("last_time_$bankKey", now)
            .putFloat("last_amount_$bankKey", amount?.toFloat() ?: -1f)
            .apply()

        return false
    }

    fun postReminderNotification(
        context: Context,
        bankName: String,
        amount: Double?,
        type: String,
        note: String
    ) {
        val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

        // Create channel for Android 8.0+
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Smart Transaction Reminders",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Reminders to log transactions after banking activity"
                enableLights(true)
                enableVibration(true)
            }
            notificationManager.createNotificationChannel(channel)
        }

        val launchIntent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            putExtra("is_smart_reminder", true)
            putExtra("reminder_bank", bankName)
            putExtra("reminder_type", type)
            if (amount != null) putExtra("reminder_amount", amount)
            putExtra("reminder_note", note)
        }

        val pendingIntent = PendingIntent.getActivity(
            context,
            (System.currentTimeMillis() % 10000).toInt(),
            launchIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val title = if (amount != null) {
            if (type == "Income") "Money Received from $bankName" else "Money Spent with $bankName"
        } else {
            "Recent activity with $bankName"
        }

        val formattedAmount = if (amount != null) {
            val formatter = NumberFormat.getNumberInstance(Locale.US)
            formatter.maximumFractionDigits = 2
            formatter.minimumFractionDigits = if (amount % 1.0 == 0.0) 0 else 2
            formatter.format(amount)
        } else null

        val body = if (formattedAmount != null) {
            if (type == "Income") {
                "Did you receive $formattedAmount? Tap to confirm and log it."
            } else {
                "Did you just spend $formattedAmount? Tap to log it in Spendr."
            }
        } else {
            "Did you make a transaction? Tap here to log it before you forget!"
        }

        val notification = NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(R.mipmap.launcher_icon)
            .setContentTitle(title)
            .setContentText(body)
            .setStyle(NotificationCompat.BigTextStyle().bigText(body))
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setAutoCancel(true)
            .setContentIntent(pendingIntent)
            .build()

        val notifId = NOTIFICATION_ID_BASE + (bankName.hashCode() % 1000)
        notificationManager.notify(notifId, notification)
    }
}
