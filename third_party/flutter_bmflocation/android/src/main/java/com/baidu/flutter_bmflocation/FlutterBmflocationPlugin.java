package com.baidu.flutter_bmflocation;

import android.app.Activity;
import android.content.Context;
import android.util.Log;

import androidx.annotation.NonNull;

import com.baidu.flutter_bmflocation.handlers.HandlersFactory;
import com.baidu.location.LocationClient;

import java.util.HashMap;

import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.plugin.common.BinaryMessenger;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.MethodChannel.MethodCallHandler;
import io.flutter.plugin.common.MethodChannel.Result;
import io.flutter.plugin.common.PluginRegistry;
import io.flutter.embedding.engine.plugins.activity.ActivityAware;
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding;

/** FlutterBmflocationPlugin */
public class FlutterBmflocationPlugin implements FlutterPlugin, MethodCallHandler,ActivityAware {

  private static MethodChannel locationChannel;

  private static MethodChannel geofenceChannel;
  public static Context mContext = null;

  public static Activity mActivity = null;

   /* 新版接口 */
  @Override
  public void onAttachedToEngine(@NonNull FlutterPluginBinding flutterPluginBinding) {
    if (null == flutterPluginBinding) {
      return;
    }
    if (null == mContext) {
      mContext = flutterPluginBinding.getApplicationContext();
    }
    initMethodChannel(flutterPluginBinding.getBinaryMessenger());
  }

  private void initMethodChannel(BinaryMessenger binaryMessenger) {
    if (null == binaryMessenger) {
      return;
    }

    locationChannel = new MethodChannel(binaryMessenger, Constants.MethodChannelName.LOCATION_CHANNEL);
    locationChannel.setMethodCallHandler(this);

    MethodChannelManager.getInstance().putLocationChannel(locationChannel);

    geofenceChannel = new MethodChannel(binaryMessenger, Constants.MethodChannelName.GEOFENCE_CHANNEL);
    geofenceChannel.setMethodCallHandler(this);

    MethodChannelManager.getInstance().putGeofenceChannel(geofenceChannel);
  }

   /* 旧版接口 */
//  public static void registerWith(PluginRegistry.Registrar registrar) {
//    if (null == registrar) {
//      return;
//    }
//    if (null == mContext) {
//      mContext = registrar.context();
//    }
//    initStaticMethodChannel(registrar.messenger());
//  }

  private static void initStaticMethodChannel(BinaryMessenger binaryMessenger) {
    if (null == binaryMessenger) {
      return;
    }

    FlutterBmflocationPlugin flutterBmfPlugin = new FlutterBmflocationPlugin();

    locationChannel = new MethodChannel(binaryMessenger, Constants.MethodChannelName.LOCATION_CHANNEL);
    locationChannel.setMethodCallHandler(flutterBmfPlugin);
    MethodChannelManager.getInstance().putLocationChannel(locationChannel);

    geofenceChannel = new MethodChannel(binaryMessenger, Constants.MethodChannelName.GEOFENCE_CHANNEL);
    geofenceChannel.setMethodCallHandler(flutterBmfPlugin);
    MethodChannelManager.getInstance().putLocationChannel(geofenceChannel);
  }


  @Override
  public void onAttachedToActivity(ActivityPluginBinding binding) {
    mActivity = binding.getActivity();
  }

  @Override
  public void onDetachedFromActivityForConfigChanges() {
    onDetachedFromActivity();
  }

  @Override
  public void onReattachedToActivityForConfigChanges(ActivityPluginBinding binding) {
    onAttachedToActivity(binding);
  }

  @Override
  public void onDetachedFromActivity() {

  }

  @Override
  public void onMethodCall(@NonNull MethodCall call, @NonNull Result result) {
    if (mContext == null) {
      result.error("-1", "context is null", null);
      return;
    }

    if (call.method.equals(Constants.MethodID.LOCATION_SETAGREEPRIVACY)) {
      try {
        boolean isAgreePrivacy = (Boolean) call.arguments;
        LocationClient.setAgreePrivacy(isAgreePrivacy);
      } catch (Exception e) {
      }
      result.success(new HashMap<String, Boolean>() {{
        put(Constants.RESULT_KEY, true);
      }});
      return;
    }
    
    HandlersFactory.getInstance(mContext).dispatchMethodHandler(mContext, call, result);
  }

  @Override
  public void onDetachedFromEngine(@NonNull FlutterPluginBinding binding) {
    if (locationChannel != null) {
      locationChannel.setMethodCallHandler(null);
      locationChannel = null;
    }
    if (geofenceChannel != null) {
      geofenceChannel.setMethodCallHandler(null);
      geofenceChannel = null;
    }
  }
}
