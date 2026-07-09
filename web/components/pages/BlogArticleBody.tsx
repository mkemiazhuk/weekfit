import type { Block, DocSection } from "@/lib/content";
import { pillars } from "@/lib/tokens";

function RichText({ text }: { text: string }) {
  const parts = text.split(/(\*\*[^*]+\*\*)/g);
  return (
    <>
      {parts.map((part, i) =>
        part.startsWith("**") && part.endsWith("**") ? (
          <strong key={i}>{part.slice(2, -2)}</strong>
        ) : (
          <span key={i}>{part}</span>
        )
      )}
    </>
  );
}

function Vo2Drop({
  before,
  after,
  labels,
}: {
  before: string;
  after: string;
  labels: [string, string];
}) {
  return (
    <div className="blog-vo2-drop not-prose surface-subtle my-6 grid grid-cols-[1fr_auto_1fr] items-center gap-3 p-5 sm:my-7 sm:gap-5 sm:p-6">
      <div className="text-center">
        <p className="kicker-sm">
          {labels[0]}
        </p>
        <p className="display mt-2 text-[clamp(2.4rem,8vw,3.2rem)] leading-none text-white/55">
          {before}
        </p>
      </div>
      <div
        aria-hidden
        className="flex h-10 w-10 shrink-0 items-center justify-center rounded-full text-lg text-white/50"
        style={{ background: `${pillars.activity}18`, border: `1px solid ${pillars.activity}33` }}
      >
        →
      </div>
      <div className="text-center">
        <p className="kicker-sm">
          {labels[1]}
        </p>
        <p
          className="display mt-2 text-[clamp(2.4rem,8vw,3.2rem)] leading-none"
          style={{ color: pillars.activity }}
        >
          {after}
        </p>
      </div>
    </div>
  );
}

function TrendChart({ values, caption }: { values: number[]; caption: string }) {
  const min = Math.min(...values) - 1;
  const max = Math.max(...values) + 1;
  const range = max - min || 1;
  const chartHeight = 96;

  return (
    <figure className="blog-trend not-prose surface-subtle my-6 p-5 sm:my-7 sm:p-6">
      <div className="flex items-end gap-1.5 sm:gap-2" style={{ height: chartHeight }}>
        {values.map((v, i) => {
          const barHeight = Math.max(((v - min) / range) * chartHeight, 10);
          const isLast = i === values.length - 1;
          return (
            <div key={i} className="flex h-full flex-1 flex-col items-center">
              <span className="mb-2 text-[10px] font-medium tabular-nums text-white/45 sm:text-[11px]">
                {v}
              </span>
              <div className="mt-auto flex w-full flex-col justify-end" style={{ height: chartHeight - 20 }}>
                <div
                  className="w-full rounded-t-[6px] transition-all"
                  style={{
                    height: barHeight,
                  background: isLast
                    ? `linear-gradient(180deg, ${pillars.activity}, ${pillars.activity}88)`
                    : "rgba(255,255,255,0.12)",
                  boxShadow: isLast ? `0 0 20px -4px ${pillars.activity}66` : undefined,
                }}
                />
              </div>
            </div>
          );
        })}
      </div>
      <figcaption className="mt-4 text-center text-[13px] leading-relaxed text-white/45">
        {caption}
      </figcaption>
    </figure>
  );
}

function CompareCards({
  left,
  right,
  question,
}: {
  left: { vo2: string; title: string; lines: string[] };
  right: { vo2: string; title: string; lines: string[] };
  question?: string;
}) {
  const card = (side: typeof left, accent: string) => (
    <div className="surface-chip p-4 sm:p-5">
      <p className="text-[11px] font-semibold uppercase tracking-[0.12em] text-white/40">
        {side.title}
      </p>
      <p className="display mt-2 text-[2rem] leading-none sm:text-[2.25rem]" style={{ color: accent }}>
        {side.vo2}
      </p>
      <ul className="mt-3 space-y-1.5 text-[14px] leading-snug text-white/55">
        {side.lines.map((line) => (
          <li key={line}>{line}</li>
        ))}
      </ul>
    </div>
  );

  return (
    <figure className="blog-compare not-prose my-6 sm:my-7">
      <div className="grid gap-3 sm:grid-cols-2 sm:gap-4">
        {card(left, pillars.recovery)}
        {card(right, pillars.activity)}
      </div>
      {question && (
        <figcaption className="mt-4 text-center text-[15px] font-medium text-white/70">
          {question}
        </figcaption>
      )}
    </figure>
  );
}

function BlockView({ block, lead }: { block: Block; lead?: boolean }) {
  switch (block.t) {
    case "p":
      return (
        <p className={lead ? "prose-lead" : undefined}>
          <RichText text={block.v} />
        </p>
      );
    case "h3":
      return <h3><RichText text={block.v} /></h3>;
    case "ul":
      return (
        <ul>
          {block.v.map((x) => (
            <li key={x}>
              <RichText text={x} />
            </li>
          ))}
        </ul>
      );
    case "quote":
      return (
        <blockquote>
          <RichText text={block.v} />
        </blockquote>
      );
    case "vo2-drop":
      return <Vo2Drop before={block.before} after={block.after} labels={block.labels} />;
    case "trend":
      return <TrendChart values={block.values} caption={block.caption} />;
    case "compare":
      return (
        <CompareCards left={block.left} right={block.right} question={block.question} />
      );
    case "divider":
      return <hr className="blog-divider" aria-hidden />;
    default:
      return null;
  }
}

export default function BlogArticleBody({ sections }: { sections: DocSection[] }) {
  return (
    <>
      {sections.map((s, si) => (
        <section key={s.id}>
          {s.h ? <h2 id={s.id}>{s.h}</h2> : null}
          {s.blocks.map((b, i) => (
            <BlockView key={`${s.id}-${i}`} block={b} lead={si === 0 && i === 0 && b.t === "p"} />
          ))}
        </section>
      ))}
    </>
  );
}
