package com.example.spendr

import android.app.AppOpsManager
import android.app.usage.UsageEvents
import android.app.usage.UsageStatsManager
import android.content.Context
import android.os.Build
import android.os.Process
import android.util.Log
import androidx.work.CoroutineWorker
import androidx.work.WorkerParameters

class BankUsageWorker(
    context: Context,
    workerParams: WorkerParameters
) : CoroutineWorker(context, workerParams) {

    companion object {
        private const val TAG = "BankUsageWorker"
        const val WORK_NAME = "spendr_bank_usage_worker"

        fun hasUsageStatsPermission(context: Context): Boolean {
            val appOps = context.getSystemService(Context.APP_OPS_SERVICE) as? AppOpsManager ?: return false
            val mode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                appOps.unsafeCheckOpNoThrow(
                    AppOpsManager.OPSTR_GET_USAGE_STATS,
                    Process.myUid(),
                    context.packageName
                )
            } else {
                @Suppress("DEPRECATION")
                appOps.checkOpNoThrow(
                    AppOpsManager.OPSTR_GET_USAGE_STATS,
                    Process.myUid(),
                    context.packageName
                )
            }
            return mode == AppOpsManager.MODE_ALLOWED
        }
    }

    override suspend fun doWork(): Result {
        if (!BankAppConfig.isEnabled(applicationContext)) return Result.success()
        if (!hasUsageStatsPermission(applicationContext)) return Result.success()

        val usageStatsManager = applicationContext.getSystemService(Context.USAGE_STATS_SERVICE) as? UsageStatsManager
            ?: return Result.success()

        val endTime = System.currentTimeMillis()
        val startTime = endTime - (15 * 60 * 1000L) // last 15 minutes

        val monitoredPackages = BankAppConfig.getMonitoredPackages(applicationContext)
        val usageEvents = usageStatsManager.queryEvents(startTime, endTime)
        val event = UsageEvents.Event()

        val recentlyUsedBanks = mutableSetOf<String>()

        while (usageEvents.hasNextEvent()) {
            usageEvents.getNextEvent(event)
            if (event.eventType == UsageEvents.Event.ACTIVITY_RESUMED) {
                val pkg = event.packageName
                if (monitoredPackages.contains(pkg)) {
                    recentlyUsedBanks.add(pkg)
                }
            }
        }

        for (pkg in recentlyUsedBanks) {
            val bankName = BankAppConfig.DEFAULT_BANKS[pkg]
                ?: try {
                    val pm = applicationContext.packageManager
                    val appInfo = pm.getApplicationInfo(pkg, 0)
                    pm.getApplicationLabel(appInfo).toString()
                } catch (e: Exception) {
                    "Your Bank"
                }

            // Check if reminder was already posted (via notification listener or previous check)
            if (!BankAppConfig.shouldDebounce(applicationContext, "usage_$pkg", null)) {
                Log.d(TAG, "Bank app opened recently: $bankName. Prompting reminder.")
                BankAppConfig.postReminderNotification(
                    context = applicationContext,
                    bankName = bankName,
                    amount = null, // unknown amount since it was an app open
                    type = "Expense",
                    note = "App open reminder ($bankName)"
                )
            }
        }

        return Result.success()
    }
}
