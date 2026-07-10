/** Premium easing — calm, Apple/Linear-style curves. */
export const easeCalm = [0.22, 1, 0.36, 1] as const;

/** Section entry reveals — soft editorial ease. */
export const easeReveal = [0.25, 1, 0.5, 1] as const;

/** Motion budget (seconds). */
export const durationMicro = 0.2;
export const durationUI = 0.2;
export const durationCard = 0.36;
export const durationReveal = 0.62;
export const durationRevealSlow = 0.68;
export const durationEntrance = 0.7;

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
  transition: { duration: durationRevealSlow, ease: easeReveal, delay },
});

export const stagger = 0.08;
