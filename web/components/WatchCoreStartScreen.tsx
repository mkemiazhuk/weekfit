/** Compact Up Next / Core start surface — matches Today screen activity card. */
export default function WatchCoreStartScreen() {
  return (
    <div className="watch-core-start" aria-hidden>
      <p className="watch-core-start__kicker">Up next</p>

      <div className="watch-core-start__icon" aria-hidden>
        <svg viewBox="0 0 24 24" width={18} height={18} fill="none">
          <path
            d="M6.5 9.5v5M17.5 9.5v5M8 8.5h-.75A1.75 1.75 0 0 0 5.5 10.25v3.5A1.75 1.75 0 0 0 7.25 15.5H8M16 8.5h.75A1.75 1.75 0 0 1 18.5 10.25v3.5A1.75 1.75 0 0 1 16.75 15.5H16M8 12h8"
            stroke="currentColor"
            strokeWidth={1.6}
            strokeLinecap="round"
            strokeLinejoin="round"
          />
        </svg>
      </div>

      <p className="watch-core-start__title">Core</p>
      <p className="watch-core-start__meta">
        Training session
        <span className="watch-core-start__dot" aria-hidden>
          ·
        </span>
        Endurance
      </p>

      <div className="watch-core-start__start">
        <span className="watch-core-start__start-icon" aria-hidden>
          <svg viewBox="0 0 16 16" width={11} height={11} fill="currentColor">
            <path d="M4.2 2.8v10.4l8.1-5.2L4.2 2.8z" />
          </svg>
        </span>
        <span>Start</span>
      </div>
    </div>
  );
}
