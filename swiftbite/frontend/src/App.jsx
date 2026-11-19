import { useEffect, useState } from "react";
import { api, session, naira, SAMPLE_RESTAURANTS, SAMPLE_MENU } from "./api.js";

// Food photos by cuisine - Unsplash free images, no upload needed
const FOOD_IMG = {
  "African food": "https://images.unsplash.com/photo-1547592180-85f173990554?w=800&q=80&auto=format&fit=crop",
  "Pasta": "https://images.unsplash.com/photo-1621996346565-e3dbc646d9a9?w=800&q=80&auto=format&fit=crop",
  "Fast food": "https://images.unsplash.com/photo-1568901346375-23c9450c58cd?w=800&q=80&auto=format&fit=crop",
  "Salad": "https://images.unsplash.com/photo-1512621776951-a57141f2eefd?w=800&q=80&auto=format&fit=crop",
  "Pastries": "https://images.unsplash.com/photo-1509440159596-0249088772ff?w=800&q=80&auto=format&fit=crop",
  "Asian food": "https://images.unsplash.com/photo-1585032226651-759b368d7246?w=800&q=80&auto=format&fit=crop",
};
const foodImg = (r) => FOOD_IMG[r.cuisine] || FOOD_IMG["African food"];


const useHash = () => {
  const [h, setH] = useState(location.hash.slice(1));
  useEffect(() => { const f = () => setH(location.hash.slice(1)); addEventListener("hashchange", f); return () => removeEventListener("hashchange", f); }, []);
  return h;
};
const go = p => (location.hash = p);

function Logo({ dark }) { return <a href="#" className={"logo" + (dark ? " dark" : "")}>SwiftBite</a>; }

function Nav({ user, count, onLogout }) {
  return (
    <header className="nav">
      <Logo />
      <nav className="pill">
        <a href="#restaurants">Restaurants</a><a href="#vendor">Vendors</a><a href="#rider">Riders</a><a href="#orders">Orders</a>
      </nav>
      <div className="navr">
        {user ? <button className="pill btn" onClick={onLogout}>Log out</button> : <a className="pill btn" href="#login">Log in</a>}
        <a className="pill btn cartbtn" href="#cart" aria-label="Cart">Cart{count > 0 && <b>{count}</b>}</a>
      </div>
    </header>
  );
}

const Skyline = () => (
  <svg className="skyline" viewBox="0 0 1200 300" preserveAspectRatio="xMidYMax slice" aria-hidden="true">
    <rect x="30" y="80" width="210" height="220" fill="#FFB938" /><rect x="90" y="40" width="100" height="40" fill="#FF8A4C" />
    {[110, 140, 170, 200, 230].map(y => <rect key={y} x="30" y={y} width="210" height="8" fill="#000" />)}
    <path d="M280 300 Q520 150 800 190 L800 300Z" fill="#000" /><path d="M280 300 Q520 150 800 190" stroke="#00C37A" strokeWidth="12" fill="none" />
    {[360, 440, 520, 600, 680].map(x => <line key={x} x1={x} y1="300" x2={x + 30} y2="170" stroke="#FFF7E3" strokeWidth="8" />)}
    <rect x="860" y="110" width="150" height="190" fill="#4F9FE6" /><rect x="1010" y="120" width="40" height="180" fill="#000" />
    <path d="M925 110 L935 20 L945 110Z" fill="#4F9FE6" /><rect x="860" y="100" width="190" height="12" fill="#FFC700" />
    <rect x="1050" y="240" width="150" height="60" fill="#1F7A5C" />
  </svg>
);

