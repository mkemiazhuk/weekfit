import Image from "next/image";
import clsx from "clsx";
import {
  screenVariantDimensions,
  screenVariantForPhoneWidth,
  screenVariantPath,
} from "@/lib/responsive-images";
import type { ScreenImageKey } from "@/lib/screen-images";

interface ScreenShotImageProps {
  name: ScreenImageKey;
  alt: string;
  phoneWidthPx: number;
  className?: string;
  priority?: boolean;
  loading?: "eager" | "lazy";
  fill?: boolean;
  sizes?: string;
}

export default function ScreenShotImage({
  name,
  alt,
  phoneWidthPx,
  className,
  priority,
  loading,
  fill,
  sizes,
}: ScreenShotImageProps) {
  const variant = screenVariantForPhoneWidth(phoneWidthPx);
  const { width, height } = screenVariantDimensions(variant);

  return (
    <Image
      src={screenVariantPath(name, variant)}
      alt={alt}
      width={width}
      height={height}
      sizes={sizes ?? `${phoneWidthPx}px`}
      priority={priority}
      loading={loading}
      fill={fill}
      className={clsx(className)}
    />
  );
}
