import type { DeviceConfig } from "@mockifydev/react";

/** Self-hosted Apple Design Resources frames (see `public/mockify/`). */
export const MOCKIFY_BASE_PATH = "/mockify";

/** Apple Watch Ultra 2 — Blue Alpine Loop (official bezel PNG, screen cutout measured). */
export const appleWatchUltra2: DeviceConfig = {
  name: "Apple Watch Ultra 2",
  frameSrc: "/devices/Apple Watch Ultra 2 - Blue Alpine Loop.png",
  framePngWidth: 600,
  framePngHeight: 940,
  screenLeftFraction: 120 / 600,
  screenTopFraction: 219 / 940,
  screenWidthFraction: 361 / 600,
  screenHeightFraction: 282 / 940,
  screenRadiusFraction: 0.055,
  statusBarSrc: "/status-bar/Notch Status Bar Black.png",
  statusBarHeightFraction: 0,
  colors: [],
};
