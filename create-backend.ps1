# create-backend.ps1
# Run this from any PowerShell; it will create the backend project under Desktop\cbl-trade-learning-sepolia\backend

$root = "$HOME\Desktop\cbl-trade-learning-sepolia"
$backend = Join-Path $root "backend"

# Make sure folder exists
New-Item -ItemType Directory -Force -Path $backend | Out-Null
Set-Location $backend

# Init npm
if (-not (Test-Path package.json)) { npm init -y | Out-Null }

# Ensure "type":"module" so we can use ESM imports safely
(Get-Content package.json -Raw) | ConvertFrom-Json | ForEach-Object {
    $pkg = $_
    if (-not $pkg.type) { $pkg | Add-Member -Notepropertyname type -Notepropertyvalue module }
    $pkg | ConvertTo-Json -Depth 10 | Set-Content package.json -Encoding UTF8
}

# Install runtime deps
npm install express cors axios lowdb bcrypt jsonwebtoken nodemon --legacy-peer-deps --save

# Create a clean db.json (no BOM)
'{
  "tokens": [],
  "users": [],
  "orders": []
}' | Set-Content -Path (Join-Path $backend "db.json") -Encoding Ascii

# Write server.js (ESM)
@'
import express from "express";
import cors from "cors";
import axios from "axios";
import bcrypt from "bcrypt";
import jwt from "jsonwebtoken";
import { Low } from "lowdb";
import { JSONFile } from "lowdb/node";
import path from "path";
import fs from "fs";

const app = express();
app.use(cors());
app.use(express.json());

const dbFile = path.join(process.cwd(), "db.json");
const adapter = new JSONFile(dbFile);
const db = new Low(adapter);
await db.read();
db.data ||= { tokens: [], users: [], orders: [] };

// Helper: create sample tokens (if not present)
if (!db.data.tokens || db.data.tokens.length === 0) {
  db.data.tokens = [
    { id: "CBL", name: "CBL Token", symbol: "CBL", supply: 20000, decimals: 18, address: null, price_usd: 0.5 },
    { id: "TKN2", name: "Token Two", symbol: "TKN2", supply: 20000, decimals: 18, address: null, price_usd: 0.12 },
    { id: "TKN3", name: "Token Three", symbol: "TKN3", supply: 20000, decimals: 18, address: null, price_usd: 0.03 }
  ];
  await db.write();
}

// Simple auth (signup/login) — returns token (simulated)
const JWT_SECRET = process.env.JWT_SECRET || "dev_secret";

app.post("/api/signup", async (req, res) => {
  const { username, password } = req.body;
  if (!username || !password) return res.status(400).json({ error: "username & password required" });
  await db.read();
  if (db.data.users.find(u => u.username === username)) return res.status(400).json({ error: "user exists" });
  const hash = await bcrypt.hash(password, 8);
  const user = { id: Date.now().toString(), username, password: hash, balances: { CBL: 20000, TKN2: 0, TKN3: 0 } };
  db.data.users.push(user);
  await db.write();
  const token = jwt.sign({ id: user.id, username: user.username }, JWT_SECRET, { expiresIn: "7d" });
  res.json({ token, user: { id: user.id, username: user.username, balances: user.balances } });
});

app.post("/api/login", async (req, res) => {
  const { username, password } = req.body;
  await db.read();
  const user = db.data.users.find(u => u.username === username);
  if (!user) return res.status(400).json({ error: "invalid credentials" });
  const ok = await bcrypt.compare(password, user.password);
  if (!ok) return res.status(400).json({ error: "invalid credentials" });
  const token = jwt.sign({ id: user.id, username: user.username }, JWT_SECRET, { expiresIn: "7d" });
  res.json({ token, user: { id: user.id, username: user.username, balances: user.balances } });
});

function auth(req, res, next) {
  const header = req.headers.authorization;
  if (!header) return res.status(401).json({ error: "missing auth" });
  const token = header.split(" ")[1];
  try {
    req.user = jwt.verify(token, JWT_SECRET);
    next();
  } catch (e) {
    return res.status(401).json({ error: "invalid token" });
  }
}

// Get tokens (includes simulated price)
app.get("/api/tokens", async (req, res) => {
  await db.read();
  res.json(db.data.tokens);
});

// Place a simulated order (buy/sell) — backend updates user balances
app.post("/api/orders", auth, async (req, res) => {
  const { type, tokenId, amount } = req.body;
  const amt = Number(amount);
  if (!amt || amt <= 0) return res.status(400).json({ error: "invalid amount" });
  await db.read();
  const user = db.data.users.find(u => u.id === req.user.id);
  if (!user) return res.status(400).json({ error: "user not found" });
  user.balances ||= {};
  user.balances[tokenId] ||= 0;
  if (type === "buy") {
    user.balances[tokenId] += amt;
  } else {
    if (user.balances[tokenId] < amt) return res.status(400).json({ error: "insufficient balance" });
    user.balances[tokenId] -= amt;
  }
  const order = { id: Date.now().toString(), userId: user.id, type, tokenId, amount: amt, ts: Date.now() };
  db.data.orders ||= [];
  db.data.orders.push(order);
  await db.write();
  res.json({ ok: true, order, balances: user.balances });
});

// CoinGecko proxy for market data
app.get("/api/prices", async (req, res) => {
  try {
    const result = await axios.get("https://api.coingecko.com/api/v3/coins/markets", {
      params: { vs_currency: "usd", per_page: 10, order: "market_cap_desc" }
    });
    res.json(result.data);
  } catch (e) {
    console.error(e?.message);
    res.status(500).json({ error: "failed to fetch prices" });
  }
});

// Simple AI assistant (proxy to free public API)
app.post("/api/chat", async (req, res) => {
  const { message } = req.body;
  if (!message) return res.status(400).json({ error: "message required" });
  try {
    // Using a free public fun chatbot API (no key)
    const r = await axios.post("https://api.monkedev.com/fun/chat", { msg: message });
    return res.json({ reply: r.data.response || "No reply" });
  } catch (e) {
    console.error(e?.message);
    return res.json({ reply: "AI service error, try again later." });
  }
});

const PORT = 4000;
app.listen(PORT, () => console.log(`✅ Backend running on http://localhost:${PORT}`));
'@ | Set-Content -Path (Join-Path $backend "server.js") -Encoding UTF8

Write-Host "Backend created at: $backend"
Write-Host "Run this in another terminal to start backend:"
Write-Host "cd `"$backend`" ; npx nodemon server.js"
