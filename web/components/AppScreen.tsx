"use client";

import type { ReactNode } from "react";

type Variant = "today" | "food" | "meals" | "activity" | "recovery" | "coach";

const ink = "#292B28";
const ink2 = "#5D5F5C";
const ink3 = "#747673";
const card = "#FFFDFB";
const line = "rgba(92, 87, 79, 0.12)";
const sage = "#72AD8A";
const peach = "#EAA06B";
const lavender = "#9B8ACB";
const teal = "#35ADD0";

function Ring({
  pct,
  color,
  label,
  value,
  note,
}: {
  pct: number;
  color: string;
  label: string;
  value: string;
  note: string;
}) {
  const r = 16;
  const c = 2 * Math.PI * r;
  const shown = Math.min(pct, 100);
  return (
    <div style={{ display: "flex", flexDirection: "column", alignItems: "center", gap: "0.35em", minWidth: 0 }}>
      <svg viewBox="0 0 40 40" style={{ width: "5.15em", height: "5.15em" }} aria-hidden>
        <circle cx="20" cy="20" r={r} fill="none" stroke="#E7E4DE" strokeWidth="3.2" />
        <circle
          cx="20"
          cy="20"
          r={r}
          fill="none"
          stroke={color}
          strokeWidth="3.2"
          strokeLinecap="round"
          strokeDasharray={`${(shown / 100) * c} ${c}`}
          transform="rotate(-90 20 20)"
        />
        <text x="20" y="21.5" textAnchor="middle" fill={ink} fontSize="8.2" fontWeight="650">
          {pct}%
        </text>
      </svg>
      <div style={{ textAlign: "center" }}>
        <div style={{ fontSize: "0.78em", fontWeight: 650, color }}>{label}</div>
        <div style={{ fontSize: "0.72em", color: ink2, marginTop: "0.1em" }}>{value}</div>
        <div style={{ fontSize: "0.66em", color: ink3 }}>{note}</div>
      </div>
    </div>
  );
}

function Card({ children }: { children: ReactNode }) {
  return (
    <div
      style={{
        background: card,
        border: `1px solid ${line}`,
        borderRadius: "1.15em",
        padding: "0.85em 0.9em",
        boxShadow: "0 8px 18px -14px rgba(40, 32, 24, 0.35)",
      }}
    >
      {children}
    </div>
  );
}

function Kicker({ children }: { children: ReactNode }) {
  return (
    <div style={{ fontSize: "0.62em", letterSpacing: "0.14em", fontWeight: 650, color: ink3, textTransform: "uppercase" }}>
      {children}
    </div>
  );
}

function Tabs({ active }: { active: string }) {
  const items = ["Today", "Coach", "Meals", "Plan"];
  return (
    <div style={{ display: "grid", gridTemplateColumns: "repeat(4, 1fr)", gap: "0.2em", marginTop: "auto", paddingTop: "0.7em" }}>
      {items.map((item) => {
        const on = item === active;
        return (
          <div key={item} style={{ textAlign: "center", fontSize: "0.62em", fontWeight: on ? 700 : 500, color: on ? ink : ink3 }}>
            <div
              style={{
                width: "1.5em",
                height: "1.5em",
                margin: "0 auto 0.2em",
                borderRadius: "999px",
                background: on ? "#E8F3EC" : "transparent",
              }}
            />
            {item}
          </div>
        );
      })}
    </div>
  );
}

function Shell({ children, tab }: { children: ReactNode; tab: string }) {
  return (
    <div
      className="app-screen"
      style={{
        height: "100%",
        width: "100%",
        overflow: "hidden",
        background: "#F7F6F2",
        color: ink,
        containerType: "inline-size",
        fontFamily: "inherit",
      }}
    >
      <div
        style={{
          height: "100%",
          display: "flex",
          flexDirection: "column",
          padding: "2.65em 0.85em 0.65em",
          fontSize: "clamp(13px, 4.85cqi, 17px)",
          boxSizing: "border-box",
        }}
      >
        {children}
        <Tabs active={tab} />
      </div>
    </div>
  );
}

