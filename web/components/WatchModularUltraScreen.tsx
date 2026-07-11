import Image from "next/image";

/** Apple Modular Ultra reference face — pre-rendered PNG for the hero watch cutout. */
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
