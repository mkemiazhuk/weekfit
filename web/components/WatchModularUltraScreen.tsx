/** WeekFit-themed Modular Ultra style watch face for the hero mockup. */
export default function WatchModularUltraScreen() {
  return (
    <div className="watch-modular" aria-hidden>
      <svg className="watch-modular__rings" viewBox="0 0 100 100" fill="none">
        <circle cx="50" cy="50" r="47.5" stroke="rgba(255,255,255,0.14)" strokeWidth="0.35" />
        <circle cx="50" cy="50" r="40" stroke="rgba(255,255,255,0.08)" strokeWidth="0.25" />
        {[0, 30, 60, 90, 120, 150, 180, 210, 240, 270, 300, 330].map((deg) => {
          const rad = ((deg - 90) * Math.PI) / 180;
          const x1 = 50 + Math.cos(rad) * 45.5;
          const y1 = 50 + Math.sin(rad) * 45.5;
          const x2 = 50 + Math.cos(rad) * 47.2;
          const y2 = 50 + Math.sin(rad) * 47.2;
          return (
            <line
              key={deg}
              x1={x1}
              y1={y1}
              x2={x2}
              y2={y2}
              stroke="rgba(255,255,255,0.22)"
              strokeWidth={deg % 90 === 0 ? 0.45 : 0.25}
            />
          );
        })}
        <text x="50" y="8.5" fill="rgba(255,255,255,0.38)" fontSize="3.2" fontWeight="700" textAnchor="middle">
          N
        </text>
        <text x="50" y="95.5" fill="rgba(255,255,255,0.28)" fontSize="2.8" fontWeight="700" textAnchor="middle">
          S
        </text>
        <circle cx="50" cy="18" r="1.15" fill="rgba(255,255,255,0.42)" />
        <circle cx="72" cy="28" r="1.05" fill="rgba(255,255,255,0.32)" />
        <circle cx="82" cy="50" r="1.05" fill="rgba(255,255,255,0.32)" />
        <circle cx="72" cy="72" r="1.05" fill="rgba(255,255,255,0.32)" />
        <circle cx="28" cy="72" r="1.05" fill="rgba(255,255,255,0.32)" />
      </svg>

      <div className="watch-modular__header">
        <span className="watch-modular__header-line">Up next</span>
        <span className="watch-modular__header-line watch-modular__header-line--sub">Core · 45 min</span>
      </div>

      <p className="watch-modular__time">07:00</p>

      <div className="watch-modular__corner watch-modular__corner--tl">
        <svg viewBox="0 0 36 36" width={28} height={28} aria-hidden>
          <path
            d="M18 4a14 14 0 0 1 0 28"
            stroke="rgba(46,219,250,0.22)"
            strokeWidth="3"
            fill="none"
            strokeLinecap="round"
          />
          <path
            d="M18 4a14 14 0 0 1 11.3 22.4"
            stroke="#2edbfa"
            strokeWidth="3"
            fill="none"
            strokeLinecap="round"
          />
        </svg>
        <span className="watch-modular__metric">81</span>
      </div>

      <div className="watch-modular__corner watch-modular__corner--tr">
        <div className="watch-modular__chip">
          <svg viewBox="0 0 16 16" width={8} height={8} fill="none" aria-hidden>
            <circle cx="8" cy="8" r="5.5" stroke="rgba(102,240,112,0.35)" strokeWidth="1.3" />
            <path
              d="M8 2.5a5.5 5.5 0 0 1 4.3 8.7"
              stroke="#66f070"
              strokeWidth="1.3"
              strokeLinecap="round"
            />
          </svg>
          <span>65%</span>
        </div>
      </div>

      <div className="watch-modular__corner watch-modular__corner--bl">
        <div className="watch-modular__chip watch-modular__chip--compact">
          <svg viewBox="0 0 16 16" width={7} height={7} fill="none" aria-hidden>
            <path
              d="M3.5 6.5v3M12.5 6.5v3M5 5.5h-.5a1 1 0 0 0-1 1v3a1 1 0 0 0 1 1H5M11 5.5h.5a1 1 0 0 1 1 1v3a1 1 0 0 1-1 1H11M5 8h6"
              stroke="currentColor"
              strokeWidth="1.1"
              strokeLinecap="round"
              strokeLinejoin="round"
            />
          </svg>
          <span>Core</span>
        </div>
      </div>

      <div className="watch-modular__corner watch-modular__corner--br">
        <div className="watch-modular__hero-ring">
          <svg viewBox="0 0 24 24" width={13} height={13} fill="none" aria-hidden>
            <path
              d="M4.5 12.5v4.5h4.5M19.5 11.5v-4.5h-4.5"
              stroke="currentColor"
              strokeWidth="1.5"
              strokeLinecap="round"
            />
            <path
              d="M8 8.5h8v7H8z"
              stroke="currentColor"
              strokeWidth="1.3"
              strokeLinejoin="round"
            />
          </svg>
          <span>Start</span>
        </div>
      </div>
    </div>
  );
}
