# create-frontend.ps1
$root = "$HOME\Desktop\cbl-trade-learning-sepolia"
$frontend = Join-Path $root "frontend"
New-Item -ItemType Directory -Force -Path $frontend | Out-Null
Set-Location $frontend

# Initialize Vite + React + TS
npm create vite@latest . -- --template react-ts
# Install dependencies
npm install axios chart.js react-chartjs-2 ethers web3modal wagmi viem
npm install -D @types/node

# Write index.html (already created by vite) and src files overwrite
# src/main.tsx
@'
import React from "react";
import { createRoot } from "react-dom/client";
import App from "./App";
import "./index.css";

createRoot(document.getElementById("root")!).render(<React.StrictMode><App /></React.StrictMode>);
'@ | Set-Content -Path (Join-Path $frontend "src/main.tsx") -Encoding UTF8

# src/index.css
@'
:root { --bg:#071017; --card:#0f1620; --accent:#00ff88; --text:#e6eef6; }
body { margin:0; font-family:Inter, Arial, sans-serif; background:var(--bg); color:var(--text); }
.container { max-width:1100px; margin:20px auto; padding:20px; }
.header { display:flex; justify-content:space-between; align-items:center; gap:12px; }
.button { background:var(--accent); color:#071017; border:none; padding:8px 12px; border-radius:8px; cursor:pointer; }
.card { background:var(--card); border:1px solid #15202b; border-radius:10px; padding:16px; margin-bottom:16px; }
'@ | Set-Content -Path (Join-Path $frontend "src/index.css") -Encoding UTF8

# src/App.tsx
@'
import React from "react";
import WalletSection from "./components/WalletSection";
import CryptoDashboard from "./components/CryptoDashboard";
import TestnetTradeArea from "./components/TestnetTradeArea";
import AIAssistant from "./components/AIAssistant";
import AuthPage from "./pages/AuthPage";

export default function App() {
  return (
    <div className="container">
      <div className="header">
        <h1 style={{ color: "#00ff88" }}>CBL Trade Learning (Local Test)</h1>
        <WalletSection />
      </div>

      <AuthPage />

      <CryptoDashboard />

      <TestnetTradeArea />

      <AIAssistant />
    </div>
  );
}
'@ | Set-Content -Path (Join-Path $frontend "src/App.tsx") -Encoding UTF8

# components folder
New-Item -ItemType Directory -Force -Path (Join-Path $frontend "src/components") | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $frontend "src/pages") | Out-Null

# WalletSection.tsx (basic, connect only)
@'
import React, { useState } from "react";
import Web3Modal from "web3modal";
import { ethers } from "ethers";

export default function WalletSection() {
  const [account, setAccount] = useState<string | null>(null);
  async function connect() {
    try {
      const modal = new Web3Modal({ cacheProvider: true });
      const provider = await modal.connect();
      const ethersProvider = new ethers.BrowserProvider(provider);
      const signer = await ethersProvider.getSigner();
      const addr = await signer.getAddress();
      setAccount(addr);
    } catch (e) {
      alert("Wallet connect failed");
    }
  }
  return (
    <div>
      {account ? <div style={{ fontSize:12 }}>Connected: {account.slice(0,6)}...{account.slice(-4)}</div> : <button className="button" onClick={connect}>Connect Wallet</button>}
    </div>
  );
}
'@ | Set-Content -Path (Join-Path $frontend "src/components/WalletSection.tsx") -Encoding UTF8

# CryptoDashboard.tsx (CoinGecko + SMA indicator)
@'
import React, { useEffect, useState } from "react";
import axios from "axios";
import { Line } from "react-chartjs-2";
import { Chart as ChartJS, LineElement, CategoryScale, LinearScale, PointElement, Tooltip, Legend } from "chart.js";
ChartJS.register(LineElement, CategoryScale, LinearScale, PointElement, Tooltip, Legend);

type Coin = { id:string; name:string; image:string; current_price:number; price_change_percentage_24h?:number };

function movingAverage(data:number[], period:number) {
  const out:number[] = [];
  for (let i=0;i<data.length;i++) {
    if (i < period-1) out.push(NaN);
    else {
      const slice = data.slice(i-period+1, i+1);
      const sum = slice.reduce((a,b)=>a+b,0);
      out.push(sum/period);
    }
  }
  return out;
}

export default function CryptoDashboard() {
  const [coins,setCoins] = useState<Coin[]>([]);
  const [selected,setSelected] = useState<string>("bitcoin");
  const [chartData,setChartData] = useState<any | null>(null);
  const [smaOn,setSmaOn] = useState(true);

  useEffect(()=> {
    axios.get("https://api.coingecko.com/api/v3/coins/markets", { params: { vs_currency: "usd", per_page: 8, order: "market_cap_desc" }})
      .then(r=> { setCoins(r.data); if (r.data && r.data.length) setSelected(r.data[0].id); })
      .catch(console.error);
  }, []);

  useEffect(()=> {
    if (!selected) return;
    setChartData(null);
    axios.get(`https://api.coingecko.com/api/v3/coins/${selected}/market_chart`, { params: { vs_currency:"usd", days:7 }})
      .then(r=> {
        const prices = r.data.prices || [];
        const xs = prices.map((p:any)=> new Date(p[0]).toLocaleString());
        const ys = prices.map((p:any)=> p[1]);
        const sma = movingAverage(ys, 9);
        const datasets:any[] = [{
          label: selected + " price (USD)",
          data: ys,
          borderColor: "rgba(0,255,136,1)",
          fill: false,
          tension:0.2,
          pointRadius:0
        }];

        if (smaOn) datasets.push({ label: "SMA(9)", data: sma, borderColor: "rgba(255,215,0,0.9)", fill:false, pointRadius:0 });

        setChartData({ labels: xs, datasets });
      }).catch(console.error);
  }, [selected, smaOn]);

  return (
    <div className="card">
      <h2>Live Market (CoinGecko)</h2>
      <div style={{ display:"flex", gap:12, overflowX:"auto", paddingBottom:8 }}>
        {coins.map(c=>(
          <div key={c.id} style={{ minWidth:160, cursor:"pointer", border: selected===c.id ? "2px solid #00ff88":"1px solid #24303a", padding:10, borderRadius:8 }} onClick={()=>setSelected(c.id)}>
            <img src={c.image} width={36} alt={c.name} />
            <div style={{ marginTop:6 }}><strong>{c.name}</strong><div>${c.current_price.toLocaleString()}</div><div style={{ color: (c.price_change_percentage_24h ?? 0) > 0 ? "#00ff88":"#ff6b6b" }}>{(c.price_change_percentage_24h ?? 0).toFixed(2)}%</div></div>
          </div>
        ))}
      </div>

      <div style={{ marginTop:16 }}>
        <label style={{ marginRight:12 }}><input type="checkbox" checked={smaOn} onChange={e=>setSmaOn(e.target.checked)} /> Show SMA(9)</label>
        { chartData ? <Line data={chartData} options={{ responsive:true, plugins:{ legend:{ labels:{ color:"#e6eef6" } } }, scales:{ x:{ ticks:{ color:'#a8b3bf' } }, y:{ ticks:{ color:'#a8b3bf' } } } }} /> : <p>Loading chart...</p> }
      </div>
    </div>
  );
}
'@ | Set-Content -Path (Join-Path $frontend "src/components/CryptoDashboard.tsx") -Encoding UTF8

# TestnetTradeArea.tsx (connects to the backend orders)
@'
import React, { useEffect, useState } from "react";
import axios from "axios";

export default function TestnetTradeArea() {
  const [tokens, setTokens] = useState<any[]>([]);
  const [tokenId, setTokenId] = useState("CBL");
  const [amount, setAmount] = useState<number>(1);
  const [msg, setMsg] = useState("");

  useEffect(()=> {
    axios.get("/api/tokens").then(r=> setTokens(r.data)).catch(()=> setTokens([{ id:"CBL", name:"CBL Test Token", price_usd:0.5 }]));
  }, []);

  async function place(type:"buy" | "sell") {
    try {
      const token = localStorage.getItem("cbl_token");
      if (!token) { setMsg("Please signup/login first"); return; }
      const r = await axios.post("/api/orders", { type, tokenId, amount }, { headers: { Authorization: "Bearer " + token }});
      setMsg("Order success: " + JSON.stringify(r.data.order || r.data));
    } catch (e:any) {
      setMsg(e.response?.data?.error || e.message);
    }
  }

  return (
    <div className="card">
      <h2>Testnet Trading Area (Simulated)</h2>
      <div style={{ display:"flex", gap:8, alignItems:"center" }}>
        <select value={tokenId} onChange={e=>setTokenId(e.target.value)}>{tokens.map(t=><option key={t.id} value={t.id}>{t.name}</option>)}</select>
        <input type="number" value={amount} onChange={e=>setAmount(Number(e.target.value))} style={{ padding:8 }} />
        <button className="button" onClick={()=>place("buy")}>Buy</button>
        <button style={{ background:"#ff6b6b", padding:"8px 12px", borderRadius:8, border:"none" }} onClick={()=>place("sell")}>Sell</button>
      </div>
      <div style={{ marginTop:12 }}>{msg}</div>
    </div>
  );
}
'@ | Set-Content -Path (Join-Path $frontend "src/components/TestnetTradeArea.tsx") -Encoding UTF8

# AIAssistant.tsx (UI calling backend /api/chat)
@'
import React, { useState } from "react";
import axios from "axios";

type Msg = { sender: "user"|"bot", text:string };

export default function AIAssistant() {
  const [messages, setMessages] = useState<Msg[]>([{ sender:"bot", text:"Hi! I am CBL AI assistant." }]);
  const [input, setInput] = useState("");

  async function send() {
    if (!input.trim()) return;
    setMessages(m=>[...m, { sender:"user", text: input }]);
    const text = input;
    setInput("");
    try {
      const r = await axios.post("/api/chat", { message: text });
      setMessages(m=>[...m, { sender:"bot", text: r.data.reply || "No reply" }]);
    } catch (e) {
      setMessages(m=>[...m, { sender:"bot", text: "AI error" }]);
    }
  }

  return (
    <div style={{ position:"fixed", bottom:20, right:20, width:360, background:"#0d1117", color:"#fff", borderRadius:10, padding:12, boxShadow:"0 0 20px rgba(0,0,0,0.6)" }}>
      <h4 style={{ margin:0, marginBottom:8 }}>CBL AI Assistant</h4>
      <div style={{ height:260, overflowY:"auto", background:"#071017", padding:8, borderRadius:6, marginBottom:8 }}>
        {messages.map((m,i)=>(
          <div key={i} style={{ textAlign: m.sender==="user" ? "right":"left", margin:"6px 0" }}>
            <span style={{ display:"inline-block", padding:"8px 10px", borderRadius:8, background: m.sender==="user" ? "#00ff88":"#30363d", color: m.sender==="user" ? "#071017":"#fff", maxWidth:"80%" }}>{m.text}</span>
          </div>
        ))}
      </div>
      <div style={{ display:"flex", gap:6 }}>
        <input value={input} onChange={e=>setInput(e.target.value)} placeholder="Ask about crypto..." style={{ flex:1, padding:8, borderRadius:6, border:"none", outline:"none" }} />
        <button className="button" onClick={send}>Ask</button>
      </div>
    </div>
  );
}
'@ | Set-Content -Path (Join-Path $frontend "src/components/AIAssistant.tsx") -Encoding UTF8

# AuthPage.tsx
@'
import React, { useEffect, useState } from "react";
import axios from "axios";

export default function AuthPage() {
  const [username,setUsername] = useState("");
  const [password,setPassword] = useState("");
  const [msg,setMsg] = useState("");

  useEffect(()=> {
    const tk = localStorage.getItem("cbl_token");
    if (tk) { axios.defaults.headers.common["Authorization"] = "Bearer " + tk; }
  }, []);

  async function signup() {
    try {
      const r = await axios.post("/api/signup", { username, password });
      localStorage.setItem("cbl_token", r.data.token);
      setMsg("Signed up");
    } catch (e:any) { setMsg(e.response?.data?.error || e.message); }
  }
  async function login() {
    try {
      const r = await axios.post("/api/login", { username, password });
      localStorage.setItem("cbl_token", r.data.token);
      setMsg("Logged in");
    } catch (e:any) { setMsg(e.response?.data?.error || e.message); }
  }
  function logout() { localStorage.removeItem("cbl_token"); setMsg("Logged out"); }

  return (
    <div className="card">
      <h3>Auth</h3>
      <div style={{ display:"flex", gap:8, flexWrap:"wrap", alignItems:"center" }}>
        <input placeholder="username" value={username} onChange={e=>setUsername(e.target.value)} style={{ padding:8 }} />
        <input placeholder="password" type="password" value={password} onChange={e=>setPassword(e.target.value)} style={{ padding:8 }} />
        <button className="button" onClick={signup}>Sign up</button>
        <button className="button" onClick={login}>Log in</button>
        <button onClick={logout} style={{ padding:"8px 12px" }}>Log out</button>
      </div>
      <div style={{ marginTop:8 }}>{msg}</div>
    </div>
  );
}
'@ | Set-Content -Path (Join-Path $frontend "src/pages/AuthPage.tsx") -Encoding UTF8

# Update package.json proxy to backend
$pkg = Get-Content package.json -Raw | ConvertFrom-Json
$pkg.proxy = "http://localhost:4000"
$pkg | ConvertTo-Json -Depth 10 | Set-Content package.json -Encoding UTF8

Write-Host "Frontend created at: $frontend"
Write-Host "Run these in two terminals:"
Write-Host "1) Backend: cd `"$HOME\Desktop\cbl-trade-learning-sepolia\backend`"; npx nodemon server.js"
Write-Host "2) Frontend: cd `"$frontend`"; npm run dev"

