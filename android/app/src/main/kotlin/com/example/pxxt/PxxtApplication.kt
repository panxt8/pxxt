package com.example.pxxt

import com.baidu.location.LocationClient
import com.baidu.mapapi.CoordType
import com.baidu.mapapi.SDKInitializer
import com.baidu.mapapi.base.BmfMapApplication
import com.baidu.mapapi.common.BaiduMapSDKException
import io.flutter.app.FlutterApplication

class PxxtApplication : FlutterApplication() {
    override fun onCreate() {
        super.onCreate()
        val context = applicationContext
        // Do not extend BmfMapApplication: the official Flutter plugin sets
        // privacy to false in its Application before initializing the SDK.
        BmfMapApplication.mContext = context
        LocationClient.setAgreePrivacy(true)
        try {
            SDKInitializer.setAgreePrivacy(context, true)
            SDKInitializer.initialize(context)
            SDKInitializer.setCoordType(CoordType.BD09LL)
        } catch (_: BaiduMapSDKException) {
            // The Flutter side handles map/location failures when SDK init is rejected.
        }
    }
}
