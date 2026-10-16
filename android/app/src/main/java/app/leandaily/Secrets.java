package app.leandaily;

import android.content.Context;
import android.security.keystore.KeyGenParameterSpec;
import android.security.keystore.KeyProperties;
import android.util.Base64;
import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.security.KeyStore;
import java.util.Arrays;
import java.util.LinkedHashMap;
import java.util.Map;
import javax.crypto.Cipher;
import javax.crypto.KeyGenerator;
import javax.crypto.SecretKey;
import javax.crypto.spec.GCMParameterSpec;
import org.json.JSONObject;

final class Secrets {
    private final Context context;
    Secrets(Context context) { this.context = context; }
    private SecretKey encryptionKey() throws Exception {
        KeyStore ks = KeyStore.getInstance("AndroidKeyStore"); ks.load(null);
        String alias = "leandaily.credentials.v1";
        if (!ks.containsAlias(alias)) {
            KeyGenerator generator = KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, "AndroidKeyStore");
            generator.init(new KeyGenParameterSpec.Builder(alias, KeyProperties.PURPOSE_ENCRYPT | KeyProperties.PURPOSE_DECRYPT)
                .setBlockModes(KeyProperties.BLOCK_MODE_GCM).setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE).build());
            generator.generateKey();
        }
        return (SecretKey) ks.getKey(alias, null);
    }
    synchronized Map<String, String> get() throws Exception {
        String encoded = context.getSharedPreferences("credentials", 0).getString("payload", null);
        JSONObject values = new JSONObject();
        if (encoded != null) {
            byte[] data = Base64.decode(encoded, Base64.NO_WRAP);
            Cipher c = Cipher.getInstance("AES/GCM/NoPadding");
            c.init(Cipher.DECRYPT_MODE, encryptionKey(), new GCMParameterSpec(128, Arrays.copyOfRange(data, 0, 12)));
            values = new JSONObject(new String(c.doFinal(Arrays.copyOfRange(data, 12, data.length)), StandardCharsets.UTF_8));
        }
        Map<String, String> out = new LinkedHashMap<>();
        out.put("modelKey", values.optString("modelKey", ""));
        return out;
    }
    synchronized void prune() throws Exception { set(get()); }
    synchronized void set(Map<?, ?> values) throws Exception {
        JSONObject allowed = new JSONObject();
        allowed.put("modelKey", values.get("modelKey") == null ? "" : values.get("modelKey"));
        Cipher c = Cipher.getInstance("AES/GCM/NoPadding"); c.init(Cipher.ENCRYPT_MODE, encryptionKey());
        byte[] cipher = c.doFinal(allowed.toString().getBytes(StandardCharsets.UTF_8));
        ByteArrayOutputStream out = new ByteArrayOutputStream(); out.write(c.getIV()); out.write(cipher);
        if (!context.getSharedPreferences("credentials", 0).edit().putString("payload", Base64.encodeToString(out.toByteArray(), Base64.NO_WRAP)).commit()) throw new IOException();
    }
}
