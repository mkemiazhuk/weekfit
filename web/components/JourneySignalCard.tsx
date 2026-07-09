"use client";

import Image from "next/image";
import clsx from "clsx";

interface JourneySignalCardProps {
  accent: string;
  signal: string;
  tip: string;
  detail?: string;
  image?: string;
  imageAlt?: string;
  className?: string;
  floating?: boolean;
}

export default function JourneySignalCard({
  accent,
  signal,
  tip,
  detail,
  image,
  imageAlt = "",
  className,
  floating,
}: JourneySignalCardProps) {
  return (
    <div
      className={clsx(
        "premium-card card relative overflow-hidden p-4 backdrop-blur-xl md:p-5",
        floating && "coach-float",
        className
      )}
      style={{
        background: `linear-gradient(150deg, ${accent}24, rgba(255,255,255,0.05) 45%, rgba(255,255,255,0.02))`,
        border: `1px solid ${accent}3d`,
        boxShadow: `0 24px 60px -20px ${accent}55, 0 10px 30px -15px rgba(0,0,0,0.6)`,
      }}
    >
      <div className="relative flex items-start gap-3">
        {image ? (
          <div
            className="relative h-11 w-11 shrink-0 overflow-hidden rounded-[14px] md:h-12 md:w-12"
            style={{ boxShadow: `0 0 0 1px ${accent}33` }}
          >
            <Image src={image} alt={imageAlt} fill sizes="48px" className="object-cover" />
          </div>
        ) : (
          <span
            aria-hidden
            className="mt-0.5 flex h-11 w-11 shrink-0 items-center justify-center rounded-[14px] md:h-12 md:w-12"
            style={{
              color: accent,
              background: `${accent}1a`,
              border: `1px solid ${accent}33`,
            }}
          >
            <span
              className="h-1.5 w-1.5 rounded-full"
              style={{ background: accent, boxShadow: `0 0 8px ${accent}` }}
            />
          </span>
        )}
        <div className="min-w-0 flex-1">
          <p className="text-[14px] font-semibold leading-snug text-white md:text-[15px]">{signal}</p>
          <p className="mt-1.5 text-[12.5px] leading-snug text-white/62 md:text-[13px]">{tip}</p>
          {detail ? (
            <p className="mt-1.5 text-[11.5px] leading-snug text-white/42 md:text-[12px]">{detail}</p>
          ) : null}
        </div>
      </div>
    </div>
  );
}
