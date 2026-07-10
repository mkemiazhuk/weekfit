/** Premium easing — calm, Apple/Linear-style curves. */
export const easeCalm = [0.22, 1, 0.36, 1] as const;

/** Shared motion durations (seconds). */
export const durationUI = 0.5;
export const durationReveal = 0.75;
export const durationRevealSlow = 0.85;
export const durationEntrance = 1.05;

export const springCalm = {
  type: "spring" as const,
  stiffness: 120,
  damping: 22,
  mass: 0.9,
};

export const springSoft = {
  type: "spring" as const,
  stiffness: 80,
  damping: 20,
  mass: 1,
};

export const fadeUp = (delay = 0, y = 20) => ({
  initial: { opacity: 0, y },
  animate: { opacity: 1, y: 0 },
  transition: { duration: durationRevealSlow, ease: easeCalm, delay },
});

export const stagger = 0.08;
