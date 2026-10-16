package app.leandaily;

import android.Manifest;
import android.app.Activity;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.net.Uri;
import android.os.Build;
import android.os.Handler;
import android.os.Looper;
import android.provider.Settings;
import android.view.WindowManager;
import io.flutter.plugin.common.BinaryMessenger;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import java.io.*;
import java.net.SocketTimeoutException;
import java.nio.charset.StandardCharsets;
import java.time.*;
import java.time.format.DateTimeFormatter;
import java.util.*;
import java.util.concurrent.*;

final class NativeChannel implements MethodChannel.MethodCallHandler {
    static final ExecutorService IO = Executors.newFixedThreadPool(4);
    private static final int EXPORT = 9101, IMPORT = 9102, IMAGES = 9103, NOTIFY_PERMISSION = 9104, CAMERA_PERMISSION = 9105;
    private static final int MAX_BACKUP = 100*1024*1024;
    private final Activity activity;
    private final MethodChannel channel;
    private final Handler main = new Handler(Looper.getMainLooper());
    private final Storage storage;
    private final Secrets secrets;
    private final Photos photos;
    private final Http http = new Http();
    private final Images images;
    private final Notifier notifier;
    private MethodChannel.Result pickerResult, notifyResult;
    private int pickerCode;
    private String exportData;
    private int imageLimit;
    private Map<String, Object> launchPayload;