function TodayBody() {
  return (
    <Shell tab="Today">
      <div style={{ display: "flex", justifyContent: "space-between", alignItems: "flex-start", marginBottom: "0.7em" }}>
        <div>
          <div style={{ fontSize: "1.55em", fontWeight: 650, letterSpacing: "-0.03em" }}>Today</div>
          <div style={{ fontSize: "0.75em", color: ink2 }}>Friday, Nov 13</div>
        </div>
        <div
          style={{
            width: "2.1em",
            height: "2.1em",
            borderRadius: "999px",
            border: "1.5px solid #B98A32",
            display: "grid",
            placeItems: "center",
            fontSize: "0.7em",
            fontWeight: 700,
            color: "#966E24",
            background: "#FAF9F7",
          }}
        >
          MK
        </div>
      </div>
      <Card>
        <Kicker>Your day</Kicker>
        <div style={{ display: "grid", gridTemplateColumns: "repeat(3, 1fr)", gap: "0.3em", marginTop: "0.55em" }}>
          <Ring pct={65} color={sage} label="Activity" value="465 kcal" note="Goal 710" />
          <Ring pct={102} color={peach} label="Food" value="1,706 kcal" note="On track" />
          <Ring pct={81} color={lavender} label="Recovery" value="8.1 h" note="Ready" />
        </div>
      </Card>
      <div style={{ height: "0.55em" }} />
      <Card>
        <Kicker>Maya</Kicker>
        <div style={{ display: "flex", alignItems: "center", justifyContent: "space-between", marginTop: "0.35em", gap: "0.6em" }}>
          <div>
            <div style={{ fontWeight: 650, fontSize: "0.95em" }}>Let’s talk</div>
            <div style={{ fontSize: "0.72em", color: ink2 }}>What is today for?</div>
          </div>
          <div style={{ background: "#fff", border: `1px solid ${line}`, borderRadius: "999px", padding: "0.35em 0.7em", fontSize: "0.72em", fontWeight: 650 }}>
            Call
          </div>
        </div>
      </Card>
      <div style={{ height: "0.55em" }} />
      <Card>
        <Kicker>Up next</Kicker>
        <div style={{ marginTop: "0.3em", fontWeight: 650, fontSize: "0.95em" }}>Easy spin · 18:00</div>
        <div style={{ fontSize: "0.75em", color: ink2 }}>Legs are fresh. Keep it easy.</div>
      </Card>
    </Shell>
  );
}

