import express from "express";
import cors from "cors";
import axios from "axios";
import { Low } from "lowdb"; import { JSONFile } from "lowdb/node";

const app = express();
app.use(cors());
app.use(express.json());

// Create or load JSON database
const adapter = new JSONFile("./db.json"); const db = new Low(adapter, { users: [], trades: [] }); await db.read();

// --- API ROUTES ---

// Get live crypto data from CoinGecko
app.get("/api/prices", async (req, res) => {
  try {
    const response = await axios.get(
      "https://api.coingecko.com/api/v3/coins/markets",
      {
        params: { vs_currency: "usd", order: "market_cap_desc", per_page: 10 },
      }
    );
    res.json(response.data);
  } catch (error) {
    res.status(500).json({ error: "Failed to fetch data" });
  }
});

// Simple user signup simulation
app.post("/api/signup", async (req, res) => {
  const { username } = req.body;
  const exists = db.data.users.find((u) => u.username === username);
  if (exists) return res.status(400).json({ message: "User already exists" });
  db.data.users.push({ username, balance: 20000, trades: [] });
  await db.write();
  res.json({ message: "Signup successful", user: { username, balance: 20000 } });
});

// Testnet trade simulator
app.post("/api/trade", async (req, res) => {
  const { username, symbol, amount } = req.body;
  const user = db.data.users.find((u) => u.username === username);
  if (!user) return res.status(404).json({ message: "User not found" });

  user.trades.push({ symbol, amount, time: new Date().toISOString() });
  user.balance -= amount;
  await db.write();
  res.json({ message: "Trade completed", user });
});

// AI chatbot simulation (local logic)
app.post("/api/chat", async (req, res) => {
  const { message } = req.body;
  let reply = "I'm not sure I understand.";
  if (message.toLowerCase().includes("price")) {
    reply = "You can view live prices on the dashboard!";
  } else if (message.toLowerCase().includes("trade")) {
    reply = "Use the Trade tab to simulate testnet trading!";
  } else if (message.toLowerCase().includes("wallet")) {
    reply = "Your wallet balance updates automatically after trades.";
  }
  res.json({ reply });
});

// Run the server
const PORT = 5000;
app.listen(PORT, () => console.log(`? Backend running on http://localhost:${PORT}`));