function Landing() {
  const [addr, setAddr] = useState("");
  const chips = ["Hot meals", "Fresh market picks", "Pharmacy runs", "Quick-grab groceries", "Live order updates", "Rated riders", "24/7 support"];
  const faqs = [
    ["How fast is delivery?", "Most orders arrive in 25 to 40 minutes, depending on distance and how busy the kitchen is."],
    ["How do I pay?", "Pay by card or bank transfer at checkout. Payment is confirmed before the restaurant starts cooking."],
    ["Can I track my order?", "Yes. You see each step, from accepted to picked up to delivered."],
    ["How do I sell on SwiftBite?", "Open the Vendors page, create a restaurant account, and add your menu."],
  ];
  return (<>
    <section className="hero">
      <div className="cloud c1" /><div className="cloud c2" />
      <h1>Hungry?<br />We’re on it.</h1>
      <form className="addr" onSubmit={e => { e.preventDefault(); go("restaurants"); }}>
        <span className="dot" /><input value={addr} onChange={e => setAddr(e.target.value)} placeholder="Enter a delivery address" aria-label="Delivery address" />
        <button className="go">Order now</button>
      </form>
      <Skyline />
    </section>

    <section className="wrap tall">
      {[["Restaurants", "#DAD3F7"], ["Shops", "#FFEBB0"], ["Pharmacies", "#9CC8FF"], ["Markets", "#C6F0E1"]].map(([t, c], i) => (
        <a key={t} href="#restaurants" className={"tallcard" + (i === 1 ? " open" : "")} style={{ background: c }}>
          <span className="vert">{t}</span>
          {i === 1 && <p><b>Shops</b>Groceries, household items and daily essentials from stores nearby.</p>}
        </a>))}
    </section>

    <section className="wrap">
      <h2 className="muted">Join our growing network ↓</h2>
      <div className="trio">
        {[["Start selling", "Own a restaurant, store or pharmacy? Reach new customers and grow without the stress.", "#FFC700", "vendor"],
          ["Deliver happiness", "Ride with SwiftBite, pick your hours and earn on every drop.", "#08875D", "rider"],
          ["Behind the scenes", "Love food and fast software? Come build SwiftBite with us.", "#FFB3D1", "#"]].map(([t, d, c, l]) => (
          <article className="card" key={t}><div className="pad"><h3>{t}</h3><p>{d}</p><a href={l.startsWith("#") ? l : "#" + l} className="more">See more →</a></div>
            <div className="art" style={{ background: c }}><i /><i /></div></article>))}
      </div>
    </section>

    <section className="wrap"><div className="orange">
      <h2>Place your order</h2><p>Download SwiftBite and get ₦300 off your first order with code <b>SWIFT300</b>.</p>
      <div className="stores"><a className="darkbtn" href="#">Download on Google Play</a><a className="darkbtn" href="#">Download on App Store</a></div>
    </div></section>

    <section className="green">
      <div className="wrap"><h2>SwiftBite has<br />you covered</h2>
        <p>A quick fix on a busy day, last-minute dinner, supplies for the week. Open the app and it’s at your door in minutes.</p></div>
      <div className="marquee"><div>{[...chips, ...chips].map((c, i) => <span key={i}>{c}</span>)}</div></div>
    </section>

    <section className="wrap"><h2>Stories</h2>
      <div className="trio">
        {[["Friday deals are back", "Weekly vouchers and price drops on your favourite spots, every Friday this month.", "#000", "#FFC700"],
          ["SwiftBite arrives in Ibadan", "Kitchens across Ibadan are now live. Order jollof, suya and more.", "#0D4F3C", "#FFF7E3"],
          ["Meet our top riders", "The people who bring your food hot and on time.", "#14357A", "#FFB3D1"]].map(([t, d, bg, fg]) => (
          <article className="card story" key={t}><div className="art short" style={{ background: bg, color: fg }}>{t}</div>
            <div className="pad"><p>{d}</p><a className="readmore" href="#">Read more</a></div></article>))}
      </div>
    </section>

    <section className="wrap"><div className="faq">
      <h2>FAQs.</h2>
      <div>{faqs.map(([q, a]) => <details key={q}><summary>{q}</summary><p>{a}</p></details>)}</div>
    </div></section>
  </>);
}

