export interface CoachAdvice {
  matters: string;
  do: string;
  avoid: string;
  next: string;
  why?: string;
}

export interface CoachAdviceLabels {
  matters: string;
  do: string;
  avoid: string;
  next: string;
  why?: string;
}

export default function CoachAdviceList({
  advice,
  labels,
  compact,
  essential,
}: {
  advice: CoachAdvice;
  labels: CoachAdviceLabels;
  compact?: boolean;
  /** Mobile-friendly: only the three most actionable blocks. */
  essential?: boolean;
}) {
  const rows = essential
    ? [
        { key: "matters", label: labels.matters, text: advice.matters },
        { key: "do", label: labels.do, text: advice.do },
        { key: "next", label: labels.next, text: advice.next },
      ]
    : [
        { key: "matters", label: labels.matters, text: advice.matters },
        { key: "do", label: labels.do, text: advice.do },
        { key: "avoid", label: labels.avoid, text: advice.avoid },
        { key: "next", label: labels.next, text: advice.next },
      ];

  return (
    <div className={compact ? "mt-3 space-y-2.5" : "mt-4 space-y-3.5"}>
      {rows.map((row) => (
        <div key={row.key}>
          <p
            className={
              compact
                ? "text-[9px] font-bold uppercase tracking-[0.12em] text-white/35"
                : "kicker-sm text-white/40"
            }
          >
            {row.label}
          </p>
          <p
            className={
              compact
                ? "mt-0.5 text-[12.5px] leading-snug text-white/78"
                : "body-sm mt-1 text-white/75"
            }
          >
            {row.text}
          </p>
        </div>
      ))}
      {advice.why && labels.why && !essential ? (
        <div className={compact ? "border-t border-white/[0.06] pt-2.5" : "border-t border-white/[0.08] pt-4"}>
          <p className={compact ? "text-[9px] font-bold uppercase tracking-[0.12em] text-white/35" : "kicker-sm"}>
            {labels.why}
          </p>
          <p className={compact ? "mt-0.5 text-[12px] text-white/55" : "body-sm mt-1 text-white/55"}>
            {advice.why}
          </p>
        </div>
      ) : null}
    </div>
  );
}
