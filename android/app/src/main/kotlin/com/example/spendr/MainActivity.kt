package com.example.spendr

import android.content.Intent
import android.os.Bundle
import android.provider.Settings
import androidx.core.app.NotificationManagerCompat
import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.PeriodicWorkRequestBuilder
import androidx.work.WorkManager
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.TimeUnit

class MainActivity : FlutterFragmentActivity() {

    private val CHANNEL = "com.spendr/smart_reminders"
    private var methodChannel: MethodChannel? = null
    private var pendingPrompt: Map<String, Any?>? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        handleIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        handleIntent(intent)
        pendingPrompt?.let { prompt ->
            methodChannel?.invokeMethod("onTransactionPrompt", prompt)
            pendingPrompt = null
        }
    }

    private fun handleIntent(intent: Intent?) {
        if (intent == null) return
        if (intent.getBooleanExtra("is_smart_reminder", false)) {
            val amount = if (intent.hasExtra("reminder_amount")) {
                intent.getDoubleExtra("reminder_amount", 0.0)
            } else null

            pendingPrompt = mapOf(
                "amount" to amount,
                "type" to (intent.getStringExtra("reminder_type") ?: "Expense"),
                "bank" to (intent.getStringExtra("reminder_bank") ?: "Bank"),
                "note" to (intent.getStringExtra("reminder_note") ?: "")
            )

            // Clear intent flags to avoid re-triggering
            intent.removeExtra("is_smart_reminder")
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).apply {
            setMethodCallHandler { call, result ->
                when (call.method) {
                    "checkPermissions" -> {
                        val hasUsage = BankUsageWorker.hasUsageStatsPermission(this@MainActivity)
                        val isEnabled = BankAppConfig.isEnabled(this@MainActivity)

                        result.success(
                            mapOf(
                                "notificationListener" to false,
                                "usageStats" to hasUsage,
                                "isEnabled" to isEnabled
                            )
                        )
                    }

                    "requestNotificationListenerPermission" -> {
                        result.success(true)
                    }

                    "requestUsageStatsPermission" -> {
                        try {
                            val intent = Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS).apply {
                                flags = Intent.FLAG_ACTIVITY_NEW_TASK
                            }
                            startActivity(intent)
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("ERROR", e.message, null)
                        }
                    }

                    "setSmartRemindersEnabled" -> {
                        val enabled = call.argument<Boolean>("enabled") ?: true
                        BankAppConfig.getPrefs(this@MainActivity)
                            .edit()
                            .putBoolean(BankAppConfig.KEY_ENABLED, enabled)
                            .apply()

                        if (enabled && BankUsageWorker.hasUsageStatsPermission(this@MainActivity)) {
                            scheduleUsageWorker()
                        } else {
                            cancelUsageWorker()
                        }
                        result.success(true)
                    }

                    "getMonitoredBanks" -> {
                        val monitored = BankAppConfig.getMonitoredPackages(this@MainActivity)
                        val list = BankAppConfig.DEFAULT_BANKS.map { (pkg, name) ->
                            mapOf(
                                "package" to pkg,
                                "name" to name,
                                "enabled" to monitored.contains(pkg)
                            )
                        }
                        result.success(list)
                    }

                    "setMonitoredBanks" -> {
                        val packages = call.argument<List<String>>("packages") ?: emptyList()
                        BankAppConfig.getPrefs(this@MainActivity)
                            .edit()
                            .putStringSet(BankAppConfig.KEY_MONITORED_PACKAGES, packages.toSet())
                            .apply()
                        result.success(true)
                    }

                    "getInitialPrompt" -> {
                        val prompt = pendingPrompt
                        pendingPrompt = null
                        result.success(prompt)
                    }

                    "testBankReminder" -> {
                        BankAppConfig.postReminderNotification(
                            context = this@MainActivity,
                            bankName = "GTBank (Demo)",
                            amount = 25000.0,
                            type = "Expense",
                            note = "Acct: 012****789 Debit: NGN25,000.00 Ref: Spendr Test"
                        )
                        result.success(true)
                    }

                    else -> result.notImplemented()
                }
            }
        }

        // Auto schedule worker if enabled
        if (BankAppConfig.isEnabled(this) && BankUsageWorker.hasUsageStatsPermission(this)) {
            scheduleUsageWorker()
        }
    }

    private fun scheduleUsageWorker() {
        val workRequest = PeriodicWorkRequestBuilder<BankUsageWorker>(15, TimeUnit.MINUTES)
            .build()
        WorkManager.getInstance(applicationContext).enqueueUniquePeriodicWork(
            BankUsageWorker.WORK_NAME,
            ExistingPeriodicWorkPolicy.KEEP,
            workRequest
        )
    }

    private fun cancelUsageWorker() {
        WorkManager.getInstance(applicationContext).cancelUniqueWork(BankUsageWorker.WORK_NAME)
    }
}
