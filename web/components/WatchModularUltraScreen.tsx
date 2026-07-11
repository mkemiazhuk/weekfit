import Image from "next/image";

/** Pre-rendered Modular Ultra face — PNG @2x for crisp scaling in the watch cutout. */
export default function WatchModularUltraScreen() {
  return (
    <div className="watch-modular" aria-hidden>
      <Image
        src="/img/watch-modular-ultra.png"
        alt=""
        fill
        sizes="200px"
        className="watch-modular__img"
      />
    </div>
  );
}
