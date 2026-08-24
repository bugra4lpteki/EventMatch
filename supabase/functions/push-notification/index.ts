// Supabase Edge Function: push-notification
// Sends push notification to receiver when a new message is inserted into 'messages' table.

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.0";

const ONESIGNAL_APP_ID = Deno.env.get("ONESIGNAL_APP_ID") || "";
const ONESIGNAL_REST_API_KEY = Deno.env.get("ONESIGNAL_REST_API_KEY") || "";
const SUPABASE_URL = Deno.env.get("SUPABASE_URL") || "";
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

    // Initialize Supabase Admin Client
    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

    // Fetch Sender Name and Receiver Push Token
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
    const pushToken = receiver?.push_token || receiver?.fcm_token;

    // 1. Send via OneSignal (Recommended for cross-platform iOS & Android)
    if (ONESIGNAL_APP_ID && ONESIGNAL_REST_API_KEY) {
      const oneSignalBody: any = {
        app_id: ONESIGNAL_APP_ID,
        include_aliases: {
          external_id: [receiverId.toLowerCase(), receiverId],
        },
        target_channel: "push",
        headings: { en: `💬 ${senderName}`, tr: `💬 ${senderName}` },
        contents: { en: content, tr: content },
        data: {
          chat_id: senderId,
          match_id: matchId,
          type: "new_message",
        },
        ios_badgeType: "Increase",
        ios_badgeCount: 1,
        ios_sound: "default",
        android_sound: "default",
        android_channel_id: "event_match_chat_channel",
      };

      if (pushToken && pushToken.length > 20) {
        oneSignalBody["include_player_ids"] = [pushToken];
      }

      const osRes = await fetch("https://onesignal.com/api/v1/notifications", {
        method: "POST",
        headers: {
          "Content-Type": "application/json; charset=utf-8",
          Authorization: `Basic ${ONESIGNAL_REST_API_KEY}`,
        },
        body: JSON.stringify(oneSignalBody),
      });

      const osData = await osRes.json();
      console.log("[OneSignal Push Response]", osData);
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