    NativeChannel(Activity activity, BinaryMessenger messenger) {
        this.activity = activity;
        channel = new MethodChannel(messenger, "leandaily/native"); channel.setMethodCallHandler(this);
        storage = new Storage(activity.getApplicationContext()); secrets = new Secrets(activity.getApplicationContext());
        photos = new Photos(activity.getApplicationContext()); images = new Images(activity); notifier = new Notifier(activity);
    }
    static Map<?, ?> map(Object value) { return value instanceof Map ? (Map<?, ?>)value : Collections.emptyMap(); }
    static String string(Map<?, ?> args, String key, String fallback) { Object v = args.get(key); return v instanceof String ? (String)v : fallback; }
    static Number number(Map<?, ?> args, String key, Number fallback) { Object v = args.get(key); return v instanceof Number ? (Number)v : fallback; }
    private interface Work { Object run() throws Exception; }
    private void async(MethodChannel.Result result, Work work) {
        IO.execute(() -> {
            try { Object value = work.run(); main.post(() -> result.success(value)); }
            catch (Exception e) { main.post(() -> fail(result, e)); }
        });
    }
    private void fail(MethodChannel.Result result, Exception e) {
        String message;
        if (e instanceof Http.Cancelled) message = "请求已取消";
        else {
            String safe = e instanceof SocketTimeoutException ? "请求超时，请手动重试"
                : e instanceof IOException ? "文件或网络不可用，请检查后重试"
                : e instanceof IllegalArgumentException ? e.getMessage() : "请检查配置或存储空间";
            message = "操作失败："+safe;
        }
        result.error("native", message, null);
    }
    // 权限/选择器与 Activity 销毁可能竞态；每次调用最多回复一次。
    private final class Reply implements MethodChannel.Result {
        private final MethodChannel.Result target;
        private final java.util.concurrent.atomic.AtomicBoolean done = new java.util.concurrent.atomic.AtomicBoolean();
        Reply(MethodChannel.Result target) { this.target = target; }
        private void once(Runnable action) {
            if (!done.compareAndSet(false, true)) return;
            if (Looper.myLooper() == Looper.getMainLooper()) action.run(); else main.post(action);
        }
        @Override public void success(Object value) { once(() -> target.success(value)); }
        @Override public void error(String code, String message, Object details) { once(() -> target.error(code, message, details)); }
        @Override public void notImplemented() { once(target::notImplemented); }
    }
    @Override public void onMethodCall(MethodCall call, MethodChannel.Result rawResult) {
        MethodChannel.Result result = new Reply(rawResult);
        Map<?, ?> args = map(call.arguments);
        try {
            switch (call.method) {
                case "all": async(result, storage::all); break;
                case "put": async(result, () -> { storage.put(string(args,"key",null), string(args,"value",null)); return null; }); break;
                case "pruneSecrets": async(result, () -> { secrets.prune(); return null; }); break;
                case "secretsGet": async(result, secrets::get); break;
                case "secretsSet": async(result, () -> { secrets.set(args); return null; }); break;
                case "photoWrite": async(result, () -> photos.write((byte[])args.get("bytes"))); break;
                case "photoRead": async(result, () -> photos.read(string(args,"path",""))); break;
                case "http": async(result, () -> http.request(args)); break;
                // 取消标记必须立即登记，不能排在被取消的请求后面。
                case "cancelHttp": http.cancel(string(args,"id","")); result.success(null); break;
                case "exportDocument": exportDocument(args, result); break;
                case "importDocument": importDocument(result); break;
                case "pickImages": pickImages(args, result); break;
                case "clock": async(result, () -> {
                    ZonedDateTime now = ZonedDateTime.now(zone(args));
                    Map<String,Object> out = new LinkedHashMap<>();
                    out.put("today", now.toLocalDate().toString()); out.put("now", now.format(DateTimeFormatter.ofPattern("HH:mm", Locale.ROOT))); return out;
                }); break;
                case "deviceTz": result.success(java.util.TimeZone.getDefault().getID()); break;
                case "zonedMs": async(result, () -> LocalDate.parse(string(args,"date","")).atStartOfDay(zone(args)).toInstant().toEpochMilli()); break;
                case "zonedDate": async(result, () -> Instant.ofEpochMilli(number(args,"ms",0).longValue()).atZone(zone(args)).toLocalDate().toString()); break;
                case "notifyState": async(result, () -> {
                    Map<String,Object> out = new LinkedHashMap<>(); out.put("granted", notifier.granted()); out.put("exact", notifier.exact()); return out;
                }); break;
                case "requestNotify": requestNotify(result); break;
                case "openExactAlarmSettings":
                    if (Build.VERSION.SDK_INT >= 31) activity.startActivity(new Intent(Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM, Uri.parse("package:"+activity.getPackageName())));
                    result.success(null); break;
                case "schedule": async(result, () -> { notifier.schedule((List<?>)call.arguments); return null; }); break;
                case "cancel": async(result, () -> { notifier.cancel((List<?>)call.arguments); return null; }); break;
                case "pendingIds": async(result, notifier::pendingIds); break;
                case "takeLaunchPayload": result.success(launchPayload); launchPayload = null; break;
                case "keepAwake":
                    if (Boolean.TRUE.equals(call.arguments)) activity.getWindow().addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON);
                    else activity.getWindow().clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON);
                    result.success(null); break;
                case "openUrl": activity.startActivity(new Intent(Intent.ACTION_VIEW, Uri.parse(string(args,"url","")))); result.success(null); break;
                case "minimize": activity.moveTaskToBack(true); result.success(null); break;
                default: result.notImplemented();
            }
        } catch (Exception e) { fail(result, e); }
    }
    private ZoneId zone(Map<?, ?> args) {
        try { return ZoneId.of(string(args,"tz","")); }
        catch (DateTimeException e) { throw new IllegalArgumentException("时区无效"); }
    }
    private boolean reserve(MethodChannel.Result result, int code) {
        if (pickerResult != null) { result.error("native", "操作失败：请检查配置或存储空间", null); return false; }
        pickerResult = result; pickerCode = code; return true;
    }
    private void startPicker(Intent intent, MethodChannel.Result result) {
        try { activity.startActivityForResult(intent, pickerCode); }
        catch (Exception e) { pickerResult = null; exportData = null; fail(result, e); }
    }
    private void exportDocument(Map<?, ?> args, MethodChannel.Result result) {
        if (!reserve(result, EXPORT)) return;
        exportData = string(args,"data","");
        Intent intent = new Intent(Intent.ACTION_CREATE_DOCUMENT).addCategory(Intent.CATEGORY_OPENABLE).setType("application/json");
        String name = string(args,"name","");
        intent.putExtra(Intent.EXTRA_TITLE, name.isEmpty() ? "薄肌日课备份-"+System.currentTimeMillis()+".json" : name);
        startPicker(intent, result);
    }
    private void importDocument(MethodChannel.Result result) {
        if (!reserve(result, IMPORT)) return;
        startPicker(new Intent(Intent.ACTION_OPEN_DOCUMENT).addCategory(Intent.CATEGORY_OPENABLE).setType("*/*"), result);
    }
    private void pickImages(Map<?, ?> args, MethodChannel.Result result) {
        if (!reserve(result, IMAGES)) return;
        imageLimit = Math.max(1, number(args,"limit",1).intValue());
        String source = string(args,"source","");
        if (source.equals("camera") && activity.checkSelfPermission(Manifest.permission.CAMERA) != PackageManager.PERMISSION_GRANTED) {
            activity.requestPermissions(new String[]{Manifest.permission.CAMERA}, CAMERA_PERMISSION); return;
        }
        startImages(source, result);
    }
    private void startImages(String source, MethodChannel.Result result) {
        try { images.start(source, imageLimit, IMAGES); }
        catch (Exception e) { pickerResult = null; images.cleanup(); fail(result,e); }
    }
    void activityResult(int code, int status, Intent data) {
        if (pickerResult == null || code != pickerCode) return;
        MethodChannel.Result result = pickerResult;
        // 图片处理完成前仍占用选择器，避免下一次相机请求覆盖临时文件。
        if (code == IMAGES) {
            IO.execute(() -> {
                try {
                    List<byte[]> values = images.finish(status, data);
                    main.post(() -> { pickerResult = null; result.success(values); });
                } catch (Exception e) { main.post(() -> { pickerResult = null; fail(result, e); }); }
            }); return;
        }
        pickerResult = null;
        String content = exportData; exportData = null;
        if (status != Activity.RESULT_OK || data == null || data.getData() == null) {
            result.error("native", code == EXPORT ? "已取消导出" : "已取消导入", null); return;
        }
        Uri uri = data.getData();
        async(result, () -> {
            if (code == EXPORT) {
                byte[] bytes = content.getBytes(StandardCharsets.UTF_8);
                if (bytes.length > MAX_BACKUP) throw new IllegalArgumentException("备份超过100MB，请减少照片后重试");
                try (OutputStream out = activity.getContentResolver().openOutputStream(uri,"wt")) {
                    if (out == null) throw new IOException(); out.write(bytes);
                }
                return null;
            }
            return new String(Photos.read(activity.getContentResolver().openInputStream(uri), MAX_BACKUP), StandardCharsets.UTF_8);
        });
    }
    private void requestNotify(MethodChannel.Result result) {
        if (Build.VERSION.SDK_INT < 33 || activity.checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED) {
            result.success(notifier.granted()); return;
        }
        if (notifyResult != null) { result.error("native", "操作失败：请检查配置或存储空间", null); return; }
        notifyResult = result; activity.requestPermissions(new String[]{Manifest.permission.POST_NOTIFICATIONS}, NOTIFY_PERMISSION);
    }
    void permissionResult(int code, int[] results) {
        if (code == NOTIFY_PERMISSION && notifyResult != null) {
            MethodChannel.Result result = notifyResult; notifyResult = null; result.success(notifier.granted());
        } else if (code == CAMERA_PERMISSION && pickerResult != null && pickerCode == IMAGES) {
            if (results.length > 0 && results[0] == PackageManager.PERMISSION_GRANTED) startImages("camera", pickerResult);
            else { MethodChannel.Result result = pickerResult; pickerResult = null; result.error("native", "操作失败：文件或网络不可用，请检查后重试", null); }
        }
    }
    void launch(Intent intent, boolean warm) {
        if (intent == null || !intent.getBooleanExtra("notificationTap", false)) return;
        Map<String,Object> payload = new LinkedHashMap<>(); payload.put("plan", intent.getBooleanExtra("plan",false));
        intent.removeExtra("notificationTap"); intent.removeExtra("plan");
        if (warm) channel.invokeMethod("notificationTap", payload); else launchPayload = payload;
    }
    void detach() {
        channel.setMethodCallHandler(null);
        if (pickerResult != null) { pickerResult.error("native", pickerCode == EXPORT ? "已取消导出" : pickerCode == IMPORT ? "已取消导入" : "操作失败：文件或网络不可用，请检查后重试", null); pickerResult = null; }
        if (notifyResult != null) { notifyResult.success(false); notifyResult = null; }
    }
}
