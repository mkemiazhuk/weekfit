/** Apple cycling workout view — vector UI for crisp scaling in the watch cutout. */
export default function WatchModularUltraScreen() {
  return (
    <div className="watch-workout" aria-hidden>
      <div className="watch-workout__header">
        <div className="watch-workout__sport" aria-hidden>
          <svg viewBox="0 0 16 16" width={10} height={10} fill="none">
            <circle cx="4.5" cy="10.5" r="1.1" fill="currentColor" />
            <circle cx="11.5" cy="10.5" r="1.1" fill="currentColor" />
            <path
              d="M4.5 10.5h7M6.2 8.2h1.4l1.1 2.3h2.8"
              stroke="currentColor"
              strokeWidth="1.15"
              strokeLinecap="round"
              strokeLinejoin="round"
            />
            <path
              d="M8.2 6.3c.8-.9 2-.9 2.6 0"
              stroke="currentColor"
              strokeWidth="1.1"
              strokeLinecap="round"
            />
          </svg>
        </div>
        <span className="watch-workout__clock">10:09</span>
      </div>

      <p className="watch-workout__timer">31:12.25</p>

      <div className="watch-workout__metrics">
        <div className="watch-workout__row">
          <span className="watch-workout__value">137</span>
          <span className="watch-workout__heart" aria-hidden>
            ♥
          </span>
        </div>

        <div className="watch-workout__row watch-workout__row--labeled">
          <span className="watch-workout__value">16.2</span>
          <span className="watch-workout__labels">
            <span>AVERAGE</span>
            <span>MPH</span>
          </span>
        </div>

        <div className="watch-workout__row watch-workout__row--labeled">
          <span className="watch-workout__value">
            372<span className="watch-workout__unit">FT</span>
          </span>
          <span className="watch-workout__labels">
            <span>ELEV</span>
            <span>GAINED</span>
          </span>
        </div>

        <div className="watch-workout__row">
          <span className="watch-workout__value">
            8.4<span className="watch-workout__unit">MI</span>
          </span>
        </div>
      </div>

      <div className="watch-workout__pages" aria-hidden>
        <span />
        <span className="is-active" />
        <span />
      </div>
    </div>
  );
}
