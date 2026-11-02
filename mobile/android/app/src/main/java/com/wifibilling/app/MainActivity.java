package com.wifibilling.app;

import android.Manifest;
import android.content.pm.PackageManager;
import android.os.Build;
import androidx.annotation.NonNull;
import androidx.core.app.ActivityCompat;
import androidx.core.content.ContextCompat;
import io.flutter.embedding.android.FlutterActivity;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugin.common.MethodChannel;
import java.util.ArrayList;
import java.util.List;

public class MainActivity extends FlutterActivity {
    private static final String CHANNEL = "com.wifibilling.app/bluetooth_permission";
    private static final int PERMISSION_REQ_CODE = 1001;
    private MethodChannel.Result pendingResult;

    @Override
    public void configureFlutterEngine(@NonNull FlutterEngine flutterEngine) {
        super.configureFlutterEngine(flutterEngine);
        new MethodChannel(flutterEngine.getDartExecutor().getBinaryMessenger(), CHANNEL)
                .setMethodCallHandler((call, result) -> {
                    if (call.method.equals("checkAndRequestBluetoothPermission")) {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) { // Android 12+ (API 31+)
                            boolean connectGranted = ContextCompat.checkSelfPermission(this, Manifest.permission.BLUETOOTH_CONNECT) == PackageManager.PERMISSION_GRANTED;
                            boolean scanGranted = ContextCompat.checkSelfPermission(this, Manifest.permission.BLUETOOTH_SCAN) == PackageManager.PERMISSION_GRANTED;

                            if (connectGranted && scanGranted) {
                                result.success(true);
                            } else {
                                pendingResult = result;
                                List<String> permissions = new ArrayList<>();
                                if (!connectGranted) permissions.add(Manifest.permission.BLUETOOTH_CONNECT);
                                if (!scanGranted) permissions.add(Manifest.permission.BLUETOOTH_SCAN);
                                ActivityCompat.requestPermissions(this, permissions.toArray(new String[0]), PERMISSION_REQ_CODE);
                            }
                        } else { // Android 11 or lower
                            boolean locFine = ContextCompat.checkSelfPermission(this, Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED;
                            if (locFine) {
                                result.success(true);
                            } else {
                                pendingResult = result;
                                ActivityCompat.requestPermissions(this, new String[]{Manifest.permission.ACCESS_FINE_LOCATION}, PERMISSION_REQ_CODE);
                            }
                        }
                    } else if (call.method.equals("isBluetoothPermissionGranted")) {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                            boolean connectGranted = ContextCompat.checkSelfPermission(this, Manifest.permission.BLUETOOTH_CONNECT) == PackageManager.PERMISSION_GRANTED;
                            result.success(connectGranted);
                        } else {
                            result.success(true);
                        }
                    } else {
                        result.notImplemented();
                    }
                });
    }

    @Override
    public void onRequestPermissionsResult(int requestCode, @NonNull String[] permissions, @NonNull int[] grantResults) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults);
        if (requestCode == PERMISSION_REQ_CODE) {
            boolean allGranted = grantResults.length > 0;
            for (int res : grantResults) {
                if (res != PackageManager.PERMISSION_GRANTED) {
                    allGranted = false;
                    break;
                }
            }
            if (pendingResult != null) {
                pendingResult.success(allGranted);
                pendingResult = null;
            }
        }
    }
}
