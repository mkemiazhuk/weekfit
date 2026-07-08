import Image from "next/image";
import clsx from "clsx";

export default function Wordmark({ className }: { className?: string }) {
  return (
    <a href="/" className={clsx("flex items-center gap-2.5", className)}>
      <Image
        src="/brand/icon-192.png"
        alt="WeekFit app icon"
        width={30}
        height={30}
        className="rounded-[8px]"
      />
      <span className="text-[17px] font-semibold tracking-[-0.02em] text-white">
        Week<span className="text-brand">Fit</span>
      </span>
    </a>
  );
}
