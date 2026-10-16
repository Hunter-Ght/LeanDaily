package app.leandaily;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;

public class BootReceiver extends BroadcastReceiver {
    @Override public void onReceive(Context context, Intent intent) {
        PendingResult pending = goAsync();
        Notifier.RECEIVERS.execute(() -> {
            try { new Notifier(context).restore(); }
            catch (Exception e) { android.util.Log.e("LeanDaily", "恢复通知失败", e); }
            finally { pending.finish(); }
        });
    }
}