function Footer() {
  const col = (t, items) => <div><h4>{t}</h4>{items.map(i => <a key={i} href="#">{i}</a>)}</div>;
  return (
    <footer className="foot"><div className="wrap">
      <div className="news"><h2>✦ Good stuff only <small>Subscribe to our newsletter</small></h2>
        <form onSubmit={e => e.preventDefault()}><input placeholder="yourname@email.com" aria-label="Email" /><button aria-label="Subscribe">→</button></form></div>
      <div className="cols">
        <div><Logo dark /><p>SwiftBite Foods Ltd.<br />12 Bode Thomas Street,<br />Surulere, Lagos<br />hello@swiftbite.example</p></div>
        {col("Company", ["Customers", "Vendors", "Riders", "Ads", "Storefront", "About", "Careers", "FAQs"])}
        {col("Cuisines near you", ["Pasta near me", "Rice near me", "Fast food near me", "African food in Lagos", "Breakfast in Lagos", "Pastries in Lagos", "Salad in Lagos"])}
        {col("Popular", ["Food delivery", "Surulere", "Ogudu", "Yaba", "Ikeja", "Lekki"])}
      </div>
      <div className="social">{["Twitter", "Instagram", "Facebook", "LinkedIn"].map(s => <a key={s} href="#">{s}</a>)}<span>© 2026 SwiftBite Foods Ltd.</span></div>
    </div></footer>
  );
}

function Login({ onLogin }) {
  const [f, setF] = useState({ email: "promise@example.com", password: "1234", role: "user" });
  const [err, setErr] = useState("");
  const submit = async e => {
    e.preventDefault();
    const r = await api("/auth/login", { method: "POST", body: f, fallback: { detail: "Cannot reach the server. Try again." } });
    if (r.token) { onLogin(r); go(r.role === "restaurant" ? "vendor" : r.role === "rider" ? "rider" : "restaurants"); }
    else setErr(r.detail || "Login failed. Check your email and password.");
  };
  return (<section className="wrap narrow"><h2>Log in</h2>
    <form className="box" onSubmit={submit}>
      <label>Email<input value={f.email} onChange={e => setF({ ...f, email: e.target.value })} /></label>
      <label>Password<input type="password" value={f.password} onChange={e => setF({ ...f, password: e.target.value })} /></label>
      <label>I am a<select value={f.role} onChange={e => setF({ ...f, role: e.target.value })}><option value="user">Customer</option><option value="restaurant">Restaurant</option><option value="rider">Rider</option></select></label>
      {err && <p className="err" role="alert">{err}</p>}<button className="go">Log in</button>
    </form></section>);
}

function Restaurants() {
  const [q, setQ] = useState(""); const [list, setList] = useState(SAMPLE_RESTAURANTS);
  useEffect(() => { api(q ? `/search?q=${encodeURIComponent(q)}` : "/restaurants", { fallback: SAMPLE_RESTAURANTS }).then(r => setList(Array.isArray(r) ? r : r.restaurants || r.results || SAMPLE_RESTAURANTS)); }, [q]);
  return (<section className="wrap"><h2>Restaurants near you</h2>
    <input className="search" placeholder="Search restaurants or food" value={q} onChange={e => setQ(e.target.value)} aria-label="Search" />
    <div className="trio">{list.map(r => (
      <a key={r.id} href={"#restaurant-" + r.id} className="card"><div className="art short" style={{ padding: 0 }}><img className="card-img" src={foodImg(r)} alt={r.name} loading="lazy" onError={(e) => { e.target.style.display = "none"; }} /></div>
        <div className="pad"><h3>{r.name}</h3><p>{r.cuisine} · {r.area}</p><p>★ {r.rating ?? "New"} · {r.eta ?? "30 min"}</p></div></a>))}</div></section>);
}

