import type { CSSProperties } from "react";
import Icon, { type IconName } from "./Icon";
import AppleHealthMark from "./AppleHealthMark";

export function isAppleHealthIcon(icon: IconName) {
  return icon === "health";
}

export function topicIconTileClassName(icon: IconName, extra?: string) {
  const base = isAppleHealthIcon(icon) ? "icon-tile apple-health-tile" : "icon-tile";
  return extra ? `${base} ${extra}` : base;
}

export function topicIconTileStyle(icon: IconName, color: string): CSSProperties | undefined {
  if (isAppleHealthIcon(icon)) return undefined;
  return { background: `${color}1f`, border: `1px solid ${color}33` };
}

export default function TopicIcon({
  icon,
  color,
  size = 22,
  className,
}: {
  icon: IconName;
  color?: string;
  size?: number;
  className?: string;
}) {
  if (isAppleHealthIcon(icon)) {
    return <AppleHealthMark size={size} className={className} />;
  }
  return <Icon name={icon} color={color} size={size} className={className} />;
}
