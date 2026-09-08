// @ts-nocheck
// Supabase Edge Function: push-notification
// Sends push notification to receiver when a new message is inserted into 'messages' table.
// Supports both Firebase Cloud Messaging (FCM) & OneSignal with high priority & WhatsApp-like heads-up styling.

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.0";

const ONESIGNAL_APP_ID = Deno.env.get("ONESIGNAL_APP_ID") || "bc0c0b94-e465-4b0f-b01c-581d848df2ca";
const ONESIGNAL_REST_API_KEY = Deno.env.get("ONESIGNAL_REST_API_KEY") || "";
const FIREBASE_SERVER_KEY = Deno.env.get("FIREBASE_SERVER_KEY") || "";
const SUPABASE_URL = Deno.env.get("SUPABASE_URL") || "https://pqtpogebnfubrqowlnkq.supabase.co";
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") || "";

serve(async (req) => {
  try {
    const payload = await req.json();
    const record = payload.record || payload;

    const senderId = record.sender_id;
    const receiverId = record.receiver_id;
    const content = record.content || "Yeni bir mesajınız var.";
    const matchId = record.match_id;

    if (!receiverId || !senderId) {
      return new Response(JSON.stringify({ error: "Missing sender or receiver" }), {
        status: 400,
        headers: { "Content-Type": "application/json" },
      });
    }

    // Supabase Admin Client
    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

    // Fetch Sender Name and Receiver Push Tokens
    const { data: sender } = await supabase
      .from("users")
      .select("name, avatar_url")
      .eq("id", senderId)
      .maybeSingle();

    const { data: receiver } = await supabase
      .from("users")
      .select("id, name, push_token, fcm_token")
      .eq("id", receiverId)
      .maybeSingle();

    const senderName = sender?.name || "Biri";
    const pushToken = receiver?.fcm_token || receiver?.push_token;

    // 1. Firebase Cloud Messaging (FCM) Gönderimi (High Priority & Heads-up)
    if (FIREBASE_SERVER_KEY && pushToken && pushToken.length > 20) {
      const fcmPayload = {
        to: pushToken,
        priority: "high",
        notification: {
          title: `💬 ${senderName}`,
          body: content,
          sound: "default",
          android_channel_id: "high_importance_channel",
        },
        android: {
          priority: "high",
          notification: {
            channel_id: "high_importance_channel",
            sound: "default",
            priority: "max",
            visibility: "public",
            click_action: "FLUTTER_NOTIFICATION_CLICK",
          },
        },
        headers: {
          "apns-priority": "10",
        },
        apns: {
          headers: {
            "apns-priority": "10",
          },
          payload: {
            aps: {
              alert: {
                title: `💬 ${senderName}`,
                body: content,
              },
              sound: "default",
              badge: 1,
              "content-available": 1,
            },
          },
        },
        data: {
          chat_id: senderId,
          sender_id: senderId,
          sender_name: senderName,
          match_id: matchId?.toString() ?? "",
          content: content,
          type: "new_message",
          click_action: "FLUTTER_NOTIFICATION_CLICK",
        },
      };

      try {
        const fcmRes = await fetch("https://fcm.googleapis.com/fcm/send", {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
            Authorization: `key=${FIREBASE_SERVER_KEY}`,
          },
          body: JSON.stringify(fcmPayload),
        });
        const fcmData = await fcmRes.json();
        console.log("[FCM Push Result]", fcmData);
      } catch (fcmErr) {
        console.error("[FCM Push Error]", fcmErr);
      }
    }

    // 2. OneSignal Gönderimi (Yüksek Öncelik & Heads-up)
    if (ONESIGNAL_APP_ID && ONESIGNAL_REST_API_KEY) {
      const oneSignalBody: any = {
        app_id: ONESIGNAL_APP_ID,
        include_aliases: {
          external_id: [receiverId.toLowerCase(), receiverId],
        },
        target_channel: "push",
        priority: 10,
        android_priority: 5,
        headings: { en: `💬 ${senderName}`, tr: `💬 ${senderName}` },
        contents: { en: content, tr: content },
        data: {
          chat_id: senderId,
          sender_id: senderId,
          match_id: matchId,
          type: "new_message",
        },
        ios_badgeType: "Increase",
        ios_badgeCount: 1,
        ios_sound: "default",
        android_sound: "default",
        android_channel_id: "high_importance_channel",
        apns_priority: 10,
        content_available: true,
      };

      if (pushToken && pushToken.length > 20) {
        oneSignalBody["include_player_ids"] = [pushToken];
      }

      try {
        const osRes = await fetch("https://onesignal.com/api/v1/notifications", {
          method: "POST",
          headers: {
            "Content-Type": "application/json; charset=utf-8",
            Authorization: `Key ${ONESIGNAL_REST_API_KEY}`,
          },
          body: JSON.stringify(oneSignalBody),
        });
        const osData = await osRes.json();
        console.log("[OneSignal Push Response]", osData);
      } catch (osErr) {
        console.error("[OneSignal Push Error]", osErr);
      }
    }

    return new Response(JSON.stringify({ success: true, receiver: receiverId }), {
      status: 200,
      headers: { "Content-Type": "application/json" },
    });
  } catch (error) {
    console.error("[Push Notification Error]", error);
    return new Response(JSON.stringify({ error: error.message }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }
});
