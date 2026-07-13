import { GoogleGenerativeAI } from "@google/generative-ai";
import { defineSecret } from "firebase-functions/params";
import { onCall, HttpsError } from "firebase-functions/v2/https";
import * as logger from "firebase-functions/logger";

const geminiApiKey = defineSecret("GEMINI_API_KEY");

interface MessagePayload {
  text: string;
  senderId: string;
}

interface GenerateSmartRepliesRequest {
  messages: MessagePayload[];
  currentUserId: string;
}

function buildPrompt(messages: MessagePayload[], currentUserId: string): string {
  const transcript = messages
    .map((message) => {
      const role = message.senderId === currentUserId ? "Me" : "Them";
      return `${role}: ${message.text}`;
    })
    .join("\n");

  return `You suggest short tap-to-send reply options for a casual 1:1 chat app.
You are NOT a chatbot. Do not continue the conversation yourself.
Return exactly 3 brief reply options the local user ("Me") could send next.
Keep each reply under 80 characters. Match the tone of the chat.

Conversation:
${transcript}

Respond with JSON only, no markdown:
{"replies":["reply1","reply2","reply3"]}`;
}

function parseReplies(raw: string): string[] {
  const trimmed = raw.trim();
  const jsonMatch = trimmed.match(/\{[\s\S]*\}/);
  if (!jsonMatch) return [];

  try {
    const parsed = JSON.parse(jsonMatch[0]) as { replies?: unknown };
    if (!Array.isArray(parsed.replies)) return [];

    return parsed.replies
      .filter((item): item is string => typeof item === "string")
      .map((reply) => reply.trim())
      .filter((reply) => reply.length > 0)
      .map((reply) => reply.slice(0, 80))
      .slice(0, 3);
  } catch {
    return [];
  }
}

export const generateSmartReplies = onCall(
  {
    secrets: [geminiApiKey],
    timeoutSeconds: 30,
    memory: "256MiB",
  },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Must be signed in.");
    }

    const data = request.data as GenerateSmartRepliesRequest;
    const messages = Array.isArray(data?.messages) ? data.messages : [];
    const currentUserId = data?.currentUserId;

    if (!currentUserId || typeof currentUserId !== "string") {
      throw new HttpsError("invalid-argument", "currentUserId is required.");
    }

    if (messages.length === 0) {
      return { replies: [] };
    }

    const recent = messages.slice(-10).filter(
      (message) =>
        message &&
        typeof message.text === "string" &&
        typeof message.senderId === "string" &&
        message.text.trim().length > 0,
    );

    if (recent.length === 0) {
      return { replies: [] };
    }

    try {
      const genAI = new GoogleGenerativeAI(geminiApiKey.value());
      const model = genAI.getGenerativeModel({ model: "gemini-2.0-flash" });
      const result = await model.generateContent(buildPrompt(recent, currentUserId));
      const text = result.response.text();
      const replies = parseReplies(text);

      return { replies };
    } catch (error) {
      logger.error("generateSmartReplies failed", error);
      return { replies: [] };
    }
  },
);
