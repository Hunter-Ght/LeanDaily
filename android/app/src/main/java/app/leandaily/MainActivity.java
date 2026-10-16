package app.leandaily;

import android.content.Intent;
import io.flutter.embedding.android.FlutterActivity;
import io.flutter.embedding.engine.FlutterEngine;

public class MainActivity extends FlutterActivity {
    private NativeChannel nativeChannel;
    @Override public void configureFlutterEngine(FlutterEngine engine) {
        super.configureFlutterEngine(engine);
        nativeChannel = new NativeChannel(this, engine.getDartExecutor().getBinaryMessenger());
        nativeChannel.launch(getIntent(), false);
    }
    @Override protected void onNewIntent(Intent intent) {
        super.onNewIntent(intent); setIntent(intent);
        if (nativeChannel != null) nativeChannel.launch(intent, true);
    }
    @Override protected void onActivityResult(int requestCode, int resultCode, Intent data) {
        super.onActivityResult(requestCode, resultCode, data);
        if (nativeChannel != null) nativeChannel.activityResult(requestCode, resultCode, data);
    }
    @Override public void onRequestPermissionsResult(int requestCode, String[] permissions, int[] grantResults) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults);
        if (nativeChannel != null) nativeChannel.permissionResult(requestCode, grantResults);
    }
    @Override public void cleanUpFlutterEngine(FlutterEngine engine) {
        if (nativeChannel != null) { nativeChannel.detach(); nativeChannel = null; }
        super.cleanUpFlutterEngine(engine);
    }
}
