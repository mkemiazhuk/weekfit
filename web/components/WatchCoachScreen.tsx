interface WatchCoachScreenProps {
  accent: string;
  state?: string;
  title: string;
  body: string;
  coachLabel: string;
}

export default function WatchCoachScreen({
  accent,
  state,
  title,
  body,
  coachLabel,
}: WatchCoachScreenProps) {
  return (
    <div
      className="watch-coach-screen"
      style={{ "--accent-color": accent } as React.CSSProperties}
    >
      {state ? (
        <span className="watch-coach-screen__state">
          <span className="watch-coach-screen__dot" aria-hidden />
          {state}
        </span>
      ) : null}
      <p className="watch-coach-screen__label">{coachLabel}</p>
      <p className="watch-coach-screen__title">{title}</p>
      <p className="watch-coach-screen__body">{body}</p>
    </div>
  );
}
