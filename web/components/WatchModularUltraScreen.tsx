import Image from "next/image";

/** Apple cycling workout screen — cropped from official watchOS 10 press imagery. */
export default function WatchModularUltraScreen() {
  return (
    <div className="box-border h-full w-full bg-black p-[4%_3%_5%_7%]">
      <Image
        src="/img/watch-cycling-workout.png"
        alt=""
        aria-hidden
        width={1000}
        height={1116}
        sizes="172px"
        className="h-full w-full object-contain"
        priority
      />
    </div>
  );
}
