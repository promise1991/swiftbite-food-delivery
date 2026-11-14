import { demo } from "./demo.js";
// All calls go to /api (nginx or vite proxies it to the api-gateway).
const ls = { get: k => { try { return localStorage.getItem(k); } catch { return null; } }, set: (k, v) => { try { localStorage.setItem(k, v); } catch {} }, del: k => { try { localStorage.removeItem(k); } catch {} } };
export const session = {
  get: () => JSON.parse(ls.get("sb_session") || "null"),
  set: s => ls.set("sb_session", JSON.stringify(s)),
  clear: () => ls.del("sb_session"),
};
export async function api(path, { method = "GET", body, fallback } = {}) {
  if (import.meta.env.VITE_DEMO === "1") {
    try { return await demo(path, method, body); } catch (e) { if (fallback !== undefined) return fallback; throw e; }
  }
  try {
    const s = session.get();
    const r = await fetch("/api" + path, {
      method, body: body ? JSON.stringify(body) : undefined,
      headers: { "Content-Type": "application/json", ...(s ? { Authorization: "Bearer " + s.token } : {}) },
    });
    if (!r.ok) throw new Error(r.status);
    return await r.json();
  } catch (e) {
    if (fallback !== undefined) return fallback;  // keeps the UI demo-able if a backend is down
    throw e;
  }
}
export const naira = n => "₦" + Number(n).toLocaleString();
export const SAMPLE_RESTAURANTS = [
  { id: 1, name: "Mama Put Kitchen", cuisine: "African food", area: "Surulere", rating: 4.6, eta: "25-35 min" },
  { id: 2, name: "Pasta Palace", cuisine: "Pasta", area: "Yaba", rating: 4.4, eta: "30-40 min" },
  { id: 3, name: "Grill House", cuisine: "Fast food", area: "Ikeja", rating: 4.2, eta: "20-30 min" },
];
export const SAMPLE_MENU = [
  { id: 11, name: "Jollof rice and chicken", price: 3500 },
  { id: 12, name: "Pounded yam and egusi", price: 4200 },
  { id: 13, name: "Chapman", price: 1500 },
];