function Menu({ id, add }) {
  const [menu, setMenu] = useState(SAMPLE_MENU); const [rev, setRev] = useState(null);
  const [rate, setRate] = useState(5); const [txt, setTxt] = useState("");
  const load = () => api(`/reviews/restaurant/${id}`, { fallback: null }).then(setRev);
  useEffect(() => { api(`/menu/${id}`, { fallback: SAMPLE_MENU }).then(r => setMenu(Array.isArray(r) ? r : r.items || r.menu || SAMPLE_MENU)); load(); }, [id]);
  const post = async e => { e.preventDefault(); await api("/reviews", { method: "POST", body: { target_type: "restaurant", target_id: +id, rating: +rate, comment: txt }, fallback: null }); setTxt(""); load(); };
  return (<section className="wrap"><h2>Menu {rev?.average && <small>★ {rev.average} ({rev.count})</small>}</h2>
    <div className="list">{menu.map(m => <div className="row" key={m.id}><span>{m.name}</span><b>{naira(m.price)}</b><button className="go sm" onClick={() => add(+id, m)}>Add</button></div>)}</div>
    <h3>Rate this restaurant</h3>
    <form className="box" onSubmit={post}><label>Rating<select value={rate} onChange={e => setRate(e.target.value)}>{[5, 4, 3, 2, 1].map(n => <option key={n}>{n}</option>)}</select></label>
      <label>Comment<input value={txt} onChange={e => setTxt(e.target.value)} /></label><button className="go sm">Send review</button></form>
    {rev?.reviews?.map(r => <p key={r.id}>★ {r.rating} {r.comment}</p>)}</section>);
}

function Cart({ cart, setQty, user, onOrdered }) {
  const [msg, setMsg] = useState("");
  const total = cart.items.reduce((s, i) => s + i.price * i.qty, 0);
  const checkout = async () => {
    if (!user) return go("login");
    const body = { user_id: user.user_id, restaurant_id: cart.restaurant_id, items: cart.items, total };
    const o = await api("/order", { method: "POST", body, fallback: { order_id: Date.now() % 100000, status: "PLACED" } });
    const oid = o.order_id ?? o.id;
    await api("/payment", { method: "POST", body: { order_id: oid, amount: total, provider: "paystack" }, fallback: null });
    await api(`/cart/${user.user_id}`, { method: "DELETE", fallback: null });
    onOrdered({ id: oid, total, status: o.status || "PLACED" }); go("orders");
  };
  if (!cart.items.length) return <section className="wrap narrow"><h2>Your cart is empty</h2><p>Pick a restaurant and add something tasty.</p><a className="go" href="#restaurants">Browse restaurants</a></section>;
  return (<section className="wrap narrow"><h2>Your cart</h2>
    <div className="list">{cart.items.map(i => <div className="row" key={i.id}><span>{i.name}</span>
      <span className="qty"><button onClick={() => setQty(i.id, i.qty - 1)} aria-label="Less">−</button>{i.qty}<button onClick={() => setQty(i.id, i.qty + 1)} aria-label="More">+</button></span><b>{naira(i.price * i.qty)}</b></div>)}</div>
    <p className="total">Total <b>{naira(total)}</b></p>{msg && <p className="err">{msg}</p>}
    <button className="go" onClick={checkout}>Pay and place order</button></section>);
}

const STEPS = ["PLACED", "ACCEPTED", "PICKED_UP", "DELIVERED"];
function Orders({ orders }) {
  const [live, setLive] = useState({});
  useEffect(() => {
    const t = setInterval(() => orders.forEach(o => api(`/order/${o.id}`, { fallback: null }).then(r => r && setLive(l => ({ ...l, [o.id]: r.status })))), 5000);
    return () => clearInterval(t);
  }, [orders]);
  if (!orders.length) return <section className="wrap narrow"><h2>No orders yet</h2><a className="go" href="#restaurants">Order something</a></section>;
  return (<section className="wrap narrow"><h2>Your orders</h2>{orders.map(o => {
    const st = live[o.id] || o.status; const at = Math.max(0, STEPS.indexOf(st));
    return (<div className="box" key={o.id}><b>Order #{o.id}</b> · {naira(o.total)}
      <ol className="steps">{STEPS.map((s, i) => <li key={s} className={i <= at ? "on" : ""}>{s.replace("_", " ").toLowerCase()}</li>)}</ol></div>);
  })}</section>);
}

