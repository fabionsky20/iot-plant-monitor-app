require("dotenv").config();

const express = require("express");
const cors = require("cors");
const mqtt = require("mqtt");
const { MongoClient } = require("mongodb");

const WebSocket = require("ws");

const app = express();
const wss = new WebSocket.Server({ noServer: true });

// deviceId -> Set<WebSocket>
const wsClientsByDevice = new Map();

function broadcastToDevice(deviceId, data) {

    console.log("📣 broadcastToDevice:", deviceId, "clients=", (wsClientsByDevice.get(deviceId)?.size ?? 0));

  const clients = wsClientsByDevice.get(deviceId);
  if (!clients) return;

  const msg = JSON.stringify(data);
  for (const ws of clients) {
    if (ws.readyState === WebSocket.OPEN) {
      ws.send(msg);
    }
  }
}

app.use(cors());
app.use(express.json());

const PORT = process.env.PORT || 3000;

// ===== Mongo =====
const mongoClient = new MongoClient(process.env.MONGO_URI);
let telemetryCol;
let alarmsCol;

// ===== MQTT =====
const mqttUrl = `mqtts://${process.env.MQTT_HOST}:${process.env.MQTT_PORT}`;

function parseDeviceIdFromTopic(topic) {
  // plantform/<deviceId>/telemetry
  const parts = topic.split("/");
  if (parts.length < 3) return null;
  return parts[1];
}

async function start() {
  // --- Mongo connect
  await mongoClient.connect();
  const db = mongoClient.db(process.env.MONGO_DB || "plantformio");
  telemetryCol = db.collection("telemetry");
  alarmsCol = db.collection("alarms");

  // Indici utili
  await telemetryCol.createIndex({ deviceId: 1, ts: -1 });
  await alarmsCol.createIndex({ deviceId: 1, ts: -1 });

  console.log("✅ Mongo connected");

  // --- MQTT connect
  const mqttClient = mqtt.connect(mqttUrl, {
    username: process.env.MQTT_USERNAME,
    password: process.env.MQTT_PASSWORD,
    protocol: "mqtts",
    rejectUnauthorized: true
  });

  mqttClient.on("connect", () => {
    console.log("✅ MQTT connected");
    mqttClient.subscribe("plantform/+/telemetry", { qos: 1 });
    mqttClient.subscribe("plantform/+/alarm", { qos: 1 });
  });

  mqttClient.on("message", async (topic, payloadBuf) => {
    const payloadStr = payloadBuf.toString("utf8");
    let json = null;

    try {
      json = JSON.parse(payloadStr);
    } catch {
      // ignora non-json (per ora)
      return;
    }

    const deviceId = parseDeviceIdFromTopic(topic);
    if (!deviceId) return;

    const receivedAt = new Date();

    // se vuoi tenere anche il timestamp del device (opzionale)
    let deviceTs = null;
    if (typeof json.ts === "number") {
      // supporta sia ms che secondi (se arriva in secondi)
      deviceTs = new Date(json.ts < 1e12 ? json.ts * 1000 : json.ts);
    }
    const ts = receivedAt; // 🔥 questo è quello usato per db + "ultimo dato"


    if (topic.endsWith("/telemetry")) {
      const doc = {
        deviceId,
        ts,
        temperature: typeof json.temperature === "number" ? json.temperature : null,
        humidity: typeof json.humidity === "number" ? json.humidity : null,
        chlorophyll: typeof json.chlorophyll === "number" ? json.chlorophyll : null,
        raw: json
      };

      await telemetryCol.insertOne(doc);
    } else if (topic.endsWith("/alarm")) {
      const doc = {
        deviceId,
        ts,
        level: json.level ?? "unknown",
        message: json.message ?? "",
        raw: json
      };
      await alarmsCol.insertOne(doc);
    }

    broadcastToDevice(deviceId, {
      type: topic.endsWith("/telemetry") ? "telemetry" : "alarm",
      deviceId,
      ts: ts.toISOString(),
      data: { ...json, ts: ts.toISOString() }
    });


  });

  // --- REST endpoints
  app.get("/devices/:id/latest", async (req, res) => {
    const deviceId = req.params.id;
    const last = await telemetryCol
      .find({ deviceId })
      .sort({ ts: -1 })
      .limit(1)
      .toArray();

    res.json(last[0] ?? null);
  });

  app.get("/devices/:id/history", async (req, res) => {
    try {
      const deviceId = req.params.id;

      const hoursRaw = req.query.hours;
      const limit = Math.min(Number(req.query.limit ?? 500), 2000);

      const query = { deviceId };

      // hours opzionale: se non lo passi, ritorna tutto (limitato)
      if (hoursRaw !== undefined) {
        const hours = Number(hoursRaw);
        if (!Number.isFinite(hours) || hours <= 0) {
          return res.status(400).json({ error: "Invalid hours" });
        }
        const from = new Date(Date.now() - hours * 60 * 60 * 1000);
        query.ts = { $gte: from };
      }

      const list = await telemetryCol
        .find(query)
        .sort({ ts: 1 })
        .limit(limit)
        .toArray();

      res.json(list);
    } catch (e) {
      console.error("history error", e);
      res.status(500).json({ error: "history_failed" });
    }
  });



  const server = app.listen(PORT, "0.0.0.0", () => {
    console.log(`✅ Backend running on http://0.0.0.0:${PORT}`);
  });

  server.on("upgrade", (req, socket, head) => {
    const url = new URL(req.url, "http://localhost");
    const deviceId = url.searchParams.get("deviceId");

    console.log("🔌 WS upgrade:", req.url, "deviceId=", deviceId);


    if (!deviceId) {
      socket.destroy();
      return;
    }

    wss.handleUpgrade(req, socket, head, (ws) => {
      if (!wsClientsByDevice.has(deviceId)) {
        wsClientsByDevice.set(deviceId, new Set());
      }
      wsClientsByDevice.get(deviceId).add(ws);

      ws.on("close", () => {
        wsClientsByDevice.get(deviceId)?.delete(ws);
      });
    });
  });

}

start().catch((e) => {
  console.error("❌ Fatal:", e);
  process.exit(1);
});
