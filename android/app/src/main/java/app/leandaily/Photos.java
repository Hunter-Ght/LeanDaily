package app.leandaily;

import android.content.Context;
import java.io.*;
import java.security.MessageDigest;
import java.util.*;

final class Photos {
    private final File dir;
    Photos(Context context) { dir = new File(context.getFilesDir(), "photos"); }
    private File photo(String path) throws IOException {
        dir.mkdirs();
        File f = new File(path).getCanonicalFile();
        if (!dir.getCanonicalFile().equals(f.getParentFile()) || !f.getName().matches("[a-f0-9-]+\\.jpg")) throw new IllegalArgumentException("照片路径无效");
        return f;
    }
    static byte[] read(InputStream input, int limit) throws IOException {
        if (input == null) throw new IOException();
        try (InputStream in = input; ByteArrayOutputStream out = new ByteArrayOutputStream()) {
            byte[] buf = new byte[8192]; int n;
            while ((n = in.read(buf)) != -1) { if (out.size() + n > limit) throw new IOException("文件过大"); out.write(buf, 0, n); }
            return out.toByteArray();
        }
    }
    String write(byte[] bytes) throws Exception {
        if (bytes == null || bytes.length < 3 || bytes.length > 12*1024*1024 || (bytes[0]&255) != 255 || (bytes[1]&255) != 216) throw new IllegalArgumentException("仅支持有效 JPEG 照片");
        File f = photo(new File(dir, UUID.randomUUID()+".jpg").getPath());
        try (FileOutputStream out = new FileOutputStream(f)) { out.write(bytes); out.getFD().sync(); }
        return f.getPath();
    }
    Map<String, Object> read(String path) throws Exception {
        byte[] bytes = read(new FileInputStream(photo(path)), 12*1024*1024);
        StringBuilder hash = new StringBuilder();
        for (byte b : MessageDigest.getInstance("SHA-256").digest(bytes)) hash.append(String.format(Locale.ROOT, "%02x", b&255));
        Map<String, Object> out = new LinkedHashMap<>(); out.put("bytes", bytes); out.put("size", bytes.length); out.put("sha256", hash.toString()); return out;
    }
}
