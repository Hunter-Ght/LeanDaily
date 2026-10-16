package app.leandaily;

import android.app.Activity;
import android.content.ClipData;
import android.content.Intent;
import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.graphics.Matrix;
import android.media.ExifInterface;
import android.net.Uri;
import android.provider.MediaStore;
import androidx.core.content.FileProvider;
import java.io.*;
import java.util.*;

final class Images {
    private final Activity activity;
    private File cameraFile;
    private Uri cameraUri;
    private int limit;
    Images(Activity activity) { this.activity = activity; }
    void start(String source, int requestedLimit, int code) throws IOException {
        limit = Math.max(1, requestedLimit);
        Intent intent;
        if (source.equals("camera")) {
            File dir = new File(activity.getCacheDir(), "camera"); dir.mkdirs();
            cameraFile = File.createTempFile("capture-", ".jpg", dir);
            cameraUri = FileProvider.getUriForFile(activity, activity.getPackageName()+".fileprovider", cameraFile);
            intent = new Intent(MediaStore.ACTION_IMAGE_CAPTURE);
            intent.putExtra(MediaStore.EXTRA_OUTPUT, cameraUri);
            intent.setClipData(ClipData.newRawUri("photo", cameraUri));
            intent.addFlags(Intent.FLAG_GRANT_WRITE_URI_PERMISSION | Intent.FLAG_GRANT_READ_URI_PERMISSION);
        } else if (source.equals("gallery")) {
            intent = new Intent(Intent.ACTION_OPEN_DOCUMENT); intent.setType("image/*");
            intent.addCategory(Intent.CATEGORY_OPENABLE); intent.putExtra(Intent.EXTRA_ALLOW_MULTIPLE, limit > 1);
        } else throw new IllegalArgumentException("照片来源无效");
        try { activity.startActivityForResult(intent, code); }
        catch (RuntimeException e) { cleanup(); throw e; }
    }
    List<byte[]> finish(int resultCode, Intent data) throws Exception {
        try {
            List<byte[]> result = new ArrayList<>();
            if (resultCode != Activity.RESULT_OK) return result;
            List<Uri> uris = new ArrayList<>();
            if (cameraUri != null) uris.add(cameraUri);
            else if (data != null && data.getClipData() != null) {
                ClipData clips = data.getClipData();
                for (int i = 0; i < Math.min(limit, clips.getItemCount()); i++) uris.add(clips.getItemAt(i).getUri());
            } else if (data != null && data.getData() != null) uris.add(data.getData());
            for (Uri uri : uris) result.add(jpeg(uri));
            return result;
        } finally { cleanup(); }
    }
    void cleanup() {
        if (cameraUri != null) activity.revokeUriPermission(cameraUri, Intent.FLAG_GRANT_READ_URI_PERMISSION | Intent.FLAG_GRANT_WRITE_URI_PERMISSION);
        if (cameraFile != null) cameraFile.delete();
        cameraFile = null; cameraUri = null;
    }
    private InputStream open(Uri uri) throws IOException {
        InputStream in = activity.getContentResolver().openInputStream(uri); if (in == null) throw new IOException(); return in;
    }
    private byte[] jpeg(Uri uri) throws IOException {
        BitmapFactory.Options options = new BitmapFactory.Options(); options.inJustDecodeBounds = true;
        try (InputStream in = open(uri)) { BitmapFactory.decodeStream(in, null, options); }
        if (options.outWidth <= 0 || options.outHeight <= 0) throw new IllegalArgumentException("仅支持有效 JPEG 照片");
        int orientation = ExifInterface.ORIENTATION_NORMAL;
        try (InputStream in = open(uri)) {
            orientation = new ExifInterface(in).getAttributeInt(ExifInterface.TAG_ORIENTATION, ExifInterface.ORIENTATION_NORMAL);
        } catch (IOException ignored) { /* PNG 等无 EXIF 的图片仍可转换为 JPEG。 */ }
        options.inSampleSize = 1;
        while (Math.max(options.outWidth, options.outHeight) / options.inSampleSize > 3200) options.inSampleSize *= 2;
        options.inJustDecodeBounds = false;
        Bitmap bitmap;
        try (InputStream in = open(uri)) { bitmap = BitmapFactory.decodeStream(in, null, options); }
        if (bitmap == null) throw new IOException();
        try {
            Matrix matrix = new Matrix();
            switch (orientation) {
                case ExifInterface.ORIENTATION_FLIP_HORIZONTAL: matrix.setScale(-1, 1); break;
                case ExifInterface.ORIENTATION_ROTATE_180: matrix.setRotate(180); break;
                case ExifInterface.ORIENTATION_FLIP_VERTICAL: matrix.setScale(1, -1); break;
                case ExifInterface.ORIENTATION_TRANSPOSE: matrix.setRotate(90); matrix.postScale(-1, 1); break;
                case ExifInterface.ORIENTATION_ROTATE_90: matrix.setRotate(90); break;
                case ExifInterface.ORIENTATION_TRANSVERSE: matrix.setRotate(-90); matrix.postScale(-1, 1); break;
                case ExifInterface.ORIENTATION_ROTATE_270: matrix.setRotate(-90); break;
                default: break;
            }
            float scale = Math.min(1f, 1600f / Math.max(bitmap.getWidth(), bitmap.getHeight()));
            matrix.postScale(scale, scale);
            Bitmap corrected = Bitmap.createBitmap(bitmap, 0, 0, bitmap.getWidth(), bitmap.getHeight(), matrix, true);
            if (corrected != bitmap) { bitmap.recycle(); bitmap = corrected; }
            ByteArrayOutputStream out = new ByteArrayOutputStream();
            if (!bitmap.compress(Bitmap.CompressFormat.JPEG, 80, out)) throw new IOException();
            return out.toByteArray();
        } finally { bitmap.recycle(); }
    }
}
