import { ImageResponse } from "next/og";
import { readFileSync } from "node:fs";
import { join } from "node:path";
import { ENTITY } from "./site";

// Loaded once at build time (no network dependency during CI).
const fontRegular = readFileSync(join(process.cwd(), "assets/Inter-Regular.woff"));
const fontSemiBold = readFileSync(join(process.cwd(), "assets/Inter-SemiBold.woff"));
const fontBold = readFileSync(join(process.cwd(), "assets/Inter-Bold.woff"));
const iconBytes = readFileSync(join(process.cwd(), "assets-src/brand/logo-wf-mark.png"));
const iconSrc = `data:image/png;base64,${iconBytes.toString("base64")}`;
const MARK_ASPECT = 821 / 929;
const MARK_HEIGHT = 120;
const MARK_WIDTH = Math.round(MARK_HEIGHT * MARK_ASPECT);

export const OG_SIZE = { width: 1200, height: 630 };
export const OG_CONTENT_TYPE = "image/png";

const CANVAS = "#F7F6F2";
const GREEN = "#386B4D";

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
          background: `linear-gradient(135deg, #FFF9EC 0%, ${CANVAS} 55%, #F3F1EA 100%)`,
          color: "#292B28",
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
              "radial-gradient(900px 500px at 82% 12%, rgba(114,173,138,0.28), rgba(247,246,242,0) 60%), radial-gradient(700px 500px at 10% 100%, rgba(234,160,107,0.22), rgba(247,246,242,0) 55%)",
          }}
        />

        {/* brand row — WF mark only */}
        <div style={{ display: "flex", alignItems: "center" }}>
          {/* next/og ImageResponse requires native img, not next/image */}
          {/* eslint-disable-next-line @next/next/no-img-element */}
          <img
            src={iconSrc}
            width={MARK_WIDTH}
            height={MARK_HEIGHT}
            alt=""
          />
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
                color: "#5D5F5C",
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
            color: "#5D5F5C",
          }}
        >
          <div style={{ display: "flex", width: 10, height: 10, borderRadius: 10, background: GREEN }} />
          <span>weekfit.app</span>
          <span style={{ color: "#8F908B" }}>·</span>
          <span>{ENTITY.socialFooter ?? `${ENTITY.category} for ${ENTITY.platform}`}</span>
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