function FoodBody() {
  return (
    <Shell tab="Meals">
      <div style={{ fontSize: "1.45em", fontWeight: 650, letterSpacing: "-0.03em" }}>Food</div>
      <div style={{ fontSize: "0.75em", color: ink2, marginBottom: "0.7em" }}>Log what you actually ate</div>
      <Card>
        <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center" }}>
          <div style={{ fontWeight: 650, fontSize: "0.95em" }}>From a photo</div>
          <div style={{ fontSize: "0.62em", fontWeight: 700, letterSpacing: "0.08em", color: "#A76432", background: "#F8EBE2", borderRadius: "999px", padding: "0.25em 0.5em" }}>
            PREMIUM
          </div>
        </div>
        <div style={{ fontSize: "0.74em", color: ink2, margin: "0.35em 0 0.7em" }}>
          Calories, protein, carbs, and fat. You confirm before it saves.
        </div>
        <div style={{ display: "grid", gridTemplateColumns: "1.2fr 1fr", gap: "0.45em" }}>
          <div style={{ background: peach, color: "#3d2918", borderRadius: "0.8em", textAlign: "center", padding: "0.55em 0.3em", fontWeight: 700, fontSize: "0.78em" }}>
            Take photo
          </div>
          <div style={{ background: "#fff", border: `1px solid ${line}`, borderRadius: "0.8em", textAlign: "center", padding: "0.55em 0.3em", fontWeight: 650, fontSize: "0.78em" }}>
            Library
          </div>
        </div>
      </Card>
      <div style={{ height: "0.55em" }} />
      <Card>
        <div style={{ display: "flex", justifyContent: "space-between", fontSize: "0.86em", fontWeight: 600 }}>
          <span>Scan barcode</span>
          <span style={{ color: ink3 }}>›</span>
        </div>
      </Card>
      <div style={{ height: "0.55em" }} />
      <Card>
        <Kicker>This plate</Kicker>
        <div style={{ marginTop: "0.35em", fontWeight: 650 }}>Grain bowl</div>
        <div style={{ display: "flex", gap: "0.7em", marginTop: "0.35em", fontSize: "0.78em" }}>
          <span style={{ color: peach, fontWeight: 700 }}>640 kcal</span>
          <span style={{ color: lavender }}>P 32</span>
          <span style={{ color: peach }}>C 71</span>
          <span style={{ color: sage }}>F 22</span>
        </div>
      </Card>
      <div style={{ height: "0.55em" }} />
      <Card>
        <Kicker>Today</Kicker>
        {[
          ["Breakfast", "420 kcal"],
          ["Lunch", "640 kcal"],
          ["Snack", "180 kcal"],
        ].map(([name, kcal]) => (
          <div key={name} style={{ display: "flex", justifyContent: "space-between", marginTop: "0.45em", fontSize: "0.86em" }}>
            <span style={{ fontWeight: 650 }}>{name}</span>
            <span style={{ color: ink2 }}>{kcal}</span>
          </div>
        ))}
      </Card>
    </Shell>
  );
}

function MealsBody() {
  return (
    <Shell tab="Meals">
      <div style={{ fontSize: "1.45em", fontWeight: 650, letterSpacing: "-0.03em" }}>Before 18:00</div>
      <div style={{ fontSize: "0.75em", color: ink2, marginBottom: "0.7em" }}>Eat for the session, not a template</div>
      <Card>
        <Kicker>Suggested</Kicker>
        <div style={{ marginTop: "0.4em", fontWeight: 650 }}>Rice, chicken, fruit</div>
        <div style={{ fontSize: "0.74em", color: ink2, marginTop: "0.2em" }}>Carbs and protein, about 90 minutes out.</div>
      </Card>
      <div style={{ height: "0.55em" }} />
      <Card>
        <div style={{ display: "flex", justifyContent: "space-between", alignItems: "baseline" }}>
          <span style={{ fontWeight: 650 }}>Water</span>
          <span style={{ color: teal, fontWeight: 700, fontSize: "0.85em" }}>1.2 L</span>
        </div>
        <div style={{ height: "0.35em", borderRadius: "999px", background: "#E6F5F8", marginTop: "0.45em" }}>
          <div style={{ width: "60%", height: "100%", borderRadius: "999px", background: teal }} />
        </div>
      </Card>
      <div style={{ height: "0.55em" }} />
      <Card>
        <Kicker>Also on the day</Kicker>
        <div style={{ marginTop: "0.4em", fontWeight: 650 }}>Greek yogurt and fruit</div>
        <div style={{ fontSize: "0.78em", color: ink2, marginTop: "0.2em" }}>After the ride, if you go.</div>
      </Card>
    </Shell>
  );
}

function ActivityBody() {
  return (
    <Shell tab="Today">
      <div style={{ fontSize: "1.45em", fontWeight: 650, letterSpacing: "-0.03em" }}>Training</div>
      <div style={{ fontSize: "0.75em", color: ink2, marginBottom: "0.7em" }}>The plan updates when you finish</div>
      <Card>
        <Kicker>Now</Kicker>
        <div style={{ marginTop: "0.35em", fontWeight: 650 }}>Easy spin · 45 min</div>
        <div style={{ fontSize: "0.74em", color: ink2 }}>No intervals. Heart rate stays easy.</div>
        <div style={{ marginTop: "0.6em", height: "0.35em", borderRadius: "999px", background: "#E8F3EC" }}>
          <div style={{ width: "40%", height: "100%", borderRadius: "999px", background: sage }} />
        </div>
      </Card>
      <div style={{ height: "0.55em" }} />
      <Card>
        <Kicker>From Apple Health</Kicker>
        <div style={{ marginTop: "0.4em", fontWeight: 650 }}>Ride · 16 km</div>
        <div style={{ fontSize: "0.78em", color: ink2 }}>Yesterday. The plan already counted it.</div>
      </Card>
    </Shell>
  );
}

