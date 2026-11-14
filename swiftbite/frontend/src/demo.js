// Preview-only fake backend so the hosted page works without the microservices.
const RS = [
 { id: 1, name: "Mama Put Kitchen", cuisine: "African food", area: "Surulere", rating: 4.6, eta: "25-35 min" },
 { id: 2, name: "Pasta Palace", cuisine: "Pasta", area: "Yaba", rating: 4.4, eta: "30-40 min" },
 { id: 3, name: "Grill House", cuisine: "Fast food", area: "Ikeja", rating: 4.2, eta: "20-30 min" },
 { id: 4, name: "Green Bowl", cuisine: "Salad", area: "Lekki", rating: 4.5, eta: "25-35 min" },
 { id: 5, name: "Sweet Crumbs", cuisine: "Pastries", area: "Ogudu", rating: 4.3, eta: "20-30 min" },
 { id: 6, name: "Wok This Way", cuisine: "Asian food", area: "Yaba", rating: 4.1, eta: "30-45 min" }];
const M = { 1: [["Jollof rice and chicken", 3500], ["Pounded yam and egusi", 4200], ["Chapman", 1500]],
 2: [["Spaghetti bolognese", 4000], ["Creamy chicken penne", 4500], ["Garlic bread", 1200]],
 3: [["Double beef burger", 5000], ["Peppered chicken wings", 3800], ["Fries", 1500]],
 4: [["Caesar salad", 3800], ["Chicken avocado bowl", 4800], ["Fresh smoothie", 2000]],
 5: [["Meat pie", 1000], ["Chin chin pack", 1500], ["Cream doughnut", 900]],
 6: [["Chicken fried rice", 4200], ["Beef noodles", 3900], ["Spring rolls", 2000]] };
const MENU = Object.fromEntries(Object.entries(M).map(([r, it]) => [r, it.map(([name, price], i) => ({ id: r * 10 + i + 1, restaurant_id: +r, name, price }))]));
const ORDERS = [], REVIEWS = []; let next = 1000;
const setStatus = (id, status) => { const o = ORDERS.find(x => x.id === id); if (!o) throw new Error("404"); o.status = status; return o; };
export async function demo(path, method = "GET", body = {}) {
  const [p, qs = ""] = path.split("?"); const [root, a, b] = p.split("/").filter(Boolean); const id = Number(a); const q = new URLSearchParams(qs);
  if (root === "auth") return body.email === "promise@example.com" && body.password === "1234" ? { token: "demo-token", user_id: 1, role: body.role, email: body.email } : { detail: "Invalid login. Try promise@example.com and 1234." };
  if (root === "restaurants") return RS;
  if (root === "search") { const s = (q.get("q") || "").toLowerCase(); return { results: RS.filter(r => [r.name, r.cuisine, r.area].some(x => x.toLowerCase().includes(s)) || MENU[r.id].some(i => i.name.toLowerCase().includes(s))) }; }
  if (root === "menu") return MENU[id] || [];
  if (root === "cart") return {};
  if (root === "payment") return { status: "success", reference: "PSK_DEMO" };
  if (root === "order") {
    if (method === "POST") { const items = body.items || []; const o = { id: ++next, order_id: next, ...body, items_summary: items.map(i => `${i.qty} × ${i.name}`).join(", "), status: "PLACED" }; ORDERS.unshift(o); return o; }
    if (b === "status") return setStatus(id, body.status);
    return a ? ORDERS.find(o => o.id === id) : ORDERS;
  }
  if (root === "delivery") return method === "PUT" ? setStatus(id, body.status) : ORDERS.filter(o => o.status !== "PLACED");
  if (root === "reviews") {
    if (method === "POST") { REVIEWS.push({ id: REVIEWS.length + 1, ...body }); return REVIEWS.at(-1); }
    const rows = REVIEWS.filter(r => r.target_id === Number(b));
    return { average: rows.length ? +(rows.reduce((s, r) => s + r.rating, 0) / rows.length).toFixed(1) : null, count: rows.length, reviews: rows };
  }
  throw new Error("no demo route");
}
