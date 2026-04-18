package com.beacon.sos;

import com.getcapacitor.BridgeActivity;

public class MainActivity extends BridgeActivity {
    @Override
    public void onCreate(android.os.Bundle savedInstanceState) {
        registerPlugin(BeaconNativePlugin.class);
        super.onCreate(savedInstanceState);
    }
}
