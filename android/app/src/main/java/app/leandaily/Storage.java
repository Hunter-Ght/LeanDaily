package app.leandaily;

import android.content.ContentValues;
import android.content.Context;
import android.database.Cursor;
import android.database.sqlite.SQLiteDatabase;
import java.io.IOException;
import java.util.LinkedHashMap;
import java.util.Map;

final class Storage {
    private final Context context;
    private SQLiteDatabase db;
    Storage(Context context) { this.context = context; }
    private SQLiteDatabase database() {
        if (db == null) {
            SQLiteDatabase opened = context.openOrCreateDatabase("fitness.db", 0, null);
            if (opened.getVersion() > 1) { opened.close(); throw new IllegalArgumentException("数据库版本不兼容"); }
            opened.execSQL("CREATE TABLE IF NOT EXISTS documents (key TEXT PRIMARY KEY, value TEXT NOT NULL)");
            opened.setVersion(1);
            opened.enableWriteAheadLogging();
            db = opened;
        }
        return db;
    }
    synchronized Map<String, String> all() {
        SQLiteDatabase db = database();
        Map<String, String> values = new LinkedHashMap<>();
        try (Cursor c = db.rawQuery("SELECT key,length(value) FROM documents", null)) {
            while (c.moveToNext()) {
                String key = c.getString(0); int size = c.getInt(1);
                StringBuilder value = new StringBuilder();
                for (int offset = 1; offset <= size; offset += 262144) {
                    try (Cursor part = db.rawQuery("SELECT substr(value,?,262144) FROM documents WHERE key=?", new String[]{String.valueOf(offset),key})) {
                        if (part.moveToFirst()) value.append(part.getString(0));
                    }
                }
                values.put(key, value.toString());
            }
        }
        return values;
    }
    synchronized void put(String key, String value) throws IOException {
        if (key == null || value == null) throw new IllegalArgumentException("缺少保存内容");
        ContentValues v = new ContentValues(); v.put("key", key); v.put("value", value);
        if (database().insertWithOnConflict("documents", null, v, SQLiteDatabase.CONFLICT_REPLACE) < 0) throw new IOException();
    }
}
