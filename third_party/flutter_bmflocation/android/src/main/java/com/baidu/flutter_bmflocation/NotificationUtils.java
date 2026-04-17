package com.baidu.flutter_bmflocation;

import android.app.Notification;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.content.Context;
import android.content.ContextWrapper;
import android.graphics.Color;
import android.os.Build;

public class NotificationUtils extends ContextWrapper {

    private NotificationManager mManager;
    public String mChannelID = "";
    public String mChannelName = "";

    public NotificationUtils(Context base, String channelId, String channelName) {
        super(base);
        mChannelID = channelId;
        mChannelName = channelName;
        createChannels();
    }

    public void createChannels() {
        // create android channel
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            NotificationChannel androidChannel = new NotificationChannel(mChannelID,
                    mChannelName, NotificationManager.IMPORTANCE_DEFAULT);

            // Sets whether notifications posted to this channel should display notification lights
            androidChannel.enableLights(true);
            // Sets whether notification posted to this channel should vibrate.
            androidChannel.enableVibration(true);
            // Sets the notification light color for notifications posted to this channel
            androidChannel.setLightColor(Color.GREEN);
            // Sets whether notifications posted to this channel appear on the lockscreen or not
            androidChannel.setLockscreenVisibility(Notification.VISIBILITY_PRIVATE);

            getManager().createNotificationChannel(androidChannel);
        }
    }

    private NotificationManager getManager() {
        if (mManager == null) {
            mManager = (NotificationManager) getSystemService(Context.NOTIFICATION_SERVICE);
        }
        return mManager;
    }

    public Notification.Builder getAndroidChannelNotification(String title, String body) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            return new Notification.Builder(getApplicationContext(), mChannelID)
                    .setContentTitle(title)
                    .setContentText(body)
                    .setSmallIcon(R.drawable.bd_notification_icon)
                    .setAutoCancel(true);
        }

        return null;
    }
}