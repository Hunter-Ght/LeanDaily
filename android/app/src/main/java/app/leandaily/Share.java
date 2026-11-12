package app.leandaily;

import android.app.Activity;
import android.content.ClipData;
import android.content.Intent;
import android.net.Uri;
import androidx.core.content.FileProvider;
import java.io.File;
import java.io.FileOutputStream;
import java.io.IOException;

/** 把一张 PNG 写进缓存目录，经 FileProvider 交给系统分享面板。 */
final class Share {
    private static final int MAX_BYTES = 30 * 1024 * 1024;
    private static final long STALE_MS = 60 * 60 * 1000L;
    private Share() {}

    /** 写文件（可在后台线程调用）。同时清掉一小时前遗留的旧图。 */
    static File write(Activity activity, byte[] bytes, String name) throws IOException {
        if (bytes == null || bytes.length == 0 || bytes.length > MAX_BYTES) throw new IllegalArgumentException("图片无效");
        File dir = new File(activity.getCacheDir(), "share");
        if (!dir.isDirectory() && !dir.mkdirs()) throw new IOException();
        File[] old = dir.listFiles();
        if (old != null) for (File f : old) if (System.currentTimeMillis() - f.lastModified() > STALE_MS) f.delete();
        String safe = new File(name == null ? "" : name).getName().replaceAll("[^A-Za-z0-9._-]", "_");
        if (safe.isEmpty() || safe.equals(".") || safe.equals("..")) safe = "LeanDaily.png";
        if (!safe.toLowerCase(java.util.Locale.ROOT).endsWith(".png")) safe += ".png";
        File file = new File(dir, safe);
        try (FileOutputStream out = new FileOutputStream(file)) { out.write(bytes); }
        return file;
    }

    /** 必须在主线程调用。 */
    static void start(Activity activity, File file) {
        Uri uri = FileProvider.getUriForFile(activity, activity.getPackageName() + ".fileprovider", file);
        Intent send = new Intent(Intent.ACTION_SEND);
        send.setType("image/png");
        send.putExtra(Intent.EXTRA_STREAM, uri);
        send.setClipData(ClipData.newRawUri("image", uri));
        send.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION);
        Intent chooser = Intent.createChooser(send, null);
        chooser.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION);
        activity.startActivity(chooser);
    }
}
