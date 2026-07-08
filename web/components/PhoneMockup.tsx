"use client";

import Image from "next/image";
import clsx from "clsx";

interface PhoneMockupProps {
  src: string;
  alt: string;
  glow?: string; // accent color for the ambient bloom
  className?: string;
  priority?: boolean;
}

export default function PhoneMockup({
  src,
  alt,
  glow,
  className,
  priority,
}: PhoneMockupProps) {
  return (
    <div className={clsx("relative", className)}>
      {glow && (
        <div
          aria-hidden
          className="absolute -inset-[14%] -z-10 rounded-[50%]"
          style={{
            background: `radial-gradient(closest-side, ${glow}44, transparent 70%)`,
            filter: "blur(36px)",
          }}
        />
      )}
      <div
        className="relative w-full overflow-hidden rounded-[13.5%] p-[3%]"
        style={{
          aspectRatio: "900 / 1950",
          background:
            "linear-gradient(150deg, #202227, #0c0d11 60%, #060709)",
          border: "1px solid rgba(255,255,255,0.14)",
          boxShadow:
            "0 60px 130px -30px rgba(0,0,0,0.75), inset 0 0 0 1.5px rgba(255,255,255,0.04)",
        }}
      >
        {/* Dynamic Island */}
        <div
          aria-hidden
          className="absolute left-1/2 top-[2.4%] z-20 h-[2.4%] w-[30%] -translate-x-1/2 rounded-full bg-black"
        />
        {/* Screen */}
        <div className="relative h-full w-full overflow-hidden rounded-[11%]">
          <Image
            src={src}
            alt={alt}
            fill
            priority={priority}
            sizes="(max-width: 768px) 70vw, 320px"
            className="object-cover"
          />
          {/* Glass reflection */}
          <div
            aria-hidden
            className="pointer-events-none absolute inset-0 mix-blend-screen"
            style={{
              background:
                "linear-gradient(135deg, rgba(255,255,255,0.16) 0%, rgba(255,255,255,0.03) 22%, transparent 46%)",
            }}
          />
          <div
            aria-hidden
            className="pointer-events-none absolute inset-0"
            style={{
              boxShadow: "inset 0 0 40px rgba(0,0,0,0.35)",
            }}
          />
        </div>
      </div>
    </div>
  );
}
