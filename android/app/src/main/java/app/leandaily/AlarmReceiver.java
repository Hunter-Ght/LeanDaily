package app.leandaily;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;

public class AlarmReceiver extends BroadcastReceiver {
    @Override public void onReceive(Context context, Intent intent) {
        PendingResult pending = goAsync();
        Notifier.RECEIVERS.execute(() -> {
            try { new Notifier(context).fire(); }
            catch (Exception e) { android.util.Log.e("LeanDaily", "通知发送失败", e); }
            finally { pending.finish(); }
        });
    }
}