function RecoveryBody() {
  return (
    <Shell tab="Today">
      <div style={{ fontSize: "1.45em", fontWeight: 650, letterSpacing: "-0.03em" }}>Recovery</div>
      <div style={{ fontSize: "0.75em", color: ink2, marginBottom: "0.7em" }}>Compared with your recent nights</div>
      <Card>
        <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center" }}>
          <div>
            <Kicker>Stress index</Kicker>
            <div style={{ fontSize: "1.6em", fontWeight: 650, letterSpacing: "-0.04em" }}>32</div>
            <div style={{ fontSize: "0.75em", color: sage, fontWeight: 700 }}>Moderate</div>
          </div>
          <Ring pct={81} color={lavender} label="Ready" value="Sleep 8.1 h" note="HRV up" />
        </div>
      </Card>
      <div style={{ height: "0.55em" }} />
      <Card>
        {[
          ["Sleep", "8 h 12 m"],
          ["HRV", "Up vs your week"],
          ["Resting HR", "Steady"],
        ].map(([name, note]) => (
          <div key={name} style={{ display: "flex", justifyContent: "space-between", gap: "0.8em", marginTop: "0.4em", fontSize: "0.84em" }}>
            <span style={{ fontWeight: 650 }}>{name}</span>
            <span style={{ color: ink2, textAlign: "right" }}>{note}</span>
          </div>
        ))}
      </Card>
    </Shell>
  );
}

function CoachBody() {
  return (
    <Shell tab="Coach">
      <div style={{ fontSize: "1.45em", fontWeight: 650, letterSpacing: "-0.03em" }}>Today’s call</div>
      <div style={{ fontSize: "0.75em", color: ink2, marginBottom: "0.7em" }}>One decision, with the reason</div>
      <Card>
        <Kicker>Do</Kicker>
        <div style={{ marginTop: "0.35em", fontWeight: 650 }}>Easy 45 min. Skip intervals.</div>
        <div style={{ fontSize: "0.74em", color: ink2, marginTop: "0.35em" }}>
          Sleep was solid. Yesterday’s ride is still in the legs.
        </div>
      </Card>
      <div style={{ height: "0.55em" }} />
      <Card>
        <Kicker>Maya</Kicker>
        <div style={{ marginTop: "0.3em", fontWeight: 650 }}>Talk it through</div>
        <div style={{ fontSize: "0.74em", color: ink2 }}>Move the hard block to tomorrow.</div>
      </Card>
    </Shell>
  );
}

export default function AppScreen({ variant = "today" }: { variant?: Variant }) {
  if (variant === "food") return <FoodBody />;
  if (variant === "meals") return <MealsBody />;
  if (variant === "activity") return <ActivityBody />;
  if (variant === "recovery") return <RecoveryBody />;
  if (variant === "coach") return <CoachBody />;
  return <TodayBody />;
}

export function appScreenForKey(key: string): Variant {
  switch (key) {
    case "meals":
    case "prep":
      return "meals";
    case "nutrition":
    case "food":
      return "food";
    case "activity":
    case "workout":
      return "activity";
    case "recovery":
      return "recovery";
    case "coach":
    case "night":
      return "coach";
    default:
      return "today";
  }
}

export function appScreenForJourney(key: string): Variant {
  switch (key) {
    case "prep":
      return "meals";
    case "workout":
      return "activity";
    case "recovery":
      return "recovery";
    case "night":
      return "coach";
    default:
      return "today";
  }
}
