import React from "react";

export type IconName =
  | "start"
  | "health"
  | "recovery"
  | "nutrition"
  | "activity"
  | "coach"
  | "plan"
  | "trouble"
  | "mail"
  | "shield"
  | "sparkles";

const paths: Record<IconName, React.ReactNode> = {
  start: <path d="M12 2l2.4 5.6L20 9l-4.4 3.9L17 19l-5-3-5 3 1.4-6.1L4 9l5.6-1.4L12 2z" />,
  health: (
    <path d="M12 21s-7-4.35-7-9.5A3.5 3.5 0 0 1 12 8a3.5 3.5 0 0 1 7 3.5C19 16.65 12 21 12 21z" />
  ),
  recovery: (
    <path d="M12 3a9 9 0 1 0 9 9c-4 1-8-2-8-6 0-1.5.4-2.5 1-4-.7-.06-1.4 0-2 1z" />
  ),
  nutrition: (
    <>
      <path d="M8 5v6a2 2 0 0 0 4 0V5" />
      <path d="M10 5v14" />
      <path d="M16 5v4a2.5 2.5 0 0 1-2.5 2.5v9" />
    </>
  ),
  activity: <path d="M3 12h4l3 8 4-16 3 8h4" />,
  coach: (
    <path d="M12 2c1.1 0 2 .9 2 2 1.66 0 3 1.34 3 3 1.1 0 2 .9 2 2 0 .74-.4 1.38-1 1.72V13c0 3.31-2.69 6-6 6s-6-2.69-6-6v-.28C5.4 12.38 5 11.74 5 11c0-1.1.9-2 2-2 0-1.66 1.34-3 3-3 0-1.1.9-2 2-2z" />
  ),
  plan: (
    <path d="M4 5h16v16H4zM4 9h16M8 3v4M16 3v4" />
  ),
  trouble: (
    <path d="M12 3l9 16H3L12 3zM12 10v4M12 17h.01" />
  ),
  mail: <path d="M3 6h18v12H3zM3 7l9 6 9-6" />,
  shield: <path d="M12 2l8 3v6c0 5-3.5 8.5-8 11-4.5-2.5-8-6-8-11V5l8-3z" />,
  sparkles: (
    <path d="M12 3l1.8 4.2L18 9l-4.2 1.8L12 15l-1.8-4.2L6 9l4.2-1.8L12 3z" />
  ),
};

// Icons that read better as strokes than fills.
const stroked: IconName[] = ["nutrition", "activity", "plan", "trouble", "mail"];

export default function Icon({
  name,
  color = "currentColor",
  size = 22,
  className,
}: {
  name: IconName;
  color?: string;
  size?: number;
  className?: string;
}) {
  const isStroke = stroked.includes(name);
  return (
    <svg
      viewBox="0 0 24 24"
      width={size}
      height={size}
      className={className}
      fill={isStroke ? "none" : color}
      stroke={isStroke ? color : "none"}
      strokeWidth={isStroke ? 1.8 : 0}
      strokeLinecap="round"
      strokeLinejoin="round"
      aria-hidden
    >
      {paths[name]}
    </svg>
  );
}
