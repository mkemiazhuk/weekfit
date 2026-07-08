/** Premium easing — calm, Apple/Linear-style curves. */
export const easeCalm = [0.22, 1, 0.36, 1] as const;

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

export const fadeUp = (delay = 0, y = 24) => ({
  initial: { opacity: 0, y },
  animate: { opacity: 1, y: 0 },
  transition: { duration: 0.85, ease: easeCalm, delay },
});

export const stagger = 0.08;
