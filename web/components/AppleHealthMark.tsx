/** Apple Health app icon — white tile, red heart (matches iOS Health). */
export default function AppleHealthMark({
  size = 20,
  className,
}: {
  size?: number;
  className?: string;
}) {
  return (
    <svg
      viewBox="0 0 24 24"
      width={size}
      height={size}
      className={className}
      aria-hidden
    >
      <rect
        x="0.75"
        y="0.75"
        width="22.5"
        height="22.5"
        rx="5.25"
        fill="#ffffff"
        stroke="rgba(0, 0, 0, 0.06)"
        strokeWidth="0.5"
      />
      {/* Heart sits slightly top-right, like the real Health icon */}
      <path
        fill="#FF2D55"
        d="M12.35 19.85s-5.15-3.45-5.15-7.55c0-2.05 1.55-3.45 3.45-3.45 1.05 0 1.95 0.5 2.35 1.25 0.4-0.75 1.3-1.25 2.35-1.25 1.9 0 3.45 1.4 3.45 3.45 0 4.1-5.15 7.55-5.15 7.55z"
      />
    </svg>
  );
}
