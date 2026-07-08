import { ImageResponse } from "next/og";
import { readFileSync } from "node:fs";
import { join } from "node:path";
import { ENTITY } from "./site";

// Loaded once at build time (no network dependency during CI).
const fontRegular = readFileSync(join(process.cwd(), "assets/Inter-Regular.woff"));
const fontSemiBold = readFileSync(join(process.cwd(), "assets/Inter-SemiBold.woff"));
const fontBold = readFileSync(join(process.cwd(), "assets/Inter-Bold.woff"));
const iconBytes = readFileSync(join(process.cwd(), "public/brand/icon-192.png"));
const iconSrc = `data:image/png;base64,${iconBytes.toString("base64")}`;

export const OG_SIZE = { width: 1200, height: 630 };
export const OG_CONTENT_TYPE = "image/png";

const CANVAS = "#06070a";
const GREEN = "#66bc87";

export function renderOgImage(opts: {
  kicker?: string;
  title: string;
  subtitle?: string;
}) {
  const { kicker, title, subtitle } = opts;
  return new ImageResponse(
    (
      <div
        style={{
          width: "100%",
          height: "100%",
          display: "flex",
          flexDirection: "column",
          justifyContent: "space-between",
          padding: "72px 80px",
          background: `linear-gradient(135deg, #0a0d12 0%, ${CANVAS} 55%, #0a0710 100%)`,
          color: "#f5f6f8",
          fontFamily: "Inter",
          position: "relative",
        }}
      >
        {/* accent glow */}
        <div
          style={{
            position: "absolute",
            inset: 0,
            display: "flex",
            backgroundImage:
              "radial-gradient(900px 500px at 82% 12%, rgba(102,240,112,0.16), rgba(6,7,10,0) 60%), radial-gradient(700px 500px at 10% 100%, rgba(46,219,250,0.10), rgba(6,7,10,0) 55%)",
          }}
        />

        {/* brand row */}
        <div style={{ display: "flex", alignItems: "center", gap: 20 }}>
          <img
            src={iconSrc}
            width={76}
            height={76}
            style={{ borderRadius: 18 }}
            alt=""
          />
          <div style={{ display: "flex", fontSize: 34, fontWeight: 700, letterSpacing: -0.5 }}>
            <span style={{ color: "#ffffff" }}>Week</span>
            <span style={{ color: GREEN }}>Fit</span>
          </div>
        </div>

        {/* headline block */}
        <div style={{ display: "flex", flexDirection: "column", maxWidth: 940 }}>
          {kicker ? (
            <div
              style={{
                display: "flex",
                fontSize: 24,
                fontWeight: 600,
                letterSpacing: 4,
                textTransform: "uppercase",
                color: GREEN,
                marginBottom: 22,
              }}
            >
              {kicker}
            </div>
          ) : null}
          <div style={{ display: "flex", fontSize: 68, fontWeight: 700, lineHeight: 1.05, letterSpacing: -1.5 }}>
            {title}
          </div>
          {subtitle ? (
            <div
              style={{
                display: "flex",
                fontSize: 30,
                fontWeight: 400,
                lineHeight: 1.35,
                color: "rgba(245,246,248,0.66)",
                marginTop: 26,
                maxWidth: 900,
              }}
            >
              {subtitle}
            </div>
          ) : null}
        </div>

        {/* footer row */}
        <div
          style={{
            display: "flex",
            alignItems: "center",
            gap: 14,
            fontSize: 24,
            color: "rgba(245,246,248,0.5)",
          }}
        >
          <div style={{ display: "flex", width: 10, height: 10, borderRadius: 10, background: GREEN }} />
          <span>weekfit.app</span>
          <span style={{ color: "rgba(245,246,248,0.28)" }}>·</span>
          <span>{ENTITY.category} for {ENTITY.platform}</span>
        </div>
      </div>
    ),
    {
      ...OG_SIZE,
      fonts: [
        { name: "Inter", data: fontRegular, weight: 400, style: "normal" },
        { name: "Inter", data: fontSemiBold, weight: 600, style: "normal" },
        { name: "Inter", data: fontBold, weight: 700, style: "normal" },
      ],
    }
  );
}
