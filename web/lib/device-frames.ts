import type { DeviceConfig } from "@mockifydev/react";

/** Self-hosted Apple Design Resources frames (see `public/mockify/`). */
export const MOCKIFY_BASE_PATH = "/mockify";

/** Apple Watch Ultra 2 — Blue Alpine Loop (screen cutout measured from PNG alpha). */
export const appleWatchUltra2: DeviceConfig = {
  name: "Apple Watch Ultra 2",
  frameSrc: "/devices/Apple Watch Ultra 2 - Blue Alpine Loop.png",
  framePngWidth: 600,
  framePngHeight: 940,
  screenLeftFraction: 50 / 600,
  screenTopFraction: 194 / 940,
  screenWidthFraction: 500 / 600,
  screenHeightFraction: 558 / 940,
  screenRadiusFraction: 55 / 600,
  statusBarSrc: "/status-bar/Notch Status Bar Black.png",
  statusBarHeightFraction: 0,
  colors: [],
};