function Board({ role }) {
  const rider = role === "rider", base = rider ? "/delivery" : "/order";
  const [rows, setRows] = useState([]);
  const load = () => api(base, { fallback: [] }).then(r => setRows(Array.isArray(r) ? r : []));
  useEffect(() => { load(); const t = setInterval(load, 5000); return () => clearInterval(t); }, [role]);
  const flow = rider ? { ACCEPTED: ["PICKED_UP", "Pick up"], PICKED_UP: ["DELIVERED", "Mark delivered"] } : { PLACED: ["ACCEPTED", "Accept"] };
  const act = async (o, st) => { await api(`${base}/${o.id}/status`, { method: "PUT", body: { status: st }, fallback: null }); load(); };
  return (<section className="wrap narrow"><h2>{rider ? "Rider dashboard" : "Restaurant dashboard"}</h2>
    {!rows.length && <p>No orders waiting. New orders show up here automatically.</p>}
    <div className="list">{rows.map(o => <div className="row" key={o.id}><span>#{o.id} {o.items_summary}</span><em>{o.status}</em>
      {flow[o.status] && <button className="go sm" onClick={() => act(o, flow[o.status][0])}>{flow[o.status][1]}</button>}</div>)}</div></section>);
}

export default function App() {
  const route = useHash();
  const [user, setUser] = useState(session.get());
  const [cart, setCart] = useState({ restaurant_id: null, items: [] });
  const [orders, setOrders] = useState([]);
  const uid = user?.user_id ?? 1;
  const add = (rid, m) => {
    setCart(c => { const items = c.restaurant_id === rid ? c.items : []; const hit = items.find(i => i.id === m.id);
      return { restaurant_id: rid, items: hit ? items.map(i => i.id === m.id ? { ...i, qty: i.qty + 1 } : i) : [...items, { id: m.id, name: m.name, price: m.price, qty: 1 }] }; });
    api("/cart/add", { method: "POST", body: { user_id: uid, restaurant_id: rid, item_id: m.id, name: m.name, price: m.price }, fallback: null });
  };
  const setQty = (id, qty) => {
    setCart(c => ({ ...c, items: qty <= 0 ? c.items.filter(i => i.id !== id) : c.items.map(i => i.id === id ? { ...i, qty } : i) }));
    api(`/cart/${uid}/item/${id}`, { method: "PUT", body: { qty }, fallback: null });
  };
  const [p, id] = route.split("-");
  let page = <Landing />;
  if (p === "login") page = <Login onLogin={s => { session.set(s); setUser(s); }} />;
  if (p === "restaurants") page = <Restaurants />;
  if (p === "restaurant") page = <Menu id={id} add={add} />;
  if (p === "cart") page = <Cart cart={cart} setQty={setQty} user={user} onOrdered={o => { setOrders(x => [o, ...x]); setCart({ restaurant_id: null, items: [] }); }} />;
  if (p === "orders") page = <Orders orders={orders} />;
  if (p === "vendor") page = <Board role="restaurant" />;
  if (p === "rider") page = <Board role="rider" />;
  return (<>{import.meta.env.VITE_DEMO === "1" && <div className="demo">Preview mode: sample data, nothing is sent to a server. Log in with promise@example.com / 1234.</div>}<Nav user={user} count={cart.items.reduce((s, i) => s + i.qty, 0)} onLogout={() => { session.clear(); setUser(null); go(""); }} /><main>{page}</main><Footer /></>);
}
