package app.leandaily;

import java.io.*;
import java.net.*;
import java.nio.charset.StandardCharsets;
import java.util.*;
import java.util.concurrent.*;

final class Http {
    private final Map<String, HttpURLConnection> connections = new ConcurrentHashMap<>();
    private final Set<String> cancelled = ConcurrentHashMap.newKeySet();
    private final ScheduledExecutorService deadlines = Executors.newSingleThreadScheduledExecutor();
    void cancel(String id) {
        cancelled.add(id);
        HttpURLConnection conn = connections.get(id); if (conn != null) conn.disconnect();
    }
    Map<String, Object> request(Map<?, ?> args) throws Exception {
        String id = NativeChannel.string(args, "id", UUID.randomUUID().toString());
        if (cancelled.remove(id)) throw new Cancelled();
        URL url = new URL(NativeChannel.string(args, "url", ""));
        if (!url.getProtocol().equals("https")) throw new IllegalArgumentException("接口必须使用 HTTPS");
        HttpURLConnection conn = (HttpURLConnection) url.openConnection();
        connections.put(id, conn);
        ScheduledFuture<?> deadline = null;
        final java.util.concurrent.atomic.AtomicBoolean expired = new java.util.concurrent.atomic.AtomicBoolean();
        try {
            int timeout = Math.min(120000, Math.max(1000, NativeChannel.number(args, "timeout", 120000).intValue()));
            deadline = deadlines.schedule(() -> { expired.set(true); conn.disconnect(); }, timeout, TimeUnit.MILLISECONDS);
            conn.setConnectTimeout(Math.min(30000, timeout)); conn.setReadTimeout(timeout); conn.setInstanceFollowRedirects(false);
            conn.setRequestMethod(NativeChannel.string(args, "method", "GET"));
            Map<?, ?> headers = NativeChannel.map(args.get("headers"));
            for (Map.Entry<?, ?> e : headers.entrySet()) conn.setRequestProperty((String)e.getKey(), (String)e.getValue());
            byte[] payload = null;
            if (args.get("multipart") instanceof Map) {
                Map<?, ?> multipart = (Map<?, ?>)args.get("multipart");
                String boundary = "Fitness"+UUID.randomUUID().toString().replace("-", "");
                ByteArrayOutputStream bytes = new ByteArrayOutputStream();
                for (Map.Entry<?, ?> e : NativeChannel.map(multipart.get("fields")).entrySet()) {
                    bytes.write(("--"+boundary+"\r\nContent-Disposition: form-data; name=\""+e.getKey()+"\"\r\n\r\n"+e.getValue()+"\r\n").getBytes(StandardCharsets.UTF_8));
                }
                bytes.write(("--"+boundary+"\r\nContent-Disposition: form-data; name=\"file\"; filename=\"meal.jpg\"\r\nContent-Type: image/jpeg\r\n\r\n").getBytes(StandardCharsets.UTF_8));
                bytes.write((byte[])multipart.get("bytes"));
                bytes.write(("\r\n--"+boundary+"--\r\n").getBytes(StandardCharsets.UTF_8));
                payload = bytes.toByteArray(); conn.setRequestProperty("Content-Type", "multipart/form-data; boundary="+boundary);
            } else if (args.get("body") != null) payload = ((String)args.get("body")).getBytes(StandardCharsets.UTF_8);
            if (cancelled.contains(id)) throw new Cancelled();
            if (payload != null) {
                conn.setDoOutput(true); conn.setFixedLengthStreamingMode(payload.length);
                try (OutputStream out = conn.getOutputStream()) { out.write(payload); }
            }
            int status = conn.getResponseCode(); InputStream stream = status >= 400 ? conn.getErrorStream() : conn.getInputStream();
            String body = stream == null ? "" : new String(Photos.read(stream, 16*1024*1024), StandardCharsets.UTF_8);
            if (cancelled.contains(id)) throw new Cancelled();
            if (expired.get()) throw new SocketTimeoutException();
            Map<String, Object> result = new LinkedHashMap<>(); result.put("status", status); result.put("body", body); return result;
        } catch (Exception e) {
            if (cancelled.contains(id)) throw new Cancelled();
            if (expired.get()) throw new SocketTimeoutException();
            throw e;
        } finally {
            connections.remove(id, conn); cancelled.remove(id); if (deadline != null) deadline.cancel(false); conn.disconnect();
        }
    }
    static final class Cancelled extends IOException { }
}
