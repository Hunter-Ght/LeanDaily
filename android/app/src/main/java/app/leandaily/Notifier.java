package app.leandaily;

import android.Manifest;
import android.app.*;
import android.content.*;
import android.content.pm.PackageManager;
import android.os.Build;
import java.io.IOException;
import java.util.*;
import org.json.*;

final class Notifier {
    private static final Object LOCK = new Object();
    // 广播不能等待网络线程池，避免长请求延误闹钟或超过 goAsync 的时限。
    static final java.util.concurrent.ExecutorService RECEIVERS = java.util.concurrent.Executors.newSingleThreadExecutor();
    private static final String CHANNEL = "default";
    private final Context context;
    Notifier(Context context) { this.context = context.getApplicationContext(); }
    boolean granted() {
        return (Build.VERSION.SDK_INT < 33 || context.checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED)
            && context.getSystemService(NotificationManager.class).areNotificationsEnabled();
    }
    boolean exact() { return Build.VERSION.SDK_INT < 31 || alarms().canScheduleExactAlarms(); }
    private AlarmManager alarms() { return context.getSystemService(AlarmManager.class); }
    private JSONArray load() throws JSONException {
        return new JSONArray(context.getSharedPreferences("native-notifications", 0).getString("pending", "[]"));
    }
    private void save(JSONArray list) throws IOException {
        if (!context.getSharedPreferences("native-notifications", 0).edit().putString("pending", list.toString()).commit()) throw new IOException();
    }
    private PendingIntent alarm(int id) {
        Intent intent = new Intent(context, AlarmReceiver.class); intent.setAction("app.leandaily.ALARM");
        return PendingIntent.getBroadcast(context, id, intent, PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE);
    }
    private void arm(JSONObject note) throws JSONException {
        long at = note.getLong("atMs"); PendingIntent pending = alarm(note.getInt("id"));
        if (exact()) {
            try { alarms().setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, at, pending); return; }
            catch (SecurityException ignored) { /* 权限可能在检查后被撤销。 */ }
        }
        alarms().setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, at, pending);
    }
    void schedule(List<?> notes) throws Exception {
        synchronized (LOCK) {
            JSONArray list = load();
            for (Object value : notes) {
                Map<?, ?> m = NativeChannel.map(value);
                JSONObject note = new JSONObject();
                note.put("id", NativeChannel.number(m, "id", 0).intValue());
                note.put("title", NativeChannel.string(m, "title", "")); note.put("body", NativeChannel.string(m, "body", ""));
                note.put("atMs", NativeChannel.number(m, "atMs", 0).longValue()); note.put("plan", Boolean.TRUE.equals(m.get("plan")));
                for (int i = list.length()-1; i >= 0; i--) if (list.getJSONObject(i).getInt("id") == note.getInt("id")) list.remove(i);
                list.put(note);
            }
            save(list);
            for (Object value : notes) {
                int id = NativeChannel.number(NativeChannel.map(value), "id", 0).intValue();
                for (int i = 0; i < list.length(); i++) if (list.getJSONObject(i).getInt("id") == id) arm(list.getJSONObject(i));
            }
        }
    }
    void cancel(List<?> ids) throws Exception {
        synchronized (LOCK) {
            JSONArray list = load();
            for (Object value : ids) {
                int id = ((Number)value).intValue(); alarms().cancel(alarm(id));
                for (int i = list.length()-1; i >= 0; i--) if (list.getJSONObject(i).getInt("id") == id) list.remove(i);
            }
            save(list);
        }
    }
    List<Integer> pendingIds() throws Exception {
        synchronized (LOCK) {
            JSONArray list = load(); List<Integer> ids = new ArrayList<>();
            for (int i = 0; i < list.length(); i++) ids.add(list.getJSONObject(i).getInt("id")); return ids;
        }
    }
    void restore() throws Exception {
        synchronized (LOCK) {
            JSONArray list = load(), future = new JSONArray(); long now = System.currentTimeMillis();
            for (int i = 0; i < list.length(); i++) {
                JSONObject note = list.getJSONObject(i);
                if (note.getLong("atMs") > now) { future.put(note); arm(note); }
            }
            save(future);
        }
    }
    void fire() throws Exception {
        synchronized (LOCK) {
            JSONArray list = load(), future = new JSONArray(); long now = System.currentTimeMillis();
            for (int i = 0; i < list.length(); i++) {
                JSONObject note = list.getJSONObject(i);
                if (note.getLong("atMs") <= now) show(note); else future.put(note);
            }
            save(future);
        }
    }
    private void show(JSONObject note) throws JSONException {
        if (!granted()) return;
        NotificationManager manager = context.getSystemService(NotificationManager.class);
        manager.createNotificationChannel(new NotificationChannel(CHANNEL, "Default", NotificationManager.IMPORTANCE_DEFAULT));
        int id = note.getInt("id");
        Intent launch = new Intent(context, MainActivity.class).addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP | Intent.FLAG_ACTIVITY_SINGLE_TOP);
        launch.putExtra("notificationTap", true); launch.putExtra("plan", note.optBoolean("plan", false));
        PendingIntent tap = PendingIntent.getActivity(context, id, launch, PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE);
        Notification notification = new Notification.Builder(context, CHANNEL).setSmallIcon(R.drawable.ic_stat_rest)
            .setColor(0xff3b82f6).setContentTitle(note.getString("title")).setContentText(note.getString("body"))
            .setStyle(new Notification.BigTextStyle().bigText(note.getString("body"))).setContentIntent(tap).setAutoCancel(true).build();
        manager.notify(id, notification);
    }
}
